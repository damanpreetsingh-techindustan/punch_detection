import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import '../services/arm_kinetic_tracker.dart';
import '../services/punch_scoring_engine.dart';
import '../guards/punch_restriction_guard.dart';
import '../guards/restriction_guard_pipeline.dart';
import '../entities/pose_frame_sample.dart';
import '../entities/punch_detection_config.dart';
import '../entities/punch_fsm_state.dart';

export '../entities/punch_fsm_state.dart';
export '../services/punch_scoring_engine.dart';

class TemporalPunchEvaluationResult {
  final bool isPunchConfirmed;
  final String? confirmedArm;
  final double confidenceScore;
  final PunchFsmState fsmState;
  final SignalScoreBreakdown signalBreakdown;
  final String debugTelemetry;

  const TemporalPunchEvaluationResult({
    required this.isPunchConfirmed,
    this.confirmedArm,
    required this.confidenceScore,
    required this.fsmState,
    this.signalBreakdown = const SignalScoreBreakdown(),
    required this.debugTelemetry,
  });
}

/// Facade Orchestrator: Temporal Multi-Signal Punch Detector with 5-State FSM.
/// Coordinates Arm Kinetic Trackers, Punch Scoring Engine, and Restriction Guard Pipeline.
class TemporalPunchDetector {
  PunchDetectionConfig config;

  final ArmKineticTracker leftArmTracker = ArmKineticTracker(side: 'left');
  final ArmKineticTracker rightArmTracker = ArmKineticTracker(side: 'right');

  final PunchScoringEngine _scoringEngine = PunchScoringEngine();
  late final RestrictionGuardPipeline _guardPipeline;

  String _lastConfirmedArm = '';
  int _lastConfirmedTimeMs = 0;
  int _globalCooldownUntilMs = 0;

  // Face motion tracking state (used when enableExtraFaceRestrictions == false)
  Offset? _prevFacePos;
  int _prevFaceTimeMs = 0;
  double _smoothedFaceVelocity = 0.0;
  int _lastFacePunchTimeMs = 0;

  TemporalPunchDetector({
    PunchDetectionConfig? config,
    RestrictionGuardPipeline? guardPipeline,
  }) : config = config ?? const PunchDetectionConfig(),
       _guardPipeline = guardPipeline ?? RestrictionGuardPipeline();

  /// Returns the current restriction guard pipeline for dynamic rule modification.
  RestrictionGuardPipeline get guardPipeline => _guardPipeline;

  void updateConfig(PunchDetectionConfig newConfig) {
    config = newConfig;
  }

  void resetTrackers() {
    leftArmTracker.reset();
    rightArmTracker.reset();
    _prevFacePos = null;
    _prevFaceTimeMs = 0;
    _smoothedFaceVelocity = 0.0;
  }

  /// Evaluates a live ML Kit Pose frame temporally.
  TemporalPunchEvaluationResult processPose({
    required Pose pose,
    required double imageWidth,
    required double imageHeight,
    bool isDeviceStable = true,
  }) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    // ── 1. Extract Landmarks ────────────────────────────────────────────────
    final lShoulderLM = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulderLM = pose.landmarks[PoseLandmarkType.rightShoulder];
    final noseLM = pose.landmarks[PoseLandmarkType.nose];
    final lEyeLM = pose.landmarks[PoseLandmarkType.leftEye];
    final rEyeLM = pose.landmarks[PoseLandmarkType.rightEye];
    final lEarLM = pose.landmarks[PoseLandmarkType.leftEar];
    final rEarLM = pose.landmarks[PoseLandmarkType.rightEar];
    final faceLM = noseLM ?? lEyeLM ?? rEyeLM ?? lEarLM ?? rEarLM;

    final bool hasShoulders =
        lShoulderLM != null &&
        rShoulderLM != null &&
        lShoulderLM.likelihood >= config.minShoulderConfidence &&
        rShoulderLM.likelihood >= config.minShoulderConfidence;

    if (AppConstants.enableExtraFaceRestrictions) {
      if (!hasShoulders) {
        resetTrackers();
        return const TemporalPunchEvaluationResult(
          isPunchConfirmed: false,
          confidenceScore: 0.0,
          fsmState: PunchFsmState.idle,
          signalBreakdown: SignalScoreBreakdown(),
          debugTelemetry: '[TEMPORAL] Pose Invalid: Shoulders not detected',
        );
      }
    } else {
      // Relaxed Mode: Shoulders are NOT required if face is present
      if (!hasShoulders && (faceLM == null || faceLM.likelihood < 0.20)) {
        resetTrackers();
        return const TemporalPunchEvaluationResult(
          isPunchConfirmed: false,
          confidenceScore: 0.0,
          fsmState: PunchFsmState.idle,
          signalBreakdown: SignalScoreBreakdown(),
          debugTelemetry:
              '[TEMPORAL] Pose Invalid: No face or shoulders detected',
        );
      }
    }

