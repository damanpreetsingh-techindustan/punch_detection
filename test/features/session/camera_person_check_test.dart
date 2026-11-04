import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/impact_gate_evaluator.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';
import 'package:punch_detection_demo/features/vision_detection/data/face/subject_face_checker.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/camera_tracker_guard.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/appearance_signature.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/face_alignment.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/i_face_embedder.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/subject_lock.dart';

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

/// [personPose] plus mouth corners: a clear frontal face for the face check.
Pose facePose() => Pose(
  landmarks: <PoseLandmarkType, PoseLandmark>{
    ...personPose().landmarks,
    PoseLandmarkType.leftMouth: lm(PoseLandmarkType.leftMouth, 125, 0.9, x: 188),
    PoseLandmarkType.rightMouth: lm(
      PoseLandmarkType.rightMouth,
      125,
      0.9,
      x: 212,
    ),
  },
);

/// Returns a fixed embedding for whoever is "in front of the camera".
class _FakeFaceEmbedder implements IFaceEmbedder {
  static const List<double> user = <double>[1, 0, 0, 0];
  static const List<double> other = <double>[0.1, 0.995, 0, 0];
  List<double> current = user;
  int calls = 0;

  @override
  Future<List<double>?> embed(FramePixels pixels, FacePoints poseFace) async {
    calls++;
    return current;
  }

