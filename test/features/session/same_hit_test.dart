import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/adaptive_audio_baseline.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/impact_gate_evaluator.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';

class _MockAudioLevelService implements IAudioLevelService {
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

/// One hard punch counted twice (logs of 2026-11-26): the second sound of the
/// same hit takes either the late peak of the same jolt or a rise of the
/// still-shaking bag.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FreeSessionController controller;
  const int t0 = 1000000000000;

  setUp(() {
    AppConstants.changeSettingToDefault();
    AppConstants.warmUpDurationInMiliSeconds = 0;
    controller = FreeSessionController(
      audioLevelService: _MockAudioLevelService(),
      adaptiveBaseline: AdaptiveAudioBaseline()..seedBaseline(50.0),
    );
    controller.sessionMode.value = DetectionMode.fusion;
    controller.mountType.value = MountType.wall;
    controller.isVibrationGateEnabled.value = true;
    controller.minVibrationThreshold.value = 0.06;
    controller.isVisionConfirmationRequired.value = true;
    controller.isCameraInitialized.value = true;
    controller.isBodyMotionGateEnabled.value = false;
    controller.isCameraUnavailable.value = false;
    controller.staticCalibratedAudioDb.value = 70.0;
    controller.customTargetAudioDb.value = 75.0;
    controller.minAudioPunchSpikeDb.value = 5.0;
  });

  tearDown(() => controller.onClose());

  /// Plays audio frames (every 10 ms, [db] gives the level at session time t)
  /// and raw accelerometer readings ([raw]: time -> z) in time order until
  /// [endMs]. Readings not listed rest at z = 0.05 every [sensorEveryMs].
  void play({
    required double Function(int t) db,
    required Map<int, double> raw,
    required int sensorEveryMs,
    int endMs = 1600,
  }) {
    final Map<int, double> readings = <int, double>{
      for (int t = 0; t < endMs; t += sensorEveryMs) t: 0.05,
      ...raw,
    };
    final List<int> times = <int>{
      ...readings.keys,
      for (int t = 0; t < endMs; t += 10) t,
    }.toList()
      ..sort();
    for (final int t in times) {
      final double? z = readings[t];
      if (z != null) {
        controller.vibrationGate.addRawSample(
          sensorMs: t0 + t,
          rawX: 0.0,
          rawY: 0.0,
          rawZ: z,
          rawMag: z.abs(),
        );
      }
      if (t % 30 == 0) {
        // The camera reports the user about every 33 ms.
        controller.setCameraObservationForTesting(
          CameraGateState.valid,
          atMs: t0 + t,
        );
      }
      if (t % 10 == 0) {
        controller.feedAudioFrameForTesting(db(t), atEpochMs: t0 + t);
      }
    }
  }

  List<String> codes() =>
      controller.telemetryEvents.map((e) => e.decisionCode).toList();

  String sameHitReason() => controller.telemetryEvents
      .firstWhere((e) => e.decisionCode == 'IMPACT_REJECTED_SAME_HIT')
      .reasonLabel;

  /// Punch at 1000 ms, then a second sound of [secondDb] at 1070 ms. [dipDb]
  /// is the level just before it: at 84 dB or more the first sound is still
  /// ringing (the "still ringing" rule), below that it has died down.
  double Function(int t) twoSounds({
    required double dipDb,
    double secondDb = 101.0,
  }) => (int t) {
    if (t < 1000) return 50.0;
    if (t == 1000) return 105.0;
    if (t < 1060) return 95.0;
    if (t == 1060) return dipDb;
    if (t == 1070) return secondDb;
    if (t < 1150) return 88.0;
    return 50.0;
  };

  /// The first sound has died down to 80 dB; the second rises only 12 dB.
  final double Function(int t) quietThenSmallRise = twoSounds(
    dipDb: 80.0,
    secondDb: 92.0,
  );

  /// A fresh jolt 60 ms after the punch's own, not stronger than it.
  const Map<int, double> freshJolt = <int, double>{
    990: 20.0,
    1010: 6.0,
    1030: 2.0,
    1050: 19.0,
    1070: 6.0,
  };

  group('peak of the same jolt arriving 60 ms after it starts', () {
    // Recorded hard punch (20 ms readings): the jolt starts at 970, its
    // biggest reading comes 60 ms later, past the 40 ms knock merge.
    const Map<int, double> jolt = <int, double>{
      970: 10.0,
      990: 19.5,
      1010: 17.5,
      1030: 59.8,
      1050: 21.2,
      1070: 15.5,
      1090: 15.7,
      1110: 5.6,
      1130: 5.0,
    };

    test('second sound with no new glove sound is not a second punch', () {
      play(db: quietThenSmallRise, raw: jolt, sensorEveryMs: 20);
      expect(controller.punchCount.value, 1);
      expect(codes(), contains('IMPACT_REJECTED_SAME_HIT'));
      expect(sameHitReason(), contains('x stronger'));
    });

    test('a clearly new sound on the same timing still counts', () {
      play(db: twoSounds(dipDb: 72.0), raw: jolt, sensorEveryMs: 20);
      expect(controller.punchCount.value, 2);
      expect(codes(), isNot(contains('IMPACT_REJECTED_SAME_HIT')));
    });
  });

  test('a fast follow-up punch whose jolt is not stronger still counts', () {
    // Like the real flurry punch 71 ms after the previous one (0.93x, its
    // sound had fallen to 81 dB): the first jolt settles, the next hit jumps
    // from near rest 60 ms later.
    play(db: quietThenSmallRise, raw: freshJolt, sensorEveryMs: 20);
    expect(controller.punchCount.value, 2);
    expect(codes(), isNot(contains('IMPACT_REJECTED_SAME_HIT')));
  });

