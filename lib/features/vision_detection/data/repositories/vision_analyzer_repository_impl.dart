import 'dart:async';
import '../../domain/entities/body_pose_data.dart';
import '../../domain/entities/vision_confidence_score.dart';
import '../../domain/entities/vision_filter_config.dart';
import '../../domain/repositories/vision_analyzer_repository.dart';
import '../datasources/mlkit_pose_datasource.dart';
import '../geometric_rules/elbow_extension_rule.dart';
import '../geometric_rules/shoulder_drive_rule.dart';
import '../geometric_rules/vision_geometric_rule.dart';
import '../geometric_rules/wrist_advance_rule.dart';

class VisionAnalyzerRepositoryImpl implements VisionAnalyzerRepository {
  final MLKitPoseDatasource mlKitDatasource;
  final List<VisionGeometricRule> rules;

  VisionAnalyzerRepositoryImpl({
    required this.mlKitDatasource,
    List<VisionGeometricRule>? customRules,
  }) : rules =
           customRules ??
           [ElbowExtensionRule(), WristAdvanceRule(), ShoulderDriveRule()];

  @override
  Stream<BodyPoseData> streamPoseData() {
    return mlKitDatasource.streamLivePose();
  }

  @override
  VisionConfidenceScore analyzePose(
    BodyPoseData pose,
    VisionFilterConfig config,
  ) {
    final Map<String, bool> ruleResults = {};
    final Map<String, dynamic> metrics = {};

    double totalScore = 0.0;
    int passCount = 0;

    for (final rule in rules) {
      final result = rule.evaluate(pose, config);
      ruleResults[rule.name] = result.passed;
      metrics[rule.name] = result.metrics;
      totalScore += result.score;
      if (result.passed) {
        passCount++;
      }
    }

    final double overallScore = (totalScore / rules.length).clamp(0.0, 1.0);
    final bool isPunchMotionDetected =
        ruleResults['Elbow Joint Extension Check'] == true && passCount >= 2;

    return VisionConfidenceScore(
      score: overallScore,
      isPunchMotionDetected: isPunchMotionDetected,
      timestampMicroseconds: pose.timestampMicroseconds,
      ruleResults: ruleResults,
      metrics: metrics,
    );
  }
}