  @override
  Future<void> close() async {}
}

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

  group('subject lock', () {
    /// A camera frame filled with one colour (NV21, upright, wide enough for
    /// a second person next to the user).
    FramePixels frameOf(YuvColor colour) {
      const int w = 1000;
      const int h = 700;
      final Uint8List bytes = Uint8List(w * h + w * h ~/ 2);
      bytes.fillRange(0, w * h, colour.y);
      for (int i = w * h; i < bytes.length; i += 2) {
        bytes[i] = colour.v;
        bytes[i + 1] = colour.u;
      }
      return FramePixels(
        bytes: bytes,
        width: w,
        height: h,
        bytesPerRow: w,
        format: FramePixelFormat.nv21,
      );
    }

    Pose shifted(Pose pose, double dx) => Pose(
      landmarks: pose.landmarks.map(
        (PoseLandmarkType type, PoseLandmark l) => MapEntry(
          type,
          PoseLandmark(
            type: type,
            x: l.x + dx,
            y: l.y,
            z: l.z,
            likelihood: l.likelihood,
          ),
        ),
      ),
    );

    const int start = 2000000000000;
    final FramePixels blueShirt = frameOf(const YuvColor(41, 240, 110));
    final FramePixels redShirt = frameOf(const YuvColor(82, 90, 240));

    int frames = 0;
    int nextFrameMs() => start + 33 * frames++;

    /// The user stands still for the reference photo until it is learned.
    void lockOnUser() {
      for (int i = 0;
          i < 200 &&
              controller.subjectLockState.value != SubjectLockState.locked;
          i++) {
        controller.analyzePoseForTesting(
          personPose(),
          frameMs: nextFrameMs(),
          pixels: blueShirt,
        );
      }
      expect(controller.subjectLockState.value, SubjectLockState.locked);
    }

    setUp(() => frames = 0);

    test('before the reference photo the camera confirms nothing', () {
      controller.analyzePoseForTesting(
        personPose(),
        frameMs: nextFrameMs(),
        pixels: blueShirt,
      );
      expect(controller.subjectLockState.value, SubjectLockState.holdStill);
      expect(controller.subjectHoldStillSeconds.value, 2);
      punchWithVibration();
      expect(controller.punchCount.value, 0);
      expect(
        controller.telemetryEvents.map((e) => e.decisionCode),
        contains('IMPACT_REJECTED_CAMERA_NO_PERSON'),
      );
    });

    test('skipping the photo runs the session without the lock', () {
      controller.skipReferencePhoto();
      controller.analyzePoseForTesting(
        personPose(),
        frameMs: nextFrameMs(),
        pixels: blueShirt,
      );
      punchWithVibration();
      expect(controller.punchCount.value, 1);
    });

    test('the reference photo is made from the frame it was taken from',
        () async {
      lockOnUser();
      for (int i = 0;
          i < 100 && controller.subjectReferencePhoto.value == null;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(controller.subjectReferencePhoto.value, isNotNull);
      expect(controller.subjectReferencePhoto.value!.width, 96);
      controller.relockSubject();
      expect(controller.subjectReferencePhoto.value, isNull);
      expect(
        controller.subjectLockState.value,
        SubjectLockState.waitingForUser,
      );
    });

    test('the locked user still confirms a hit', () {
      lockOnUser();
      punchWithVibration();
      expect(controller.punchCount.value, 1);
      expect(controller.summaryTable.toCsv(), contains('SUBJECT_LOCKED'));
    });

    test('another person tracked by ML Kit cannot confirm a hit', () {
      lockOnUser();
      // ML Kit jumps to someone in a red shirt, two body widths away.
      controller.analyzePoseForTesting(
        shifted(personPose(), 400),
        frameMs: nextFrameMs(),
        pixels: redShirt,
      );
      // Blocked from the first frame, before anything has proven who it is.
      expect(controller.subjectLockState.value, SubjectLockState.verifying);
      expect(controller.liveCameraGateState.value, CameraGateState.noPerson);
      punchWithVibration();
      expect(controller.punchCount.value, 0);
      expect(
        controller.telemetryEvents.map((e) => e.decisionCode),
        contains('IMPACT_REJECTED_CAMERA_NO_PERSON'),
      );
      controller.analyzePoseForTesting(
        shifted(personPose(), 400),
        frameMs: nextFrameMs(),
        pixels: redShirt,
      );
      expect(controller.subjectLockState.value, SubjectLockState.otherPerson);
      expect(controller.summaryTable.toCsv(), contains('other person'));
    });

    test('with the switch off, the other person is not checked', () {
      controller.toggleSubjectLock(false);
      controller.analyzePoseForTesting(
        shifted(personPose(), 400),
        frameMs: nextFrameMs(),
        pixels: redShirt,
      );
      expect(controller.liveCameraGateState.value, CameraGateState.valid);
    });

    test('a person in the same clothes is caught by the face check', () async {
      // Real controller + face checker scheduling; the embedder is a fake
      // that returns whichever face is "in front of the camera".
      final _FakeFaceEmbedder faces = _FakeFaceEmbedder();
      controller.onClose();
      controller = FreeSessionController(
        audioLevelService: _MockAudioLevelService(),
        faceChecker: SubjectFaceChecker(embedder: faces),
      );
      controller.sessionMode.value = DetectionMode.fusion;
      controller.isVisionConfirmationRequired.value = true;
      controller.isCameraInitialized.value = true;
      controller.isCameraUnavailable.value = false;

      Future<void> frame(Pose pose) async {
        controller.analyzePoseForTesting(
          pose,
          frameMs: nextFrameMs(),
          pixels: blueShirt,
        );
        await Future<void>.delayed(Duration.zero); // let the check finish
      }

      faces.current = _FakeFaceEmbedder.user;
      for (int i = 0;
          i < 200 &&
              controller.subjectLockState.value != SubjectLockState.locked;
          i++) {
        await frame(facePose());
      }
      expect(controller.subjectLockState.value, SubjectLockState.locked);
      expect(faces.calls, greaterThan(0));

      // Same blue shirt, someone else's face, two body widths away.
      faces.current = _FakeFaceEmbedder.other;
      for (int i = 0; i < 8; i++) {
        await frame(shifted(facePose(), 400));
      }
      expect(controller.subjectLockState.value, SubjectLockState.otherPerson);
      expect(controller.liveCameraGateState.value, CameraGateState.noPerson);
      expect(controller.summaryTable.toCsv(), contains('other person (face)'));
    });
  });

  test('a tracker stuck on an object asks for a reset, a real person does not',
      () {
    final CameraTrackerGuard guard = CameraTrackerGuard();
    controller.onClose();
    controller = FreeSessionController(
      audioLevelService: _MockAudioLevelService(),
      trackerGuard: guard,
    );
    controller.toggleSubjectLock(false);
    const int start = 2000000000000;
    controller.analyzePoseForTesting(bottlePose(), frameMs: start);
    controller.analyzePoseForTesting(
      bottlePose(),
      frameMs: start + guard.maxRefusedMs - 1,
    );
    expect(guard.takeReset(), isFalse);
    controller.analyzePoseForTesting(
      bottlePose(),
      frameMs: start + guard.maxRefusedMs,
    );
    expect(guard.takeReset(), isTrue);

    controller.analyzePoseForTesting(bottlePose(), frameMs: start + 2000);
    controller.analyzePoseForTesting(personPose(), frameMs: start + 2500);
    controller.analyzePoseForTesting(bottlePose(), frameMs: start + 3000);
    expect(guard.takeReset(), isFalse);
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