    // ── Track Face / Head Motion ──
    double normFaceVelocity = 0.0;
    if (faceLM != null) {
      final Offset currentFacePos = Offset(
        noseLM?.x ?? faceLM.x,
        noseLM?.y ?? faceLM.y,
      );
      if (_prevFacePos != null && _prevFaceTimeMs > 0) {
        final double dt = (nowMs - _prevFaceTimeMs) / 1000.0;
        if (dt >= 0.01 && dt <= 0.25) {
          final double dist = (currentFacePos - _prevFacePos!).distance;
          final double instVelocity = dist / dt;
          _smoothedFaceVelocity =
              (_smoothedFaceVelocity * 0.30) + (instVelocity * 0.70);
        }
      }
      _prevFacePos = currentFacePos;
      _prevFaceTimeMs = nowMs;
      final double referenceDim = imageWidth > 0 ? imageWidth : 375.0;
      normFaceVelocity = _smoothedFaceVelocity / referenceDim;
    }

    // Check if Face / Head Motion triggers a punch
    if (!AppConstants.enableExtraFaceRestrictions &&
        normFaceVelocity >= 0.55 &&
        (nowMs - _lastFacePunchTimeMs >= 320) &&
        (nowMs >= _globalCooldownUntilMs)) {
      _lastFacePunchTimeMs = nowMs;
      _globalCooldownUntilMs = nowMs + 300;
      _lastConfirmedArm = 'face';
      final double faceConf = min(98.0, 75.0 + (normFaceVelocity * 40.0));
      return TemporalPunchEvaluationResult(
        isPunchConfirmed: true,
        confirmedArm: 'face',
        confidenceScore: faceConf,
        fsmState: PunchFsmState.punchConfirmed,
        signalBreakdown: const SignalScoreBreakdown(
          scoreExtension: 25.0,
          scoreVelocity: 25.0,
          scoreTrajectory: 15.0,
          scoreShoulder: 15.0,
          scoreDepth: 10.0,
          scoreHead: 10.0,
          activeArm: 'face',
        ),
        debugTelemetry:
            '[FACE_MOTION] Punch Confirmed (Head/Face Movement: ${(normFaceVelocity * 100).round()}% | ${_smoothedFaceVelocity.round()} px/s)',
      );
    }

    // ── Determine Shoulder Geometry (Real or Synthesized from Face) ──
    final double shoulderWidth;
    final Offset lShoulderPos;
    final Offset rShoulderPos;

    if (hasShoulders) {
      lShoulderPos = Offset(lShoulderLM.x, lShoulderLM.y);
      rShoulderPos = Offset(rShoulderLM.x, rShoulderLM.y);
      final double sw = sqrt(
        pow(rShoulderLM.x - lShoulderLM.x, 2) +
            pow(rShoulderLM.y - lShoulderLM.y, 2),
      );
      if (sw <= 1.0) {
        if (AppConstants.enableExtraFaceRestrictions) {
          resetTrackers();
          return const TemporalPunchEvaluationResult(
            isPunchConfirmed: false,
            confidenceScore: 0.0,
            fsmState: PunchFsmState.idle,
            signalBreakdown: SignalScoreBreakdown(),
            debugTelemetry: '[TEMPORAL] Pose Invalid: Shoulder width zero',
          );
        } else {
          shoulderWidth = 100.0;
        }
      } else {
        shoulderWidth = sw;
      }
    } else {
      // Synthesize virtual shoulders relative to head/face position
      final double eyeSpan = (lEyeLM != null && rEyeLM != null)
          ? (lEyeLM.x - rEyeLM.x).abs()
          : 0.0;
      final double sw = eyeSpan > 10.0
          ? eyeSpan * 2.8
          : (imageWidth > 0 ? imageWidth * 0.32 : 120.0);
      shoulderWidth = max(50.0, sw);

      if (lShoulderLM != null && lShoulderLM.likelihood >= 0.20) {
        lShoulderPos = Offset(lShoulderLM.x, lShoulderLM.y);
        final double midX =
            noseLM?.x ?? (lShoulderPos.dx + shoulderWidth * 0.5);
        rShoulderPos = Offset(
          midX + (midX - lShoulderPos.dx).abs(),
          lShoulderPos.dy,
        );
      } else if (rShoulderLM != null && rShoulderLM.likelihood >= 0.20) {
        rShoulderPos = Offset(rShoulderLM.x, rShoulderLM.y);
        final double midX =
            noseLM?.x ?? (rShoulderPos.dx - shoulderWidth * 0.5);
        lShoulderPos = Offset(
          midX - (rShoulderPos.dx - midX).abs(),
          rShoulderPos.dy,
        );
      } else {
        final double fx = noseLM?.x ?? faceLM!.x;
        final double fy = noseLM?.y ?? faceLM!.y;
        lShoulderPos = Offset(
          fx - shoulderWidth * 0.5,
          fy + shoulderWidth * 0.45,
        );
        rShoulderPos = Offset(
          fx + shoulderWidth * 0.5,
          fy + shoulderWidth * 0.45,
        );
      }
    }

