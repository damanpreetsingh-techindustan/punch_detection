import 'dart:math';
import '../entities/punch_detection_config.dart';
// import '../entities/punch_fsm_state.dart';
import 'arm_kinetic_tracker.dart';

/// Detailed Breakdown of Feature Signal Scores for Live Telemetry UI.
class SignalScoreBreakdown {
  final double totalScore;
  final double scoreShoulder;
  final double scoreHead;
  final double scoreVelocity;
  final double scoreValidity;
  final double scoreTrajectory;
  final double scoreDepth;
  final double scoreExtension;
  final double scoreTemporal;
  final double rawShoulderMovement;
  final double rawHeadMovement;
  final double rawMotionVelocity;
  final double rawArmExtension;
  final double rawRelativeDepth;
  final String activeArm;

  const SignalScoreBreakdown({
    this.totalScore = 0.0,
    this.scoreShoulder = 0.0,
    this.scoreHead = 0.0,
    this.scoreVelocity = 0.0,
    this.scoreValidity = 0.0,
    this.scoreTrajectory = 0.0,
    this.scoreDepth = 0.0,
    this.scoreExtension = 0.0,
    this.scoreTemporal = 0.0,
    this.rawShoulderMovement = 0.0,
    this.rawHeadMovement = 0.0,
    this.rawMotionVelocity = 0.0,
    this.rawArmExtension = 0.0,
    this.rawRelativeDepth = 0.0,
    this.activeArm = 'right',
  });
}

/// Single-Responsibility Service: Computes the 100-Point Weighted Signal Score Breakdown.
class PunchScoringEngine {
  SignalScoreBreakdown calculateScore({
    required ArmKineticTracker tracker,
    required double shoulderWidth,
    required PunchDetectionConfig config,
  }) {
    // 1. Pose Validity (Max 10)
    double scoreValidity = config.weightPoseValidity;

    // 2. Head Movement & Dynamics (Max 10) - Commented Out
    /*
    double scoreHead = 0.0;
    if (tracker.shoulderMovement >= config.minShoulderMovementThreshold &&
        tracker.headMovement >= config.minHeadMovementThreshold) {
      final double netHead =
          tracker.headMovement - config.minHeadMovementThreshold;
      const double targetActiveHeadRange = 0.025;
      scoreHead = min(
        config.weightHeadMovement,
        (netHead / targetActiveHeadRange) * config.weightHeadMovement,
      );
    }
    */
    double scoreHead = 0.0;

    // 3. Arm Extension (Max 8 - Commented out per user request)
    double scoreExtension = 0.0;
    /*
    if (config.weightArmExtension > 0.0 &&
        tracker.armExtension >= config.minArmExtensionThreshold) {
      final double netExt =
          tracker.armExtension - config.minArmExtensionThreshold;
      const double targetActiveExtRange = 0.40;
      scoreExtension = min(
        config.weightArmExtension,
        (netExt / targetActiveExtRange) * config.weightArmExtension,
      );
    }
    */

    // 4. Motion Velocity (Max 10 - Commented out per user request)
    double scoreVelocity = 0.0;
    /*
    if (tracker.armExtension >= 0.50 &&
        tracker.shoulderMovement >= config.minShoulderMovementThreshold &&
        tracker.motionVelocity >= config.minWristVelocityThreshold) {
      final double baseVelScore = min(
        config.weightWristVelocity,
        (tracker.motionVelocity / 2.0) * config.weightWristVelocity,
      );
      final double fastBonus =
          (tracker.motionVelocity >= 1.50 &&
           tracker.shoulderMovement >= 0.045 &&
           tracker.wristVelocity >= 0.25)
              ? 10.0
              : 0.0;
      scoreVelocity = baseVelScore + fastBonus;
    }
    */

    // 5. Forward Depth Movement (Max 0 - Disabled)
    double scoreDepth = 0.0;

    // 6. Shoulder Movement (Max 65 - Primary Kinetic Signal with Sigmoidal Response Curve)
    double scoreShoulder = 0.0;
    if (tracker.shoulderMovement >= config.minShoulderMovementThreshold) {
      final double netMovement =
          tracker.shoulderMovement - config.minShoulderMovementThreshold;

      // SIGMOIDAL S-CURVE RESPONSE:
      // Calibrated to ignore idle standing sway (netMovement < 0.010 SW) while rapidly scaling for active punches (netMovement >= 0.018 SW).
      const double k = 85.0; // Steepness gain
      const double x0 = 0.018; // Midpoint offset to reject idle standing sway
      final double sigmoid = 1.0 / (1.0 + exp(-k * (netMovement - x0)));

      scoreShoulder = (sigmoid * config.weightShoulderMovement).clamp(
        0.0,
        config.weightShoulderMovement,
      );
    }

    // 7. Punch Trajectory (Max 10 - Commented out per user request)
    double scoreTrajectory = 0.0;
    /*
    if (tracker.armExtension >= 0.60 &&
        tracker.shoulderMovement >= 0.06 &&
        tracker.motionVelocity >= 0.35 &&
        (tracker.phase == ArmTrajectoryPhase.extending ||
            tracker.phase == ArmTrajectoryPhase.peakExtension)) {
      scoreTrajectory = config.weightPunchTrajectory;
    }
    */

    // 8. Temporal Consistency (Max 5)
    double scoreTemporal = 0.0;
    if (tracker.history.length >= 4) {
      scoreTemporal = config.weightTemporalConsistency;
    }

    final double totalScore =
        (scoreValidity +
                scoreHead +
                scoreExtension +
                scoreVelocity +
                scoreDepth +
                scoreShoulder +
                scoreTrajectory +
                scoreTemporal)
            .clamp(0.0, 100.0);

    return SignalScoreBreakdown(
      totalScore: totalScore,
      scoreShoulder: scoreShoulder,
      scoreHead: scoreHead,
      scoreVelocity: scoreVelocity,
      scoreValidity: scoreValidity,
      scoreTrajectory: scoreTrajectory,
      scoreDepth: scoreDepth,
      scoreExtension: scoreExtension,
      scoreTemporal: scoreTemporal,
      rawShoulderMovement: tracker.shoulderMovement,
      rawHeadMovement: tracker.headMovement,
      rawMotionVelocity: tracker.motionVelocity,
      rawArmExtension: tracker.armExtension,
      rawRelativeDepth: tracker.relativeDepthMovement,
      activeArm: tracker.side,
    );
  }
}
