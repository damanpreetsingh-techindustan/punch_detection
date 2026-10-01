import 'package:equatable/equatable.dart';

class VisionFilterConfig extends Equatable {
  // ── Existing geometry thresholds ──────────────────────────────────────────
  final double minElbowExtensionAngle; // e.g. 140.0 degrees
  final double minWristAdvanceDelta;   // e.g. 0.15 normalized units
  final double minShoulderDriveDelta;  // e.g. 0.08 normalized units

  // ── Validity gate thresholds ──────────────────────────────────────────────
  /// Minimum ML Kit likelihood for each shoulder to be considered detected.
  final double minShoulderLikelihood;

  /// Minimum shoulder-to-shoulder distance as a fraction of image width.
  /// Prevents hands/fingers from satisfying the shoulder check.
  final double minNormalisedShoulderWidth;

  /// Maximum shoulder-to-shoulder distance as a fraction of image width.
  /// Prevents ML Kit pose hallucinations from triggering detection.
  final double maxNormalisedShoulderWidth;

  /// Shoulders must be below this fraction of image height (measured from top).
  /// A value of 0.15 means shoulders must appear below the top 15% of the frame.
  final double maxShoulderTopYFraction;

  // ── Punch signal thresholds ───────────────────────────────────────────────
  /// Minimum elbow likelihood for elbow-emergence signal (increased from 0.40).
  final double minElbowLikelihoodForEmergence;

  /// Maximum contraction ratio to trigger the shoulder-width contraction signal.
  /// 0.82 = 18% contraction required (tighter than the original 15%).
  final double maxContractionRatio;

  // ── Stability tracker settings ────────────────────────────────────────────
  /// Number of stable frames required before punch detection is armed.
  final int stabilityWindowFrames;

  /// Maximum average inter-frame shoulder-centre displacement (pixels) allowed
  /// to consider the person "stable".
  final double maxStabilityDisplacementPerFrame;

  /// Grace period (ms) for the stability tracker after a validity failure.
  final int stabilityGracePeriodMs;

  const VisionFilterConfig({
    this.minElbowExtensionAngle = 140.0,
    this.minWristAdvanceDelta = 0.15,
    this.minShoulderDriveDelta = 0.08,
    this.minShoulderLikelihood = 0.60,
    this.minNormalisedShoulderWidth = 0.12,
    this.maxNormalisedShoulderWidth = 0.80,
    this.maxShoulderTopYFraction = 0.15,
    this.minElbowLikelihoodForEmergence = 0.50,
    this.maxContractionRatio = 0.82,
    this.stabilityWindowFrames = 5,
    this.maxStabilityDisplacementPerFrame = 8.0,
    this.stabilityGracePeriodMs = 1000,
  });

  @override
  List<Object?> get props => [
        minElbowExtensionAngle,
        minWristAdvanceDelta,
        minShoulderDriveDelta,
        minShoulderLikelihood,
        minNormalisedShoulderWidth,
        maxNormalisedShoulderWidth,
        maxShoulderTopYFraction,
        minElbowLikelihoodForEmergence,
        maxContractionRatio,
        stabilityWindowFrames,
        maxStabilityDisplacementPerFrame,
        stabilityGracePeriodMs,
      ];
}

