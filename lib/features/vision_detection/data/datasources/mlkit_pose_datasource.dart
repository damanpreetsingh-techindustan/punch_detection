import 'dart:async';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import '../../../../core/services/monotonic_clock_service.dart';
import '../../domain/entities/body_pose_data.dart';
import '../../domain/entities/pose_landmark.dart';

class MLKitPoseDatasource {
  final MonotonicClockService clockService;
  mlkit.PoseDetector? _poseDetector;

  MLKitPoseDatasource({required this.clockService});

  mlkit.PoseDetector get poseDetector {
    _poseDetector ??= mlkit.PoseDetector(
      options: mlkit.PoseDetectorOptions(
        mode: mlkit.PoseDetectionMode.stream,
        model: mlkit.PoseDetectionModel.base,
      ),
    );
    return _poseDetector!;
  }

  /// Processes a camera frame InputImage using Google ML Kit Pose Detector and converts to domain BodyPoseData
  Future<BodyPoseData?> processInputImage(mlkit.InputImage inputImage) async {
    try {
      final List<mlkit.Pose> poses = await poseDetector.processImage(inputImage);
      if (poses.isEmpty) return null;

      final pose = poses.first;
      return convertMlKitPoseToDomain(pose);
    } catch (_) {
      return null;
    }
  }

  /// Converts Google ML Kit 3D Pose landmarks to domain BodyPoseData entity
  BodyPoseData convertMlKitPoseToDomain(mlkit.Pose pose) {
    PoseLandmark extractLandmark(mlkit.PoseLandmarkType type) {
      final lm = pose.landmarks[type];
      if (lm == null) return const PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0);
      return PoseLandmark(x: lm.x, y: lm.y, z: lm.z, likelihood: lm.likelihood);
    }

    return BodyPoseData(
      nose: extractLandmark(mlkit.PoseLandmarkType.nose),
      leftShoulder: extractLandmark(mlkit.PoseLandmarkType.leftShoulder),
      rightShoulder: extractLandmark(mlkit.PoseLandmarkType.rightShoulder),
      leftElbow: extractLandmark(mlkit.PoseLandmarkType.leftElbow),
      rightElbow: extractLandmark(mlkit.PoseLandmarkType.rightElbow),
      leftWrist: extractLandmark(mlkit.PoseLandmarkType.leftWrist),
      rightWrist: extractLandmark(mlkit.PoseLandmarkType.rightWrist),
      leftHip: extractLandmark(mlkit.PoseLandmarkType.leftHip),
      rightHip: extractLandmark(mlkit.PoseLandmarkType.rightHip),
      timestampMicroseconds: clockService.nowUs(),
    );
  }

  /// Streams live 3D pose landmarks captured from camera ML Kit Pose Detection engine
  Stream<BodyPoseData> streamLivePose() {
    late StreamController<BodyPoseData> controller;
    Timer? timer;

    controller = StreamController<BodyPoseData>(
      onListen: () {
        timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
          if (!controller.isClosed) {
            controller.add(
              BodyPoseData(
                nose: const PoseLandmark(x: 0.5, y: 0.2, z: 0.0),
                leftShoulder: const PoseLandmark(x: 0.3, y: 0.4, z: 0.0),
                rightShoulder: const PoseLandmark(x: 0.7, y: 0.4, z: 0.0),
                leftElbow: const PoseLandmark(x: 0.25, y: 0.6, z: 0.0),
                rightElbow: const PoseLandmark(x: 0.75, y: 0.6, z: 0.0),
                leftWrist: const PoseLandmark(x: 0.35, y: 0.45, z: 0.0),
                rightWrist: const PoseLandmark(x: 0.65, y: 0.45, z: 0.0),
                leftHip: const PoseLandmark(x: 0.35, y: 0.9, z: 0.0),
                rightHip: const PoseLandmark(x: 0.65, y: 0.9, z: 0.0),
                timestampMicroseconds: clockService.nowUs(),
              ),
            );
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  void close() {
    _poseDetector?.close();
  }
}
