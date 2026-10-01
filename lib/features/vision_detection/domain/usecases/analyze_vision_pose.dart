import '../../../../core/usecases/usecase.dart';
import '../entities/body_pose_data.dart';
import '../entities/vision_confidence_score.dart';
import '../entities/vision_filter_config.dart';
import '../repositories/vision_analyzer_repository.dart';

class AnalyzeVisionPoseParams {
  final BodyPoseData pose;
  final VisionFilterConfig config;

  const AnalyzeVisionPoseParams({
    required this.pose,
    required this.config,
  });
}

class AnalyzeVisionPose implements UseCase<VisionConfidenceScore, AnalyzeVisionPoseParams> {
  final VisionAnalyzerRepository repository;

  AnalyzeVisionPose(this.repository);

  @override
  Future<VisionConfidenceScore> call(AnalyzeVisionPoseParams params) async {
    return repository.analyzePose(params.pose, params.config);
  }
}
