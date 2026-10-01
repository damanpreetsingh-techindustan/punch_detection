import 'package:flutter/foundation.dart';

/// Centralized Configuration for Temporal Multi-Signal Punch Detection & FSM.
///
/// Contains configurable constants for thresholds, weights, window sizes, and cooldowns.
@immutable
class PunchDetectionConfig {
  // ─── Pose Validity & Strict Front-Facing Alignment ───────────────────────
  final double minNoseConfidence;
  final double minEyeConfidence;
  final double minEarConfidence;
  final double minShoulderConfidence;
  final double minNormShoulderWidth;
  final double maxNormShoulderWidth;
  final double minEyeSymmetryThreshold;
  final double maxNoseCenteringOffsetRatio;
  final double minNoseCenteringScore;
  final double minFacingCameraScore;
  final int minConsecutiveFacingFrames;
  final double minShoulderSymmetryScore;
  final double maxFacialSymmetryRatio;
  final double minNormEyeDistance;
  final double maxHandFaceProximityRatio;

  // ─── Temporal Buffers & Windowing ──────────────────────────────────────────
  final int temporalWindowMs;
  final int candidateTimeoutMs;

  // ─── 100-Point Weighted Scoring Breakdown ──────────────────────────────────
  final double weightPoseValidity;
  final double weightHeadMovement;
  final double weightArmExtension;
  final double weightWristVelocity;
  final double weightForwardDepth;
  final double weightShoulderMovement;
  final double weightPunchTrajectory;
  final double weightTemporalConsistency;

  // ─── Thresholds for FSM Transitions ───────────────────────────────────────
  final double punchConfirmationScoreThreshold;
  final double candidateActivationScoreThreshold;
  final double minWristVelocityThreshold;
  final double minWristAccelerationThreshold;
  final double minArmExtensionThreshold;
  final double minShoulderMovementThreshold;
  final double minHeadMovementThreshold;
  final double minForwardDepthThreshold;
  final double retractionDistanceRatioThreshold;

  // ─── Cooldowns (ms) ────────────────────────────────────────────────────────
  final int sameArmCooldownMs;
  final int alternatingArmCooldownMs;

  // ─── Debug Telemetry & Guard Flags ───────────────────────────────────────
  final bool enableDebugLogging;
  final bool enableDeviceStabilityGuard;

  const PunchDetectionConfig({
    // Pose Validity & Facing Orientation
    this.minNoseConfidence = 0.55,
    this.minEyeConfidence = 0.55, // Both eyes required with >= 0.55
    this.minEarConfidence = 0.35, // Ear evaluation threshold when available
    this.minShoulderConfidence = 0.35,
    this.minNormShoulderWidth = 0.06,
    this.maxNormShoulderWidth = 0.92,
    this.minEyeSymmetryThreshold =
        0.48, // Tightened from 0.45 to reject side-facing profiles
    this.maxNoseCenteringOffsetRatio =
        0.52, // Tightened from 0.60 to reject off-center nose offset
    this.minNoseCenteringScore =
        0.25, // Minimum normalized nose centering score required
    this.minFacingCameraScore =
        0.50, // Composite facing camera score threshold (tightened from 0.45)
    this.minConsecutiveFacingFrames = 3, // Temporal stability frames required
    this.minShoulderSymmetryScore = 0.60,
    this.maxFacialSymmetryRatio = 1.85,
    this.minNormEyeDistance = 0.030,
    this.maxHandFaceProximityRatio = 0.28,

    // Temporal Windowing (150 - 300 ms)
    this.temporalWindowMs = 250,
    this.candidateTimeoutMs = 600,

    // 100-Point Scoring Weights (Sum = 100)
    this.weightPoseValidity = 10.0,
    this.weightHeadMovement = 0.0,
    this.weightArmExtension = 0.0,
    this.weightWristVelocity = 0.0,
    this.weightForwardDepth = 0.0,
    this.weightShoulderMovement = 85.0, // Primary Punch Reference (85.0 pts)
    this.weightPunchTrajectory = 0.0,
    this.weightTemporalConsistency = 5.0,

    // FSM Thresholds
    this.punchConfirmationScoreThreshold =
        55.0, // Calibrated so passive standing sway (score ~45) cannot confirm a punch
    this.candidateActivationScoreThreshold = 45.0,
    this.minWristVelocityThreshold = 0.35,
    this.minWristAccelerationThreshold = 0.20,
    this.minArmExtensionThreshold = 0.12,
    this.minShoulderMovementThreshold =
        0.040, // Calibrated for mobile close-ups & active shoulder pops (4.0% SW)
    this.minHeadMovementThreshold =
        0.025, // Calibrated for fast punches (2.5% SW)
    this.minForwardDepthThreshold = 0.035,
    this.retractionDistanceRatioThreshold = 0.35,

    // Cooldowns
    this.sameArmCooldownMs = 360,
    this.alternatingArmCooldownMs = 180,

    // Debugging & Device Guard Toggles
    this.enableDebugLogging = kDebugMode,
    this.enableDeviceStabilityGuard = true,
  });

