import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fused_punch_event.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../entities/free_mode_config.dart';
import '../entities/free_mode_stats.dart';

abstract class FreeModeRepository {
  /// Initializes a free mode workout session
  Future<void> startSession(FreeModeConfig config);

  /// Processes live signals and calculates rolling cadence (PPM)
  FusedPunchEvent processLiveFrame({
    required AudioConfidenceScore audioResult,
    VisionConfidenceScore? visionResult,
    required FusionConfig config,
  });

  /// Retrieves current free mode statistics
  FreeModeStats getStats();

  /// Ends free mode session
  FreeModeStats endSession();
}
