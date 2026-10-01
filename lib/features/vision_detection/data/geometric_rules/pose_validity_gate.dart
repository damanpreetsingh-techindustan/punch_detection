import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui';
import 'package:punch_detection_demo/core/utils/constants.dart';

import '../../domain/entities/punch_detection_config.dart';

/// Explicit Orientation State of the user relative to the camera.
enum FacingOrientationState {
  /// Person is directly facing the camera with high facial and torso symmetry.
  facingCamera,

  /// Person is clearly turned left/right sideways or showing profile/back.
  turnedSideways,

  /// Insufficient landmark confidence, single-eye visibility, or initializing multi-frame window.
  unknownOrInsufficientData,
}

/// Strict Pose Validity Gate & Facing Camera Orientation Engine
///
/// Runs BEFORE punch scoring to verify strict front-facing orientation & pose usability.
/// Uses body-scale normalized metrics, eye symmetry, nose centering, ear evaluation,
/// shoulder geometry, and temporal stability across consecutive frames.
class PoseValidityGate {
  final PunchDetectionConfig config;

  // Temporal stability frame counters
  static int _consecutiveFacingFrames = 0;
  static int _consecutiveFailedFrames = 0;

  const PoseValidityGate({PunchDetectionConfig? config})
    : config = config ?? const PunchDetectionConfig();

  /// Legacy constructor support for direct parameter passing.
  PoseValidityGate.legacy({
    double minNoseLikelihood = 0.55,
    double minEyeLikelihood = 0.55,
    double minShoulderLikelihood = 0.35,
    double minNormShoulderWidth = 0.06,
    double maxNormShoulderWidth = 0.92,
    double maxFacialSymmetryRatio = 1.85,
  }) : config = PunchDetectionConfig(
         minNoseConfidence: minNoseLikelihood,
         minEyeConfidence: minEyeLikelihood,
         minShoulderConfidence: minShoulderLikelihood,
         minNormShoulderWidth: minNormShoulderWidth,
         maxNormShoulderWidth: maxNormShoulderWidth,
         maxFacialSymmetryRatio: maxFacialSymmetryRatio,
       );

  /// Resets temporal facing state.
  void resetTemporalState() {
    _consecutiveFacingFrames = 0;
    _consecutiveFailedFrames = 0;
  }

  /// Calculates eye symmetry ratio: min(leftDistance, rightDistance) / max(leftDistance, rightDistance).
  /// Replaces old formula (max / (min + 1.5)) to provide true 0.0 - 1.0 symmetry metric.
  double _calculateEyeSymmetry({
    required Offset nose,
    required Offset leftEye,
    required Offset rightEye,
  }) {
    final double leftDistance = sqrt(
      pow(nose.dx - leftEye.dx, 2) + pow(nose.dy - leftEye.dy, 2),
    );
    final double rightDistance = sqrt(
      pow(nose.dx - rightEye.dx, 2) + pow(nose.dy - rightEye.dy, 2),
    );

    final double maxDistance = max(leftDistance, rightDistance);
    final double minDistance = min(leftDistance, rightDistance);

    if (maxDistance <= 0.0001) return 0.0;
    return minDistance / maxDistance;
  }

  /// Calculates eye-to-nose centering score normalized by eye-to-eye span.
  /// Returns a normalized score in range [0.0, 1.0] and the offset ratio.
  ({double score, double offsetRatio}) _calculateNoseCentering({
    required Offset nose,
    required Offset leftEye,
    required Offset rightEye,
  }) {
    final double eyeToEyeSpan = sqrt(
      pow(leftEye.dx - rightEye.dx, 2) + pow(leftEye.dy - rightEye.dy, 2),
    );

    final double expectedMidX = (leftEye.dx + rightEye.dx) / 2.0;
    final double noseOffsetRatio =
        (nose.dx - expectedMidX).abs() / (eyeToEyeSpan + 0.0001);

    final double maxAllowedOffset = config.maxNoseCenteringOffsetRatio;
    final double score = max(0.0, 1.0 - (noseOffsetRatio / maxAllowedOffset));

    return (score: score, offsetRatio: noseOffsetRatio);
  }

