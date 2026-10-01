import '../../domain/entities/body_pose_data.dart';
import '../../domain/entities/vision_filter_config.dart';

class RuleResult {
  final bool passed;
  final String ruleName;
  final double score; // 0.0 to 1.0
  final Map<String, dynamic> metrics;

  const RuleResult({
    required this.passed,
    required this.ruleName,
    required this.score,
    required this.metrics,
  });
}

abstract class VisionGeometricRule {
  String get name;

  RuleResult evaluate(BodyPoseData pose, VisionFilterConfig config);
}
