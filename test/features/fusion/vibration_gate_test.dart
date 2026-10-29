import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/impact_gate_evaluator.dart';
import 'package:punch_detection_demo/features/fusion/domain/vibration_gate/services/fresh_knock_gate.dart';
import 'package:punch_detection_demo/features/fusion/domain/vibration_gate/services/peak_threshold_gate.dart';
import 'package:punch_detection_demo/features/fusion/domain/vibration_gate/services/vibration_knock_tracker.dart';
import 'package:punch_detection_demo/features/fusion/domain/vibration_gate/vibration_gate_factory.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';
import 'dart:async';

class _MockAudioLevelService implements IAudioLevelService {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  @override
  Stream<double> get decibelStream => _controller.stream;

  @override
  Stream<AudioLevelSample> get sampleStream => _controller.stream.map(
    (double db) => AudioLevelSample(
      db: db,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  @override
  Map<String, Object?> get diagnostics => const <String, Object?>{};

  @override
  double get currentDecibels => 45.0;

  @override
  bool get isMonitoring => true;

  @override
  bool get isEarbudsConnected => false;

  @override
  Future<bool> checkEarbudsConnected() async => false;

  @override
  Future<bool> startMonitoring({int sampleIntervalMs = 50}) async => true;

  @override
  Future<void> stopMonitoring() async {}

  @override
  Future<void> updateSampleInterval(int newIntervalMs) async {}

  @override
  void dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VibrationKnockTracker Pure Mathematical Tests', () {
    late VibrationKnockTracker tracker;

    setUp(() {
      tracker = VibrationKnockTracker(
        minKnockDelta: 0.15,
        knockMergeMs: 40,
        maxKnockAgeMs: 3000,
      );
    });

    test('detects high-jerk impact collision knock in 3D acceleration', () {
      // Resting sample at t=0
      tracker.addSample(sensorMs: 1000, rawMag: 0.02, x: 0.01, y: 0.01, z: 0.01);
      expect(tracker.allKnocks.length, 0);

      // Sudden impact shockwave at t=20ms: sudden jump on X and Z axes
      tracker.addSample(sensorMs: 1020, rawMag: 0.85, x: 0.60, y: 0.05, z: -0.55);

      expect(tracker.allKnocks.length, 1);
      final knock = tracker.allKnocks.first;
      expect(knock.timestampMs, 1020);
      expect(knock.deltaMag, greaterThan(0.70));
      expect(knock.rawMag, 0.85);
      expect(knock.isUsed, false);
    });

    test('rejects smooth sinusoidal pendulum bag swing motion (no false knocks)', () {
      // Simulate heavy bag oscillation at 0.5 Hz (period = 2000ms), 50Hz sample rate (every 20ms)
      // Even with large peak amplitude (up to 2.5 m/s²), sample-to-sample jerk is smooth (~0.04 m/s²).
      const double peakAmplitude = 2.5;
      const double frequencyHz = 0.5;
      const int sampleIntervalMs = 20;

      for (int step = 0; step <= 100; step++) {
        final int tMs = 1000 + (step * sampleIntervalMs);
        final double timeSec = step * (sampleIntervalMs / 1000.0);
        final double rawMag = (peakAmplitude * sin(2 * pi * frequencyHz * timeSec)).abs();
        final double x = rawMag * 0.8;
        final double y = rawMag * 0.1;
        final double z = rawMag * 0.5;

        tracker.addSample(
          sensorMs: tMs,
          rawMag: rawMag,
          x: x,
          y: y,
          z: z,
        );
      }

      // Smooth swinging bag must NOT generate high-frequency collision knocks!
      expect(tracker.allKnocks.length, 0);
    });

    test('merges multi-axis rebound oscillations within 40ms into 1 single hit', () {
      // Hit onset at 1000ms
      tracker.addSample(sensorMs: 1000, rawMag: 0.02, x: 0.0, y: 0.0, z: 0.0);
      tracker.addSample(sensorMs: 1020, rawMag: 1.20, x: 1.0, y: 0.2, z: 0.6);
      expect(tracker.allKnocks.length, 1);

      // Physical bag leather rebound oscillation 15ms later (t=1035ms, <= 40ms)
      tracker.addSample(sensorMs: 1035, rawMag: 1.45, x: -0.8, y: 0.4, z: 1.1);

      // Must remain exactly 1 merged knock, tracking the maximum magnitude
      expect(tracker.allKnocks.length, 1);
      expect(tracker.allKnocks.first.rawMag, 1.45);
    });

    test('rapid combo 1-2 punch (120ms apart) creates two distinct unused knocks', () {
      // Punch 1 (Hard strike): jump from rest to 2.2 m/s² at t=1020
      tracker.addSample(sensorMs: 1000, rawMag: 0.02, x: 0.0, y: 0.0, z: 0.0);
      tracker.addSample(sensorMs: 1020, rawMag: 2.20, x: 1.8, y: 0.3, z: 1.2);
      expect(tracker.allKnocks.length, 1);

      // Decay samples at 1040, 1060, 1080, 1100
      tracker.addSample(sensorMs: 1040, rawMag: 0.80, x: 0.6, y: 0.1, z: 0.5);
      tracker.addSample(sensorMs: 1060, rawMag: 0.30, x: 0.2, y: 0.05, z: 0.2);
      tracker.addSample(sensorMs: 1080, rawMag: 0.15, x: 0.1, y: 0.02, z: 0.1);
      tracker.addSample(sensorMs: 1100, rawMag: 0.10, x: 0.05, y: 0.01, z: 0.08);

      // Punch 2 (Soft strike): sharp jump from 0.10 to 0.45 m/s² at t=1140 (120ms after Punch 1)
      tracker.addSample(sensorMs: 1140, rawMag: 0.45, x: 0.35, y: 0.05, z: 0.28);

      // Must identify both strikes as separate knocks
      expect(tracker.allKnocks.length, 2);
      expect(tracker.allKnocks[0].timestampMs, 1020);
      expect(tracker.allKnocks[0].rawMag, 2.20);
      expect(tracker.allKnocks[1].timestampMs, 1140);
      expect(tracker.allKnocks[1].rawMag, 0.45);
    });

    test('claims, consumes permanently, and releases knocks properly', () {
      tracker.addSample(sensorMs: 1000, rawMag: 0.0);
      tracker.addSample(sensorMs: 1020, rawMag: 0.6);

      // Find knock for audio spike at 1030ms
      final knock = tracker.findUnusedKnock(
        fromMs: 950,
        toMs: 1150,
        audioTsMs: 1030,
        minRawMag: 0.18,
      );
      expect(knock, isNotNull);
      knock!.claimedByAudioTsMs = 1030;

      // Cannot be claimed by another competing audio spike at 1035ms
      final competing = tracker.findUnusedKnock(
        fromMs: 950,
        toMs: 1150,
        audioTsMs: 1035,
        minRawMag: 0.18,
      );
      expect(competing, isNull);

      // Rejection releases the claim
      tracker.releaseClaim(1030);
      expect(knock.claimedByAudioTsMs, isNull);

      // Now audio at 1035 can claim it
      final reclaimed = tracker.findUnusedKnock(
        fromMs: 950,
        toMs: 1150,
        audioTsMs: 1035,
        minRawMag: 0.18,
      );
      expect(reclaimed, isNotNull);
      reclaimed!.claimedByAudioTsMs = 1035;

      // Punch confirmation consumes it permanently
      tracker.markKnockUsed(audioTsMs: 1035, punchNo: 1);
      expect(reclaimed.isUsed, true);
      expect(reclaimed.confirmedPunchNo, 1);

      // Never reused again
      final reused = tracker.findUnusedKnock(
        fromMs: 950,
        toMs: 1150,
        audioTsMs: 1040,
        minRawMag: 0.18,
      );
      expect(reused, isNull);
    });
  });