  /// Evaluates Ear Landmarks safely if present.
  /// If ears are partially cropped, covered by hair or headphones, returns neutral 1.0 score without rejecting.
  double _evaluateEarSymmetry({
    required Offset nose,
    Offset? leftEar,
    double leftEarConf = 0.0,
    Offset? rightEar,
    double rightEarConf = 0.0,
  }) {
    final bool hasLeftEar =
        leftEar != null && leftEarConf >= config.minEarConfidence;
    final bool hasRightEar =
        rightEar != null && rightEarConf >= config.minEarConfidence;

    if (hasLeftEar && hasRightEar) {
      final double leftEarDist = sqrt(
        pow(nose.dx - leftEar.dx, 2) + pow(nose.dy - leftEar.dy, 2),
      );
      final double rightEarDist = sqrt(
        pow(nose.dx - rightEar.dx, 2) + pow(nose.dy - rightEar.dy, 2),
      );

      final double maxEarDist = max(leftEarDist, rightEarDist);
      final double minEarDist = min(leftEarDist, rightEarDist);

      if (maxEarDist <= 0.0001) return 1.0;
      return minEarDist / maxEarDist;
    }

    // Ear unavailable due to hair/crop/angle -> return 1.0 (neutral, no crash/rejection)
    return 1.0;
  }

  /// Evaluates Body/Torso Orientation using normalized shoulder geometry as a secondary reference.
  double _evaluateBodyOrientation({
    required Offset leftShoulder,
    required Offset rightShoulder,
    required Offset nose,
  }) {
    final double shoulderWidth = sqrt(
      pow(leftShoulder.dx - rightShoulder.dx, 2) +
          pow(leftShoulder.dy - rightShoulder.dy, 2),
    );

    if (shoulderWidth <= 0.0001) return 0.0;

    final double shoulderMidX = (leftShoulder.dx + rightShoulder.dx) / 2.0;
    final double shoulderCenteringOffset =
        (nose.dx - shoulderMidX).abs() / shoulderWidth;

    return max(0.0, 1.0 - (shoulderCenteringOffset / 0.50));
  }

  /// Calculates composite facing camera score (0.0 to 1.0).
  double _calculateFacingCameraScore({
    required double eyeSymmetry,
    required double noseCenteringScore,
    required double earScore,
    required double bodyOrientationScore,
    required double noseConf,
    required double leftEyeConf,
    required double rightEyeConf,
  }) {
    final double facialConfScore = min(
      1.0,
      (noseConf + leftEyeConf + rightEyeConf) / 3.0,
    );

    return (eyeSymmetry * 0.35) +
        (noseCenteringScore * 0.25) +
        (bodyOrientationScore * 0.25) +
        (earScore * 0.10) +
        (facialConfScore * 0.05);
  }

