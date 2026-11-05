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

    // Readings below are real 50 Hz wall-mount samples from a session where
    // these punches were lost (2026-11-05 rapid flurries).
    void feed(List<List<double>> rows) {
      for (final List<double> r in rows) {
        tracker.addSample(
          sensorMs: r[0].toInt(),
          x: r[1],
          y: r[2],
          z: r[3],
          rawMag: r[4],
        );
      }
    }

    test('a hit jumping from near rest on a big shake is a new knock', () {
      feed(const <List<double>>[
        [15253, 2.089, -2.956, 4.206, 5.549],
        [15273, -34.390, -1.993, 5.993, 34.965], // hit 2
        [15293, -12.231, -6.172, -20.037, 24.272],
        [15313, -8.926, 1.060, 19.871, 21.810],
        [15333, 5.774, -0.891, -9.047, 10.770],
        [15353, 1.673, 1.414, 1.978, 2.951],
        [15373, 1.310, -0.150, 1.591, 2.066],
        [15393, -7.435, -9.500, 21.770, 24.889], // hit 3: 2.1 -> 24.9
        [15413, -7.782, 3.779, -10.441, 13.559],
        [15433, 0.075, 1.066, 5.241, 5.349],
        [15453, 8.529, -5.059, 1.892, 10.096], // tail bump, not a hit
      ]);
      // Hit 3 starts at 15393; its knock keeps the strongest jerk (15413).
      expect(tracker.allKnocks.map((k) => k.timestampMs).toList(), <int>[
        15273,
        15413,
      ]);
    });

    test('the merge window does not slide onto the next punch', () {
      feed(const <List<double>>[
        [22939, 2.673, -0.535, -1.020, 2.910],
        [22959, -7.565, 1.114, -1.180, 7.737], // hit A starts
        [22979, 0.779, 5.041, -2.253, 5.576],
        [22999, 3.378, -5.364, 9.962, 11.808],
        [23019, 1.139, -1.075, -1.713, 2.321],
        [23039, 23.207, 9.464, 0.465, 25.066], // hit B, 80 ms after A
        [23059, 13.648, -3.388, -4.869, 14.881],
      ]);
      expect(tracker.allKnocks, hasLength(2));
      expect(tracker.allKnocks.last.timestampMs, 23039);
    });

    test('fast combo hit 60 ms after a hit gets its own knock; tail does not', () {
      feed(const <List<double>>[
        [24800, -4.511, -6.444, 4.560, 9.093],
        [24820, -20.576, -2.748, -18.068, 27.521], // hit
        [24840, 0.199, 5.280, 6.702, 8.535],
        [24860, 2.823, -4.612, 2.702, 6.045],
        [24880, -24.858, 2.110, 5.433, 25.532], // next hit: 6.0 -> 25.5
        [24900, 3.193, 1.024, -9.679, 10.243],
        [24921, -1.940, -0.307, 10.897, 11.073],
        [24941, 3.848, -0.750, -4.665, 6.094],
        [24961, -0.656, 2.605, -0.602, 2.753],
        [24981, 1.955, -1.471, 2.989, 3.863],
        [25001, 2.315, 0.807, -1.333, 2.790],
      ]);
      expect(tracker.allKnocks, hasLength(2));
      expect(tracker.allKnocks.last.timestampMs, inInclusiveRange(24880, 24900));
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
      // Body motion is covered by body_motion_gate_test; keep it off here.
      controller.isBodyMotionGateEnabled.value = false;
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

      frame(95.0, 60); // punch 1 audio
      rest(60, 100);
      rawVibe(1.0, 100, x: 0.8, y: 0.2, z: 0.6); // its knock, 40 ms late
      rest(120, 180);
      quiet(70, 170);
      expect(controller.punchCount.value, 0, reason: 'late knock: waits');

      frame(92.0, 170); // punch 2 audio while punch 1 is still open
      rawVibe(2.0, 180, x: 1.6, y: 0.3, z: 1.1); // knock of punch 2
      quiet(180, 200);
      expect(controller.punchCount.value, 1, reason: 'punch 2 has its knock');

      camera(CameraGateState.valid, 200);
      rest(200, 400);
      quiet(200, 400);

      // Before: punch 2 was dropped as IMPACT_ALREADY_PENDING.
      expect(controller.punchCount.value, 2);
      expect(codes(), isNot(contains('IMPACT_ALREADY_PENDING')));
    });

    test('a sound with no hit on the bag cannot take the next punch\'s knock', () {
      rest(0, 60);
      quiet(0, 60);
      camera(CameraGateState.valid, 40);

      frame(95.0, 60); // loud sound, bag at rest
      rest(60, 140);
      quiet(70, 150);
      rawVibe(2.0, 140, x: 1.6, y: 0.3, z: 1.1); // knock of the next punch
      frame(95.0, 150); // next punch, 90 ms later
      rest(160, 400);
      quiet(160, 400);

      // Before: the first sound took this knock (80 ms after it) and the real
      // punch was rejected; the last punch of a fast combo was lost this way.
      expect(controller.punchCount.value, 1);
      final valid =
          controller.telemetryEvents.where((e) => e.isValidPunch).toList();
      expect(valid.single.timestampMs, t0 + 150);
    });

    test('a punch landing on the still-shaking bag is counted (recorded readings)', () {
      // Real 50 Hz readings of two punches 142 ms apart. The second hit the
      // bag while it was still shaking and made no clean knock.
      rest(0, 40);
      quiet(0, 90);
      camera(CameraGateState.valid, 30);
      rawVibe(1.084, 40, x: -0.194, y: 0.288, z: 1.027);
      rawVibe(1.393, 60, x: -0.603, y: 0.026, z: -1.256);
      rawVibe(12.830, 80, x: -12.759, y: 0.740, z: 1.128);
      frame(95.0, 93);
      expect(controller.punchCount.value, 1);

      rawVibe(8.149, 100, x: -4.478, y: 4.304, z: 5.276);
      rawVibe(10.908, 120, x: 6.763, y: -5.416, z: 6.626);
      rawVibe(5.288, 140, x: 3.358, y: 0.597, z: -4.041);
      rawVibe(5.448, 160, x: -4.915, y: 2.265, z: -0.630);
      rawVibe(2.753, 180, x: 0.362, y: -2.634, z: 0.716);
      rawVibe(7.916, 200, x: 7.243, y: 2.848, z: -1.448);
      rawVibe(12.167, 220, x: 3.245, y: -0.883, z: -11.693);
      quiet(103, 235);
      frame(95.0, 235);
      rawVibe(5.754, 240, x: 3.309, y: 1.907, z: 4.303);
      rawVibe(2.138, 260, x: 0.629, y: -0.147, z: -2.038);
      rawVibe(1.964, 280, x: -1.216, y: 0.252, z: -1.521);
      rawVibe(2.794, 300, x: -0.620, y: -0.578, z: 2.662);
      rest(320, 420);
      quiet(245, 420);

      expect(controller.punchCount.value, 2);
    });

    test('a loud sound while the bag barely moves is not counted (recorded readings)', () {
      // Real readings and sound times of three punches of a fast combo,
      // then a loud sound 98 ms later while the bag stays at 3-6 m/s².
      quiet(0, 30);
      camera(CameraGateState.valid, 0);
      rawVibe(2.577, 6, x: 0.000, y: -0.607, z: -2.504);
      rawVibe(13.325, 26, x: -12.751, y: 3.113, z: -2.298);
      frame(95.0, 36); // punch 1
      rawVibe(9.388, 46, x: 0.826, y: 2.803, z: 8.922);
      rawVibe(9.508, 66, x: 6.778, y: -5.828, z: 3.241);
      rawVibe(6.079, 86, x: 3.474, y: 2.480, z: -4.328);
      rawVibe(1.998, 106, x: -1.740, y: 0.951, z: -0.252);
      rawVibe(14.613, 126, x: -14.099, y: -2.218, z: 3.134);
      rawVibe(14.765, 146, x: 11.725, y: -0.614, z: -8.952);
      quiet(46, 150);
      frame(95.0, 152); // punch 2
      rawVibe(12.276, 166, x: -9.394, y: 0.440, z: 7.891);
      rawVibe(6.740, 186, x: 3.569, y: -1.398, z: -5.544);
      rawVibe(2.028, 206, x: 0.448, y: 1.380, z: -1.416);
      rawVibe(1.263, 226, x: 0.195, y: -1.117, z: 0.557);
      rawVibe(3.318, 246, x: 1.319, y: 0.500, z: -3.004);
      rawVibe(20.196, 266, x: 18.859, y: 4.687, z: -5.500);
      quiet(162, 287);
      frame(95.0, 287); // punch 3
      rawVibe(18.074, 286, x: 3.077, y: 6.355, z: -16.638);
      rawVibe(13.753, 306, x: -3.190, y: -4.580, z: 12.569);
      rawVibe(4.789, 326, x: 0.464, y: -2.670, z: -3.949);
      rawVibe(5.692, 346, x: -4.194, y: 3.585, z: -1.402);
      rawVibe(4.257, 366, x: -2.146, y: -3.344, z: 1.528);
      camera(CameraGateState.valid, 370);
      quiet(297, 385);
      frame(95.0, 385); // loud sound, no hit on the bag
      rawVibe(2.877, 386, x: -0.791, y: -1.246, z: -2.470);
      rawVibe(4.436, 406, x: -2.325, y: 1.536, z: 3.452);
      rawVibe(5.445, 426, x: 3.460, y: -1.068, z: -4.065);
      rawVibe(2.909, 446, x: 1.242, y: 0.163, z: 2.626);
      rawVibe(1.230, 466, x: 1.000, y: -0.123, z: -0.706);
      rawVibe(0.165, 486, x: 0.077, y: -0.104, z: -0.102);
      rawVibe(0.335, 506, x: -0.028, y: -0.276, z: 0.189);
      rawVibe(0.748, 526, x: 0.169, y: 0.062, z: -0.726);
      rawVibe(0.707, 546, x: 0.502, y: -0.320, z: 0.381);
      quiet(395, 560);

      expect(controller.punchCount.value, 3);
      expect(codes().first, 'IMPACT_REJECTED_NO_VIBRATION');
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
