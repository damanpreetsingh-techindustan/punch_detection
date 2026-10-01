import 'dart:math';
import '../../domain/entities/body_pose_data.dart';
import '../../domain/entities/vision_filter_config.dart';
import 'vision_geometric_rule.dart';

class ElbowExtensionRule implements VisionGeometricRule {
  @override
  String get name => 'Elbow Joint Extension Check';

  @override
  RuleResult evaluate(BodyPoseData pose, VisionFilterConfig config) {
    final double leftAngle = BodyPoseData.calculateAngle(
      pose.leftShoulder,
      pose.leftElbow,
      pose.leftWrist,
    );

    final double rightAngle = BodyPoseData.calculateAngle(
      pose.rightShoulder,
      pose.rightElbow,
      pose.rightWrist,
    );

    final double maxAngle = max(leftAngle, rightAngle);
    final bool passed = maxAngle >= config.minElbowExtensionAngle;
    final double score = (maxAngle / 180.0).clamp(0.0, 1.0);

    return RuleResult(
      passed: passed,
      ruleName: name,
      score: score,
      metrics: {
        'leftElbowAngle': leftAngle,
        'rightElbowAngle': rightAngle,
        'maxElbowAngle': maxAngle,
        'requiredMinAngle': config.minElbowExtensionAngle,
      },
    );
  }
}
