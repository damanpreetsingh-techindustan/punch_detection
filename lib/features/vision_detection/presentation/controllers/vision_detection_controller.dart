import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../domain/entities/body_pose_data.dart';
import '../../domain/entities/vision_confidence_score.dart';
import '../../domain/entities/vision_filter_config.dart';
import '../../domain/usecases/analyze_vision_pose.dart';

class VisionDetectionController extends GetxController {
  final AnalyzeVisionPose analyzeVisionPoseUseCase;
  final ConfigService configService;

  final RxDouble visionConfidence = 0.0.obs;
  final RxBool isMotionConfirmed = false.obs;
  final RxMap<String, bool> ruleResults = <String, bool>{}.obs;

  StreamSubscription<BodyPoseData>? _poseSubscription;

  VisionDetectionController({
    required this.analyzeVisionPoseUseCase,
    required this.configService,
  });

  void processPose(BodyPoseData pose) async {
    final config = VisionFilterConfig(
      minElbowExtensionAngle: 140.0,
      minWristAdvanceDelta: configService.visionWeight.value * 0.5,
    );

    final VisionConfidenceScore result = await analyzeVisionPoseUseCase(
      AnalyzeVisionPoseParams(pose: pose, config: config),
    );

    visionConfidence.value = result.score;
    isMotionConfirmed.value = result.isPunchMotionDetected;
    ruleResults.assignAll(result.ruleResults);
  }

  @override
  void onClose() {
    _poseSubscription?.cancel();
    super.onClose();
  }
}
