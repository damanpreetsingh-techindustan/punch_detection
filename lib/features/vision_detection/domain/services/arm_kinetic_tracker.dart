import 'dart:math';
import '../entities/pose_frame_sample.dart';
import '../entities/punch_fsm_state.dart';

/// Independent Arm Kinetic Tracker.
/// Computes normalized 2D/3D metrics (extension, velocity, shoulder drive, trajectory)
/// across a temporal sliding window.
class ArmKineticTracker {
  final String side; // 'left' or 'right'
  PunchFsmState fsmState = PunchFsmState.idle;
  ArmTrajectoryPhase phase = ArmTrajectoryPhase.guard;

  final List<PoseFrameSample> _history = [];

  double currentScore = 0.0;
  double peakExtensionInCandidate = 0.0;
  double lastPunchPeakExtension = 0.0;
  double baselineGuardExtension = 0.0;
  int candidateStartTimeMs = 0;
  int lastPunchTimeMs = 0;

  /// Stance anchor baseline coordinates
  double _baselineShoulderX = 0.0;
  double _baselineShoulderY = 0.0;
  bool _hasBaselineShoulderAnchor = false;
  double _prevShoulderVel = 0.0;

  /// Mandatory physical arm retraction flag.
  bool hasRetractedSinceLastPunch = true;

  // Real-time derived kinetic metrics
  double wristVelocity = 0.0; // shoulder-widths / sec
  double wristAcceleration = 0.0; // shoulder-widths / sec²
  double motionVelocity = 0.0; // Max of 2D Velocity or Z-Depth Thrust
  double armExtension = 0.0; // fraction of shoulder-width
  double shoulderMovement = 0.0; // fraction of shoulder-width
  double headMovement = 0.0; // fraction of shoulder-width
  double relativeDepthMovement = 0.0; // Z-axis forward thrust
  double minRecentGuardExtension =
      0.45; // Lowest extension reach observed in recent guard stance

  ArmKineticTracker({required this.side});

  List<PoseFrameSample> get history => List.unmodifiable(_history);

  void addSample(PoseFrameSample sample, int maxWindowMs) {
    _history.add(sample);
    _history.removeWhere(
      (s) => (sample.timestampMs - s.timestampMs) > maxWindowMs,
    );
  }

  void reset() {
    _history.clear();
    fsmState = PunchFsmState.idle;
    phase = ArmTrajectoryPhase.guard;
    currentScore = 0.0;
    peakExtensionInCandidate = 0.0;
    lastPunchPeakExtension = 0.0;
    hasRetractedSinceLastPunch = true;
    wristVelocity = 0.0;
    wristAcceleration = 0.0;
    motionVelocity = 0.0;
    armExtension = 0.0;
    shoulderMovement = 0.0;
    headMovement = 0.0;
    relativeDepthMovement = 0.0;
    minRecentGuardExtension = 0.45;
    _hasBaselineShoulderAnchor = false;
    _prevShoulderVel = 0.0;
  }

  void resetHistory() {
    _history.clear();
  }

