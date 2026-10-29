import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
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
  Stream<AudioLevelSample> get sampleStream => _controller.stream.map(
    (double db) => AudioLevelSample(db: db, timestampMs: 0),
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

  void vibe(double mag, int t) =>
      controller.ingestVibrationSampleForTesting(mag, atEpochMs: t0 + t);

  void camera(CameraGateState state, int t) =>
      controller.setCameraObservationForTesting(state, atMs: t0 + t);

  void touch(int t) => controller.notifyPointerDown(atMs: t0 + t);

  /// A clean punch at [t]: camera valid, vibration with the sound.
  void punch(int t) {
    camera(CameraGateState.valid, t - 10);
    vibe(0.6, t);
    frame(95.0, t);
  }

  List<String> codes() =>
      controller.telemetryEvents.map((e) => e.decisionCode).toList();

  setUp(() {
    AppConstants.changeSettingToDefault();
    AppConstants.warmUpDurationInMiliSeconds = 0;
    controller = FreeSessionController(
      audioLevelService: _MockAudioLevelService(),
    );
    controller.sessionMode.value = DetectionMode.fusion;
    controller.mountType.value = MountType.wall;
    controller.isVibrationGateEnabled.value = true;
    controller.minVibrationThreshold.value = 0.18;
    controller.isVisionConfirmationRequired.value = true;
    controller.isCameraInitialized.value = true;
    controller.isCameraUnavailable.value = false;
    controller.staticCalibratedAudioDb.value = 70.0;
    controller.customTargetAudioDb.value = 75.0;
    controller.minAudioPunchSpikeDb.value = 5.0;
  });

  tearDown(() => controller.onClose());

  group('touch lockout', () {
    test('an impact up to 400 ms after a touch is rejected', () {
      quiet(0, 60);
      touch(50);
      quiet(60, 300);
      punch(300); // 250 ms after the touch
      quiet(310, 500);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_TOUCH'));
    });

    test('an impact more than 400 ms after a touch counts', () {
      quiet(0, 60);
      touch(50);
      quiet(60, 460);
      punch(460); // 410 ms after the touch
      expect(controller.punchCount.value, 1);
    });

    test(
      'a punch counted just before the touch event arrives is taken back',
      () {
        quiet(0, 60);
        punch(60);
        expect(controller.punchCount.value, 1);
        touch(120); // the tap's touch event lands 60 ms after its sound
        expect(controller.punchCount.value, 0);
        expect(controller.recorder.totals.counter('impact.retracted_touch'), 1);
        expect(
          controller.confirmedPunchLog.last,
          contains('RETRACTED PUNCH #1'),
        );
      },
    );

    test('a punch more than 100 ms before the touch stays counted', () {
      quiet(0, 60);
      punch(60);
      touch(170); // 110 ms later
      expect(controller.punchCount.value, 1);
    });

    test('an impact still waiting for vibration is cancelled by a touch', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      frame(95.0, 60); // pending: no vibration yet
      touch(90);
      vibe(0.6, 100); // vibration from the tap arrives late
      quiet(110, 300);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_TOUCH'));
    });

    test('audio-only mode is protected as well', () {
      controller.sessionMode.value = DetectionMode.audio;
      quiet(0, 60);
      touch(50);
      frame(95.0, 100);
      expect(controller.punchCount.value, 0);
    });

    test('lockout switched off -> the old behaviour', () {
      controller.setTouchLockout(false);
      quiet(0, 60);
      touch(50);
      quiet(60, 300);
      punch(300);
      expect(controller.punchCount.value, 1);
    });
  });

  group('camera presence window', () {
    test('glove covers the face at the impact -> still counts', () {
      camera(CameraGateState.valid, -900); // seen 960 ms before the punch
      quiet(0, 60);
      camera(CameraGateState.noPerson, 40); // face occluded now
      vibe(0.6, 60);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
      expect(codes().first, 'IMPACT_VALID_AUDIO_VIBE_CAM');
      expect(controller.recorder.totals.counter('cam.presence_window_pass'), 1);
    });

    test('old per-frame gate (flag off) rejects the same punch', () {
      controller.setCameraPresenceWindow(false);
      camera(CameraGateState.valid, -900);
      quiet(0, 60);
      camera(CameraGateState.noPerson, 40);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_CAMERA_NO_PERSON'));
    });

    test('person last seen more than 1.5 s before -> rejected', () {
      camera(CameraGateState.valid, -1500); // 1560 ms before
      quiet(0, 60);
      camera(CameraGateState.noPerson, 40);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_CAMERA_NO_PERSON'));
    });

    test('user too far and never valid -> rejected as too far', () {
      quiet(0, 60);
      camera(CameraGateState.tooFar, 40);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_CAMERA_TOO_FAR'));
    });

    test('camera not ready in the first 3 s -> startup grace pass', () {
      controller.setSessionStartForTesting(t0 - 1000);
      controller.isCameraInitialized.value = false;
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
      expect(codes().first, 'IMPACT_VALID_AUDIO_VIBE_CAM_STARTUP_GRACE');
      expect(controller.recorder.totals.counter('cam.startup_grace_pass'), 1);
    });

    test('camera running but no frame analysed yet, in grace -> passes', () {
      controller.setSessionStartForTesting(t0 - 1000);
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
    });

    test('camera still not ready after 3 s -> rejected as not ready', () {
      controller.setSessionStartForTesting(t0 - 5000);
      controller.isCameraInitialized.value = false;
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_CAMERA_NOT_READY'));
    });
  });
}
