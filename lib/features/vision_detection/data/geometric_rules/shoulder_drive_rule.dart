import 'dart:math';
import '../../domain/entities/body_pose_data.dart';
import '../../domain/entities/vision_filter_config.dart';
import 'vision_geometric_rule.dart';

class ShoulderDriveRule implements VisionGeometricRule {
  @override
  String get name => 'Shoulder Drive & Torso Rotation';

  @override
  RuleResult evaluate(BodyPoseData pose, VisionFilterConfig config) {
    // Calculates forward shoulder rotation relative to hip baseline
    final double shoulderDist = (pose.leftShoulder.z - pose.rightShoulder.z).abs();
    final double hipDist = (pose.leftHip.z - pose.rightHip.z).abs();
    final double shoulderDrive = (shoulderDist - hipDist).abs();

    final bool passed = shoulderDrive >= config.minShoulderDriveDelta || shoulderDist >= config.minShoulderDriveDelta;
    final double maxDrive = max(shoulderDrive, shoulderDist);
    final double score = (maxDrive / (config.minShoulderDriveDelta * 2)).clamp(0.0, 1.0);

    return RuleResult(
      passed: passed,
      ruleName: name,
      score: score,
      metrics: {
        'shoulderDist': shoulderDist,
        'hipDist': hipDist,
        'shoulderDrive': shoulderDrive,
        'requiredDelta': config.minShoulderDriveDelta,
      },
    );
  }
}