  /// Updates derived kinetic metrics across temporal buffer.
  void updateMetrics(double shoulderWidth) {
    if (_history.length < 2) return;

    final latest = _history.last;
    final prev = _history[_history.length - 2];

    final double dt = (latest.timestampMs - prev.timestampMs) / 1000.0;
    if (dt <= 0.005) return;

    // 1. Arm Velocity Calculation (Commented out per user request)
    /*
    if (latest.elbow != null && prev.elbow != null) {
      final double elbowDisp = sqrt(
        pow(latest.elbow!.dx - prev.elbow!.dx, 2) +
            pow(latest.elbow!.dy - prev.elbow!.dy, 2),
      );
      final double normElbowDisp = elbowDisp / shoulderWidth;
      final double newVel = normElbowDisp / dt;

      if (newVel <= 3.5 && normElbowDisp <= 1.4) {
        wristAcceleration = (newVel - wristVelocity) / dt;
        wristVelocity = wristVelocity * 0.40 + newVel * 0.60;
      }
    }
    */
    wristVelocity = 0.0;

    // 2. Arm Extension Reach (Commented out per user request)
    /*
    if (latest.elbow != null) {
      final double dist2D =
          sqrt(
            pow(latest.elbow!.dx - latest.shoulder.dx, 2) +
                pow(latest.elbow!.dy - latest.shoulder.dy, 2),
          ) /
          shoulderWidth;

      double zExt = max(
        0.0,
        (prev.shoulderZ - latest.shoulderZ) / (shoulderWidth * 1.0),
      ).clamp(0.0, 0.65);

      if (dist2D < 0.40) {
        zExt = min(zExt, 0.15);
      }

      armExtension = (dist2D + zExt).clamp(0.0, 1.10);

      if (fsmState == PunchFsmState.idle && armExtension > 0.0) {
        if (armExtension < minRecentGuardExtension) {
          minRecentGuardExtension = armExtension;
        } else {
          minRecentGuardExtension = minRecentGuardExtension * 0.90 + armExtension * 0.10;
        }
      }
    }
    */
    armExtension = 0.0;

    // 3. Shoulder Movement (Baseline Stance Anchor)
    final double rawShoulderDisp =
        sqrt(
          pow(latest.shoulder.dx - prev.shoulder.dx, 2) +
              pow(latest.shoulder.dy - prev.shoulder.dy, 2),
        ) /
        shoulderWidth;

    if (fsmState == PunchFsmState.idle) {
      if (!_hasBaselineShoulderAnchor) {
        _baselineShoulderX = latest.shoulder.dx;
        _baselineShoulderY = latest.shoulder.dy;
        _hasBaselineShoulderAnchor = true;
      } else if (rawShoulderDisp < 0.030) {
        _baselineShoulderX =
            _baselineShoulderX * 0.92 + latest.shoulder.dx * 0.08;
        _baselineShoulderY =
            _baselineShoulderY * 0.92 + latest.shoulder.dy * 0.08;
      }
    }

    double anchorShoulderDisp = 0.0;
    if (_hasBaselineShoulderAnchor) {
      anchorShoulderDisp =
          sqrt(
            pow(latest.shoulder.dx - _baselineShoulderX, 2) +
                pow(latest.shoulder.dy - _baselineShoulderY, 2),
          ) /
          shoulderWidth;
    }

    double effectiveShoulderDisp = rawShoulderDisp;

    // SINGLE-FRAME LANDMARK NOISE FILTER & GATED ACCELERATION SURGE:
    // MLKit camera landmark flutter in a single frame is filtered out.
    // Acceleration surge only applies if motion was already active in the previous frame.
    final double shoulderVel = rawShoulderDisp / dt;
    final double shoulderAccel = (shoulderVel - _prevShoulderVel) / dt;

    if (_prevShoulderVel < 0.10 && rawShoulderDisp > 0.060) {
      // Single-frame MLKit camera landmark noise jump — dampen false spike
      effectiveShoulderDisp = rawShoulderDisp * 0.25;
    } else if (shoulderAccel >= 0.80 &&
        rawShoulderDisp >= 0.040 &&
        _prevShoulderVel >= 0.12) {
      // Explosive acceleration surge on genuine physical punch movement
      effectiveShoulderDisp = max(
        effectiveShoulderDisp,
        rawShoulderDisp * 1.25,
      );
    }
    _prevShoulderVel = shoulderVel;

    // STANCE ANCHOR GUARD: If shoulder is still at baseline stance anchor, dampen jitter
    if (_hasBaselineShoulderAnchor && anchorShoulderDisp < 0.025) {
      effectiveShoulderDisp = min(rawShoulderDisp * 0.15, 0.010);
    }

    // 4. Head Movement & Head Motion Isolation (Commented out per user request)
    if (latest.head != null && prev.head != null) {
      final double rawHeadDisp =
          sqrt(
            pow(latest.head!.dx - prev.head!.dx, 2) +
                pow(latest.head!.dy - prev.head!.dy, 2),
          ) /
          shoulderWidth;
      headMovement = headMovement * 0.70 + rawHeadDisp * 0.30;

      // HEAD MOTION ISOLATION (Commented out per user request)
      /*
      if (rawHeadDisp >= (rawShoulderDisp * 0.65)) {
        effectiveShoulderDisp = min(rawShoulderDisp * 0.15, 0.010);
      }
      */
    } else {
      headMovement = 0.0;
    }

    // Shoulder Movement Peak Retention Smoothing (Holds peak across 2 frames, decays quickly on idle)
    shoulderMovement = max(
      shoulderMovement * 0.55 + effectiveShoulderDisp * 0.45,
      effectiveShoulderDisp,
    );

    // 5. Motion Velocity (Commented out per user request)
    /*
    double zDelta = prev.shoulderZ - latest.shoulderZ;
    relativeDepthMovement = max(0.0, zDelta).clamp(0.0, 0.35);

    final double zSpeed = (relativeDepthMovement / dt).clamp(0.0, 1.5);
    motionVelocity = max(wristVelocity, zSpeed);
    */
    motionVelocity = 0.0;

    // 6. Monitor Mandatory Arm Retraction
    if (!hasRetractedSinceLastPunch) {
      final double retractionDelta = lastPunchPeakExtension - armExtension;
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      if (retractionDelta >= 0.08 ||
          armExtension <= 0.40 ||
          shoulderMovement <= 0.025 ||
          (nowMs - lastPunchTimeMs) > 280) {
        hasRetractedSinceLastPunch = true;
      }
    }
  }
}