    // If only face is visible and wrists are not extending, provide active tracking result
    final lWristLM = pose.landmarks[PoseLandmarkType.leftWrist];
    final rWristLM = pose.landmarks[PoseLandmarkType.rightWrist];
    final bool hasWrists =
        (lWristLM != null && lWristLM.likelihood >= 0.25) ||
        (rWristLM != null && rWristLM.likelihood >= 0.25);

    if (!hasShoulders &&
        !hasWrists &&
        !AppConstants.enableExtraFaceRestrictions) {
      final double trackingConfidence = min(
        85.0,
        max(55.0, (faceLM?.likelihood ?? 0.8) * 80.0),
      );
      return TemporalPunchEvaluationResult(
        isPunchConfirmed: false,
        confidenceScore: trackingConfidence,
        fsmState: PunchFsmState.idle,
        signalBreakdown: const SignalScoreBreakdown(),
        debugTelemetry:
            '[FACE_TRACKING] Face in Frame — Live Motion Tracking Active (${(normFaceVelocity * 100).round()}% motion)',
      );
    }

    // ── 2. Add Frame Samples with Anatomical Elbow Inferrer ──────────────────
    final lElbowLM = pose.landmarks[PoseLandmarkType.leftElbow];
    final rElbowLM = pose.landmarks[PoseLandmarkType.rightElbow];

    Offset? resolveElbow({
      required PoseLandmark? elbowLM,
      required PoseLandmark? wristLM,
      required Offset shoulder,
      required Offset otherShoulder,
      required bool isLeft,
    }) {
      if (elbowLM != null && elbowLM.likelihood >= 0.20) {
        return Offset(elbowLM.x, elbowLM.y);
      }
      final Offset? wrist = (wristLM != null && wristLM.likelihood >= 0.20)
          ? Offset(wristLM.x, wristLM.y)
          : null;
      if (wrist != null) {
        final midX = (shoulder.dx + wrist.dx) / 2.0;
        final midY = (shoulder.dy + wrist.dy) / 2.0;
        final outwardOffset = isLeft ? 10.0 : -10.0;
        return Offset(midX + outwardOffset, midY);
      }
      final double shoulderDist = sqrt(
        pow(shoulder.dx - otherShoulder.dx, 2) +
            pow(shoulder.dy - otherShoulder.dy, 2),
      );
      if (shoulderDist < 1.0) return null;
      final double armLen = shoulderDist * 0.60;
      final double shoulderAngle = atan2(
        otherShoulder.dy - shoulder.dy,
        otherShoulder.dx - shoulder.dx,
      );
      final double downAngle = isLeft
          ? (shoulderAngle - pi / 2)
          : (shoulderAngle + pi / 2);
      double projDx = cos(downAngle) * armLen;
      double projDy = sin(downAngle) * armLen;
      if (projDy < 0) projDy = -projDy;
      return Offset(shoulder.dx + projDx, shoulder.dy + projDy);
    }

    final Offset? lElbowPos = resolveElbow(
      elbowLM: lElbowLM,
      wristLM: lWristLM,
      shoulder: lShoulderPos,
      otherShoulder: rShoulderPos,
      isLeft: true,
    );
    final Offset? rElbowPos = resolveElbow(
      elbowLM: rElbowLM,
      wristLM: rWristLM,
      shoulder: rShoulderPos,
      otherShoulder: lShoulderPos,
      isLeft: false,
    );