  PoseValidityResult evaluate({
    required double lsX,
    required double lsY,
    required double lsLikelihood,
    required double rsX,
    required double rsY,
    required double rsLikelihood,
    required double noseLikelihood,
    double noseX = 0.0,
    double noseY = 0.0,
    double leftEyeX = 0.0,
    double leftEyeY = 0.0,
    double rightEyeX = 0.0,
    double rightEyeY = 0.0,
    double leftEyeLikelihood = 0.0,
    double rightEyeLikelihood = 0.0,
    double leftEarX = 0.0,
    double leftEarY = 0.0,
    double rightEarX = 0.0,
    double rightEarY = 0.0,
    double leftEarLikelihood = 0.0,
    double rightEarLikelihood = 0.0,
    required double imageWidth,
    required double imageHeight,
  }) {
    // ── Relaxed Single-Point Validation when extra face restrictions are disabled ──
    if (!AppConstants.enableExtraFaceRestrictions) {
      final bool hasShoulder = lsLikelihood >= 0.20 || rsLikelihood >= 0.20;
      final bool hasFace = noseLikelihood >= 0.20 ||
          leftEyeLikelihood >= 0.20 ||
          rightEyeLikelihood >= 0.20 ||
          leftEarLikelihood >= 0.20 ||
          rightEarLikelihood >= 0.20;

      if (hasShoulder || hasFace) {
        return PoseValidityResult(
          isValid: true,
          failReason: null,
          normShoulderWidth:
              imageWidth > 0 ? (lsX - rsX).abs() / imageWidth : 0.0,
          nosePresent: noseLikelihood >= 0.20,
          areEyesVisible:
              leftEyeLikelihood >= 0.20 || rightEyeLikelihood >= 0.20,
          orientationState: FacingOrientationState.facingCamera,
          facingCameraScore: 1.0,
          eyeSymmetry: 1.0,
          noseCenteringScore: 1.0,
          shoulderOrientationScore: 1.0,
          noseConfidence: noseLikelihood,
          leftEyeConfidence: leftEyeLikelihood,
          rightEyeConfidence: rightEyeLikelihood,
          leftEarConfidence: leftEarLikelihood,
          rightEarConfidence: rightEarLikelihood,
        );
      } else {
        return _rejectFrame(
          reason: 'No face or shoulder detected in frame',
          state: FacingOrientationState.unknownOrInsufficientData,
          noseConf: noseLikelihood,
          lEyeConf: leftEyeLikelihood,
          rEyeConf: rightEyeLikelihood,
          lEarConf: leftEarLikelihood,
          rEarConf: rightEarLikelihood,
        );
      }
    }

    // ── 1. Nose Confidence Validation ──────────────────────────────────────────
    if (noseLikelihood < config.minNoseConfidence) {
      return _rejectFrame(
        reason:
            'Nose confidence low (${noseLikelihood.toStringAsFixed(2)} < ${config.minNoseConfidence})',
        state: FacingOrientationState.unknownOrInsufficientData,
        noseConf: noseLikelihood,
        lEyeConf: leftEyeLikelihood,
        rEyeConf: rightEyeLikelihood,
        lEarConf: leftEarLikelihood,
        rEarConf: rightEarLikelihood,
      );
    }

    // ── 2. BOTH Eyes Confidence Gate (STRICT) ──────────────────────────────────
    final bool hasLeftEye = leftEyeLikelihood >= config.minEyeConfidence;
    final bool hasRightEye = rightEyeLikelihood >= config.minEyeConfidence;

    if (!hasLeftEye || !hasRightEye) {
      return _rejectFrame(
        reason:
            'BOTH eyes must be visible with confidence >= ${config.minEyeConfidence} (L: ${leftEyeLikelihood.toStringAsFixed(2)}, R: ${rightEyeLikelihood.toStringAsFixed(2)})',
        state: FacingOrientationState.unknownOrInsufficientData,
        noseConf: noseLikelihood,
        lEyeConf: leftEyeLikelihood,
        rEyeConf: rightEyeLikelihood,
        lEarConf: leftEarLikelihood,
        rEarConf: rightEarLikelihood,
      );
    }

    // ── 3. Eye Symmetry Calculation (min / max distance) ──────────────────────
    final Offset noseOffset = Offset(noseX, noseY);
    final Offset leftEyeOffset = Offset(leftEyeX, leftEyeY);
    final Offset rightEyeOffset = Offset(rightEyeX, rightEyeY);

    final double eyeSymmetry = _calculateEyeSymmetry(
      nose: noseOffset,
      leftEye: leftEyeOffset,
      rightEye: rightEyeOffset,
    );

    if (eyeSymmetry < config.minEyeSymmetryThreshold) {
      return _rejectFrame(
        reason:
            'Eye symmetry low (${eyeSymmetry.toStringAsFixed(2)} < ${config.minEyeSymmetryThreshold}) - user turned away',
        state: FacingOrientationState.turnedSideways,
        eyeSymmetry: eyeSymmetry,
        noseConf: noseLikelihood,
        lEyeConf: leftEyeLikelihood,
        rEyeConf: rightEyeLikelihood,
        lEarConf: leftEarLikelihood,
        rEarConf: rightEarLikelihood,
      );
    }

    // ── 4. Nose Centering Validation (Normalized by eye-to-eye span) ────────
    final noseCentering = _calculateNoseCentering(
      nose: noseOffset,
      leftEye: leftEyeOffset,
      rightEye: rightEyeOffset,
    );

    if (noseCentering.offsetRatio > config.maxNoseCenteringOffsetRatio) {
      return _rejectFrame(
        reason:
            'Nose offset ratio high (${noseCentering.offsetRatio.toStringAsFixed(2)} > ${config.maxNoseCenteringOffsetRatio}) - nose not centered',
        state: FacingOrientationState.turnedSideways,
        eyeSymmetry: eyeSymmetry,
        noseCenteringScore: noseCentering.score,
        noseConf: noseLikelihood,
        lEyeConf: leftEyeLikelihood,
        rEyeConf: rightEyeLikelihood,
        lEarConf: leftEarLikelihood,
        rEarConf: rightEarLikelihood,
      );
    }

    // ── 5. Ear Landmark Evaluation (Safe & Configurable) ─────────────────────
    final Offset? leftEarOffset = (leftEarX != 0 || leftEarY != 0)
        ? Offset(leftEarX, leftEarY)
        : null;
    final Offset? rightEarOffset = (rightEarX != 0 || rightEarY != 0)
        ? Offset(rightEarX, rightEarY)
        : null;

    final double earScore = _evaluateEarSymmetry(
      nose: noseOffset,
      leftEar: leftEarOffset,
      leftEarConf: leftEarLikelihood,
      rightEar: rightEarOffset,
      rightEarConf: rightEarLikelihood,
    );

    // ── 6. Shoulder Geometry & Body Orientation ──────────────────────────────
    if (lsLikelihood < config.minShoulderConfidence ||
        rsLikelihood < config.minShoulderConfidence) {
      return _rejectFrame(
        reason:
            'Shoulder likelihood low (L: ${lsLikelihood.toStringAsFixed(2)}, R: ${rsLikelihood.toStringAsFixed(2)})',
        state: FacingOrientationState.unknownOrInsufficientData,
        eyeSymmetry: eyeSymmetry,
        noseCenteringScore: noseCentering.score,
        noseConf: noseLikelihood,
        lEyeConf: leftEyeLikelihood,
        rEyeConf: rightEyeLikelihood,
        lEarConf: leftEarLikelihood,
        rEarConf: rightEarLikelihood,
      );
    }

    final double normShoulderWidth = imageWidth > 0
        ? (lsX - rsX).abs() / imageWidth
        : 0.0;

    if (normShoulderWidth < config.minNormShoulderWidth ||
        normShoulderWidth > config.maxNormShoulderWidth) {
      return _rejectFrame(
        reason:
            'Shoulder width out of range (${normShoulderWidth.toStringAsFixed(2)})',
        state: FacingOrientationState.unknownOrInsufficientData,
        normShoulderWidth: normShoulderWidth,
        eyeSymmetry: eyeSymmetry,
        noseCenteringScore: noseCentering.score,
        noseConf: noseLikelihood,
        lEyeConf: leftEyeLikelihood,
        rEyeConf: rightEyeLikelihood,
        lEarConf: leftEarLikelihood,
        rEarConf: rightEarLikelihood,
      );
    }

    final Offset leftShoulderOffset = Offset(lsX, lsY);
    final Offset rightShoulderOffset = Offset(rsX, rsY);

    final double bodyOrientationScore = _evaluateBodyOrientation(
      leftShoulder: leftShoulderOffset,
      rightShoulder: rightShoulderOffset,
      nose: noseOffset,
    );

    // ── 7. Composite Facing Camera Score ─────────────────────────────────────
    final double facingCameraScore = _calculateFacingCameraScore(
      eyeSymmetry: eyeSymmetry,
      noseCenteringScore: noseCentering.score,
      earScore: earScore,
      bodyOrientationScore: bodyOrientationScore,
      noseConf: noseLikelihood,
      leftEyeConf: leftEyeLikelihood,
      rightEyeConf: rightEyeLikelihood,
    );

    if (facingCameraScore < config.minFacingCameraScore) {
      return _rejectFrame(
        reason:
            'Facing camera score low (${facingCameraScore.toStringAsFixed(2)} < ${config.minFacingCameraScore})',
        state: FacingOrientationState.turnedSideways,
        normShoulderWidth: normShoulderWidth,
        facingScore: facingCameraScore,
        eyeSymmetry: eyeSymmetry,
        noseCenteringScore: noseCentering.score,
        bodyOrientationScore: bodyOrientationScore,
        noseConf: noseLikelihood,
        lEyeConf: leftEyeLikelihood,
        rEyeConf: rightEyeLikelihood,
        lEarConf: leftEarLikelihood,
        rEarConf: rightEarLikelihood,
      );
    }

    // ── 8. Temporal Stability Mechanism ──────────────────────────────────────
    _consecutiveFacingFrames++;
    _consecutiveFailedFrames = 0;

    final bool isTemporallyStable =
        _consecutiveFacingFrames >= config.minConsecutiveFacingFrames;

    final FacingOrientationState finalState = isTemporallyStable
        ? FacingOrientationState.facingCamera
        : FacingOrientationState.unknownOrInsufficientData;

    final bool isValid = isTemporallyStable;

    final String? failReason = isTemporallyStable
        ? null
        : 'Building temporal facing orientation stability ($_consecutiveFacingFrames / ${config.minConsecutiveFacingFrames} frames)';

    // Debug Logging
    _logDebug(
      noseConf: noseLikelihood,
      lEyeConf: leftEyeLikelihood,
      rEyeConf: rightEyeLikelihood,
      lEarConf: leftEarLikelihood,
      rEarConf: rightEarLikelihood,
      eyeSymmetry: eyeSymmetry,
      noseCenteringScore: noseCentering.score,
      bodyOrientationScore: bodyOrientationScore,
      finalFacingScore: facingCameraScore,
      orientationState: finalState,
      rejectionReason: failReason,
    );

    return PoseValidityResult(
      isValid: isValid,
      failReason: failReason,
      normShoulderWidth: normShoulderWidth,
      nosePresent: true,
      areEyesVisible: true,
      orientationState: finalState,
      facingCameraScore: facingCameraScore,
      eyeSymmetry: eyeSymmetry,
      noseCenteringScore: noseCentering.score,
      shoulderOrientationScore: bodyOrientationScore,
      noseConfidence: noseLikelihood,
      leftEyeConfidence: leftEyeLikelihood,
      rightEyeConfidence: rightEyeLikelihood,
      leftEarConfidence: leftEarLikelihood,
      rightEarConfidence: rightEarLikelihood,
    );
  }