  test('the same fresh jolt while the punch is still ringing is not a second '
      'punch', () {
    // Recorded duplicates: 62-83 ms after the punch, the sound never fell
    // below 86 dB and rose only 7-17 dB, whatever the jolt looked like. The
    // dip to 85 dB is a 20 dB drop, so only the still-ringing rule applies.
    play(db: twoSounds(dipDb: 85.0), raw: freshJolt, sensorEveryMs: 20);
    expect(controller.punchCount.value, 1);
    expect(sameHitReason(), contains('still ringing'));
  });

  group('the bag\'s light tap after a hard punch', () {
    // Recorded (build 8): 135-878 ms after a hard punch, once its sound has
    // died away, a sound with a jolt of 0.2-5.5 m/s² (the punch: 14-54).
    double Function(int t) punchThenTap({int tapMs = 1350}) => (int t) {
      if (t < 1000) return 50.0;
      if (t == 1000) return 105.0;
      if (t < 1100) return 85.0;
      if (t < tapMs) return 52.0;
      if (t == tapMs) return 80.0;
      if (t < tapMs + 50) return 70.0;
      return 50.0;
    };

    Map<int, double> jolts({required double tap, int tapMs = 1350}) =>
        <int, double>{
          990: 20.0,
          1010: 6.0,
          1030: 2.0,
          tapMs - 10: tap,
          tapMs + 10: 0.05,
        };

    test('a tiny jolt is the same punch', () {
      play(db: punchThenTap(), raw: jolts(tap: 0.6), sensorEveryMs: 20);
      expect(controller.punchCount.value, 1);
      expect(sameHitReason(), contains('weak echo'));
    });

    test('a real jolt at the same moment is a new punch', () {
      play(db: punchThenTap(), raw: jolts(tap: 12.0), sensorEveryMs: 20);
      expect(controller.punchCount.value, 2);
    });

    test('a tiny jolt 880 ms later is still the same punch', () {
      play(
        db: punchThenTap(tapMs: 1880),
        raw: jolts(tap: 1.6, tapMs: 1880),
        sensorEveryMs: 20,
        endMs: 2200,
      );
      expect(controller.punchCount.value, 1);
      expect(sameHitReason(), contains('weak echo'));
    });

    test('a light punch more than a second later counts', () {
      play(
        db: punchThenTap(tapMs: 2100),
        raw: jolts(tap: 1.6, tapMs: 2100),
        sensorEveryMs: 20,
        endMs: 2400,
      );
      expect(controller.punchCount.value, 2);
    });

    test('a jolt of 18% while the bag still rings is the same punch', () {
      // Recorded punch 27: 135 ms after the punch, 5.5 m/s² (punch: 30.1).
      play(
        db: punchThenTap(tapMs: 1140),
        raw: jolts(tap: 3.6, tapMs: 1140),
        sensorEveryMs: 20,
      );
      expect(controller.punchCount.value, 1);
      expect(sameHitReason(), contains('weak echo'));
    });

    test('a fast follow-up with a third of the jolt counts', () {
      // Real fast punches measured 31-39% of the one before, 9 m/s² or more.
      play(
        db: punchThenTap(tapMs: 1140),
        raw: jolts(tap: 9.0, tapMs: 1140),
        sensorEveryMs: 20,
      );
      expect(controller.punchCount.value, 2);
    });
  });

  group('one burst of sound', () {
    // Recorded punch 5: the glove's small sound (78 dB) is counted, the sound
    // dips only to 71-72 dB and then the hit itself (110 dB) arrives 70 ms
    // later with a jolt of its own.
    double Function(int t) gloveThenHit({required double dipDb}) => (int t) {
      if (t < 1000) return 50.0;
      if (t == 1000) return 78.0;
      if (t < 1040) return 75.0;
      if (t < 1070) return dipDb;
      if (t == 1070) return 108.0;
      if (t < 1150) return 90.0;
      return 50.0;
    };

    test('the hit right after the glove\'s small sound is the same punch', () {
      play(db: gloveThenHit(dipDb: 72.0), raw: freshJolt, sensorEveryMs: 20);
      expect(controller.punchCount.value, 1);
      expect(sameHitReason(), contains('same sound burst'));
    });

    test('counts again once the sound has dropped 20 dB', () {
      // From the 78 dB peak down to 55 dB: the first sound has died away.
      play(db: gloveThenHit(dipDb: 55.0), raw: freshJolt, sensorEveryMs: 20);
      expect(controller.punchCount.value, 2);
    });
  });

  group('rise of the still-shaking bag right after a punch', () {
    // Punch knock at 990, then the bag swings: low at 1056, back up to 9 at
    // 1089 (above the rescue's 7, below the 10 that makes a fresh knock),
    // then fades out slowly.
    const Map<int, double> swing = <int, double>{
      990: 20.0,
      1023: -15.0,
      1056: 3.0,
      1089: 9.0,
      1122: 7.0,
      1155: 5.0,
      1188: 3.0,
      1221: 1.0,
    };

    test('is not a second punch when the sound barely rose', () {
      play(db: quietThenSmallRise, raw: swing, sensorEveryMs: 33);
      expect(controller.punchCount.value, 1);
      expect(codes(), contains('IMPACT_REJECTED_SAME_HIT'));
      expect(sameHitReason(), contains('shaking bag'));
    });

    test('counts when a clearly new sound comes with it', () {
      play(db: twoSounds(dipDb: 72.0), raw: swing, sensorEveryMs: 33);
      expect(controller.punchCount.value, 2);
    });
  });
}
