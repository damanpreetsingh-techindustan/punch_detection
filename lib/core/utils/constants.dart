import 'dart:io';

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
  static const bool showAllFeatures = false;
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