  group('FreshKnockGate Strategy Unit Tests', () {
    late FreshKnockGate gate;

    setUp(() {
      gate = FreshKnockGate();
    });

    test('returns present when an unused mechanical knock is within coincidence window', () {
      gate.addRawSample(sensorMs: 1000, rawMag: 0.0);
      gate.addRawSample(sensorMs: 1030, rawMag: 0.75, rawX: 0.5, rawY: 0.1, rawZ: 0.5);

      final eval = gate.evaluate(
        audioTsMs: 1050,
        fromMs: 930,
        toMs: 1170,
        threshold: 0.18,
        windowClosed: true,
        isVibrationDisabled: false,
      );

      expect(eval.state, VibrationGateState.present);
      expect(eval.matchedKnock, isNotNull);
      expect(eval.peakMagnitude, 0.75);
    });

    test('returns notRequired when vibration is disabled (pole mount)', () {
      final eval = gate.evaluate(
        audioTsMs: 1050,
        fromMs: 930,
        toMs: 1170,
        threshold: 0.18,
        windowClosed: true,
        isVibrationDisabled: true,
      );

      expect(eval.state, VibrationGateState.notRequired);
    });

    test('returns missing when no unused knock exists in window', () {
      gate.addRawSample(sensorMs: 500, rawMag: 0.0);
      gate.addRawSample(sensorMs: 520, rawMag: 0.6); // Too early, far outside window

      final eval = gate.evaluate(
        audioTsMs: 1050,
        fromMs: 930,
        toMs: 1170,
        threshold: 0.18,
        windowClosed: true,
        isVibrationDisabled: false,
      );

      expect(eval.state, VibrationGateState.missing);
      expect(eval.matchedKnock, isNull);
    });
  });

