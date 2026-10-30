import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/impact_gate_evaluator.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';
import 'package:punch_detection_demo/features/session/presentation/widgets/pose_skeleton_painter.dart';
import 'package:punch_detection_demo/features/session/presentation/widgets/skeleton/skeleton_style.dart';
import 'package:punch_detection_demo/features/session/presentation/widgets/skeleton/skeleton_style_resolver.dart';

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

/// Confident face above confident shoulders [shoulderSpan] px apart.
/// In the default 480x640 image (diagonal 800) a span of 200 is near
/// (ratio 0.25) and 40 is too far (ratio 0.05).
Pose personPose({double shoulderSpan = 200}) => Pose(
  landmarks: <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.nose: lm(PoseLandmarkType.nose, 100, 0.95),
    PoseLandmarkType.leftShoulder: lm(
      PoseLandmarkType.leftShoulder,
      250,
      0.85,
      x: 200 - shoulderSpan / 2,
    ),
    PoseLandmarkType.rightShoulder: lm(
      PoseLandmarkType.rightShoulder,
      250,
      0.8,
      x: 200 + shoulderSpan / 2,
    ),
  },
);

/// Confident shoulders but the face is hidden (e.g. gloves up).
Pose faceHiddenPose() => Pose(
  landmarks: <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.nose: lm(PoseLandmarkType.nose, 100, 0.2),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraGateSkeletonStyleResolver', () {
    const ISkeletonStyleResolver resolver = CameraGateSkeletonStyleResolver();

    test('valid user -> active', () {
      expect(resolver.resolve(CameraGateState.valid), SkeletonStyle.active);
    });

    test('too far -> inactive (grey)', () {
      expect(resolver.resolve(CameraGateState.tooFar), SkeletonStyle.inactive);
    });

    test('not a person -> inactive (grey)', () {
      expect(
        resolver.resolve(CameraGateState.noPerson),
        SkeletonStyle.inactive,
      );
    });

    test('camera starting up -> active (no grey flash)', () {
      expect(resolver.resolve(CameraGateState.notReady), SkeletonStyle.active);
      expect(
        resolver.resolve(CameraGateState.notRequired),
        SkeletonStyle.active,
      );
    });
  });

  group('PoseSkeletonPainter', () {
    test('defaults to the active style (prompt session unchanged)', () {
      expect(PoseSkeletonPainter(pose: null).style, SkeletonStyle.active);
    });

    test('repaints when only the style changes', () {
      final PoseSkeletonPainter active = PoseSkeletonPainter(pose: null);
      final PoseSkeletonPainter grey = PoseSkeletonPainter(
        pose: null,
        style: SkeletonStyle.inactive,
      );
      expect(grey.shouldRepaint(active), isTrue);
      expect(PoseSkeletonPainter(pose: null).shouldRepaint(active), isFalse);
    });
  });

  group('FreeSessionController.skeletonStyle', () {
    late FreeSessionController controller;

    setUp(() {
      AppConstants.changeSettingToDefault();
      AppConstants.warmUpDurationInMiliSeconds = 0;
      controller = FreeSessionController(
        audioLevelService: _MockAudioLevelService(),
      );
      controller.sessionMode.value = DetectionMode.fusion;
      controller.isVisionConfirmationRequired.value = true;
      controller.isCameraInitialized.value = true;
      controller.isCameraUnavailable.value = false;
    });

    tearDown(() => controller.onClose());

    test('starts active before the first camera frame', () {
      expect(controller.skeletonStyle, SkeletonStyle.active);
    });

    test('near user -> active', () {
      controller.analyzePoseForTesting(personPose());
      expect(controller.liveCameraGateState.value, CameraGateState.valid);
      expect(controller.skeletonStyle, SkeletonStyle.active);
    });

    test('far user -> grey', () {
      controller.analyzePoseForTesting(personPose(shoulderSpan: 40));
      expect(controller.liveCameraGateState.value, CameraGateState.tooFar);
      expect(controller.skeletonStyle, SkeletonStyle.inactive);
    });

    test('face hidden (not a person) -> grey', () {
      controller.analyzePoseForTesting(faceHiddenPose());
      expect(controller.liveCameraGateState.value, CameraGateState.noPerson);
      expect(controller.skeletonStyle, SkeletonStyle.inactive);
    });

    test('hook: a few far frames after a near one stay active', () {
      controller.analyzePoseForTesting(personPose());
      for (int i = 0; i < AppConstants.cameraFarFramesToLeaveNear - 1; i++) {
        controller.analyzePoseForTesting(personPose(shoulderSpan: 40));
        expect(controller.skeletonStyle, SkeletonStyle.active);
      }
    });

    test('walking away: grey once the hook hold runs out', () {
      controller.analyzePoseForTesting(personPose());
      for (int i = 0; i < AppConstants.cameraFarFramesToLeaveNear; i++) {
        controller.analyzePoseForTesting(personPose(shoulderSpan: 40));
      }
      expect(controller.skeletonStyle, SkeletonStyle.inactive);
    });

    test('back within range -> active again', () {
      controller.analyzePoseForTesting(personPose(shoulderSpan: 40));
      expect(controller.skeletonStyle, SkeletonStyle.inactive);
      controller.analyzePoseForTesting(personPose());
      expect(controller.skeletonStyle, SkeletonStyle.active);
    });

    test('camera-only mode follows the same rule', () {
      controller.sessionMode.value = DetectionMode.camera;
      controller.analyzePoseForTesting(personPose(shoulderSpan: 40));
      expect(controller.skeletonStyle, SkeletonStyle.inactive);
    });
  });
}
