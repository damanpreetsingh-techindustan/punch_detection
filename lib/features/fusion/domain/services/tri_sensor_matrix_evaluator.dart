import '../entities/sensor_signal_state.dart';
import '../entities/tri_sensor_fusion_result.dart';

/// Pure Domain Service implementing the Punch Detection Combination Matrix.
///
/// Follows SOLID principles:
///  - Single Responsibility: Exclusive authority for multi-sensor state evaluation.
///  - Open/Closed: Thresholds and decision matrix are encapsulated and configurable.
class TriSensorMatrixEvaluator {
  final double strongAudioSpikeDb;
  final double weakAudioSpikeDb;
  final double strongVibrationMag;
  final double weakVibrationMag;
  final bool requireVisionConfirmation;
  final bool isVibrationDisabled;
  final bool isPoleMount;

  const TriSensorMatrixEvaluator({
    this.strongAudioSpikeDb = 8.0,
    this.weakAudioSpikeDb = 4.0,
    this.strongVibrationMag = 0.18,
    this.weakVibrationMag = 0.10,
    this.requireVisionConfirmation = false,
    this.isVibrationDisabled = false,
    bool? isPoleMount,
  }) : isPoleMount = isPoleMount ?? isVibrationDisabled;

  /// Evaluates current raw sensor signals into discrete states and maps to matrix decision.
  TriSensorFusionResult evaluate({
    required double audioSpikeDb,
    required double vibrationMag,
    required bool isCameraAvailable,
    required bool isCameraConfirmed,
    required bool isCameraRejected,
    required int timestampMs,
  }) {
    final AudioSignalState audioState = _classifyAudio(audioSpikeDb);
    final VibrationSignalState vibeState = _classifyVibration(vibrationMag);
    final CameraSignalState cameraState = _classifyCamera(
      isAvailable: isCameraAvailable,
      isConfirmed: isCameraConfirmed,
      isRejected: isCameraRejected,
    );

    return evaluateStates(
      audioState: audioState,
      vibrationState: vibeState,
      cameraState: cameraState,
      timestampMs: timestampMs,
    );
  }

  AudioSignalState _classifyAudio(double spikeDb) {
    if (spikeDb >= strongAudioSpikeDb) return AudioSignalState.strong;
    final double effectiveWeakAudio = weakAudioSpikeDb >= strongAudioSpikeDb
        ? strongAudioSpikeDb * 0.5
        : weakAudioSpikeDb;
    if (spikeDb >= effectiveWeakAudio) return AudioSignalState.weak;
    return AudioSignalState.none;
  }

  VibrationSignalState _classifyVibration(double mag) {
    if (mag >= strongVibrationMag) return VibrationSignalState.strong;
    final double effectiveWeakVibe = weakVibrationMag >= strongVibrationMag
        ? strongVibrationMag * 0.5
        : weakVibrationMag;
    if (mag >= effectiveWeakVibe) return VibrationSignalState.weak;
    return VibrationSignalState.none;
  }

  CameraSignalState _classifyCamera({
    required bool isAvailable,
    required bool isConfirmed,
    required bool isRejected,
  }) {
    if (!isAvailable) return CameraSignalState.unavailable;
    if (isConfirmed) return CameraSignalState.confirmed;
    if (isRejected) return CameraSignalState.rejected;
    return CameraSignalState.unavailable;
  }

