import 'dart:async';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../domain/entities/body_pose_data.dart';
import '../../domain/entities/pose_landmark.dart';

class TestVideoPoseDatasource {
  final MonotonicClockService clockService;

  TestVideoPoseDatasource({required this.clockService});

  /// Generates synthetic 3D pose data representing a fully extended punch motion (Elbow ~165°, wrist advanced, shoulder forward).
  BodyPoseData generateExtendedPunchPose() {
    return BodyPoseData(
      leftShoulder: const PoseLandmark(x: 0.2, y: 0.4, z: 0.1),
      rightShoulder: const PoseLandmark(
        x: 0.8,
        y: 0.4,
        z: 0.3,
      ), // Forward shoulder drive
      leftElbow: const PoseLandmark(x: 0.15, y: 0.6, z: 0.0),
      rightElbow: const PoseLandmark(x: 0.85, y: 0.4, z: 0.6), // Extended arm
      leftWrist: const PoseLandmark(x: 0.1, y: 0.8, z: -0.1),
      rightWrist: const PoseLandmark(x: 0.9, y: 0.4, z: 0.9), // Wrist advanced
      leftHip: const PoseLandmark(x: 0.3, y: 0.9, z: 0.0),
      rightHip: const PoseLandmark(x: 0.7, y: 0.9, z: 0.0),
      timestampMicroseconds: clockService.nowUs(),
    );
  }

  /// Generates synthetic 3D pose data representing an idle guard stance (Elbows bent ~65°, wrists near chin).
  BodyPoseData generateIdleGuardPose() {
    return BodyPoseData(
      leftShoulder: const PoseLandmark(x: 0.3, y: 0.4, z: 0.0),
      rightShoulder: const PoseLandmark(x: 0.7, y: 0.4, z: 0.0),
      leftElbow: const PoseLandmark(x: 0.25, y: 0.6, z: 0.0),
      rightElbow: const PoseLandmark(x: 0.75, y: 0.6, z: 0.0), // Bent elbows
      leftWrist: const PoseLandmark(x: 0.35, y: 0.45, z: 0.0), // Hands at chin
      rightWrist: const PoseLandmark(x: 0.65, y: 0.45, z: 0.0),
      leftHip: const PoseLandmark(x: 0.35, y: 0.9, z: 0.0),
      rightHip: const PoseLandmark(x: 0.65, y: 0.9, z: 0.0),
      timestampMicroseconds: clockService.nowUs(),
    );
  }

  /// Stream continuous synthetic pose data
  Stream<BodyPoseData> streamTestPoses({int intervalMs = 100}) {
    late StreamController<BodyPoseData> controller;
    Timer? timer;

    controller = StreamController<BodyPoseData>(
      onListen: () {
        timer = Timer.periodic(Duration(milliseconds: intervalMs), (t) {
          if (!controller.isClosed) {
            controller.add(generateIdleGuardPose());
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
}
