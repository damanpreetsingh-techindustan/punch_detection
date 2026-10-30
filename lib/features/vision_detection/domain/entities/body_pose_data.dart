import 'dart:math';
import 'package:equatable/equatable.dart';
import 'pose_landmark.dart';

class BodyPoseData extends Equatable {
  /// Head / nose landmark. Optional — defaults to likelihood 0 when absent.
  /// Used by the pose validity gate as a soft confidence signal.
  final PoseLandmark nose;
  final PoseLandmark leftShoulder;
  final PoseLandmark rightShoulder;
  final PoseLandmark leftElbow;
  final PoseLandmark rightElbow;
  final PoseLandmark leftWrist;
  final PoseLandmark rightWrist;
  final PoseLandmark leftHip;
  final PoseLandmark rightHip;
  final int timestampMicroseconds;

  const BodyPoseData({
    this.nose = const PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0),
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftElbow,
    required this.rightElbow,
    required this.leftWrist,
    required this.rightWrist,
    required this.leftHip,
    required this.rightHip,
    required this.timestampMicroseconds,
  });

  /// Calculates the 3D joint angle (in degrees) formed by three points p1 -> vertex -> p3.
  static double calculateAngle(
    PoseLandmark p1,
    PoseLandmark vertex,
    PoseLandmark p3,
  ) {
    final double v1x = p1.x - vertex.x;
    final double v1y = p1.y - vertex.y;
    final double v1z = p1.z - vertex.z;

    final double v2x = p3.x - vertex.x;
    final double v2y = p3.y - vertex.y;
    final double v2z = p3.z - vertex.z;

    final double dotProduct = (v1x * v2x) + (v1y * v2y) + (v1z * v2z);
    final double mag1 = sqrt((v1x * v1x) + (v1y * v1y) + (v1z * v1z));
    final double mag2 = sqrt((v2x * v2x) + (v2y * v2y) + (v2z * v2z));

    if (mag1 == 0 || mag2 == 0) return 0.0;

    final double cosTheta = (dotProduct / (mag1 * mag2)).clamp(-1.0, 1.0);
    final double radians = acos(cosTheta);
    return radians * (180.0 / pi);
  }

  @override
  List<Object?> get props => [
    nose,
    leftShoulder,
    rightShoulder,
    leftElbow,
    rightElbow,
    leftWrist,
    rightWrist,
    leftHip,
    rightHip,
    timestampMicroseconds,
  ];
}