  group('PeakThresholdGate Strategy Unit Tests', () {
    late PeakThresholdGate gate;

    setUp(() {
      gate = PeakThresholdGate();
    });

    test('evaluates present when peak envelope exceeds threshold in window', () {
      gate.addEnvelopeSample(arrivalMs: 1040, magnitude: 0.45);

      final eval = gate.evaluate(
        audioTsMs: 1050,
        fromMs: 930,
        toMs: 1170,
        threshold: 0.18,
        windowClosed: true,
        isVibrationDisabled: false,
      );

      expect(eval.state, VibrationGateState.present);
      expect(eval.peakMagnitude, 0.45);
    });

    test('evaluates missing when envelope does not reach threshold', () {
      gate.addEnvelopeSample(arrivalMs: 1040, magnitude: 0.08);

      final eval = gate.evaluate(
        audioTsMs: 1050,
        fromMs: 930,
        toMs: 1170,
        threshold: 0.18,
        windowClosed: true,
        isVibrationDisabled: false,
      );

      expect(eval.state, VibrationGateState.missing);
    });
  });

  group('VibrationGateFactory SOLID OCP/DIP Tests', () {
    test('creates FreshKnockGate when vibrationGateType is knock', () {
      AppConstants.vibrationGateType = VibrationGateType.knock;
      final gate = VibrationGateFactory.create();
      expect(gate, isA<FreshKnockGate>());
      expect(gate.name, 'FreshKnockGate');
    });

    test('creates PeakThresholdGate when vibrationGateType is peakThreshold', () {
      AppConstants.vibrationGateType = VibrationGateType.peakThreshold;
      final gate = VibrationGateFactory.create();
      expect(gate, isA<PeakThresholdGate>());
      expect(gate.name, 'PeakThresholdGate');
      // Restore default
      AppConstants.vibrationGateType = VibrationGateType.knock;
    });
  });