  /// Evaluates discrete sensor signal states against the user's decision matrix.
  TriSensorFusionResult evaluateStates({
    required AudioSignalState audioState,
    required VibrationSignalState vibrationState,
    required CameraSignalState cameraState,
    required int timestampMs,
  }) {
    // If strict vision confirmation is required, reject if camera did not confirm punching motion
    if (requireVisionConfirmation &&
        cameraState != CameraSignalState.confirmed) {
      return TriSensorFusionResult(
        outcome: PunchOutcome.notPunch,
        combinationCode: 'REJECTED_VISION_CONFIRMATION_REQUIRED',
        reasonLabel: 'Punch Rejected — Camera Confirmation Required',
        confidenceScore: 35.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. POLE MOUNT OR VIBRATION DISABLED:
    // Phone mounted on separate pole/stand, OR physical vibration is disabled.
    // Detects on EITHER:
    //  (a) Audio + Camera (visual-acoustic hit)
    //  (b) Audio + Vibration (physical frame shockwave, if available)
    //  (c) Audio + Vibe + Camera (all three)
    //  (d) Audio fallback (when camera is disabled/unavailable)
    // ─────────────────────────────────────────────────────────────────────────
    if (isPoleMount || isVibrationDisabled) {
      // 1a. Strong Audio + Strong Vibe + Confirmed Camera -> High confidence
      if (audioState == AudioSignalState.strong &&
          vibrationState == VibrationSignalState.strong &&
          cameraState == CameraSignalState.confirmed) {
        return TriSensorFusionResult(
          outcome: PunchOutcome.validPunch,
          combinationCode: 'VALID_HIGH_CONFIDENCE_TRIPLE_POLE',
          reasonLabel: 'Valid Punch — High Confidence (Audio + Vibe + Camera — Pole Mount)',
          confidenceScore: 98.0,
          audioState: audioState,
          vibrationState: vibrationState,
          cameraState: cameraState,
          timestampMs: timestampMs,
        );
      }

      // 1b. Strong Audio + Strong Vibe (even without Camera confirmation)
      if (audioState == AudioSignalState.strong &&
          vibrationState == VibrationSignalState.strong) {
        return TriSensorFusionResult(
          outcome: PunchOutcome.validPunch,
          combinationCode: 'VALID_AUDIO_VIBE_POLE',
          reasonLabel: 'Valid Punch (Audio + Vibration — Pole Mount)',
          confidenceScore: 92.0,
          audioState: audioState,
          vibrationState: vibrationState,
          cameraState: cameraState,
          timestampMs: timestampMs,
        );
      }

      // 1c. Strong Audio + Confirmed Camera (even without Vibration)
      if (audioState == AudioSignalState.strong &&
          cameraState == CameraSignalState.confirmed) {
        return TriSensorFusionResult(
          outcome: PunchOutcome.validPunch,
          combinationCode: 'VALID_AUDIO_CAMERA_POLE',
          reasonLabel: 'Valid Punch (Audio + Camera — Pole Mount / Vibe Off)',
          confidenceScore: 90.0,
          audioState: audioState,
          vibrationState: vibrationState,
          cameraState: cameraState,
          timestampMs: timestampMs,
        );
      }

      // 1d. Weak Audio + Confirmed Camera + Strong Vibe
      if (audioState == AudioSignalState.weak &&
          vibrationState == VibrationSignalState.strong &&
          cameraState == CameraSignalState.confirmed) {
        return TriSensorFusionResult(
          outcome: PunchOutcome.validPunch,
          combinationCode: 'VALID_VIBE_CAMERA_POLE',
          reasonLabel: 'Valid Punch (Vibration + Camera — Pole Mount)',
          confidenceScore: 84.0,
          audioState: audioState,
          vibrationState: vibrationState,
          cameraState: cameraState,
          timestampMs: timestampMs,
        );
      }

      // 1e. Weak Audio + Confirmed Camera (Motion with weak impact)
      if (audioState == AudioSignalState.weak &&
          cameraState == CameraSignalState.confirmed) {
        return TriSensorFusionResult(
          outcome: PunchOutcome.validPunch,
          combinationCode: 'VALID_WEAK_AUDIO_CAMERA_POLE',
          reasonLabel: 'Valid Punch (Camera Motion + Weak Sound — Pole Mount / Vibe Off)',
          confidenceScore: 78.0,
          audioState: audioState,
          vibrationState: vibrationState,
          cameraState: cameraState,
          timestampMs: timestampMs,
        );
      }

      // 1f. Strong Audio + Camera Unavailable (Fallback when camera is off/hidden/disabled)
      if (audioState == AudioSignalState.strong &&
          cameraState == CameraSignalState.unavailable) {
        return TriSensorFusionResult(
          outcome: PunchOutcome.validPunch,
          combinationCode: 'VALID_AUDIO_CAMERA_POLE',
          reasonLabel: 'Valid Punch (Audio Spike — Camera Disabled/Unavailable)',
          confidenceScore: 86.0,
          audioState: audioState,
          vibrationState: vibrationState,
          cameraState: cameraState,
          timestampMs: timestampMs,
        );
      }

      // 1g. Strong Audio + Camera Rejected but strict vision confirmation is relaxed/optional
      if (audioState == AudioSignalState.strong &&
          cameraState == CameraSignalState.rejected &&
          !requireVisionConfirmation) {
        return TriSensorFusionResult(
          outcome: PunchOutcome.validPunch,
          combinationCode: 'VALID_AUDIO_CAMERA_POLE',
          reasonLabel: 'Valid Punch (Audio Spike — Vision Confirmation Optional)',
          confidenceScore: 80.0,
          audioState: audioState,
          vibrationState: vibrationState,
          cameraState: cameraState,
          timestampMs: timestampMs,
        );
      }

      // 1h. Insufficient signals on Pole Mount / Vibration Disabled
      return TriSensorFusionResult(
        outcome: PunchOutcome.notPunch,
        combinationCode: 'REJECTED_INSUFFICIENT_SIGNALS_POLE',
        reasonLabel: 'Not Punch — No Valid Camera or Audio Confirmation',
        confidenceScore: 0.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. WALL MOUNT: Phone mounted directly to wall/bag mount.
    // Physical vibration is STRICTLY MANDATORY!
    // Weak or zero vibration CANNOT count as a punch.
    // ─────────────────────────────────────────────────────────────────────────

    // 2a. REJECT if Vibration is None (Air punch / clapping noise / shadow boxing)
    if (vibrationState == VibrationSignalState.none) {
      if (cameraState == CameraSignalState.confirmed) {
        return TriSensorFusionResult(
          outcome: PunchOutcome.notPunch,
          combinationCode: 'REJECTED_NO_VIBRATION_WALL_MOUNT',
          reasonLabel: 'Rejected — Physical Vibration Required on Wall Mount (Air Punch / Sound Mismatch)',
          confidenceScore: 25.0,
          audioState: audioState,
          vibrationState: vibrationState,
          cameraState: cameraState,
          timestampMs: timestampMs,
        );
      }
      return TriSensorFusionResult(
        outcome: PunchOutcome.notPunch,
        combinationCode: 'REJECTED_NO_VIBRATION_WALL_MOUNT',
        reasonLabel: 'Rejected — No Physical Vibration on Wall Mount',
        confidenceScore: 10.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // 2b. REJECT if Vibration is Weak (below minVibrationThreshold)
    if (vibrationState == VibrationSignalState.weak) {
      return TriSensorFusionResult(
        outcome: PunchOutcome.notPunch,
        combinationCode: 'REJECTED_WEAK_VIBRATION_WALL_MOUNT',
        reasonLabel: 'Rejected — Vibration Below Threshold on Wall Mount',
        confidenceScore: 35.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // At this point on Wall Mount, vibrationState IS VibrationSignalState.strong!

    // 2c. Strong Audio + Strong Vibe + Confirmed Cam -> High Confidence VALID PUNCH
    if (audioState == AudioSignalState.strong &&
        cameraState == CameraSignalState.confirmed) {
      return TriSensorFusionResult(
        outcome: PunchOutcome.validPunch,
        combinationCode: 'VALID_HIGH_CONFIDENCE_TRIPLE',
        reasonLabel: 'Valid Punch — High Confidence (Audio + Vibe + Camera)',
        confidenceScore: 98.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // 2d. Strong Audio + Strong Vibe + Camera Unavailable/Optional -> VALID PUNCH
    if (audioState == AudioSignalState.strong &&
        cameraState == CameraSignalState.unavailable) {
      return TriSensorFusionResult(
        outcome: PunchOutcome.validPunch,
        combinationCode: 'VALID_AUDIO_VIBE_DUAL',
        reasonLabel: 'Valid Punch (Audio + Vibration)',
        confidenceScore: 92.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // 2e. Strong Audio + Strong Vibe + Camera Rejected (Visual mismatch, but physical dual impact occurred)
    // Note: If requireVisionConfirmation was true, it was already rejected at line 82!
    if (audioState == AudioSignalState.strong &&
        cameraState == CameraSignalState.rejected) {
      return TriSensorFusionResult(
        outcome: PunchOutcome.validPunch,
        combinationCode: 'VALID_AUDIO_VIBE_DUAL_VISUAL_UNCONFIRMED',
        reasonLabel: 'Valid Punch (Audio + Vibration Dual Impact)',
        confidenceScore: 86.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // 2f. Weak Audio + Strong Vibe + Confirmed Cam -> VALID PUNCH (Quiet strike but strong shockwave & confirmed pose)
    if (audioState == AudioSignalState.weak &&
        cameraState == CameraSignalState.confirmed) {
      return TriSensorFusionResult(
        outcome: PunchOutcome.validPunch,
        combinationCode: 'VALID_VIBE_CAMERA_DUAL',
        reasonLabel: 'Valid Punch (Vibration + Camera Confirmation)',
        confidenceScore: 85.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // 2g. Weak Audio + Strong Vibe + Unavailable Cam -> Candidate Impact
    if (audioState == AudioSignalState.weak &&
        cameraState == CameraSignalState.unavailable) {
      return TriSensorFusionResult(
        outcome: PunchOutcome.candidate,
        combinationCode: 'CANDIDATE_VIBE_WEAK_AUDIO',
        reasonLabel: 'Candidate — Physical Impact with Weak Sound',
        confidenceScore: 60.0,
        audioState: audioState,
        vibrationState: vibrationState,
        cameraState: cameraState,
        timestampMs: timestampMs,
      );
    }

    // 2h. Default fallback on Wall Mount
    return TriSensorFusionResult(
      outcome: PunchOutcome.notPunch,
      combinationCode: 'REJECTED_INSUFFICIENT_SIGNALS',
      reasonLabel: 'Not Punch — Insufficient Signal on Wall Mount',
      confidenceScore: 0.0,
      audioState: audioState,
      vibrationState: vibrationState,
      cameraState: cameraState,
      timestampMs: timestampMs,
    );
  }
}
