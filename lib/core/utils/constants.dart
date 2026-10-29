import 'dart:io';

import '../enums/detection_enums.dart';

class AppConstants {
  static const String appName = 'Hyper Hitter';
  static const int calibrationDurationSeconds = 10;
  static const int targetDetectionLatencyMs = 100;

  // Design baseline dimensions
  static const double designWidth = 375.0;
  static const double designHeight = 812.0;
  static const bool testingAnglerLogs = false;
  static const bool testingPoseValidationLogs = false;
  static const bool testingArmValidationLogs = false;
  static const bool testingFreeSessionLogs = true;
  static const bool testingPromptSessionLogs = true;
  // for camera const variables
  static const bool testingNeedToUseUltraWideCamera = true;
  static const bool testingNeedStaticZoom = false;
  static const double testingZoomValue = 1.0;
  static const bool showAllFeatures = true;
  static const bool useAvarageAudioFormate = false;
  static const int globalStaticAudioMsg = 10;

  /// Global Toggle Flag for Device Stability & Motion Check (sensors_plus)
  static bool enableDeviceStabilityCheck = false;

  /// Global Toggle Flag for Extra Face Restrictions (Eye Symmetry, Nose  ̰Centering, Ear Evaluation)
  /// When true: strict face, eye symmetry, and two-shoulder validation runs.
  /// When false: relaxed validation runs (checks if any single face point or shoulder point is in frame).
  static bool enableExtraFaceRestrictions = false;

  /// Global Toggle Flag for Device Haptic Vibration Feedback on Punch Detection
  /// When true: phone vibrates (haptic impact) on punch confirmation.
  /// When false: haptic vibration is disabled.
  static bool enableHapticVibrationOnPunch = false;

  /// Maximum physical audio limit from mobile microphone hardware (110 dB)
  static const double maxSystemAudioDb = 110.0;

  /// Global runtime audio capture interval in milliseconds (Default: 20ms).
  /// Single source of truth: change here or mutate dynamically via settings.
  static int globalAudioSampleIntervalMs = AppConstants.globalStaticAudioMsg;

  /// Number of consecutive audio frames used for the rolling moving average (Default: 3 frames, ~60ms).
  /// Averages out transient micro-noises (breath pops, mouth clicks) while keeping punch strike energy intact.
  static const int audioRollingAverageFrames = 2;

  /// Minimum gap between two counted audio spikes, in milliseconds. Used by the
  /// Free session (the Prompt session still has its own copy of 160).
  /// Value unchanged; whether to lower it waits for measured punch cadence.
  static const int audioRefractoryMs = 160;

  /// When true the Free session reads the microphone as 10 ms blocks computed
  /// from the raw PCM stream, with real timestamps, instead of the plugin's
  /// whole-chunk amplitude. Flip to false to compare against the old behaviour.
  static const bool useSubBlockPcmLevels = true;

  /// PCM chunk lengths (milliseconds) to try, smallest first. Converted to a
  /// buffer size in bytes from the actual sample rate. The Android `AudioRecord`
  /// is created with that size and fails to start when it is below the device
  /// minimum, so the service tries each and keeps the first that starts; the
  /// plugin default (about 80 ms chunks) is tried last.
  static const List<int> audioStreamChunkCandidatesMs = [20, 40, 80];

  // ─── Impact window (audio + vibration + camera decided once) ────────────────
  /// Vibration counts for an audio spike if it happened up to this many
  /// milliseconds BEFORE the spike (audio is delivered later than the sensor).
  static const int impactVibrationBeforeMs = 100;

  /// ...and up to this many milliseconds AFTER the spike. This is also how long
  /// the decision waits for late vibration. Must stay below [audioRefractoryMs]
  /// (the Free session clamps it) so one window closes before the next can open.
  static const int impactVibrationAfterMs = 150;

  // ─── Camera real-person gate ─────────────────────────────────────────────────
  // A camera pose only counts as a person when it has at least one FACE point
  // (nose, eye, ear, mouth) AND at least one SHOULDER, each detected with at
  // least this confidence (0.0 - 1.0). Face + one shoulder is enough.
  // Objects such as a bottle can produce a weak "pose"; they rarely reach this
  // confidence on both a face point and a shoulder.
  //
  // How to tune: SESSION TOTALS shows `cam.best_face_conf` and
  // `cam.best_shoulder_conf` (min / avg / max), and the CSV table at the end of
  // the log shows them on every camera change. Compare a session with you in
  // frame against one with only the object in frame.

  /// Master switch. false = old rule (any face point OR any shoulder at >= 0.20).
  static const bool cameraPersonGateEnabled = true;

  /// Minimum confidence of the best face point.
  static const double cameraMinFaceConfidence = 0.5;

  /// Minimum confidence of the best shoulder.
  static const double cameraMinShoulderConfidence = 0.5;

  /// The face must be above the shoulder in the camera image (a real upright
  /// person). Turn off only if the camera image is mounted sideways.
  static const bool cameraRequireFaceAboveShoulder = true;

