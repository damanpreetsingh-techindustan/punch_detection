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
    double targetDb = 90.0,
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
    controller.customTargetAudioDb.value = targetDb;
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

  test('hard single punches on a 33 ms accelerometer count once', () {
    startSession(
      startEpochMs: 1795669747795,
      baselineDb: 54.368,
      calibratedDb: 59.0,
      targetDb: 67.0,
    );
    replay('test/fixtures/hard_punch_double_count_2026_11_26.csv');

    // ignore: avoid_print
    print('punches at (ms): $punchTimes');

    // Each punch the user threw, with the app's count before the fix in
    // brackets. The second sound of punches 5, 6 and 9 arrived 62-69 ms after
    // the first and took the same jolt (or the bag swinging back).
    expect(punchesBetween(12500, 12800), 1, reason: 'punch 5 [2]');
    expect(punchesBetween(17500, 17800), 1, reason: 'punch 6 [2]');
    expect(punchesBetween(24950, 25250), 1, reason: 'punch 9 [2]');
    // Up to the last punch. The faint touch 50 ms before the session ended
    // (0.6 m/s², the Finish tap) was never decided in the app.
    expect(punchesBetween(0, 28500), 10, reason: 'app counted 13');
  });

  test('second session: hard single punches count once', () {
    startSession(
      startEpochMs: 1795679111252,
      baselineDb: 69.25,
      calibratedDb: 59.0,
      targetDb: 67.0,
    );
    replay('test/fixtures/hard_punch_double_count_2026_11_26_b.csv');

    // ignore: avoid_print
    print('punches at (ms): $punchTimes');

    // The punches the user counted twice, with the app's count in brackets.
    expect(punchesBetween(213400, 213600), 1, reason: 'punch 1 [2]');
    expect(punchesBetween(217900, 218100), 1, reason: 'punch 3 [2]');
    expect(punchesBetween(227200, 227400), 1, reason: 'punch 9 [2]');
    expect(punchesBetween(234400, 234650), 1, reason: 'punch 14 [2]');
    expect(punchesBetween(235900, 236100), 1, reason: 'punch 15 [2]');
    expect(controller.punchCount.value, 15, reason: 'app counted 20');
  });

  test('third session: hard single punches count once', () {
    startSession(
      startEpochMs: 1795689338266,
      baselineDb: 75.985,
      calibratedDb: 56.0,
      targetDb: 66.0,
    );
    replay('test/fixtures/hard_punch_double_count_2026_11_26_c.csv');

    // ignore: avoid_print
    print('punches at (ms): $punchTimes');

    // Each of the 6 punches once (the app's count in brackets). The replay
    // starts without the app's 200 ms warm-up, so its first frame is skipped.
    expect(punchesBetween(72600, 73500), 1, reason: 'punch 1 [3]');
    expect(punchesBetween(81200, 81450), 1, reason: 'punch 4 [2]');
    expect(punchesBetween(83650, 83900), 1, reason: 'punch 5 [2]');
    expect(punchesBetween(71000, 92000), 6, reason: 'app counted 10');
  });

  test('build 8 session: singles and combos, the bag\'s light tap after a '
      'hard punch is not a punch', () {
    startSession(
      startEpochMs: 1795754280301,
      baselineDb: 67.456,
      calibratedDb: 61.0,
      targetDb: 69.0,
    );
    replay('test/fixtures/hard_punch_double_count_2026_11_27.csv');

    // ignore: avoid_print
    print('punches at (ms): $punchTimes');

    // The punches the app counted twice (its count in brackets): the extra
    // came 320-410 ms later with a jolt of 0.2-1.3 m/s².
    expect(punchesBetween(42200, 42700), 1, reason: 'punch 12 [2]');
    expect(punchesBetween(49800, 50400), 1, reason: 'punch 15 [2]');
    expect(punchesBetween(62400, 62950), 1, reason: 'punch 24 [2]');
    // Punch 18's own second bump (55.145) is the same burst.
    expect(punchesBetween(54990, 55320), 1, reason: 'punch 18');
    // Double/triple combos 75-90 s all counted (app: 31 there).
    expect(punchesBetween(72000, 90000), 31, reason: 'combos');
    expect(controller.punchCount.value, 58, reason: 'app counted 61');
  });

  test('build 8 second session: hard single punches count once', () {
    startSession(
      startEpochMs: 1795758471114,
      baselineDb: 40.831,
      calibratedDb: 48.0,
      targetDb: 66.0,
    );
    replay('test/fixtures/hard_punch_double_count_2026_11_27_b.csv');

    // ignore: avoid_print
    print('punches at (ms): $punchTimes');

    // The punches the app counted twice (its count in brackets). Punch 2's
    // extra: a 60 dB sound 646 ms later on the settling bag (0.55 m/s²);
    // punch 22's: 878 ms later (1.58 m/s²); punch 27's: 135 ms later while
    // the bag still rang at 3-6 m/s² (5.54 m/s², 18% of the punch's).
    expect(punchesBetween(31700, 32600), 1, reason: 'punch 2 [2]');
    expect(punchesBetween(79000, 80100), 1, reason: 'punch 22 [2]');
    expect(punchesBetween(87400, 87700), 1, reason: 'punch 27 [2]');
    // From the first punch on. The sound at 27.4 s came while Settings was
    // open on the phone (declined there), which the replay cannot see.
    expect(punchesBetween(29000, 140000), 57, reason: 'app counted 60');
  });
}
