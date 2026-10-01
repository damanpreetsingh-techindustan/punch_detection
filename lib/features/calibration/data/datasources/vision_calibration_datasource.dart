import '../../../vision_detection/domain/entities/body_pose_data.dart';

class VisionCalibrationDatasource {
  /// Validates subject camera framing by verifying key 3D landmarks (shoulders, hips) are detected
  bool validateSubjectFraming(BodyPoseData? pose) {
    if (pose == null) return false;

    // Subject is properly framed if left/right shoulders and hips have high likelihood
    final double shoulderLikelihood = (pose.leftShoulder.likelihood + pose.rightShoulder.likelihood) / 2.0;
    final double hipLikelihood = (pose.leftHip.likelihood + pose.rightHip.likelihood) / 2.0;

    return shoulderLikelihood >= 0.5 && hipLikelihood >= 0.5;
  }
}
