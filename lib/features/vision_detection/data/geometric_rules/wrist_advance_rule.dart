import 'dart:math';
import '../../domain/entities/body_pose_data.dart';
import '../../domain/entities/vision_filter_config.dart';
import 'vision_geometric_rule.dart';

class WristAdvanceRule implements VisionGeometricRule {
  @override
  String get name => 'Wrist Advance Past Shoulder';

  @override
  RuleResult evaluate(BodyPoseData pose, VisionFilterConfig config) {
    // Calculates Z/X displacement of wrist relative to shoulder
    final double leftAdvance =
        (pose.leftWrist.z - pose.leftShoulder.z).abs() +
        (pose.leftWrist.x - pose.leftShoulder.x).abs();
    final double rightAdvance =
        (pose.rightWrist.z - pose.rightShoulder.z).abs() +
        (pose.rightWrist.x - pose.rightShoulder.x).abs();

    final double maxAdvance = max(leftAdvance, rightAdvance);
    final bool passed = maxAdvance >= config.minWristAdvanceDelta;
    final double score = (maxAdvance / (config.minWristAdvanceDelta * 2)).clamp(
      0.0,
      1.0,
    );

    return RuleResult(
      passed: passed,
      ruleName: name,
      score: score,
      metrics: {
        'leftWristAdvance': leftAdvance,
        'rightWristAdvance': rightAdvance,
        'maxAdvance': maxAdvance,
        'requiredDelta': config.minWristAdvanceDelta,
      },
    );
  }
}
