import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../../domain/entities/fused_punch_event.dart';
import '../../domain/entities/fusion_config.dart';
import '../../domain/repositories/fusion_repository.dart';

class FusionRepositoryImpl implements FusionRepository {
  @override
  FusedPunchEvent fuseSignals({
    required AudioConfidenceScore audioResult,
    VisionConfidenceScore? visionResult,
    required FusionConfig config,
  }) {
    // 1. Audio Primary Gate: Movement without an audio impact spike is rejected
    if (!audioResult.isPunchCandidate) {
      return FusedPunchEvent(
        timestampMicroseconds: audioResult.timestampMicroseconds,
        fusedConfidenceScore: 0.0,
        isPunchConfirmed: false,
        audioScore: audioResult.score,
        visionScore: visionResult?.score ?? 0.0,
        fusionMode: visionResult != null ? FusionMode.fusion : FusionMode.cameraFallback,
      );
    }

    // 2. Camera Offline / Fallback check
    if (visionResult == null) {
      final double fallbackScore = audioResult.score;
      final bool isConfirmed = fallbackScore >= config.minFusedConfidenceThreshold;
      return FusedPunchEvent(
        timestampMicroseconds: audioResult.timestampMicroseconds,
        fusedConfidenceScore: fallbackScore,
        isPunchConfirmed: isConfirmed,
        audioScore: audioResult.score,
        visionScore: 0.0,
        fusionMode: FusionMode.cameraFallback,
      );
    }

    // 3. Coincidence Window Check (timestamp offset within 150ms)
    final int timeDiffUs = (audioResult.timestampMicroseconds - visionResult.timestampMicroseconds).abs();
    final int timeDiffMs = timeDiffUs ~/ 1000;

    if (timeDiffMs > config.coincidenceWindowMs) {
      // Out-of-window vision frame -> Fallback to Audio Primary
      final double fallbackScore = audioResult.score;
      final bool isConfirmed = fallbackScore >= config.minFusedConfidenceThreshold;
      return FusedPunchEvent(
        timestampMicroseconds: audioResult.timestampMicroseconds,
        fusedConfidenceScore: fallbackScore,
        isPunchConfirmed: isConfirmed,
        audioScore: audioResult.score,
        visionScore: visionResult.score,
        fusionMode: FusionMode.cameraFallback,
      );
    }

    // 4. Weighted Fusion Combination Formula
    final double fusedScore = (config.audioWeight * audioResult.score) + (config.visionWeight * visionResult.score);
    final bool isConfirmed = fusedScore >= config.minFusedConfidenceThreshold;

    return FusedPunchEvent(
      timestampMicroseconds: audioResult.timestampMicroseconds,
      fusedConfidenceScore: fusedScore.clamp(0.0, 1.0),
      isPunchConfirmed: isConfirmed,
      audioScore: audioResult.score,
      visionScore: visionResult.score,
      fusionMode: FusionMode.fusion,
    );
  }
}
