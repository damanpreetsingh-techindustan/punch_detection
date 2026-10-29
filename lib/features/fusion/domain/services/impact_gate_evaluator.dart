/// Vibration gate state for one impact.
enum VibrationGateState {
  /// Vibration is not used (pole mount, gate off, or a mode without vibration).
  notRequired,

  /// Required but no vibration at or above the threshold was seen in the window.
  missing,

  /// Required and seen.
  present,
}

/// Camera gate state for one impact.
enum CameraGateState {
  /// Camera is not used (mode without camera, vision confirmation off, or no camera).
  notRequired,

  /// Camera is enabled but not ready yet (still starting up).
  notReady,

  /// Camera is running but no valid user is visible (no shoulder or face).
  noPerson,

  /// A user is visible but farther than the allowed distance.
  tooFar,

  /// A valid user is visible and close enough.
  valid,
}

/// Body-motion gate state for one impact (did the user's upper body move?).
enum BodyMotionGateState {
  /// Gate is off, or the camera is not used for this impact.
  notRequired,

  /// The body moved enough around the impact.
  moved,

  /// Camera frames were seen but the body did not move enough (standing still).
  still,

  /// Too few camera frames to measure movement.
  unknown,
}

enum ImpactOutcome { valid, rejected, pending }

class ImpactGateResult {
  final ImpactOutcome outcome;
  final String code;
  final String reasonLabel;
  final VibrationGateState vibration;
  final CameraGateState camera;
  final BodyMotionGateState motion;

  const ImpactGateResult({
    required this.outcome,
    required this.code,
    required this.reasonLabel,
    required this.vibration,
    required this.camera,
    this.motion = BodyMotionGateState.notRequired,
  });

  bool get isValid => outcome == ImpactOutcome.valid;
  bool get isPending => outcome == ImpactOutcome.pending;
  bool get isRejected => outcome == ImpactOutcome.rejected;
}

/// Decides one impact from all three sensors at once.
///
/// Rule: an audio spike that reached its target becomes a punch only when every
/// gate that is in use also confirms it:
///   - vibration (unless not required),
///   - camera (unless not required),
///   - body motion (unless not required; on top of the camera person check).
/// A gate that is not in use is skipped, so with the camera disabled the punch is
/// decided by audio + vibration, and with vibration disabled by audio + camera.
///
/// While the impact window is open a missing gate keeps the result `pending`
/// (late vibration or a late camera frame can still arrive). Once the window is
/// closed a missing gate rejects the impact.
///
/// Pure: no clocks, no I/O.
class ImpactGateEvaluator {
  const ImpactGateEvaluator();

  /// [motion] defaults to notRequired, so callers without the body-motion
  /// gate behave exactly as before. [motionUnknownIsValid]: what an
  /// unmeasurable motion means once the window has closed.
  ImpactGateResult evaluate({
    required VibrationGateState vibration,
    required CameraGateState camera,
    required bool windowClosed,
    BodyMotionGateState motion = BodyMotionGateState.notRequired,
    bool motionUnknownIsValid = true,
  }) {
    final bool vibrationOk = vibration != VibrationGateState.missing;
    final bool cameraOk =
        camera == CameraGateState.notRequired ||
        camera == CameraGateState.valid;
    // "unknown" only passes once the window closed: until then more camera
    // frames can still arrive and show the movement.
    final bool motionOk =
        motion == BodyMotionGateState.notRequired ||
        motion == BodyMotionGateState.moved ||
        (motion == BodyMotionGateState.unknown &&
            motionUnknownIsValid &&
            windowClosed);
    final String motionSuffix = switch (motion) {
      BodyMotionGateState.moved => ' + Body Motion',
      BodyMotionGateState.unknown => ' (body motion not measurable)',
      _ => '',
    };

    if (vibrationOk && cameraOk && motionOk) {
      final bool usesVibration = vibration == VibrationGateState.present;
      final bool usesCamera = camera == CameraGateState.valid;
      final String code;
      final String label;
      if (usesVibration && usesCamera) {
        code = 'IMPACT_VALID_AUDIO_VIBE_CAM';
        label = 'Valid Punch (Audio + Vibration + Camera)';
      } else if (usesVibration) {
        code = 'IMPACT_VALID_AUDIO_VIBE';
        label = 'Valid Punch (Audio + Vibration, camera not used)';
      } else if (usesCamera) {
        code = 'IMPACT_VALID_AUDIO_CAM';
        label = 'Valid Punch (Audio + Camera, vibration not used)';
      } else {
        code = 'IMPACT_VALID_AUDIO_ONLY';
        label = 'Valid Punch (Audio only, vibration and camera not used)';
      }
      return ImpactGateResult(
        outcome: ImpactOutcome.valid,
        code: code,
        reasonLabel: '$label$motionSuffix',
        vibration: vibration,
        camera: camera,
        motion: motion,
      );
    }

    if (!windowClosed) {
      return ImpactGateResult(
        outcome: ImpactOutcome.pending,
        code: 'IMPACT_PENDING',
        reasonLabel:
            'Waiting for ${_missing(vibrationOk, camera, motionOk)}',
        vibration: vibration,
        camera: camera,
        motion: motion,
      );
    }

    // Vibration / camera problems are reported first (unchanged codes); the
    // body-motion code only appears when those two passed.
    final String code;
    final String label;
    if (!vibrationOk && !cameraOk) {
      code = 'IMPACT_REJECTED_NO_VIBRATION_NO_CAMERA';
      label = 'Rejected — no vibration and ${_cameraProblem(camera)}';
    } else if (!vibrationOk) {
      code = 'IMPACT_REJECTED_NO_VIBRATION';
      label = 'Rejected — no physical vibration at the impact';
    } else if (!cameraOk) {
      code = switch (camera) {
        CameraGateState.tooFar => 'IMPACT_REJECTED_CAMERA_TOO_FAR',
        CameraGateState.notReady => 'IMPACT_REJECTED_CAMERA_NOT_READY',
        _ => 'IMPACT_REJECTED_CAMERA_NO_PERSON',
      };
      label = 'Rejected — ${_cameraProblem(camera)}';
    } else if (motion == BodyMotionGateState.unknown) {
      code = 'IMPACT_REJECTED_MOTION_UNKNOWN';
      label = 'Rejected — body motion could not be measured';
    } else {
      code = 'IMPACT_REJECTED_NO_BODY_MOTION';
      label = 'Rejected — user did not move (standing still)';
    }
    return ImpactGateResult(
      outcome: ImpactOutcome.rejected,
      code: code,
      reasonLabel: label,
      vibration: vibration,
      camera: camera,
      motion: motion,
    );
  }

  static String _missing(
    bool vibrationOk,
    CameraGateState camera,
    bool motionOk,
  ) {
    final List<String> parts = <String>[
      if (!vibrationOk) 'vibration',
      if (camera != CameraGateState.notRequired &&
          camera != CameraGateState.valid)
        'camera',
      if (!motionOk) 'body motion',
    ];
    return parts.join(' and ');
  }

  static String _cameraProblem(CameraGateState camera) => switch (camera) {
    CameraGateState.tooFar => 'user too far from camera',
    CameraGateState.notReady => 'camera not ready',
    _ => 'no user visible to camera',
  };
}
