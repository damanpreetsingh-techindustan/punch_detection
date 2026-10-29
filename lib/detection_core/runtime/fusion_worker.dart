import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../accel/shock_tracker.dart';
import '../audio/resampler.dart';
import '../calibration/quick_calibration.dart';
import '../config/detector_config.dart';
import '../engine/fusion_v2_engine.dart';
import '../scoring/logistic_scorer.dart';

/// Message protocol between the app (main isolate) and the fusionV2 worker
/// isolate. All times are detection-clock microseconds.
///
/// main -> worker (`op`):
///   init       {mount, scorer?: json}
///   pcm        {samples: Int16List, rate, firstUs}
///   accel      {data: Float64List [t, x, y, z, ...]}
///   touch      {t}          settings {open, t}      camera {on, t}
///   person     {t}          arm      {score, hand, t}
///   calibrate  {t}          stop
/// worker -> main (`type`):
///   ready, decision {decision, calibrating}, debug {state},
///   calibration {result}, error {message}
abstract final class FusionWorkerProtocol {
  static const int debugEveryUs = 250000;
}

/// The worker's logic without the isolate (unit-testable synchronously).
class FusionWorkerCore {
  FusionWorkerCore({
    required MountProfile mount,
    ScorerSet? scorer,
    DetectorConfig config = const DetectorConfig(),
  }) : engine = FusionV2Engine(config: config, mount: mount, scorer: scorer) {
    calibrator = QuickCalibrator(engine: engine);
  }

  final FusionV2Engine engine;
  late final QuickCalibrator calibrator;
  StreamingResampler? _resampler;
  int _lastDebugUs = 0;

  static const int coreRate = 16000;

  /// Handles one message and returns the replies to send back.
  List<Map<String, Object?>> handle(Map<Object?, Object?> msg) {
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];
    void emit(List<ImpactDecision> ds) {
      for (final ImpactDecision d in ds) {
        final bool calibrating = calibrator.isActive;
        if (calibrating) calibrator.addDecision(d);
        out.add(<String, Object?>{
          'type': 'decision',
          'calibrating': calibrating,
          'decision': d.toMap(),
        });
      }
    }

    final int? t = (msg['t'] as num?)?.toInt();
    switch (msg['op']) {
      case 'pcm':
        final Int16List samples = msg['samples']! as Int16List;
        final int rate = (msg['rate']! as num).toInt();
        final int firstUs = (msg['firstUs']! as num).toInt();
        if (rate == coreRate) {
          emit(engine.addAudio(samples, firstUs));
        } else {
          final StreamingResampler r = _resampler ??= StreamingResampler(
            inRate: rate,
            outRate: coreRate,
          );
          final int inBefore = r.inputSamples;
          final int outBefore = r.outputSamples;
          final Int16List resampled = r.process(samples);
          if (resampled.isNotEmpty) {
            // Time of the first output sample from its input position.
            final double inputPos = outBefore * rate / coreRate;
            final int outFirstUs =
                firstUs + ((inputPos - inBefore) * 1e6 / rate).round();
            emit(engine.addAudio(resampled, outFirstUs));
          }
        }
      case 'accel':
        final Float64List d = msg['data']! as Float64List;
        for (int i = 0; i + 3 < d.length; i += 4) {
          emit(
            engine.addAccel(
              AccelSampleIn(d[i].round(), d[i + 1], d[i + 2], d[i + 3]),
            ),
          );
        }
      case 'touch':
        engine.addTouch(t!);
        emit(engine.advance(t));
      case 'settings':
        engine.setSettingsOpen(msg['open'] == true, t!);
      case 'camera':
        engine.setCameraAvailable(msg['on'] == true, t!);
      case 'person':
        engine.notePersonValid(t!);
      case 'arm':
        engine.setArmActivity(
          (msg['score']! as num).toDouble(),
          msg['hand'] as String? ?? 'unknown',
          t!,
        );
      case 'calibrate':
        calibrator.start(t ?? engine.nowUs);
      case 'stop':
        emit(engine.flush());
    }

    final QuickCalibrationResult? cal = calibrator.finishIfDue(engine.nowUs);
    if (cal != null) {
      out.add(<String, Object?>{'type': 'calibration', 'result': cal.toMap()});
    }
    if (engine.nowUs - _lastDebugUs >= FusionWorkerProtocol.debugEveryUs) {
      _lastDebugUs = engine.nowUs;
      out.add(<String, Object?>{
        'type': 'debug',
        'nowUs': engine.nowUs,
        'calibrating': calibrator.isActive,
        'state': engine.debugState(),
      });
    }
    return out;
  }
}

/// Isolate entry point. The first message must be `init`.
void fusionWorkerMain(SendPort toMain) {
  final ReceivePort inbox = ReceivePort();
  toMain.send(inbox.sendPort);
  FusionWorkerCore? core;
  late final StreamSubscription<Object?> sub;
  sub = inbox.listen((Object? message) {
    if (message is! Map) return;
    try {
      if (message['op'] == 'init') {
        final Object? scorerJson = message['scorer'];
        core = FusionWorkerCore(
          mount: MountProfile.fromName(message['mount'] as String?),
          scorer: scorerJson is Map
              ? ScorerSet.fromJson(scorerJson.cast<String, Object?>())
              : null,
        );
        toMain.send(<String, Object?>{'type': 'ready'});
        return;
      }
      final FusionWorkerCore? c = core;
      if (c == null) return;
      for (final Map<String, Object?> reply in c.handle(message)) {
        toMain.send(reply);
      }
      if (message['op'] == 'stop') {
        sub.cancel();
        inbox.close();
      }
    } catch (e, st) {
      toMain.send(<String, Object?>{'type': 'error', 'message': '$e\n$st'});
    }
  });
}
