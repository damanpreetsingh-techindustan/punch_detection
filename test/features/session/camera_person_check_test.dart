import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';

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

PoseLandmark lm(
  PoseLandmarkType type,
  double y,
  double likelihood, {
  double x = 200,
}) => PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);

/// A real user: confident nose and eyes above confident shoulders.
Pose personPose() => Pose(
  landmarks: <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.nose: lm(PoseLandmarkType.nose, 100, 0.95),
    PoseLandmarkType.leftEye: lm(PoseLandmarkType.leftEye, 90, 0.9, x: 180),
    PoseLandmarkType.rightEye: lm(PoseLandmarkType.rightEye, 90, 0.9, x: 220),
    PoseLandmarkType.leftShoulder: lm(
      PoseLandmarkType.leftShoulder,
      250,
      0.85,
      x: 100,
    ),
    PoseLandmarkType.rightShoulder: lm(
      PoseLandmarkType.rightShoulder,
      250,
      0.8,
      x: 300,
    ),
  },
);

/// What an object such as a bottle produces: a few low-confidence points.
Pose bottlePose() => Pose(
  landmarks: <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.nose: lm(PoseLandmarkType.nose, 100, 0.28),
    PoseLandmarkType.leftEye: lm(PoseLandmarkType.leftEye, 90, 0.22),
    PoseLandmarkType.leftShoulder: lm(PoseLandmarkType.leftShoulder, 250, 0.31),
    PoseLandmarkType.rightShoulder: lm(
      PoseLandmarkType.rightShoulder,
      250,
      0.25,
    ),
  },
);

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

  void punchWithVibration() {
    quiet(0, 60);
    controller.ingestVibrationSampleForTesting(0.6, atEpochMs: t0 + 60);
    frame(95.0, 60);
    quiet(70, 220);
  }

  setUp(() {
    AppConstants.changeSettingToDefault();
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

  test('a bottle-like pose does not confirm a real bag hit', () {
    controller.analyzePoseForTesting(bottlePose());
    punchWithVibration();
    expect(controller.punchCount.value, 0);
    expect(
      controller.telemetryEvents.map((e) => e.decisionCode),
      contains('IMPACT_REJECTED_CAMERA_NO_PERSON'),
    );
    final String csv = controller.summaryTable.toCsv();
    expect(csv, contains('not a person'));
  });

  test('a real person pose confirms the same hit', () {
    controller.analyzePoseForTesting(personPose());
    punchWithVibration();
    expect(controller.punchCount.value, 1);
    final String csv = controller.summaryTable.toCsv();
    expect(csv, contains('IMPACT_VALID_AUDIO_VIBE_CAM'));
    expect(csv, contains('CAMERA_VALID'));
  });

  test('face + only one confident shoulder still counts', () {
    final Pose onlyLeftShoulder = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.nose: lm(PoseLandmarkType.nose, 100, 0.9),
        PoseLandmarkType.leftShoulder: lm(
          PoseLandmarkType.leftShoulder,
          250,
          0.7,
        ),
        PoseLandmarkType.rightShoulder: lm(
          PoseLandmarkType.rightShoulder,
          250,
          0.05,
        ),
      },
    );
    controller.analyzePoseForTesting(onlyLeftShoulder);
    punchWithVibration();
    expect(controller.punchCount.value, 1);
  });

  test('the CSV table records the confidences of each camera change', () {
    controller.analyzePoseForTesting(bottlePose());
    controller.analyzePoseForTesting(personPose());
    final List<String> lines = controller.summaryTable
        .toCsv()
        .trim()
        .split('\n');
    expect(lines.where((l) => l.contains(',CAMERA,')).length, 2);
    expect(lines[1], contains('CAMERA_NOPERSON'));
    expect(lines[1], contains('0.28')); // bottle best face confidence
    expect(lines[2], contains('CAMERA_VALID'));
    expect(lines[2], contains('0.95'));
  });
}
