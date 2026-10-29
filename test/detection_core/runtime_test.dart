import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/accel/shock_tracker.dart';
import 'package:punch_detection_demo/detection_core/audio/resampler.dart';
import 'package:punch_detection_demo/detection_core/calibration/quick_calibration.dart';
import 'package:punch_detection_demo/detection_core/config/detector_config.dart';
import 'package:punch_detection_demo/detection_core/engine/fusion_v2_engine.dart';
import 'package:punch_detection_demo/detection_core/replay/replay_runner.dart';
import 'package:punch_detection_demo/detection_core/runtime/fusion_worker.dart';
import 'package:punch_detection_demo/detection_core/testing/synthetic_session.dart';

/// The protocol messages the app sends for [input] (audio at [rate]).
List<Map<String, Object?>> messagesFor(ReplayInput input, {int rate = 16000}) {
  final List<(int, Map<String, Object?>)> timed =
      <(int, Map<String, Object?>)>[];
  Int16List audio = input.audio;
  if (rate != 16000) {
    audio = StreamingResampler(inRate: 16000, outRate: rate).process(audio);
  }
  final int chunk = rate ~/ 100; // 10 ms
  for (int i = 0; i + chunk <= audio.length; i += chunk) {
    final int firstUs = input.audioStartUs + (i * 1e6 / rate).round();
    timed.add((
      firstUs + 10000,
      <String, Object?>{
        'op': 'pcm',
        'samples': Int16List.fromList(audio.sublist(i, i + chunk)),
        'rate': rate,
        'firstUs': firstUs,
      },
    ));
  }
  for (int i = 0; i < input.accel.length; i += 2) {
    final List<double> d = <double>[
      for (final AccelSampleIn a in input.accel.sublist(
        i,
        i + 2 > input.accel.length ? input.accel.length : i + 2,
      )) ...<double>[a.tUs.toDouble(), a.x, a.y, a.z],
    ];
    timed.add((
      d[d.length - 4].round(),
      <String, Object?>{'op': 'accel', 'data': Float64List.fromList(d)},
    ));
  }
  for (final ContextEvent e in input.events) {
    final Map<String, Object?> m = switch (e.kind) {
      'touch' => <String, Object?>{'op': 'touch', 't': e.tUs},
      'camera_on' => <String, Object?>{'op': 'camera', 'on': true, 't': e.tUs},
      'person_valid' => <String, Object?>{'op': 'person', 't': e.tUs},
      _ => <String, Object?>{'op': 'noop'},
    };
    timed.add((e.tUs, m));
  }
  timed.sort(
    ((int, Map<String, Object?>) a, (int, Map<String, Object?>) b) =>
        a.$1.compareTo(b.$1),
  );
  return <Map<String, Object?>>[
    for (final (int, Map<String, Object?>) t in timed) t.$2,
    <String, Object?>{'op': 'stop'},
  ];
}

List<int> acceptedOnsets(Iterable<Map<String, Object?>> replies) => <int>[
  for (final Map<String, Object?> r in replies)
    if (r['type'] == 'decision' && (r['decision']! as Map)['accepted'] == true)
      ((r['decision']! as Map)['onsetUs']! as num).toInt(),
];

void main() {
  final SyntheticSession s = SyntheticSession.golden();
  final List<int> expected = <int>[
    for (final SyntheticEvent e in s.events)
      if (e.expectAccepted) e.onsetUs,
  ];

  void expectSameHits(List<int> got, {int toleranceUs = 3000}) {
    expect(got.length, expected.length, reason: 'accepted $got');
    for (int i = 0; i < expected.length; i++) {
      expect((got[i] - expected[i]).abs(), lessThan(toleranceUs));
    }
  }

  group('FusionWorkerCore (worker logic, synchronous)', () {
    test('16 kHz input gives the golden decisions and debug states', () {
      final FusionWorkerCore core = FusionWorkerCore(mount: MountProfile.wall);
      final List<Map<String, Object?>> replies = <Map<String, Object?>>[
        for (final Map<String, Object?> m in messagesFor(s.input))
          ...core.handle(m),
      ];
      expectSameHits(acceptedOnsets(replies));
      final Map<String, Object?> debug = replies.lastWhere(
        (Map<String, Object?> r) => r['type'] == 'debug',
      );
      expect((debug['state']! as Map)['audioFloorsDb'], isA<List<double>>());
    });

    test('44.1 kHz input (iOS) is resampled with correct timing', () {
      final FusionWorkerCore core = FusionWorkerCore(mount: MountProfile.wall);
      final List<Map<String, Object?>> replies = <Map<String, Object?>>[
        for (final Map<String, Object?> m in messagesFor(s.input, rate: 44100))
          ...core.handle(m),
      ];
      expectSameHits(acceptedOnsets(replies), toleranceUs: 4000);
    });
  });

  test('the worker isolate runs the core off the main isolate', () async {
    final ReceivePort fromWorker = ReceivePort();
    final Completer<SendPort> toWorker = Completer<SendPort>();
    final List<Map<String, Object?>> replies = <Map<String, Object?>>[];
    final Completer<void> ready = Completer<void>();
    fromWorker.listen((Object? m) {
      if (m is SendPort) {
        toWorker.complete(m);
      } else if (m is Map) {
        final Map<String, Object?> r = m.cast<String, Object?>();
        if (r['type'] == 'ready') ready.complete();
        replies.add(r);
      }
    });
    final Isolate isolate = await Isolate.spawn(
      fusionWorkerMain,
      fromWorker.sendPort,
    );
    final SendPort port = await toWorker.future;
    port.send(<String, Object?>{'op': 'init', 'mount': 'wall'});
    await ready.future;
    for (final Map<String, Object?> m in messagesFor(s.input)) {
      port.send(m);
    }
    // Wait for the final flush to come back.
    for (
      int i = 0;
      i < 100 && acceptedOnsets(replies).length < expected.length;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    isolate.kill();
    fromWorker.close();
    expectSameHits(acceptedOnsets(replies));
  });

  group('QuickCalibrator', () {
    test('learns lag, strength seeds and ring from 5 punches (2 low)', () {
      // A calibration session: 3 normal and 2 low punches, 1.5 s apart.
      final SyntheticSession cal = SyntheticSession.golden(seed: 5);
      final FusionV2Engine engine = FusionV2Engine(mount: MountProfile.wall);
      final QuickCalibrator calibrator = QuickCalibrator(engine: engine);
      calibrator.start(SyntheticSession.startUs);
      runReplay(engine, cal.input, onDecision: calibrator.addDecision);
      final QuickCalibrationResult r = calibrator.finish();
      expect(r.ok, isTrue, reason: r.message);
      expect(r.punches, greaterThanOrEqualTo(5));
      expect(r.lowPunches, greaterThanOrEqualTo(1));
      expect(r.lagMs, inInclusiveRange(1, 6)); // synthetic shocks lag by 3 ms
      expect(r.ringTauMs, closeTo(150, 25));
      expect(r.audioStrengthDb, greaterThan(15));
      expect(engine.medianAudioStrengthDb, r.audioStrengthDb);
      expect(engine.learnedLagMs, closeTo(r.lagMs!, 1e-9));
    });

    test('too few punches keeps the defaults', () {
      final FusionV2Engine engine = FusionV2Engine(mount: MountProfile.wall);
      final QuickCalibrator calibrator = QuickCalibrator(engine: engine)
        ..start(0);
      final QuickCalibrationResult r = calibrator.finish();
      expect(r.ok, isFalse);
      expect(engine.medianAudioStrengthDb, 20);
    });
  });
}
