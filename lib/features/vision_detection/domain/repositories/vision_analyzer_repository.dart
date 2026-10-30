import '../entities/body_pose_data.dart';
import '../entities/vision_confidence_score.dart';
import '../entities/vision_filter_config.dart';

abstract class VisionAnalyzerRepository {
  /// Stream continuous 3D pose landmarks from camera datasource
  Stream<BodyPoseData> streamPoseData();

  /// Analyzes a single 3D pose against geometric punch motion rules
  VisionConfidenceScore analyzePose(
    BodyPoseData pose,
    VisionFilterConfig config,
  );
}