  PunchDetectionConfig copyWith({
    double? minNoseConfidence,
    double? minEyeConfidence,
    double? minEarConfidence,
    double? minShoulderConfidence,
    double? minNormShoulderWidth,
    double? maxNormShoulderWidth,
    double? minEyeSymmetryThreshold,
    double? maxNoseCenteringOffsetRatio,
    double? minNoseCenteringScore,
    double? minFacingCameraScore,
    int? minConsecutiveFacingFrames,
    double? minShoulderSymmetryScore,
    double? maxFacialSymmetryRatio,
    double? minNormEyeDistance,
    double? maxHandFaceProximityRatio,
    int? temporalWindowMs,
    int? candidateTimeoutMs,
    double? weightPoseValidity,
    double? weightArmExtension,
    double? weightWristVelocity,
    double? weightForwardDepth,
    double? weightShoulderMovement,
    double? weightPunchTrajectory,
    double? weightTemporalConsistency,
    double? punchConfirmationScoreThreshold,
    double? candidateActivationScoreThreshold,
    double? minWristVelocityThreshold,
    double? minWristAccelerationThreshold,
    double? minArmExtensionThreshold,
    double? minShoulderMovementThreshold,
    double? minForwardDepthThreshold,
    double? retractionDistanceRatioThreshold,
    int? sameArmCooldownMs,
    int? alternatingArmCooldownMs,
    bool? enableDebugLogging,
    bool? enableDeviceStabilityGuard,
  }) {
    return PunchDetectionConfig(
      minNoseConfidence: minNoseConfidence ?? this.minNoseConfidence,
      minEyeConfidence: minEyeConfidence ?? this.minEyeConfidence,
      minEarConfidence: minEarConfidence ?? this.minEarConfidence,
      minShoulderConfidence:
          minShoulderConfidence ?? this.minShoulderConfidence,
      minNormShoulderWidth: minNormShoulderWidth ?? this.minNormShoulderWidth,
      maxNormShoulderWidth: maxNormShoulderWidth ?? this.maxNormShoulderWidth,
      minEyeSymmetryThreshold:
          minEyeSymmetryThreshold ?? this.minEyeSymmetryThreshold,
      maxNoseCenteringOffsetRatio:
          maxNoseCenteringOffsetRatio ?? this.maxNoseCenteringOffsetRatio,
      minNoseCenteringScore:
          minNoseCenteringScore ?? this.minNoseCenteringScore,
      minFacingCameraScore: minFacingCameraScore ?? this.minFacingCameraScore,
      minConsecutiveFacingFrames:
          minConsecutiveFacingFrames ?? this.minConsecutiveFacingFrames,
      minShoulderSymmetryScore:
          minShoulderSymmetryScore ?? this.minShoulderSymmetryScore,
      maxFacialSymmetryRatio:
          maxFacialSymmetryRatio ?? this.maxFacialSymmetryRatio,
      minNormEyeDistance: minNormEyeDistance ?? this.minNormEyeDistance,
      maxHandFaceProximityRatio:
          maxHandFaceProximityRatio ?? this.maxHandFaceProximityRatio,
      temporalWindowMs: temporalWindowMs ?? this.temporalWindowMs,
      candidateTimeoutMs: candidateTimeoutMs ?? this.candidateTimeoutMs,
      weightPoseValidity: weightPoseValidity ?? this.weightPoseValidity,
      weightArmExtension: weightArmExtension ?? this.weightArmExtension,
      weightWristVelocity: weightWristVelocity ?? this.weightWristVelocity,
      weightForwardDepth: weightForwardDepth ?? this.weightForwardDepth,
      weightShoulderMovement:
          weightShoulderMovement ?? this.weightShoulderMovement,
      weightPunchTrajectory:
          weightPunchTrajectory ?? this.weightPunchTrajectory,
      weightTemporalConsistency:
          weightTemporalConsistency ?? this.weightTemporalConsistency,
      punchConfirmationScoreThreshold:
          punchConfirmationScoreThreshold ??
          this.punchConfirmationScoreThreshold,
      candidateActivationScoreThreshold:
          candidateActivationScoreThreshold ??
          this.candidateActivationScoreThreshold,
      minWristVelocityThreshold:
          minWristVelocityThreshold ?? this.minWristVelocityThreshold,
      minWristAccelerationThreshold:
          minWristAccelerationThreshold ?? this.minWristAccelerationThreshold,
      minArmExtensionThreshold:
          minArmExtensionThreshold ?? this.minArmExtensionThreshold,
      minShoulderMovementThreshold:
          minShoulderMovementThreshold ?? this.minShoulderMovementThreshold,
      minForwardDepthThreshold:
          minForwardDepthThreshold ?? this.minForwardDepthThreshold,
      retractionDistanceRatioThreshold:
          retractionDistanceRatioThreshold ??
          this.retractionDistanceRatioThreshold,
      sameArmCooldownMs: sameArmCooldownMs ?? this.sameArmCooldownMs,
      alternatingArmCooldownMs:
          alternatingArmCooldownMs ?? this.alternatingArmCooldownMs,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
      enableDeviceStabilityGuard:
          enableDeviceStabilityGuard ?? this.enableDeviceStabilityGuard,
    );
  }
}