    // Left Arm Sample
    leftArmTracker.addSample(
      PoseFrameSample(
        timestampMs: nowMs,
        shoulder: lShoulderPos,
        head: noseLM != null ? Offset(noseLM.x, noseLM.y) : null,
        elbow: lElbowPos,
        wrist: lWristLM != null && lWristLM.likelihood >= 0.20
            ? Offset(lWristLM.x, lWristLM.y)
            : null,
        shoulderZ: lShoulderLM?.z ?? 0.0,
        wristZ: lWristLM?.z,
      ),
      config.temporalWindowMs,
    );

    // Right Arm Sample
    rightArmTracker.addSample(
      PoseFrameSample(
        timestampMs: nowMs,
        shoulder: rShoulderPos,
        head: noseLM != null ? Offset(noseLM.x, noseLM.y) : null,
        elbow: rElbowPos,
        wrist: rWristLM != null && rWristLM.likelihood >= 0.20
            ? Offset(rWristLM.x, rWristLM.y)
            : null,
        shoulderZ: rShoulderLM?.z ?? 0.0,
        wristZ: rWristLM?.z,
      ),
      config.temporalWindowMs,
    );

    /*
    ArmAngleTester.evaluateAndLogAngles(
      leftShoulder: lShoulderPos,
      leftElbow: lElbowPos,
      rightShoulder: rShoulderPos,
      rightElbow: rElbowPos,
    );
    */

    // ── 4. Kinetic Measurement Computations (4. Upper Arm Kinetic Extension -> 5. Upper Arm Kinetic Velocity) ──
    leftArmTracker.updateMetrics(shoulderWidth);
    rightArmTracker.updateMetrics(shoulderWidth);

    final SignalScoreBreakdown leftBreakdown = _scoringEngine.calculateScore(
      tracker: leftArmTracker,
      shoulderWidth: shoulderWidth,
      config: config,
    );
    final SignalScoreBreakdown rightBreakdown = _scoringEngine.calculateScore(
      tracker: rightArmTracker,
      shoulderWidth: shoulderWidth,
      config: config,
    );

    // ── Determine Leading Driving Arm (Balanced & Candidate-Aware) ──
    bool isRightDriving = false;

    // Rule 1: Prioritize active candidates in candidate or confirmation phase
    if (rightArmTracker.fsmState == PunchFsmState.punchCandidate ||
        rightArmTracker.fsmState == PunchFsmState.punchConfirmed) {
      isRightDriving = true;
    } else if (leftArmTracker.fsmState == PunchFsmState.punchCandidate ||
        leftArmTracker.fsmState == PunchFsmState.punchConfirmed) {
      isRightDriving = false;
    } else {
      // Rule 2: Compare dynamic feature scores and extension reach fairly
      if (leftBreakdown.totalScore > rightBreakdown.totalScore + 1.0) {
        isRightDriving = false;
      } else if (rightBreakdown.totalScore > leftBreakdown.totalScore + 1.0) {
        isRightDriving = true;
      } else {
        // Tie-breaker: Compare arm extension reach directly
        if (leftArmTracker.armExtension > rightArmTracker.armExtension + 0.03) {
          isRightDriving = false;
        } else if (rightArmTracker.armExtension >
            leftArmTracker.armExtension + 0.03) {
          isRightDriving = true;
        } else {
          // Fair alternation when both arms are equal
          isRightDriving = (_lastConfirmedArm != 'right');
        }
      }
    }

    final ArmKineticTracker drivingTracker = isRightDriving
        ? rightArmTracker
        : leftArmTracker;
    final ArmKineticTracker oppositeTracker = isRightDriving
        ? leftArmTracker
        : rightArmTracker;
    final SignalScoreBreakdown drivingBreakdown = isRightDriving
        ? rightBreakdown
        : leftBreakdown;
    final double maxScore = drivingBreakdown.totalScore;

    // ── 5. Evaluate FSM Transitions ──────────────────────────────────────────
    bool punchConfirmedThisFrame = false;
    String? confirmedArmName;

    // Check Global Cooldown
    if (nowMs < _globalCooldownUntilMs) {
      drivingTracker.fsmState = PunchFsmState.cooldown;
      return TemporalPunchEvaluationResult(
        isPunchConfirmed: false,
        confidenceScore: maxScore,
        fsmState: PunchFsmState.cooldown,
        signalBreakdown: drivingBreakdown,
        debugTelemetry:
            '[FSM: COOLDOWN] Remaining: ${_globalCooldownUntilMs - nowMs}ms | Score: ${maxScore.toStringAsFixed(1)}',
      );
    }

