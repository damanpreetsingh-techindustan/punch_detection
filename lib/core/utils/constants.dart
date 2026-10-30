import 'dart:io';

enum VibrationGateType {
  /// Impulsive high-frequency jerk delta knock with single-use knock ledger
  knock,

  /// Legacy envelope peak magnitude threshold
  peakThreshold,
}

/// How much upper-body movement a punch must show (body-motion gate).
/// Ordered from most sensitive (least movement needed) to strictest.
enum BodyMotionLevel {
  /// Lowest preset: almost any movement passes. Close to the standing-still
  /// jitter (1-3 %), so use only if light punches are still rejected.
  veryLight,

  /// Light jabs with very little shoulder / head movement pass.
  light,

  /// Light jabs pass easily; still blocks a user standing still.
  easy,

  /// Recommended balance.
  normal,

  /// Highest bar: only clear punching movement passes.
  strict,

  /// Value set with the slider that matches none of the presets.
  custom,
}

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
  static const int cameraTargetFps = 30;

  /// Number of consecutive audio frames used for the rolling moving average (Default: 3 frames, ~60ms).
  /// Averages out transient micro-noises (breath pops, mouth clicks) while keeping punch strike energy intact.
  static const int audioRollingAverageFrames = 2;

  /// Minimum gap between two counted audio spikes, in milliseconds. Used by the
  /// Free session (the Prompt session still has its own copy of 160).
  /// Value unchanged; whether to lower it waits for measured punch cadence.
  static const int audioRefractoryMs = 160;

  /// Shorter lockout used ONLY when every punch must also bring its own fresh
  /// vibration knock (fusion / audio+vibration mode, vibration on, Fresh Knock
  /// gate). The knock is what stops one hit being counted twice, so the audio
  /// lockout can be short enough for fast combos (1-2 at ~120 ms apart).
  /// Pole mount, vibration off or the Legacy Peak gate keep [audioRefractoryMs].
  /// How to tune: look at `msSinceLastSpike` of `spike_suppressed` lines in the
  /// session log; real combo punches should land above this value.
  static const int audioRefractoryKnockMs = 100;

  /// Impacts that may wait for their vibration / camera at the same time.
  /// More than one is only possible with the short knock lockout above; each
  /// waiting impact claims a different knock, so they cannot share one hit.
  static const int maxPendingImpacts = 3;

  /// Hard punch → soft punch combo: for this long after a confirmed punch, a
  /// spike slightly below the audio target may still count (see below).
  static const int comboSoftPunchWindowMs = 700;

  /// How many dB below the audio target a combo follow-up punch may be.
  /// Safe because it still needs its own fresh vibration knock (a voice cannot
  /// make one) and the camera, and never goes below [minAudioSafetyFloorDb].
  static const double comboSoftPunchAudioRelaxDb = 6.0;

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
  /// Rough guide for a ~90° front camera: 0.20 ≈ 0.8 m, 0.11 ≈ 1.5 m, 0.08 ≈ 2 m. // by default 0.09
  static const double cameraMinShoulderWidthRatio = 0.20;

  /// Same rule used when both shoulders are not visible but both eyes are.
  /// Eye span is about 1/6 of shoulder width, so this is ~1/6 of the value above. // by default 0.014;
  static const double cameraMinEyeSpanRatio = 0.031;

  /// Shoulders / eyes below this confidence are not used to measure distance.
  /// Far users get weak, jumpy points that can fake a wide shoulder span.
  static const double cameraDistanceMinLikelihood = 0.5;

  /// Consecutive close-enough frames needed before the user counts as near,
  /// so one noisy frame from a far user cannot confirm a punch.
  static const int cameraMinConsecutiveNearFrames = 1;

  /// Once the user is confirmed near, this many "too far" frames in a row are
  /// needed before the camera says too far. A hook or side stance turns the
  /// body for ~200 ms and makes the shoulders look narrow (= far); this keeps
  /// those punches counting while a user who really walks away is still
  /// rejected after ~1/3 s (at 30 processed frames per second).
  static const int cameraFarFramesToLeaveNear = 10;

  /// Approximate distance from a shoulder ratio: metres ≈ factor / ratio
  /// (matches the guide above: 0.20 ≈ 0.8 m, 0.08 ≈ 2 m). The default slider
  /// value is cameraDistanceMetresFactor / cameraMinShoulderWidthRatio.
  static const double cameraDistanceMetresFactor = 0.16;

  /// Range of the "Max Camera Distance" slider in the session settings (metres).
  static const double minCameraDistanceSliderM = 0.4;
  static const double maxCameraDistanceSliderM = 3.0;

  /// What to do when the distance cannot be measured (for example only one
  /// shoulder visible and no eyes): true = treat as valid (never miss a punch).
  static bool cameraDistanceUnknownIsValid = true;

  /// A camera observation older than this (milliseconds) no longer counts.
  static const int cameraObservationStaleMs = 700;

  /// Field-test experiments for microphone clipping. Both default to OFF so the
  /// recorded baseline is unchanged; flip one at a time and compare the
  /// `audio.saturated_frames` total.
  /// Turn off hardware noise suppression and echo cancellation on the mic.
  static const bool audioExperimentDisableMicProcessing = false;

  /// Use the Android `unprocessed` audio source (no gain or filtering).
  static const bool audioExperimentUnprocessedSource = false;

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

  /// Strategy type for vibration gating (knock: impulsive jerk; peakThreshold: legacy envelope)
  static VibrationGateType vibrationGateType = VibrationGateType.knock;

  /// Minimum sample-to-sample jerk (m/s²) to identify a collision knock
  static const double knockMinJerk = 0.15;

  /// Merge window (ms) to group multi-axis jerk oscillations of the same hit into one knock
  static const int knockMergeMs = 40;

  /// After a hit the mount keeps shaking for ~100 ms with SHRINKING jerks.
  /// A jerk only counts as a new knock when it is at least this many times
  /// larger than the biggest jerk of the last [knockRingDownWindowMs]; the
  /// fading tail never is, a new punch landing on it is.
  static const double knockRiseFactor = 1.5;

  /// How far back (ms) the "recent jerk" used by [knockRiseFactor] looks.
  static const int knockRingDownWindowMs = 60;

  /// A gap between two sensor readings longer than this (ms) means the sensor
  /// was paused or restarted; the next reading only becomes the new starting
  /// point and can never be a knock by itself.
  static const int knockReseedGapMs = 200;

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
    vibrationGateType = VibrationGateType.knock;
    cameraDistanceUnknownIsValid = true;
    bodyMotionGateEnabled = bodyMotionGateEnabledDefault;
    bodyMotionLevel = BodyMotionLevel.easy;
    bodyMotionMinScoreValue = bodyMotionMinScoreNormal;
  }

  // ─── Body-motion gate (camera) ──────────────────────────────────────────────
  // Problem it solves: user standing still + a loud background sound + a bump on
  // the mount = audio, a fresh knock and "person in frame" all pass, so a punch
  // was counted although the user did not move. This gate also asks the camera
  // "did the user's upper body move around the impact?".
  //
  // It needs only what is always visible: face + shoulders (one shoulder is
  // enough). Elbows / wrists are used too when ML Kit sees them.
  //
  // Score = how far the most-moved body point went from its usual position in
  // the window, divided by the user's body width (shoulder span), so the same
  // number works near or far from the camera. Standing still (breathing +
  // ML Kit jitter) ≈ 0.01-0.03; a punch moves head / shoulders ≈ 0.08-0.30.
  //
  // How to tune: every impact in the log has `motionScore` (also when the gate
  // is OFF). Compare scores of real punches with the scores of
  // "standing still + noise" impacts and pick the level between them.

  /// Default of the settings switch at the start of every session.
  /// false = the score is only LOGGED, nothing is rejected (safe first test).
  /// Flip to true once the logged scores confirm the chosen level.
  static const bool bodyMotionGateEnabledDefault = false;

  /// Live value of the settings switch (reset by [changeSettingToDefault]).
  static bool bodyMotionGateEnabled = bodyMotionGateEnabledDefault;

  /// Live difficulty level (reset by [changeSettingToDefault]).
  static BodyMotionLevel bodyMotionLevel = BodyMotionLevel.normal;

  /// Minimum motion score per preset (fraction of the body width).
  static const double bodyMotionMinScoreVeryLight = 0.03;
  static const double bodyMotionMinScoreLight = 0.04;
  static const double bodyMotionMinScoreEasy = 0.05;
  static const double bodyMotionMinScoreNormal = 0.08;
  static const double bodyMotionMinScoreStrict = 0.12;

  /// Live minimum score actually used by the gate (single source of truth).
  /// A preset sets it to the preset value; the sensitivity slider sets any
  /// value in [bodyMotionSliderMin]..[bodyMotionSliderMax].
  static double bodyMotionMinScoreValue = bodyMotionMinScoreNormal;

  /// Sensitivity slider range and step (2 % .. 20 % of the body width,
  /// 0.5 % steps). Below ~3 % standing still can start to pass.
  static const double bodyMotionSliderMin = 0.02;
  static const double bodyMotionSliderMax = 0.20;
  static const double bodyMotionSliderStep = 0.005;

  /// Preset value, or the live slider value for [BodyMotionLevel.custom].
  static double bodyMotionMinScore(BodyMotionLevel level) => switch (level) {
    BodyMotionLevel.veryLight => bodyMotionMinScoreVeryLight,
    BodyMotionLevel.light => bodyMotionMinScoreLight,
    BodyMotionLevel.easy => bodyMotionMinScoreEasy,
    BodyMotionLevel.normal => bodyMotionMinScoreNormal,
    BodyMotionLevel.strict => bodyMotionMinScoreStrict,
    BodyMotionLevel.custom => bodyMotionMinScoreValue,
  };

  /// The preset whose value equals [score], or custom when none does
  /// (used to highlight the matching chip when the slider moves).
  static BodyMotionLevel bodyMotionLevelFor(double score) {
    for (final BodyMotionLevel level in BodyMotionLevel.values) {
      if (level == BodyMotionLevel.custom) continue;
      if ((bodyMotionMinScore(level) - score).abs() < 0.0001) return level;
    }
    return BodyMotionLevel.custom;
  }

  /// Motion window around the audio spike: a punch moves the body during the
  /// wind-up BEFORE the impact, so the window starts well before the sound.
  static const int bodyMotionBeforeMs = 300;
  static const int bodyMotionAfterMs = 150;

  /// Fewer camera frames than this in the window = motion "unknown".
  static const int bodyMotionMinFrames = 3;

  /// Body points below this ML Kit confidence are ignored (weak points jump
  /// around and would look like movement).
  static const double bodyMotionMinLikelihood = 0.5;

  /// When the motion cannot be measured (too few frames, e.g. the camera
  /// dropped frames): true = let the impact through, so a slow camera never
  /// loses real punches. The person / distance gates still apply.
  static const bool bodyMotionUnknownIsValid = true;

  /// How long camera frames are kept for the motion check (ms).
  static const int bodyMotionHistoryMs = 2000;

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
