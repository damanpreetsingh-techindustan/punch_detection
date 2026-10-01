import '../../../../core/usecases/usecase.dart';
import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../entities/fused_punch_event.dart';
import '../entities/fusion_config.dart';
import '../repositories/fusion_repository.dart';

class CombineSignalsParams {
  final AudioConfidenceScore audioResult;
  final VisionConfidenceScore? visionResult;
  final FusionConfig config;

  const CombineSignalsParams({
    required this.audioResult,
    this.visionResult,
    required this.config,
  });
}

class CombineSignals implements UseCase<FusedPunchEvent, CombineSignalsParams> {
  final FusionRepository repository;

  CombineSignals(this.repository);

  @override
  Future<FusedPunchEvent> call(CombineSignalsParams params) async {
    return repository.fuseSignals(
      audioResult: params.audioResult,
      visionResult: params.visionResult,
      config: params.config,
    );
  }
}