    // Evaluate FSM State Transitions
    switch (drivingTracker.fsmState) {
      case PunchFsmState.idle:
        // Mandatory Gate: Require active shoulder movement above threshold to enter Candidate phase
        if (drivingTracker.shoulderMovement <
                config.minShoulderMovementThreshold ||
            drivingBreakdown.scoreShoulder <= 0.0) {
          break;
        }

        final double effectiveCandidateThreshold =
            config.candidateActivationScoreThreshold;
        if (maxScore >= effectiveCandidateThreshold) {
          drivingTracker.fsmState = PunchFsmState.punchCandidate;
          drivingTracker.candidateStartTimeMs = nowMs;
          drivingTracker.baselineGuardExtension = min(
            drivingTracker.armExtension,
            drivingTracker.minRecentGuardExtension,
          );
          drivingTracker.peakExtensionInCandidate = drivingTracker.armExtension;
          drivingTracker.phase = ArmTrajectoryPhase.extending;

          // Check confirmation immediately on peak candidate frame
          final context = PunchDetectionContext(
            shoulderWidth: shoulderWidth,
            lastConfirmedArm: _lastConfirmedArm,
            timeSinceLastPunchMs: nowMs - _lastConfirmedTimeMs,
            oppositeArmTracker: oppositeTracker,
            config: config,
            isDeviceStable: isDeviceStable,
          );

          final GuardPipelineResult guardResult = _guardPipeline
              .verifyAllGuards(drivingTracker, context);

          final double effectiveConfirmationThreshold =
              config.punchConfirmationScoreThreshold;

          if (maxScore >= effectiveConfirmationThreshold &&
              guardResult.isPassed) {
            drivingTracker.fsmState = PunchFsmState.punchConfirmed;
            drivingTracker.phase = ArmTrajectoryPhase.peakExtension;

            punchConfirmedThisFrame = true;
            confirmedArmName = drivingTracker.side;

            final bool isSameArm = _lastConfirmedArm == drivingTracker.side;
            _lastConfirmedArm = drivingTracker.side;
            _lastConfirmedTimeMs = nowMs;
            drivingTracker.lastPunchTimeMs = nowMs;
            drivingTracker.hasRetractedSinceLastPunch = false;
            drivingTracker.lastPunchPeakExtension = max(
              drivingTracker.peakExtensionInCandidate,
              drivingTracker.armExtension,
            );

            final int cooldownDuration = isSameArm
                ? config.sameArmCooldownMs
                : config.alternatingArmCooldownMs;
            _globalCooldownUntilMs = nowMs + cooldownDuration;
          }
        }
        break;

      case PunchFsmState.punchCandidate:
        // Update peak extension reached during candidate phase
        drivingTracker.peakExtensionInCandidate = max(
          drivingTracker.peakExtensionInCandidate,
          drivingTracker.armExtension,
        );

        // Check for Candidate Timeout
        if ((nowMs - drivingTracker.candidateStartTimeMs) >
            config.candidateTimeoutMs) {
          drivingTracker.fsmState = PunchFsmState.idle;
          drivingTracker.phase = ArmTrajectoryPhase.guard;
          break;
        }

        // Mandatory Gate: Require active shoulder movement above threshold for punch confirmation
        if (drivingTracker.shoulderMovement <
                config.minShoulderMovementThreshold ||
            drivingBreakdown.scoreShoulder <= 0.0) {
          break;
        }

        // Transition: PUNCH_CANDIDATE -> PUNCH_CONFIRMED via Restriction Guard Pipeline
        final context = PunchDetectionContext(
          shoulderWidth: shoulderWidth,
          lastConfirmedArm: _lastConfirmedArm,
          timeSinceLastPunchMs: nowMs - _lastConfirmedTimeMs,
          oppositeArmTracker: oppositeTracker,
          config: config,
          isDeviceStable: isDeviceStable,
        );

        final GuardPipelineResult guardResult = _guardPipeline.verifyAllGuards(
          drivingTracker,
          context,
        );

        final double effectiveConfirmationThreshold =
            config.punchConfirmationScoreThreshold;

        if (maxScore >= effectiveConfirmationThreshold &&
            guardResult.isPassed) {
          drivingTracker.fsmState = PunchFsmState.punchConfirmed;
          drivingTracker.phase = ArmTrajectoryPhase.peakExtension;

          punchConfirmedThisFrame = true;
          confirmedArmName = drivingTracker.side;

          final bool isSameArm = _lastConfirmedArm == drivingTracker.side;
          _lastConfirmedArm = drivingTracker.side;
          _lastConfirmedTimeMs = nowMs;
          drivingTracker.lastPunchTimeMs = nowMs;
          drivingTracker.hasRetractedSinceLastPunch = false;
          drivingTracker.lastPunchPeakExtension = max(
            drivingTracker.peakExtensionInCandidate,
            drivingTracker.armExtension,
          );

          // Set Cooldown (Same arm vs Alternating arm)
          final int cooldownDuration = isSameArm
              ? config.sameArmCooldownMs
              : config.alternatingArmCooldownMs;
          _globalCooldownUntilMs = nowMs + cooldownDuration;
        }
        break;

      case PunchFsmState.punchConfirmed:
        drivingTracker.fsmState = PunchFsmState.cooldown;
        break;

      case PunchFsmState.cooldown:
        if (nowMs >= _globalCooldownUntilMs) {
          drivingTracker.fsmState = PunchFsmState.armRetracted;
          drivingTracker.phase = ArmTrajectoryPhase.retracting;
        }
        break;

      case PunchFsmState.armRetracted:
        final double retractionDelta =
            drivingTracker.lastPunchPeakExtension - drivingTracker.armExtension;
        if (drivingTracker.hasRetractedSinceLastPunch ||
            retractionDelta >= 0.06 ||
            drivingTracker.armExtension <= 0.50 ||
            drivingTracker.shoulderMovement <= 0.020 ||
            (nowMs - drivingTracker.lastPunchTimeMs) > 300) {
          drivingTracker.hasRetractedSinceLastPunch = true;
          drivingTracker.fsmState = PunchFsmState.idle;
          drivingTracker.phase = ArmTrajectoryPhase.guard;
          drivingTracker.peakExtensionInCandidate = 0.0;
        }
        break;
    }

