import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/adaptive_audio_baseline.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/impact_gate_evaluator.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';

class _SilentAudioService implements IAudioLevelService {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  @override
  Stream<double> get decibelStream => _controller.stream;

  @override
  Stream<AudioLevelSample> get sampleStream =>
      const Stream<AudioLevelSample>.empty();

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

/// Replays a recorded real session (microphone frames, raw accelerometer,
/// vibration envelope, camera state) through the real detection code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FreeSessionController controller;
  late int t0;
  final List<int> punchTimes = <int>[];

  /// Settings the session was recorded with (its session_start line).
  void startSession({
    required int startEpochMs,
    required double baselineDb,
    required double calibratedDb,
  }) {
    t0 = startEpochMs;
    punchTimes.clear();
    controller = FreeSessionController(
      audioLevelService: _SilentAudioService(),
      adaptiveBaseline: AdaptiveAudioBaseline()..seedBaseline(baselineDb),
    );
    controller.sessionMode.value = DetectionMode.fusion;
    controller.mountType.value = MountType.wall;
    controller.isVibrationGateEnabled.value = true;
    controller.minVibrationThreshold.value = 0.06;
    controller.isVisionConfirmationRequired.value = true;
    controller.isCameraInitialized.value = true;
    controller.isCameraUnavailable.value = false;
    controller.isBodyMotionGateEnabled.value = false;
    controller.staticCalibratedAudioDb.value = calibratedDb;
    controller.customTargetAudioDb.value = 90.0;
    controller.minAudioPunchSpikeDb.value = 8.0;
  }

  setUp(() {
    AppConstants.changeSettingToDefault();
    AppConstants.warmUpDurationInMiliSeconds = 0;
  });

  tearDown(() => controller.onClose());

  void replay(String path) {
    for (final String line in File(path).readAsLinesSync()) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final List<String> p = line.split(',');
      final int at = t0 + int.parse(p[2]);
      final int countBefore = controller.punchCount.value;
      switch (p[0]) {
        case 'a':
          controller.feedAudioFrameForTesting(
            double.parse(p[3]),
            atEpochMs: at,
          );
        case 'r':
          controller.vibrationGate.addRawSample(
            sensorMs: at,
            rawX: double.parse(p[3]),
            rawY: double.parse(p[4]),
            rawZ: double.parse(p[5]),
            rawMag: double.parse(p[6]),
          );
        case 'v':
          controller.ingestVibrationSampleForTesting(
            double.parse(p[3]),
            atEpochMs: at,
          );
        case 'c':
          controller.setCameraObservationForTesting(
            CameraGateState.values.byName(p[3]),
            atMs: at,
          );
      }
      // The controller keeps only its latest telemetry events, so note each
      // punch (session time of its sound) as soon as it is counted.
      final int added = controller.punchCount.value - countBefore;
      if (added > 0) {
        punchTimes.addAll(
          controller.telemetryEvents
              .where((e) => e.isValidPunch)
              .take(added)
              .map((e) => e.timestampMs - t0)
              .toList()
              .reversed,
        );
      }
    }
  }

  int punchesBetween(int fromMs, int toMs) =>
      punchTimes.where((t) => t >= fromMs && t <= toMs).length;

  test('every punch of four rapid 5-punch flurries is counted', () {
    startSession(
      startEpochMs: 1793858297112,
      baselineDb: 72.098,
      calibratedDb: 94.0,
    );
    replay('test/fixtures/rapid_combo_session_2026_11_05.csv');

    // ignore: avoid_print
    print('punches at (ms): $punchTimes');

    expect(punchesBetween(15000, 15800), 5, reason: 'flurry 1');
    expect(punchesBetween(19000, 19800), 1, reason: 'single punch');
    expect(punchesBetween(20400, 21200), 5, reason: 'flurry 2');
    expect(punchesBetween(22600, 23400), 5, reason: 'flurry 3');
    expect(punchesBetween(24500, 25300), 5, reason: 'flurry 4');
    expect(controller.punchCount.value, 21);
  });

  test('long session: punches landing on a still-shaking bag are counted', () {
    startSession(
      startEpochMs: 1793864358105,
      baselineDb: 77.76,
      calibratedDb: 99.0,
    );
    replay('test/fixtures/rapid_combo_session_2026_11_05_b.csv');

    // ignore: avoid_print
    print('punches at (ms): $punchTimes');

    // Rounds the user threw (counted before the fix in brackets).
    expect(punchesBetween(4800, 6300), 10, reason: '10 rapid [9]');
    expect(punchesBetween(11100, 12400), 9, reason: '10 rapid [7]; one hit '
        'landed on a big shake (1.7x the trough)');
    expect(punchesBetween(27000, 28300), 9, reason: '10 rapid [7]; one lost '
        'to the camera losing the shoulder');
    expect(punchesBetween(36600, 37900), 9, reason: '10 rapid [8]; one loud '
        'sound with the bag at 3-6 m/s²');
    expect(punchesBetween(55700, 57700), 15, reason: '15 rapid [14]');
    expect(punchesBetween(67300, 68600), 10, reason: '10 rapid [9]');
    expect(punchesBetween(77100, 77700), 5, reason: '5 rapid [4]');
    // Sounds between the rounds (no hit on the bag) stay rejected.
    expect(controller.punchCount.value, 100, reason: 'app counted 90');
  });
}
