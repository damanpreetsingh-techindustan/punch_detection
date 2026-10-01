import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../entities/fused_punch_event.dart';
import '../entities/fusion_config.dart';

abstract class FusionRepository {
  /// Combines real-time audio and vision confidence scores into a single FusedPunchEvent
  FusedPunchEvent fuseSignals({
    required AudioConfidenceScore audioResult,
    VisionConfidenceScore? visionResult,
    required FusionConfig config,
  });
}