    String guardStatusText = 'IDLE';
    if (drivingTracker.fsmState == PunchFsmState.punchCandidate) {
      final context = PunchDetectionContext(
        shoulderWidth: shoulderWidth,
        lastConfirmedArm: _lastConfirmedArm,
        timeSinceLastPunchMs: nowMs - _lastConfirmedTimeMs,
        oppositeArmTracker: oppositeTracker,
        config: config,
        isDeviceStable: isDeviceStable,
      );
      final guardCheck = _guardPipeline.verifyAllGuards(
        drivingTracker,
        context,
      );
      guardStatusText = guardCheck.isPassed
          ? 'ALL_PASSED'
          : 'BLOCKED (${guardCheck.failedGuardName})';
    } else if (drivingTracker.fsmState == PunchFsmState.punchConfirmed) {
      guardStatusText = 'CONFIRMED';
    }

    final String debugTelemetry =
        '[AI-ENGINE] [FSM: ${drivingTracker.fsmState.name.toUpperCase()}] Arm: ${drivingTracker.side.toUpperCase()} | '
        'Score: ${maxScore.toStringAsFixed(1)}/100 | Validity: ${drivingBreakdown.scoreValidity.toStringAsFixed(1)}/10 | '
        'Head: ${drivingBreakdown.scoreHead.toStringAsFixed(1)}/10 (disp=${drivingBreakdown.rawHeadMovement.toStringAsFixed(3)}SW) | '
        'Shoulder: ${drivingBreakdown.scoreShoulder.toStringAsFixed(1)} (disp=${drivingBreakdown.rawShoulderMovement.toStringAsFixed(3)}SW) | '
        'Trajectory: ${drivingBreakdown.scoreTrajectory.toStringAsFixed(1)}/10 | '
        'Velocity: ${drivingBreakdown.scoreVelocity.toStringAsFixed(1)}/10 (speed=${drivingBreakdown.rawMotionVelocity.toStringAsFixed(2)}SW/s) | '
        'Ext: ${drivingBreakdown.scoreExtension.toStringAsFixed(1)} (ext=${drivingBreakdown.rawArmExtension.toStringAsFixed(2)}SW) | '
        'Temp: ${drivingBreakdown.scoreTemporal.toStringAsFixed(1)}/5 | '
        'Guard: $guardStatusText';

    return TemporalPunchEvaluationResult(
      isPunchConfirmed: punchConfirmedThisFrame,
      confirmedArm: confirmedArmName,
      confidenceScore: maxScore,
      fsmState: drivingTracker.fsmState,
      signalBreakdown: drivingBreakdown,
      debugTelemetry: debugTelemetry,
    );
  }
}
