import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fused_punch_event.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../fusion/domain/repositories/fusion_repository.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/workout_session_stats.dart';
import '../../domain/repositories/workout_session_repository.dart';

class WorkoutSessionRepositoryImpl implements WorkoutSessionRepository {
  final FusionRepository fusionRepository;

  WorkoutSessionStats _currentStats = WorkoutSessionStats.initial();

  WorkoutSessionRepositoryImpl({required this.fusionRepository});

  @override
  Future<void> startSession(SessionConfig config) async {
    _currentStats = WorkoutSessionStats.initial().copyWith(
      totalRounds: config.totalRounds,
      isCameraActive: !config.isAudioOnly,
    );
  }

  @override
  FusedPunchEvent processLiveFrame({
    required AudioConfidenceScore audioResult,
    VisionConfidenceScore? visionResult,
    required FusionConfig config,
  }) {
    final FusedPunchEvent event = fusionRepository.fuseSignals(
      audioResult: audioResult,
      visionResult: visionResult,
      config: config,
    );

    if (event.isPunchConfirmed) {
      final int newTotal = _currentStats.totalPunches + 1;
      _currentStats = _currentStats.copyWith(totalPunches: newTotal);
    }

    return event;
  }

  @override
  void pauseSession() {}

  @override
  void resumeSession() {}

  @override
  WorkoutSessionStats endSession() {
    return _currentStats;
  }
}
