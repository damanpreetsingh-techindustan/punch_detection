import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fused_punch_event.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../entities/session_config.dart';
import '../entities/workout_session_stats.dart';

abstract class WorkoutSessionRepository {
  /// Initializes live workout session streams
  Future<void> startSession(SessionConfig config);

  /// Feeds live audio and vision signals into the fusion combiner
  FusedPunchEvent processLiveFrame({
    required AudioConfidenceScore audioResult,
    VisionConfidenceScore? visionResult,
    required FusionConfig config,
  });

  /// Pauses active workout session
  void pauseSession();

  /// Resumes paused workout session
  void resumeSession();

  /// Ends workout session and compiles final statistics
  WorkoutSessionStats endSession();
}