  group('FreeSessionController with FreshKnockGate End-to-End Combinations', () {
    late FreeSessionController controller;
    const int t0 = 1000000000000;

    void frame(double db, int t) {
      controller.liveDecibelLevel.value = db;
      controller.checkPunchDetectionForTesting(frameTimestampMs: t0 + t);
    }

    void quiet(int from, int to) {
      for (int t = from; t < to; t += 10) {
        frame(50.0, t);
      }
    }

    void rawVibe(double mag, int t, {double? x, double? y, double? z}) {
      controller.vibrationGate.addRawSample(
        sensorMs: t0 + t,
        rawMag: mag,
        rawX: x,
        rawY: y,
        rawZ: z,
      );
      controller.ingestVibrationSampleForTesting(mag, atEpochMs: t0 + t);
    }

    void camera(CameraGateState state, int t) =>
        controller.setCameraObservationForTesting(state, atMs: t0 + t);

    setUp(() {
      AppConstants.changeSettingToDefault();
      AppConstants.vibrationGateType = VibrationGateType.knock;
      AppConstants.warmUpDurationInMiliSeconds = 0;
      controller = FreeSessionController(
        audioLevelService: _MockAudioLevelService(),
      );
      controller.sessionMode.value = DetectionMode.fusion;
      controller.mountType.value = MountType.wall;
      controller.minVibrationThreshold.value = 0.18;
      controller.isVisionConfirmationRequired.value = true;
      controller.isCameraInitialized.value = true;
      controller.isCameraUnavailable.value = false;
      controller.staticCalibratedAudioDb.value = 70.0;
      controller.customTargetAudioDb.value = 75.0;
      controller.minAudioPunchSpikeDb.value = 5.0;
    });

    tearDown(() => controller.onClose());

    test('flurry 1-2 combo: hard hit followed by soft hit 140ms later both count cleanly', () {
      // Baseline resting sensor
      rawVibe(0.02, 0, x: 0.0, y: 0.0, z: 0.0);
      quiet(0, 50);
      camera(CameraGateState.valid, 40);

      // Punch 1 (Hard strike): 2.0 m/s² vibration + 95 dB audio spike at 60ms
      rawVibe(2.0, 55, x: 1.6, y: 0.3, z: 1.1);
      frame(95.0, 60);

      expect(controller.punchCount.value, 1, reason: 'Punch 1 confirmed');

      // Vibration decays
      rawVibe(0.8, 80);
      rawVibe(0.3, 100);
      rawVibe(0.15, 120);
      quiet(70, 230);
      camera(CameraGateState.valid, 220);

      // Punch 2 (Soft strike): 0.35 m/s² vibration jump + 85 dB audio spike at 240ms (180ms after Punch 1)
      rawVibe(0.35, 235, x: 0.25, y: 0.05, z: 0.22);
      frame(85.0, 240);
      quiet(250, 380);

      expect(controller.punchCount.value, 2, reason: 'Punch 2 in combo confirmed cleanly without lockout');
    });

    test('loud voice while bag is swinging smoothly: rejected due to no mechanical knock', () {
      // Smooth bag oscillation: gradual ramp where delta per 20ms is only 0.03 m/s² (< 0.15 m/s² knock threshold),
      // but absolute vibration magnitude reaches 0.36 m/s² (> 0.18 m/s² threshold).
      for (int t = 0; t <= 240; t += 20) {
        final double mag = 0.03 * (t / 20);
        rawVibe(mag, t, x: mag * 0.8, y: 0.05, z: mag * 0.5);
      }
      quiet(0, 100);
      camera(CameraGateState.valid, 90);

      // Coach yells "HARDER!" reaching 95 dB audio spike at 100ms
      frame(95.0, 100);
      quiet(110, 260);

      // Must be rejected: swinging bag produces no shockwave knock!
      expect(controller.punchCount.value, 0);
      expect(
        controller.telemetryEvents.map((e) => e.decisionCode),
        contains('IMPACT_REJECTED_NO_VIBRATION'),
      );
    });
  });
}
