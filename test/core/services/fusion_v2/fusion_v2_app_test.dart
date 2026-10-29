import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/services/fusion_v2/fusion_v2_session.dart';
import 'package:punch_detection_demo/core/services/fusion_v2/native_pcm_capture.dart';
import 'package:punch_detection_demo/core/services/raw_sensors/raw_accelerometer_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/detection_core/accel/shock_tracker.dart';
import 'package:punch_detection_demo/detection_core/config/detector_config.dart';
import 'package:punch_detection_demo/detection_core/testing/synthetic_session.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';

class _SilentAudio implements IAudioLevelService {
  @override
  Stream<double> get decibelStream => const Stream<double>.empty();
  @override
  Stream<AudioLevelSample> get sampleStream =>
      const Stream<AudioLevelSample>.empty();
  @override
  Map<String, Object?> get diagnostics => const <String, Object?>{};
  @override
  double get currentDecibels => 0;
  @override
  bool get isMonitoring => false;
  @override
  bool get isEarbudsConnected => false;
  @override
  Future<bool> checkEarbudsConnected() async => false;
  @override
  Future<bool> startMonitoring({int? sampleIntervalMs}) async => true;
  @override
  Future<void> stopMonitoring() async {}
  @override
  Future<void> updateSampleInterval(int newIntervalMs) async {}
  @override
  void dispose() {}
}