  // ─── Camera distance gate ────────────────────────────────────────────────────
  // A camera pose only counts as a valid user when the person is close enough.
  // Distance is measured as a RATIO of the body width to the camera image
  // diagonal: bigger ratio = closer. Tune these two numbers to scale the
  // allowed distance; nothing else needs to change.
  //
  // How to tune: stand at the farthest spot you still want to count, run a
  // session, and read `cam.shoulder_ratio` (min / avg / max) in the exported
  // SESSION TOTALS. Set the minimum a little below that average.

  /// Master switch. false = no distance rule (any visible shoulder or face is valid).
  static const bool cameraDistanceGateEnabled = true;

  /// Minimum shoulder width as a fraction of the image diagonal. A person
  /// farther than this (smaller ratio) is NOT a valid user.
  /// Rough guide for a ~90° front camera: 0.20 ≈ 0.8 m, 0.11 ≈ 1.5 m, 0.08 ≈ 2 m.
  static const double cameraMinShoulderWidthRatio = 0.09;

  /// Same rule used when both shoulders are not visible but both eyes are.
  /// Eye span is about 1/6 of shoulder width, so this is ~1/6 of the value above.
  static const double cameraMinEyeSpanRatio = 0.014;

  /// What to do when the distance cannot be measured (for example only one
  /// shoulder visible and no eyes): true = treat as valid (never miss a punch).
  static const bool cameraDistanceUnknownIsValid = true;

  /// A camera observation older than this (milliseconds) no longer counts.
  static const int cameraObservationStaleMs = 700;

  /// Field-test experiments for microphone clipping. Both default to OFF so the
  /// recorded baseline is unchanged; flip one at a time (debug section of the
  /// session settings sheet) and compare the `audio.saturated_frames` total.
  /// They stay set until the app restarts, so the next calibration uses them too.
  /// Turn off hardware noise suppression and echo cancellation on the mic.
  static bool audioExperimentDisableMicProcessing = false;

  /// Android: record from the `unprocessed` source (no gain or filtering),
  /// falling back to `voiceRecognition` when it cannot start.
  /// iOS: put the audio session in `measurement` mode.
  static bool audioExperimentUnprocessedSource = false;

  // ─── Phase 1 fixes (legacy engine) ──────────────────────────────────────────
  /// Frame rate requested from the camera (was accidentally the audio interval).
  static const int cameraFps = 15;

  /// Camera as a soft presence check: an impact passes the camera gate when a
  /// valid person was seen at least once in the last [cameraPresenceWindowMs].
  /// false = old per-frame hard gate (the latest frame's state decides).
  static const bool cameraPresenceWindowEnabled = true;
  static const int cameraPresenceWindowMs = 1500;

  /// With the presence check on, "camera not ready" passes during the first
  /// [cameraStartupGraceMs] of a session (logged as a grace pass).
  static const int cameraStartupGraceMs = 3000;

  /// Screen-touch lockout: no impact counts from [touchLockoutBeforeMs] before
  /// to [touchLockoutAfterMs] after any pointer-down on the session screen.
  static const bool touchLockoutEnabled = true;
  static const int touchLockoutBeforeMs = 100;
  static const int touchLockoutAfterMs = 400;

  /// Pre-check calibration: blocks in the first [calibrationIgnoreFirstMs] are
  /// dropped; the room floor is the mean of the 10 ms block levels between
  /// these two percentiles.
  static const int calibrationIgnoreFirstMs = 400;
  static const double calibrationFloorLowPercentile = 20.0;
  static const double calibrationFloorHighPercentile = 50.0;

  /// Bottom of the app dB scale (-60 dBFS). A mic that stays here for longer
  /// than [micFloorWarningMs] is not delivering audio.
  static const double micScaleFloorDb = 35.0;
  static const int micFloorWarningMs = 1000;

  // ─── Phase 2: full-rate raw logging (debug) ─────────────────────────────────
  /// When true, each Free session also writes its raw sensor data (16 kHz WAV,
  /// full-rate 3-axis accelerometer, events, session_meta.json) to
  /// `<documents>/raw_sessions/session_<startMs>/`. Toggle in Settings → Debug
  /// or the session settings sheet. Format: docs/raw-logging.md.
  static bool recordRawSessionData = false;

  // ─── Phase 4: detector engine selection ─────────────────────────────────────
  /// Detector used by Free sessions (Settings → Debug). Stays `legacy` until
  /// fusionV2 is signed off; the legacy engine's values (D12) are untouched.
  /// The prompt session always uses the legacy logic.
  static DetectorEngine detectorEngine = DetectorEngine.legacy;

  /// TESTING CONFIGURATION:
  /// Absolute minimum safety floor for punch audio detection.
  /// Sounds below this dB are never considered punches.
  static const double minAudioSafetyFloorDb = 60.0;

  /// Bounds for target punch dB sent to workout session after calibration.
  /// Minimum calibrated target dB sent (Testing default: 66.0 dB).write
  static const double minCalibratedTargetPunchDb = 66.0;