  PoseValidityResult _rejectFrame({
    required String reason,
    required FacingOrientationState state,
    double normShoulderWidth = 0.0,
    double facingScore = 0.0,
    double eyeSymmetry = 0.0,
    double noseCenteringScore = 0.0,
    double bodyOrientationScore = 0.0,
    double noseConf = 0.0,
    double lEyeConf = 0.0,
    double rEyeConf = 0.0,
    double lEarConf = 0.0,
    double rEarConf = 0.0,
  }) {
    _consecutiveFailedFrames++;
    if (_consecutiveFailedFrames > 1) {
      _consecutiveFacingFrames = 0;
    }

    _logDebug(
      noseConf: noseConf,
      lEyeConf: lEyeConf,
      rEyeConf: rEyeConf,
      lEarConf: lEarConf,
      rEarConf: rEarConf,
      eyeSymmetry: eyeSymmetry,
      noseCenteringScore: noseCenteringScore,
      bodyOrientationScore: bodyOrientationScore,
      finalFacingScore: facingScore,
      orientationState: state,
      rejectionReason: reason,
    );

    return PoseValidityResult(
      isValid: false,
      failReason: reason,
      normShoulderWidth: normShoulderWidth,
      nosePresent: noseConf >= config.minNoseConfidence,
      areEyesVisible:
          lEyeConf >= config.minEyeConfidence &&
          rEyeConf >= config.minEyeConfidence,
      orientationState: state,
      facingCameraScore: facingScore,
      eyeSymmetry: eyeSymmetry,
      noseCenteringScore: noseCenteringScore,
      shoulderOrientationScore: bodyOrientationScore,
      noseConfidence: noseConf,
      leftEyeConfidence: lEyeConf,
      rightEyeConfidence: rEyeConf,
      leftEarConfidence: lEarConf,
      rightEarConfidence: rEarConf,
    );
  }

