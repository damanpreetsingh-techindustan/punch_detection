import '../../../../core/usecases/usecase.dart';
import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fused_punch_event.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../repositories/free_mode_repository.dart';

class ProcessFreeModeImpactParams {
  final AudioConfidenceScore audioResult;
  final VisionConfidenceScore? visionResult;
  final FusionConfig config;

  const ProcessFreeModeImpactParams({
    required this.audioResult,
    this.visionResult,
    required this.config,
  });
}

class ProcessFreeModeImpact implements UseCase<FusedPunchEvent, ProcessFreeModeImpactParams> {
  final FreeModeRepository repository;

  ProcessFreeModeImpact(this.repository);

  @override
  Future<FusedPunchEvent> call(ProcessFreeModeImpactParams params) async {
    return repository.processLiveFrame(
      audioResult: params.audioResult,
      visionResult: params.visionResult,
      config: params.config,
    );
  }
}