  /// Maximum calibrated target dB sent (Testing default: 90.0 dB).
  static const double maxCalibratedTargetPunchDb = 90.0;

  /// Direct Audio Target Calibration Offset:
  /// Default 0.0: direct max calibrated average dB shown on screen is used with no extra offset added.
  static const double calibrationAudioTargetOffsetDb = 0.0;

  /// Default audio punch spike threshold added above calibrated audio (default +6 dB)
  static const double defaultAudioSpikeThresholdDb = 8.0;

  /// Spike Threshold Slider bounds in session detection settings (min: -15.0 dB, max: 50.0 dB)
  static const double minAudioSpikeSliderDb = -15.0;
  static const double maxAudioSpikeSliderDb = 50.0;

  /// Audio Spike Waveform Graph Visual Display Boundaries:
  /// Controls the minimum and maximum decibel range rendered on the waveform graphs across all sessions.
  static const double minAudioGraphDb = 55.0;
  static const double maxAudioGraphDb = 115.0;

  /// Physical Impact (Vibration) Threshold Settings in m/s²:
  /// Default threshold for physical impact detection.
  static double defaultImpactVibrationThreshold = Platform.isIOS ? 0.18 : 0.06;

  /// Impact Sensitivity Slider bounds in session detection settings (0.05 m/s² to 1.0 m/s²)
  static double minImpactVibrationSlider = 0.05;
  static double maxImpactVibrationSlider = 1.0;
  static double warmUpDurationInMiliSeconds = 200;

  /// Cooldown duration in milliseconds after closing settings sheet or tune dialog
  /// before punch detection is re-enabled (Default: 1000ms / 1 second).
  static int postSettingsCooldownMs = 1000;

  static void changeSettingToDefault() {
    globalAudioSampleIntervalMs = AppConstants.globalStaticAudioMsg;
    defaultImpactVibrationThreshold = Platform.isIOS ? 0.18 : 0.06;
    enableDeviceStabilityCheck = false;
    enableExtraFaceRestrictions = false;
    postSettingsCooldownMs = 1000;
  }

  /// Official Fighter Callout Combo List
  static const List<List<int>> comboList = [
    // 2-element combos (14 items)
    [1, 2], [1, 3], [1, 5], [2, 3], [2, 6], [3, 2], [3, 4],
    [3, 5], [4, 2], [4, 6], [5, 2], [5, 3], [6, 2], [6, 3],
    // 3-element combos (28 items)
    [1, 2, 3], [1, 2, 4], [1, 2, 5], [1, 2, 6], [1, 3, 2], [1, 3, 4],
    [1, 5, 2], [1, 5, 3], [1, 6, 2], [1, 6, 3], [2, 3, 2], [2, 3, 4],
    [2, 3, 5], [2, 6, 3], [3, 2, 3], [3, 2, 4], [3, 2, 5], [3, 4, 2],
    [3, 5, 2], [3, 6, 2], [4, 2, 3], [4, 3, 2], [4, 5, 2], [4, 6, 3],
    [5, 2, 3], [5, 3, 2], [6, 2, 3], [6, 3, 2],
    // 4-element combos (60 items)
    [1, 1, 2, 3], [1, 2, 3, 2], [1, 2, 3, 4], [1, 2, 4, 2], [1, 2, 5, 2],
    [1, 2, 6, 3], [1, 3, 2, 3], [1, 3, 4, 2], [1, 5, 2, 3], [1, 5, 3, 2],
    [1, 6, 2, 3], [1, 6, 3, 2], [2, 3, 2, 3], [2, 3, 4, 2], [2, 3, 5, 2],
    [2, 3, 6, 3], [2, 6, 3, 2], [2, 6, 3, 4], [3, 2, 3, 2], [3, 2, 3, 4],
    [3, 2, 4, 2], [3, 2, 5, 2], [3, 4, 2, 3], [3, 4, 3, 2], [3, 5, 2, 3],
    [3, 5, 3, 2], [3, 6, 2, 3], [3, 6, 3, 2], [4, 2, 3, 2], [4, 2, 3, 4],
    [4, 3, 2, 3], [4, 3, 4, 2], [4, 5, 2, 3], [4, 6, 3, 2], [5, 2, 3, 2],
    [5, 2, 3, 4], [5, 3, 2, 3], [5, 3, 4, 2], [5, 2, 5, 2], [5, 3, 6, 3],
    [6, 2, 3, 2], [6, 2, 3, 4], [6, 3, 2, 3], [6, 3, 4, 2], [6, 2, 6, 3],
    [6, 3, 6, 3],
    // Additional combos
    [1, 2, 1, 2], [1, 3, 1, 2], [2, 3, 2, 3], [3, 2, 1, 2], [1, 5, 1, 2],
    [2, 6, 3, 2], [3, 5, 2, 3], [4, 6, 2, 3], [5, 2, 1, 2], [6, 3, 2, 3],
    [5, 2, 6, 3], [6, 3, 5, 2],
  ];
}