  void _logDebug({
    required double noseConf,
    required double lEyeConf,
    required double rEyeConf,
    required double lEarConf,
    required double rEarConf,
    required double eyeSymmetry,
    required double noseCenteringScore,
    required double bodyOrientationScore,
    required double finalFacingScore,
    required FacingOrientationState orientationState,
    required String? rejectionReason,
  }) {
    if (!config.enableDebugLogging) return;
    if (AppConstants.testingPoseValidationLogs) {
      developer.log(
        '[POSE VALIDITY] Nose: ${noseConf.toStringAsFixed(2)} | L-Eye: ${lEyeConf.toStringAsFixed(2)} | R-Eye: ${rEyeConf.toStringAsFixed(2)} | L-Ear: ${lEarConf.toStringAsFixed(2)} | R-Ear: ${rEarConf.toStringAsFixed(2)} | Eye-Symmetry: ${eyeSymmetry.toStringAsFixed(2)} | Nose-Centering: ${noseCenteringScore.toStringAsFixed(2)} | Body-Orient: ${bodyOrientationScore.toStringAsFixed(2)} | Facing-Score: ${finalFacingScore.toStringAsFixed(2)} | State: ${orientationState.name} | Reason: ${rejectionReason ?? "VALID"}',
        name: 'PoseValidityGate',
      );
    }
  }
}

class PoseValidityResult {
  final bool isValid;
  final String? failReason;
  final double normShoulderWidth;
  final bool nosePresent;
  final bool isFacingCamera;
  final bool areEyesVisible;
  final FacingOrientationState orientationState;
  final double facingCameraScore;
  final double eyeSymmetry;
  final double noseCenteringScore;
  final double shoulderOrientationScore;
  final double noseConfidence;
  final double leftEyeConfidence;
  final double rightEyeConfidence;
  final double leftEarConfidence;
  final double rightEarConfidence;

  const PoseValidityResult({
    required this.isValid,
    this.failReason,
    required this.normShoulderWidth,
    this.nosePresent = true,
    this.areEyesVisible = true,
    this.orientationState = FacingOrientationState.unknownOrInsufficientData,
    this.facingCameraScore = 0.0,
    this.eyeSymmetry = 0.0,
    this.noseCenteringScore = 0.0,
    this.shoulderOrientationScore = 0.0,
    this.noseConfidence = 0.0,
    this.leftEyeConfidence = 0.0,
    this.rightEyeConfidence = 0.0,
    this.leftEarConfidence = 0.0,
    this.rightEarConfidence = 0.0,
  }) : isFacingCamera = orientationState == FacingOrientationState.facingCamera;
}