Uint8List le16(Int16List samples) {
  final ByteData b = ByteData(samples.length * 2);
  for (int i = 0; i < samples.length; i++) {
    b.setInt16(2 * i, samples[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativePcmCapture timestamp mapping', () {
    test('Android: first sample from the AudioRecord HAL timestamp', () async {
      // detection clock = native ns / 1000 + 5 s; buffers arrive 2 ms late.
      const int offsetUs = 5000000;
      int now = 0;
      final NativePcmCapture cap = NativePcmCapture(nowUs: () => now);
      final List<PcmBatch> got = <PcmBatch>[];
      cap.batches.listen(got.add);
      // 160 frames starting at frame 1600; the HAL says frame 1000 was
      // captured at native 1.000 s -> frame 1600 at 1.0375 s.
      now = 1047500 + offsetUs + 2000;
      cap.handleEvent(<String, Object?>{
        'type': 'pcm',
        'data': le16(
          Int16List.fromList(List<int>.generate(160, (int i) => i - 80)),
        ),
        'frame': 1600,
        'count': 160,
        'tsFrame': 1000,
        'tsNs': 1000000000,
        'now': 1047500000,
        'sampleRate': 16000,
      });
      await Future<void>.delayed(Duration.zero);
      expect(got.single.timeSource, 'hal');
      expect(got.single.firstSampleUs, 1037500 + offsetUs + 2000);
      expect(got.single.samples.first, -80);
      expect(got.single.samples.last, 79);
    });

    test('iOS buffer host time and the arrival fallback', () async {
      int now = 0;
      final NativePcmCapture cap = NativePcmCapture(nowUs: () => now);
      final List<PcmBatch> got = <PcmBatch>[];
      cap.batches.listen(got.add);
      now = 2000000;
      cap.handleEvent(<String, Object?>{
        'type': 'pcm',
        'data': le16(Int16List(256)),
        'count': 256,
        'tsNs': 1990000000,
        'tsFrame': -1,
        'frame': -1,
        'now': 2000000000,
        'sampleRate': 48000,
      });
      now = 2010000;
      cap.handleEvent(<String, Object?>{
        'type': 'pcm',
        'data': le16(Int16List(160)),
        'tsNs': -1,
        'now': 2010000000,
        'sampleRate': 16000,
      });
      await Future<void>.delayed(Duration.zero);
      expect(got[0].timeSource, 'buffer');
      expect(got[0].firstSampleUs, 1990000);
      expect(got[1].timeSource, 'arrival');
      expect(got[1].firstSampleUs, 2010000 - 10000);
    });
  });

  test(
    'FusionV2Session runs the detector on isolates fed by the native streams',
    () async {
      final SyntheticSession s = SyntheticSession.golden();
      final StreamController<Object?> pcmEvents = StreamController<Object?>();
      final StreamController<Object?> accelEvents = StreamController<Object?>();
      int now = SyntheticSession.startUs;
      final FusionV2Session session = FusionV2Session(
        mount: MountProfile.wall,
        pcm: NativePcmCapture(eventSource: pcmEvents.stream, nowUs: () => now),
        accel: RawAccelerometerService(
          eventSource: accelEvents.stream,
          nowUs: () => now,
        ),
        useArmMotion: true,
      );
      final List<Map<String, Object?>> decisions = <Map<String, Object?>>[];
      session.decisions.listen(decisions.add);
      final List<Map<String, Object?>> arm = <Map<String, Object?>>[];
      session.armResults.listen(arm.add);
      expect(await session.start(), isTrue);
      session.camera(true, SyntheticSession.startUs);

      // Native clock == detection clock here (offset 0, no channel delay).
      int accelIdx = 0;
      final Int16List audio = s.input.audio;
      for (int i = 0; i + 160 <= audio.length; i += 160) {
        final int firstUs = SyntheticSession.startUs + (i * 62.5).round();
        now = firstUs + 10000;
        while (accelIdx < s.input.accel.length &&
            s.input.accel[accelIdx].tUs <= now) {
          final AccelSampleIn a = s.input.accel[accelIdx++];
          accelEvents.add(<String, Object?>{
            'type': 'batch',
            'now': a.tUs * 1000,
            't': <int>[a.tUs * 1000],
            'x': <double>[a.x],
            'y': <double>[a.y],
            'z': <double>[a.z],
          });
        }
        if (i % 1056 == 0) session.person(now);
        if (now >= SyntheticSession.startUs + 9020000 &&
            now < SyntheticSession.startUs + 9030000) {
          session.touch(SyntheticSession.startUs + 9020000);
        }
        pcmEvents.add(<String, Object?>{
          'type': 'pcm',
          'data': le16(Int16List.fromList(audio.sublist(i, i + 160))),
          'frame': i,
          'count': 160,
          'tsFrame': 0,
          'tsNs': SyntheticSession.startUs * 1000,
          'now': now * 1000,
          'sampleRate': 16000,
        });
        // Deliver like the platform does: buffers and sensor batches interleaved
        // in time order (the engine assumes the streams stay within 500 ms).
        await Future<void>.delayed(Duration.zero);
      }
      // One camera frame for the optical-flow isolate.
      expect(
        session.sendFrame(
          bytes: Uint8List(160 * 120),
          width: 160,
          height: 120,
          rowStride: 160,
          rotationDegrees: 0,
          tUs: now,
          bgra: false,
        ),
        isTrue,
      );
      for (int i = 0; i < 100; i++) {
        final int accepted = decisions
            .where(
              (Map<String, Object?> d) =>
                  (d['decision']! as Map)['accepted'] == true,
            )
            .length;
        if (accepted >= 5 && arm.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await session.stop();
      final List<int> accepted = <int>[
        for (final Map<String, Object?> d in decisions)
          if ((d['decision']! as Map)['accepted'] == true)
            ((d['decision']! as Map)['onsetUs']! as num).toInt(),
      ];
      expect(accepted.length, 5, reason: '$accepted');
      expect(arm, isNotEmpty);
    },
  );

  group('FreeSessionController with the fusionV2 engine', () {
    late FreeSessionController controller;
    const int t0 = 1000000000000;

    Map<String, Object?> decision({
      required int onsetMs,
      bool accepted = true,
      bool calibrating = false,
      String hand = 'left',
    }) => <String, Object?>{
      'type': 'decision',
      'calibrating': calibrating,
      'decision': <String, Object?>{
        'id': 1,
        'onsetUs': onsetMs * 1000,
        'decidedUs': (onsetMs + 35) * 1000,
        'latencyMs': 35.0,
        'accepted': accepted,
        'p': accepted ? 0.98 : 0.1,
        'pRaw': accepted ? 0.98 : 0.1,
        'path': accepted ? 'fast' : 'low',
        'reason': 'test',
        'mode': 'full',
        'audioCandidate': true,
        'shockCandidate': true,
        'hand': hand,
        'features': const <String, double>{},
        'context': const <String, double>{},
      },
    };

    setUp(() {
      AppConstants.changeSettingToDefault();
      controller = FreeSessionController(
        audioLevelService: _SilentAudio(),
        engine: DetectorEngine.fusionV2,
        clock: () => t0 + 100,
      );
    });

    tearDown(() => controller.onClose());

    testWidgets(
      'accepted decisions count; rejected and calibration ones do not',
      (WidgetTester tester) async {
        expect(controller.isFusionV2, isTrue);
        controller.handleFusionDecisionForTesting(decision(onsetMs: t0));
        controller.handleFusionDecisionForTesting(
          decision(onsetMs: t0 + 300, accepted: false),
        );
        controller.handleFusionDecisionForTesting(
          decision(onsetMs: t0 + 600, calibrating: true),
        );
        expect(controller.punchCount.value, 1);
        expect(controller.leftPunchCount.value, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500)); // hit-pulse timers
        // End-to-end latency recorded at the frame after the punch.
        expect(controller.fusionLatencyStats['e2eCount'], 1);
        expect(controller.fusionLatencyStats['e2eMedianMs'], 100);
        expect(controller.recorder.totals.counter('fusion.accepted'), 1);
        expect(controller.recorder.totals.counter('fusion.rejected'), 1);
        expect(controller.engineDebugText.value, contains('Engine: fusionV2'));
      },
    );

    testWidgets('the touch lockout also guards fusionV2 punches', (
      WidgetTester tester,
    ) async {
      controller.notifyPointerDown(atMs: t0);
      controller.handleFusionDecisionForTesting(decision(onsetMs: t0 + 200));
      expect(controller.punchCount.value, 0);
    });

    test('vibration-only mode keeps the legacy logic', () {
      final FreeSessionController c = FreeSessionController(
        audioLevelService: _SilentAudio(),
        engine: DetectorEngine.fusionV2,
      );
      c.sessionMode.value = DetectionMode.vibration;
      expect(c.isFusionV2, isFalse);
      c.onClose();
    });

    test('legacy is the default engine', () {
      final FreeSessionController c = FreeSessionController(
        audioLevelService: _SilentAudio(),
      );
      expect(c.detectorEngine, DetectorEngine.legacy);
      expect(c.isFusionV2, isFalse);
      c.onClose();
    });
  });
}
