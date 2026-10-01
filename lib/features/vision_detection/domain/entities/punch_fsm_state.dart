/// 5-State Finite State Machine Enum for Punch Detection.
enum PunchFsmState {
  idle,
  punchCandidate,
  punchConfirmed,
  cooldown,
  armRetracted,
}

/// Arm Trajectory Phase.
enum ArmTrajectoryPhase { guard, extending, peakExtension, retracting }
