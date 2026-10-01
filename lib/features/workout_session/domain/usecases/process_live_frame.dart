import '../../../../core/usecases/usecase.dart';
import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fused_punch_event.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../repositories/workout_session_repository.dart';

class ProcessLiveFrameParams {
  final AudioConfidenceScore audioResult;
  final VisionConfidenceScore? visionResult;
  final FusionConfig config;

  const ProcessLiveFrameParams({
    required this.audioResult,
    this.visionResult,
    required this.config,
  });
}

class ProcessLiveFrame implements UseCase<FusedPunchEvent, ProcessLiveFrameParams> {
  final WorkoutSessionRepository repository;

  ProcessLiveFrame(this.repository);

  @override
  Future<FusedPunchEvent> call(ProcessLiveFrameParams params) async {
    return repository.processLiveFrame(
      audioResult: params.audioResult,
      visionResult: params.visionResult,
      config: params.config,
    );
  }
}
