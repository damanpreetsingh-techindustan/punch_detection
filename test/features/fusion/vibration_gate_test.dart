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

    // ── One physical hit = one knock (fixes for false punches) ──────────────

    /// Hard hit at 1060 followed by the mount shaking down over ~140 ms
    /// (rebound + shrinking oscillation), sampled every 20 ms.
    void hardHitWithRingDown() {
      tracker.addSample(sensorMs: 1040, rawMag: 0.0, x: 0.0, y: 0.0, z: 0.0);
      tracker.addSample(sensorMs: 1060, rawMag: 2.5, x: 2.0, y: 0.4, z: 1.4);
    }

    void ringDownTail() {
      tracker.addSample(sensorMs: 1080, rawMag: 1.5, x: 1.2, y: 0.3, z: 0.8);
      tracker.addSample(sensorMs: 1100, rawMag: 0.7, x: -0.6, y: -0.1, z: -0.4);
      tracker.addSample(sensorMs: 1120, rawMag: 0.5, x: 0.4, y: 0.1, z: 0.3);
      tracker.addSample(sensorMs: 1140, rawMag: 0.3, x: -0.25, y: -0.05, z: -0.2);
      tracker.addSample(sensorMs: 1160, rawMag: 0.2, x: 0.15, y: 0.03, z: 0.1);
      tracker.addSample(sensorMs: 1180, rawMag: 0.1, x: -0.08, y: 0.0, z: -0.05);
      tracker.addSample(sensorMs: 1200, rawMag: 0.05, x: 0.04, y: 0.0, z: 0.03);
      tracker.addSample(sensorMs: 1220, rawMag: 0.0, x: 0.0, y: 0.0, z: 0.0);
    }

    test('ring-down after a CONFIRMED hit creates no new knock', () {
      hardHitWithRingDown();
      expect(tracker.allKnocks.length, 1);
      // Punch confirmed right on the first knock sample (as in the app).
      tracker.allKnocks.first.claimedByAudioTsMs = 1065;
      tracker.markKnockUsed(audioTsMs: 1065, punchNo: 1);

      ringDownTail();

      // Before the fix the rebound (1100) and the tail (1160) each became a
      // fresh unused knock that a shout could use to count a fake punch.
      expect(tracker.allKnocks.length, 1);
      expect(
        tracker.findUnusedKnock(fromMs: 1100, toMs: 1400, audioTsMs: 1230),
        isNull,
      );
    });

    test('a new punch landing on the ring-down IS a new knock', () {
      hardHitWithRingDown();
      tracker.allKnocks.first.claimedByAudioTsMs = 1065;
      tracker.markKnockUsed(audioTsMs: 1065, punchNo: 1);
      tracker.addSample(sensorMs: 1080, rawMag: 1.5, x: 1.2, y: 0.3, z: 0.8);
      tracker.addSample(sensorMs: 1100, rawMag: 0.7, x: -0.6, y: -0.1, z: -0.4);
      tracker.addSample(sensorMs: 1120, rawMag: 0.5, x: 0.4, y: 0.1, z: 0.3);
      tracker.addSample(sensorMs: 1140, rawMag: 0.3, x: -0.25, y: -0.05, z: -0.2);
      // Second punch 120 ms after the first, while the bag still shakes.
      tracker.addSample(sensorMs: 1180, rawMag: 2.4, x: 1.9, y: 0.4, z: 1.3);

      expect(tracker.allKnocks.length, 2);
      expect(tracker.allKnocks.last.timestampMs, 1180);
      expect(tracker.allKnocks.last.isUsed, isFalse);
    });

    test('a dropped sensor reading during a bag swing is not a knock', () {
      // Swing builds up smoothly on X: +0.02 m/s² per 20 ms, up to 0.42.
      for (int i = 0; i <= 21; i++) {
        final double x = 0.02 * i;
        tracker.addSample(sensorMs: 1000 + 20 * i, rawMag: x, x: x, y: 0.0, z: 0.0);
      }
      // Two readings missed (60 ms gap). Old rule compared with 0 → Δ0.46.
      tracker.addSample(sensorMs: 1480, rawMag: 0.46, x: 0.46, y: 0.0, z: 0.0);
      tracker.addSample(sensorMs: 1500, rawMag: 0.47, x: 0.47, y: 0.0, z: 0.0);

      expect(tracker.allKnocks, isEmpty);
    });

    test('the first reading after a long sensor pause only re-seeds', () {
      tracker.addSample(sensorMs: 1000, rawMag: 0.0, x: 0.0, y: 0.0, z: 0.0);
      // Monitor restarted 2 s later with the bag swinging.
      tracker.addSample(sensorMs: 3000, rawMag: 0.6, x: 0.5, y: 0.1, z: 0.3);
      expect(tracker.allKnocks, isEmpty);
      // A real hit after that is still detected.
      tracker.addSample(sensorMs: 3020, rawMag: 2.0, x: 1.8, y: 0.4, z: 1.0);
      expect(tracker.allKnocks.length, 1);
    });

    test('an impact keeps the knock it claimed (cannot collect a second one)', () {
      tracker.addSample(sensorMs: 1000, rawMag: 0.0, x: 0.0, y: 0.0, z: 0.0);
      tracker.addSample(sensorMs: 1020, rawMag: 1.0, x: 0.8, y: 0.2, z: 0.6);
      final first = tracker.findUnusedKnock(
        fromMs: 900,
        toMs: 1300,
        audioTsMs: 1100,
      );
      first!.claimedByAudioTsMs = 1100;
      // A later knock that is closer to the audio arrives.
      for (int t = 1040; t <= 1080; t += 20) {
        tracker.addSample(sensorMs: t, rawMag: 0.0, x: 0.0, y: 0.0, z: 0.0);
      }
      tracker.addSample(sensorMs: 1100, rawMag: 2.0, x: 1.6, y: 0.4, z: 1.1);
      expect(tracker.allKnocks.length, 2);

      final again = tracker.findUnusedKnock(
        fromMs: 900,
        toMs: 1300,
        audioTsMs: 1100,
      );
      expect(again!.id, first.id, reason: 'sticky claim');
      // The closer knock stays free for the next punch.
      expect(tracker.allKnocks.last.claimedByAudioTsMs, isNull);
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

    test('flurry 1-2 combo: hard hit followed by soft hit 180ms later both count cleanly', () {
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

    // ── Fast punching, soft follow-ups and false punches ────────────────────

    /// Mount at rest, one 3D reading every 20 ms in [from, to).
    void rest(int from, int to) {
      for (int t = from; t < to; t += 20) {
        rawVibe(0.0, t, x: 0.0, y: 0.0, z: 0.0);
      }
    }

    List<String> codes() =>
        controller.telemetryEvents.map((e) => e.decisionCode).toList();

    test('fast 1-2 combo 120 ms apart: both punches count', () {
      rest(0, 60);
      quiet(0, 60);
      camera(CameraGateState.valid, 40);

      // Punch 1 at 60 ms, then the mount rings down.
      rawVibe(2.0, 60, x: 1.6, y: 0.3, z: 1.1);
      frame(95.0, 60);
      rawVibe(0.8, 80, x: 0.6, y: 0.1, z: 0.5);
      rawVibe(0.3, 100, x: 0.2, y: 0.05, z: 0.2);
      rawVibe(0.1, 120, x: 0.05, y: 0.01, z: 0.08);
      rest(140, 180);
      quiet(70, 180);

      // Punch 2 at 180 ms = 120 ms after punch 1: inside the old 160 ms audio
      // lockout (was lost), past the new 100 ms knock lockout (counts).
      rawVibe(1.2, 180, x: 0.9, y: 0.2, z: 0.7);
      frame(90.0, 180);
      rest(200, 400);
      quiet(190, 400);

      expect(controller.punchCount.value, 2);
    });

    test('second punch arrives while the first is still waiting: both count', () {
      rest(0, 60);
      quiet(0, 60);
      camera(CameraGateState.valid, 40);

      frame(95.0, 60); // punch 1 audio, its vibration is late
      rest(60, 180);
      quiet(70, 170);
      frame(92.0, 170); // punch 2 audio while punch 1 is still open
      expect(controller.punchCount.value, 0, reason: 'both still waiting');

      rawVibe(1.0, 180, x: 0.8, y: 0.2, z: 0.6); // knock of punch 1
      rest(200, 260);
      quiet(180, 260);
      expect(controller.punchCount.value, 1);

      rawVibe(2.0, 260, x: 1.6, y: 0.3, z: 1.1); // knock of punch 2
      rest(280, 400);
      quiet(260, 400);

      // Before: punch 2 was dropped as IMPACT_ALREADY_PENDING.
      expect(controller.punchCount.value, 2);
      expect(codes(), isNot(contains('IMPACT_ALREADY_PENDING')));
    });

    test('shout 170 ms after a hard hit, during the ring-down: NOT counted', () {
      rest(0, 60);
      quiet(0, 60);
      camera(CameraGateState.valid, 40);

      rawVibe(2.5, 60, x: 2.0, y: 0.4, z: 1.4);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);

      // Mount shakes down (rebound + shrinking oscillation).
      rawVibe(1.5, 80, x: 1.2, y: 0.3, z: 0.8);
      rawVibe(0.7, 100, x: -0.6, y: -0.1, z: -0.4);
      rawVibe(0.5, 120, x: 0.4, y: 0.1, z: 0.3);
      rawVibe(0.3, 140, x: -0.25, y: -0.05, z: -0.2);
      rawVibe(0.2, 160, x: 0.15, y: 0.03, z: 0.1);
      rawVibe(0.1, 180, x: -0.08, y: 0.0, z: -0.05);
      rawVibe(0.05, 200, x: 0.04, y: 0.0, z: 0.03);
      rest(220, 240);
      quiet(70, 230);

      frame(95.0, 230); // coach shouts
      rest(240, 420);
      quiet(240, 420);

      expect(controller.punchCount.value, 1);
      expect(codes(), contains('IMPACT_REJECTED_NO_VIBRATION'));
    });

    test('hard punch then softer punch (below target) in the combo: both count', () {
      rest(0, 60);
      quiet(0, 60);
      camera(CameraGateState.valid, 40);

      rawVibe(2.0, 60, x: 1.6, y: 0.3, z: 1.1);
      frame(95.0, 60);
      rest(80, 260);
      quiet(70, 260);

      // Soft punch: 71 dB, 4 dB under the 75 dB target, with its own knock.
      rawVibe(0.5, 260, x: 0.4, y: 0.1, z: 0.3);
      frame(71.0, 260);
      rest(280, 460);
      quiet(270, 460);

      expect(controller.punchCount.value, 2);
    });

    test('the same soft punch WITHOUT a punch before it is not counted', () {
      rest(0, 260);
      quiet(0, 260);
      camera(CameraGateState.valid, 200);

      rawVibe(0.5, 260, x: 0.4, y: 0.1, z: 0.3);
      frame(71.0, 260);
      rest(280, 460);
      quiet(270, 460);

      expect(controller.punchCount.value, 0);
      expect(codes(), contains('AUDIO_BELOW_TARGET'));
    });

    test('a soft sound below target but with NO knock is not counted after a punch', () {
      rest(0, 60);
      quiet(0, 60);
      camera(CameraGateState.valid, 40);

      rawVibe(2.0, 60, x: 1.6, y: 0.3, z: 1.1);
      frame(95.0, 60);
      rest(80, 460);
      quiet(70, 260);
      frame(71.0, 260); // talking near the bag, no impact
      quiet(270, 460);

      expect(controller.punchCount.value, 1);
    });
  });

  group('Audio lockout without knock protection', () {
    test('pole mount keeps the 160 ms lockout (no knock to stop double counts)', () {
      AppConstants.changeSettingToDefault();
      AppConstants.warmUpDurationInMiliSeconds = 0;
      const int t0 = 1000000000000;
      final FreeSessionController controller = FreeSessionController(
        audioLevelService: _MockAudioLevelService(),
      );
      controller.sessionMode.value = DetectionMode.fusion;
      controller.mountType.value = MountType.pole;
      controller.isVisionConfirmationRequired.value = true;
      controller.isCameraInitialized.value = true;
      controller.isCameraUnavailable.value = false;
      controller.staticCalibratedAudioDb.value = 70.0;
      controller.customTargetAudioDb.value = 75.0;
      controller.minAudioPunchSpikeDb.value = 5.0;

      void frame(double db, int t) {
        controller.liveDecibelLevel.value = db;
        controller.checkPunchDetectionForTesting(frameTimestampMs: t0 + t);
      }

      for (int t = 0; t < 60; t += 10) {
        frame(50.0, t);
      }
      controller.setCameraObservationForTesting(
        CameraGateState.valid,
        atMs: t0 + 50,
      );
      frame(95.0, 60);
      for (int t = 70; t < 180; t += 10) {
        frame(50.0, t);
      }
      frame(95.0, 180); // 120 ms later: echo, must not be a second punch
      for (int t = 190; t < 300; t += 10) {
        frame(50.0, t);
      }

      expect(controller.punchCount.value, 1);
      controller.onClose();
    });
  });
}
