import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import '../../../../core/enums/detection_enums.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../vision_detection/data/geometric_rules/pose_validity_gate.dart';
import '../../../vision_detection/data/geometric_rules/shoulder_stability_tracker.dart';
import '../../../vision_detection/domain/entities/temporal_punch_detector.dart';
import '../../../vision_detection/domain/entities/punch_detection_config.dart';
import '../../../fusion/domain/services/impact_gate_evaluator.dart';
import '../../../fusion/domain/vibration_gate/i_vibration_gate.dart';
import '../../../fusion/domain/vibration_gate/models/vibration_gate_evaluation.dart';
import '../../../fusion/domain/vibration_gate/vibration_gate_factory.dart';
import '../../../fusion/domain/body_motion_gate/i_body_motion_gate.dart';
import '../../../fusion/domain/body_motion_gate/models/body_motion_evaluation.dart';
import '../../../fusion/domain/body_motion_gate/models/body_motion_frame.dart';
import '../../../fusion/domain/body_motion_gate/services/landmark_motion_gate.dart';
import '../../../vision_detection/data/mappers/pose_motion_frame_mapper.dart';
import '../../../vision_detection/domain/services/camera_distance_gate.dart';
import '../../../vision_detection/domain/services/camera_near_latch.dart';
import '../../../vision_detection/domain/services/camera_person_gate.dart';
import '../../../fusion/domain/services/fast_combo_fusion_synchronizer.dart';
import '../../../../core/services/audio_level/audio_level_sample.dart';
import '../../../../core/services/audio_level/i_audio_level_service.dart';
import '../../../../core/services/audio_level/adaptive_audio_baseline.dart';
import '../../../../core/services/audio_level/record_audio_level_service.dart';
import '../../../../core/services/device_stability/device_stability_models.dart';
import '../../../../core/services/device_stability/device_stability_service.dart';
import '../../../../core/services/device_stability/i_device_stability_service.dart';
import '../../../../core/services/device_vibration/device_vibration_service.dart';
import '../../../../core/services/device_vibration/i_device_vibration_service.dart';
import '../../../../core/services/session_recording/session_event_recorder.dart';
import '../../../../core/services/session_recording/session_summary_table.dart';
import '../../domain/entities/punch_telemetry_event.dart';
import '../../domain/services/auto_config_evaluator.dart';
import '../widgets/auto_config_dialog.dart';
import '../widgets/live_telemetry_sheet.dart';
import '../widgets/session_detection_settings_sheet.dart';

class FreeSessionController extends GetxController {
  CameraController? cameraController;
  PoseDetector? _poseDetector;

  // Real-time Audio Level Sensor Service (DIP: Injected abstract contract)
  final IAudioLevelService _audioLevelService;
  StreamSubscription<AudioLevelSample>? _audioLevelSubscription;

  // Device Stability & Motion Tracking Service (DIP: Injected abstract contract)
  final IDeviceStabilityService _stabilityService;
  final Rx<DeviceStabilityMetrics> deviceStabilityMetrics =
      DeviceStabilityMetrics.initial().obs;
  final RxBool isDeviceStabilityEnabled =
      AppConstants.enableDeviceStabilityCheck.obs;
  StreamSubscription<DeviceStabilityMetrics>? _stabilitySubscription;
  // Physical Device Impact Vibration Guard Service (DIP: Injected abstract contract)
  final IDeviceVibrationService _vibrationService;
  final RxDouble liveVibrationMagnitude = 0.0.obs;
  final RxBool isVibrationGateEnabled = true.obs;
  final RxDouble minVibrationThreshold =
      AppConstants.defaultImpactVibrationThreshold.obs;
  StreamSubscription<double>? _vibrationSubscription;
  StreamSubscription<VibrationRawSample>? _vibrationRawSubscription;

  // Vibration Gate Strategy (SOLID: Open/Closed & Dependency Inversion)
  IVibrationGate _vibrationGate;
  IVibrationGate get vibrationGate => _vibrationGate;
  final Rx<VibrationGateType> vibrationGateType =
      AppConstants.vibrationGateType.obs;

  void setVibrationGateType(VibrationGateType type) {
    vibrationGateType.value = type;
    AppConstants.vibrationGateType = type;
    _vibrationGate.reset();
    _vibrationGate = VibrationGateFactory.create(type: type);
    _recordConfigChange('vibration_gate_type');
  }

  // Camera Distance Gate Unknown Tolerance (Side-Profile & Hooks)
  final RxBool cameraDistanceUnknownIsValid =
      AppConstants.cameraDistanceUnknownIsValid.obs;

  void toggleCameraDistanceUnknownIsValid(bool value) {
    cameraDistanceUnknownIsValid.value = value;
    AppConstants.cameraDistanceUnknownIsValid = value;
    _recordConfigChange('camera_distance_unknown_is_valid');
  }

  // Body-Motion Gate (SOLID: depends on IBodyMotionGate only).
  // Rejects a "punch" when audio + knock + person all pass but the user's
  // upper body did not move (standing still while someone else makes noise and
  // bumps the mount). See LandmarkMotionGate for how movement is measured.
  final IBodyMotionGate _bodyMotionGate;
  final PoseMotionFrameMapper _motionFrameMapper;

  /// Settings switch: true = impacts without body movement are rejected.
  /// false = the motion score is still measured and LOGGED for every impact.
  final RxBool isBodyMotionGateEnabled = AppConstants.bodyMotionGateEnabled.obs;

  /// Minimum motion score the gate uses (fraction of body width). This is the
  /// value that decides; presets and the slider both write it.
  final RxDouble bodyMotionMinScore = AppConstants.bodyMotionMinScoreValue.obs;

  /// Preset matching [bodyMotionMinScore] (custom when the slider value
  /// matches none). Only highlights the chip and labels the log.
  final Rx<BodyMotionLevel> bodyMotionLevel = AppConstants.bodyMotionLevel.obs;

  void toggleBodyMotionGate(bool enable) {
    isBodyMotionGateEnabled.value = enable;
    AppConstants.bodyMotionGateEnabled = enable;
    _recordConfigChange('body_motion_gate=$enable');
  }

  /// Preset chip tapped: jump the minimum score to that preset's value.
  /// [BodyMotionLevel.custom] keeps the current slider value.
  void setBodyMotionLevel(BodyMotionLevel level) {
    if (level != BodyMotionLevel.custom) {
      bodyMotionMinScore.value = AppConstants.bodyMotionMinScore(level);
      AppConstants.bodyMotionMinScoreValue = bodyMotionMinScore.value;
    }
    bodyMotionLevel.value = level;
    AppConstants.bodyMotionLevel = level;
    _recordConfigChange('body_motion_level=${level.name}');
  }

  /// Sensitivity slider moved: any value in the slider range (snapped to its
  /// step). Lower = more sensitive (less movement needed). The highlighted
  /// preset follows the value, or becomes custom.
  void setBodyMotionMinScore(double score) {
    final double step = AppConstants.bodyMotionSliderStep;
    final double snapped = ((score / step).round() * step).clamp(
      AppConstants.bodyMotionSliderMin,
      AppConstants.bodyMotionSliderMax,
    );
    bodyMotionMinScore.value = snapped;
    AppConstants.bodyMotionMinScoreValue = snapped;
    final BodyMotionLevel level = AppConstants.bodyMotionLevelFor(snapped);
    bodyMotionLevel.value = level;
    AppConstants.bodyMotionLevel = level;
    _recordConfigChange('body_motion_min_score=${snapped.toStringAsFixed(3)}');
  }

  /// The motion check is applied when the switch is on AND the camera takes
  /// part in the decision (fusion mode, vision confirmation on, camera
  /// working). Audio-only, audio + vibration, camera-only and "camera off"
  /// sessions are never affected.
  bool get _isBodyMotionRequired =>
      isBodyMotionGateEnabled.value && _usesImpactWindow && _isCameraGateRequired;

  /// Returns true if physical vibration is disabled due to mount type (pole),
  /// manual toggle switch OFF, or non-vibration detection mode.
  bool get isVibrationEffectivelyDisabled =>
      mountType.value.isVibrationDisabled ||
      !isVibrationGateEnabled.value ||
      !sessionMode.value.requiresVibration;

  final TemporalPunchDetector _temporalPunchDetector;
  final FastComboFusionSynchronizer _fusionSynchronizer;
  final PoseValidityGate _validityGate;
  final CameraDistanceGate _distanceGate;
  final CameraPersonGate _personGate;
  final ShoulderStabilityTracker _stabilityTracker;
  final AdaptiveAudioBaseline _adaptiveBaseline;

  FreeSessionController({
    IAudioLevelService? audioLevelService,
    IDeviceStabilityService? stabilityService,
    IDeviceVibrationService? vibrationService,
    IVibrationGate? vibrationGate,
    IBodyMotionGate? bodyMotionGate,
    PoseMotionFrameMapper? motionFrameMapper,
    TemporalPunchDetector? temporalPunchDetector,
    FastComboFusionSynchronizer? fusionSynchronizer,
    PoseValidityGate? validityGate,
    CameraDistanceGate? distanceGate,
    CameraPersonGate? personGate,
    ShoulderStabilityTracker? stabilityTracker,
    AdaptiveAudioBaseline? adaptiveBaseline,
    SessionEventRecorder? recorder,
  }) : _recorder = recorder ?? SessionEventRecorder(),
       _audioLevelService =
           audioLevelService ??
           RecordAudioLevelService(
             enableSubBlockPcm: AppConstants.useSubBlockPcmLevels,
           ),
       _stabilityService = stabilityService ?? DeviceStabilityService(),
       _vibrationService = vibrationService ?? DeviceVibrationService(),
       _vibrationGate = vibrationGate ?? VibrationGateFactory.create(),
       _bodyMotionGate = bodyMotionGate ?? LandmarkMotionGate(),
       _motionFrameMapper = motionFrameMapper ?? const PoseMotionFrameMapper(),
       _temporalPunchDetector =
           temporalPunchDetector ?? TemporalPunchDetector(),
       _fusionSynchronizer =
           fusionSynchronizer ??
           FastComboFusionSynchronizer(
             audioWindowMs: 350,
             sameArmRefractoryMs: 210,
             comboArmRefractoryMs: 140,
             minShoulderDriveScore: 35.0,
           ),
       _validityGate = validityGate ?? const PoseValidityGate(),
       _distanceGate = distanceGate ?? CameraDistanceGate.fromConstants(),
       _personGate = personGate ?? CameraPersonGate.fromConstants(),
       _stabilityTracker =
           stabilityTracker ?? ShoulderStabilityTracker(windowFrames: 5),
       _adaptiveBaseline = adaptiveBaseline ?? AdaptiveAudioBaseline();

  FastComboFusionSynchronizer get fusionSynchronizer => _fusionSynchronizer;

  // Selected session mode: strongly-typed DetectionMode enum
  final Rx<DetectionMode> sessionMode = DetectionMode.fusion.obs;
  // Selected mount type: strongly-typed MountType enum
  final Rx<MountType> mountType = MountType.wall.obs;

  final RxBool isCameraInitialized = false.obs;
  final RxBool isCameraUnavailable = false.obs;
  final Rx<Pose?> livePose = Rx<Pose?>(null);
  final Rx<TemporalPunchEvaluationResult?> liveEvaluationResult =
      Rx<TemporalPunchEvaluationResult?>(null);

  final RxInt punchCount = 0.obs;
  final RxInt leftPunchCount = 0.obs;
  final RxInt rightPunchCount = 0.obs;

  void resetPunchCount() {
    _recorder.record('reset', <String, Object?>{
      'previousCount': punchCount.value,
    });
    punchCount.value = 0;
    leftPunchCount.value = 0;
    rightPunchCount.value = 0;
    _vibrationGate.reset();
    // Impacts still waiting from before the reset must not add punches after it.
    _pendingImpacts.clear();
    detectionStatusText.value = 'Count reset to 0';
  }

  final RxInt audioConfidence = 0.obs;
  final RxInt visionConfidence = 0.obs;
  final RxInt fusedConfidence = 0.obs;
  final RxDouble liveDecibelLevel = 0.0.obs;
  final RxDouble liveBaselineDb = 48.0.obs;
  final RxDouble liveSpikeThresholdDb = 10.0.obs;
  final RxList<double> decibelHistory = <double>[].obs;
  final RxList<String> recordedSpikesHistory = <String>[].obs;
  final RxList<PunchTelemetryEvent> telemetryEvents =
      <PunchTelemetryEvent>[].obs;
  final RxString detectionStatusText = 'Initializing…'.obs;

  int _lastCandidateLogMs = 0;
  String? _lastLoggedCandidateArm;

  // ─── Session instrumentation (recording only, never feeds detection) ───────
  final SessionEventRecorder _recorder;
  SessionEventRecorder get recorder => _recorder;

  /// Short CSV table (one row per punch decision and per camera change) that is
  /// exported with the log; easier to read and share than the raw JSONL file.
  final SessionSummaryTable summaryTable = SessionSummaryTable();

  /// Every confirmed punch line of the session, oldest first. Never trimmed, so
  /// the export keeps all punches even when [recordedSpikesHistory] overflows.
  final List<String> confirmedPunchLog = <String>[];

  bool _wasVibeAboveThreshold = false;
  int _lastVibeRiseMs = 0;
  int _lastVibeSampleMs = 0;
  int _lastAudioStreamMs = 0;
  int _lastAudioChunkIndex = 0;
  int _lastAudioChunkArrivalMs = 0;
  int _lastAudioValueChangeMs = 0;
  double _lastAudioStreamDb = -1.0;
  int _lastCameraTrackMs = 0;
  int _lastCameraFrameMs = 0;
  int _prevRegisteredPunchMs = 0;

  static const String _punchLogMarker = '🥊 [CONFIRMED PUNCH';

  /// Centralized logging into recordedSpikesHistory.
  /// Entries get an elapsed-time prefix. Confirmed punch lines are never evicted
  /// and are also kept in [confirmedPunchLog].
  void _insertSpikeLog(
    String logEntry, {
    bool isConfirmedPunch = false,
    int? atEpochMs,
  }) {
    final String stamped = _recorder.isBegun
        ? '[${SessionEventRecorder.formatElapsed(_recorder.elapsedForEpoch(atEpochMs ?? DateTime.now().millisecondsSinceEpoch))}] $logEntry'
        : logEntry;
    recordedSpikesHistory.insert(0, stamped);
    if (stamped.contains(_punchLogMarker)) {
      confirmedPunchLog.add(stamped);
    }
    const int maxCapacity = 500;
    while (recordedSpikesHistory.length > maxCapacity) {
      final int oldestNonPunchIdx = recordedSpikesHistory.lastIndexWhere(
        (entry) => !entry.contains(_punchLogMarker),
      );
      if (oldestNonPunchIdx == -1) {
        // Only punch lines left: let the list grow rather than drop a punch.
        break;
      }
      recordedSpikesHistory.removeAt(oldestNonPunchIdx);
    }
  }

  Map<String, Object?> _configSnapshot() => <String, Object?>{
    'mode': sessionMode.value.name,
    'mount': mountType.value.name,
    'targetDb': customTargetAudioDb.value,
    'spikeDb': minAudioPunchSpikeDb.value,
    'calibratedDb': staticCalibratedAudioDb.value,
    'baselineDb': liveBaselineDb.value,
    'vibeThreshold': minVibrationThreshold.value,
    'vibeGate': isVibrationGateEnabled.value,
    'visionRequired': isVisionConfirmationRequired.value,
    'cameraMaxDistanceM': maxCameraDistanceM.value,
    'cameraDistanceUnknownIsValid': cameraDistanceUnknownIsValid.value,
    'vibeGateType': vibrationGateType.value.name,
    'bodyMotionGate': isBodyMotionGateEnabled.value,
    'bodyMotionLevel': bodyMotionLevel.value.name,
    'bodyMotionMinScore': bodyMotionMinScore.value,
    'extraFaceRestrictions': AppConstants.enableExtraFaceRestrictions,
    'audioIntervalMs': audioSampleIntervalMs.value,
    'audioRefractoryMs': AppConstants.audioRefractoryMs,
    'subBlockPcm': AppConstants.useSubBlockPcmLevels,
    'warmupMs': AppConstants.warmUpDurationInMiliSeconds.round(),
  };

  void _recordConfigChange(String reason) {
    _recorder.record('config_change', <String, Object?>{
      'reason': reason,
      ..._configSnapshot(),
    });
  }

  /// Records one vibration stream sample and returns true on the rising edge
  /// (first sample above the threshold after the signal was below it).
  bool _traceVibrationSample(double mag, int nowMs) {
    final bool above = mag >= minVibrationThreshold.value;
    final bool risingEdge = above && !_wasVibeAboveThreshold;
    _wasVibeAboveThreshold = above;
    if (risingEdge) {
      _lastVibeRiseMs = nowMs;
      _recorder.count('vibe.threshold_crossings');
    }
    if (_lastVibeSampleMs > 0) {
      _recorder.stat(
        'interval.vibe_stream_ms',
        (nowMs - _lastVibeSampleMs).toDouble(),
      );
    }
    _lastVibeSampleMs = nowMs;
    if (nowMs - _lastPunchTimestampMs > 500) {
      _recorder.stat('level.vibe_mag_idle', mag);
    }
    _recorder.record('vibe', <String, Object?>{
      'mag': mag,
      'above': above,
      'rise': risingEdge,
    }, atEpochMs: nowMs);
    return risingEdge;
  }

  /// Records one microphone stream sample: raw level plus arrival statistics.
  void _traceAudioSample(AudioLevelSample sample) {
    final double db = sample.db;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (sample.chunkIndex != _lastAudioChunkIndex) {
      // New plugin chunk: the gap between chunk arrivals is the real audio
      // delivery period (about 80 ms with the plugin default buffer).
      if (_lastAudioChunkIndex != 0 && _lastAudioChunkArrivalMs > 0) {
        _recorder.stat(
          'interval.audio_chunk_ms',
          (nowMs - _lastAudioChunkArrivalMs).toDouble(),
        );
      }
      _lastAudioChunkIndex = sample.chunkIndex;
      _lastAudioChunkArrivalMs = nowMs;
    }
    if (_lastAudioStreamMs > 0) {
      _recorder.stat(
        'interval.audio_stream_ms',
        (nowMs - _lastAudioStreamMs).toDouble(),
      );
    }
    _lastAudioStreamMs = nowMs;
    if (db != _lastAudioStreamDb) {
      if (_lastAudioValueChangeMs > 0) {
        _recorder.stat(
          'interval.audio_value_change_ms',
          (nowMs - _lastAudioValueChangeMs).toDouble(),
        );
      }
      _lastAudioValueChangeMs = nowMs;
      _lastAudioStreamDb = db;
    }
    _recorder.count('audio.frames');
    if (sample.clipped || db >= AppConstants.maxSystemAudioDb - 0.5) {
      _recorder.count('audio.saturated_frames');
    }
    if (nowMs - _lastPunchTimestampMs > 500) {
      _recorder.stat('level.audio_db_idle', db);
    }
    _recorder.record('audio', <String, Object?>{
      'db': db,
      'chunk': sample.chunkIndex,
      'clipped': sample.clipped,
      'lagMs': nowMs - sample.timestampMs,
    }, atEpochMs: sample.timestampMs);
  }

  /// Accumulates how long the camera could not see the user.
  void _trackCameraAvailability(int nowMs) {
    if (!sessionMode.value.requiresCamera) return;
    if (_lastCameraTrackMs > 0 && nowMs - _lastCameraTrackMs <= 250) {
      final int dt = nowMs - _lastCameraTrackMs;
      _recorder.count('time.camera_tracked_ms', dt);
      final TemporalPunchEvaluationResult? eval = liveEvaluationResult.value;
      final bool available =
          !isCameraUnavailable.value &&
          isCameraInitialized.value &&
          eval != null &&
          eval.confidenceScore > 0.0 &&
          !eval.debugTelemetry.contains('Pose Invalid');
      if (!available) _recorder.count('time.camera_unavailable_ms', dt);
    }
    _lastCameraTrackMs = nowMs;
  }

  /// Text block with session totals for the exported log.
  String buildSessionTotalsText(int durationSec) {
    final int tracked = _recorder.totals.counter('time.camera_tracked_ms');
    final int unavailable = _recorder.totals.counter(
      'time.camera_unavailable_ms',
    );
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      '  Duration (s)                                        : $durationSec',
    );
    buffer.writeln(
      '  Punches registered                                  : ${punchCount.value}',
    );
    if (tracked > 0) {
      buffer.writeln(
        '  Camera unavailable (% of tracked time)              : ${(unavailable * 100 / tracked).toStringAsFixed(1)}',
      );
    }
    buffer.write(_recorder.totals.toText());
    return buffer.toString();
  }

  /// Records strongly-typed telemetry event and syncs with UI spike log & developer console.
  void _recordTelemetryEvent(PunchTelemetryEvent event) {
    telemetryEvents.insert(0, event);
    if (telemetryEvents.length > 200) {
      telemetryEvents.removeLast();
    }
    _insertSpikeLog(
      event.toLogString(isPoleMount: mountType.value.isVibrationDisabled),
      isConfirmedPunch: event.isValidPunch,
      atEpochMs: event.timestampMs,
    );
    developer.log(
      '[PUNCH TELEMETRY] ${event.isValidPunch ? '🟢 VALID' : (event.isCandidate ? '🟡 CANDIDATE' : '🔴 REJECTED')} '
      '${event.decisionCode} (${event.reasonLabel}) | Audio: ${event.peakAudioDb.toStringAsFixed(1)} dB (Rise: +${event.audioRiseDb.toStringAsFixed(1)} dB, Target: ${event.targetAudioDb.round()} dB) | '
      'Vibe: ${event.vibrationPeakMag.toStringAsFixed(2)} m/s² (Thresh: ${event.vibrationThreshold.toStringAsFixed(2)} m/s²) | '
      'Cam: ${event.cameraConfidence}% (${event.cameraArm}, Confirmed: ${event.isCameraConfirmed})',
      name: 'FreeSessionController',
    );
  }

  final RxDouble peakAudioDbRecorded = 0.0.obs;
  final RxDouble minAudioDbRecorded = 0.0.obs;
  final List<double> _frameLatencyMsList = [];
  int _candidateActivationCount = 0;

  /// Settings view & audio tune modal detection suppression state.
  /// Counter of currently active settings sheets / dialogs.
  int _openSettingsViewsCount = 0;

  /// Timestamp in milliseconds until which punch detection is suppressed
  /// following the closure of a settings sheet or tune dialog.
  int _settingsCooldownUntilMs = 0;

  /// True if settings sheet or tune dialog is currently open OR in post-close cooldown period.
  bool get isSettingsViewActive =>
      _openSettingsViewsCount > 0 ||
      DateTime.now().millisecondsSinceEpoch < _settingsCooldownUntilMs;

  int get openSettingsViewsCount => _openSettingsViewsCount;
  int get settingsCooldownUntilMs => _settingsCooldownUntilMs;

  void notifySettingsViewOpened() {
    _openSettingsViewsCount++;
    _recorder.record('settings', <String, Object?>{
      'open': true,
      'count': _openSettingsViewsCount,
    });
    developer.log(
      'Settings view opened (active count: $_openSettingsViewsCount). Punch detection paused.',
      name: 'FreeSessionController',
    );
  }

  void notifySettingsViewClosed() {
    if (_openSettingsViewsCount > 0) {
      _openSettingsViewsCount--;
      _recorder.record('settings', <String, Object?>{
        'open': false,
        'count': _openSettingsViewsCount,
      });
      if (_openSettingsViewsCount == 0) {
        _settingsCooldownUntilMs =
            DateTime.now().millisecondsSinceEpoch +
            AppConstants.postSettingsCooldownMs;
        developer.log(
          'Settings view closed. Post-settings cooldown active until $_settingsCooldownUntilMs (${AppConstants.postSettingsCooldownMs}ms).',
          name: 'FreeSessionController',
        );
      }
    }
  }

  void resetSettingsGate() {
    _openSettingsViewsCount = 0;
    _settingsCooldownUntilMs = 0;
  }

  // Dynamic Audio & Video Punch Settings (Tunable live during session)
  final RxDouble staticCalibratedAudioDb =
      0.0.obs; // Static base audio dB captured during precheck calibration
  final RxDouble minPunchAudioDb = AppConstants
      .minAudioSafetyFloorDb
      .obs; // Absolute safety floor dB from AppConstants
  final RxDouble minAudioPunchSpikeDb = AppConstants
      .defaultAudioSpikeThresholdDb
      .obs; // Spike threshold: dB jump above calibrated baseline (default 6 dB)
  final RxDouble customTargetAudioDb =
      AppConstants.minAudioSafetyFloorDb.obs; // Direct audio punch target dB
  final RxInt audioSampleIntervalMs = AppConstants
      .globalAudioSampleIntervalMs
      .obs; // Native microphone sampling interval in ms
  static const List<int> audioIntervalOptions = [
    3,
    5,
    10,
    15,
    20,
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
  ];

  void setAudioSampleInterval(int ms) {
    AppConstants.globalAudioSampleIntervalMs = ms;
    audioSampleIntervalMs.value = ms;
    _audioLevelService.updateSampleInterval(ms);
  }

  /// Whether camera vision confirmation is strictly required in Fusion mode
  /// true = Strict (Punch only counts if camera confirms), false = Optional (Audio+Vibe dual counts)
  final RxBool isVisionConfirmationRequired = true.obs;
  /// Default "Max Camera Distance" (approx. metres) from AppConstants.cameraMinShoulderWidthRatio.
  static const double defaultMaxCameraDistanceM =
      AppConstants.cameraDistanceMetresFactor /
      AppConstants.cameraMinShoulderWidthRatio;

  /// Farthest distance (approx. metres) at which the camera still counts the
  /// user as near. Lower = user must stand closer.
  final RxDouble maxCameraDistanceM = defaultMaxCameraDistanceM.obs;

  double get _cameraMinShoulderRatio =>
      AppConstants.cameraDistanceMetresFactor / maxCameraDistanceM.value;

  /// Eye minimum scaled with the shoulder minimum (keeps the constants' ratio).
  double get _cameraMinEyeRatio =>
      _cameraMinShoulderRatio *
      (AppConstants.cameraMinEyeSpanRatio /
          AppConstants.cameraMinShoulderWidthRatio);

  void updateMaxCameraDistance(double metres) {
    maxCameraDistanceM.value = metres;
    _consecutiveNearFrames = 0;
    _nearLatch.reset();
    _recordConfigChange('camera_max_distance');
  }

  final RxDouble minPunchVisionConfidence = 80.0
      .obs; // Minimum vision confidence % for punch (Default: Loud/Heavy 80%)
  final RxDouble visionScoreThreshold =
      50.0.obs; // Arm movement pose score threshold (default 50)
  final RxBool isArmExtensionEnabled =
      false.obs; // Arm Extension Ratio Signal Toggle
  final RxDouble minShoulderMovementThreshold =
      0.035.obs; // Minimum Shoulder Displacement Threshold (SW)

  void toggleArmExtension(bool enabled) {
    isArmExtensionEnabled.value = enabled;
    _updateDetectorConfig();
  }

  void updateShoulderMovementThreshold(double value) {
    minShoulderMovementThreshold.value = value;
    _updateDetectorConfig();
  }

  void _updateDetectorConfig() {
    final bool extEnabled = isArmExtensionEnabled.value;
    final config = PunchDetectionConfig(
      weightArmExtension: extEnabled ? 8.0 : 0.0,
      weightShoulderMovement: extEnabled ? 57.0 : 65.0,
      minShoulderMovementThreshold: minShoulderMovementThreshold.value,
    );
    _temporalPunchDetector.updateConfig(config);
  }

  bool _isProcessingFrame = false;
  CameraDescription? _activeCamera;

  double _prevFrameDb = 48.0; // Decibel level of previous 100ms frame
  int _lastAudioPunchTimestampMs = 0;
  double _lastPendingAudioSpikeDb = 0.0;
  int _lastVisionPunchTimestampMs = 0;
  bool _isVibrationArmed = true;

  int _sessionStartTimeMs = 0;
  int _lastPunchTimestampMs = 0;

  // Real-time Visual Highlight Pulse States for Session Cards
  final RxBool isAudioHitActive = false.obs;
  final RxBool isVisionHitActive = false.obs;
  Timer? _audioHitTimer;
  Timer? _visionHitTimer;

  void triggerAudioHit() {
    isAudioHitActive.value = true;
    _audioHitTimer?.cancel();
    _audioHitTimer = Timer(const Duration(milliseconds: 450), () {
      isAudioHitActive.value = false;
    });
  }

  void triggerVisionHit() {
    isVisionHitActive.value = true;
    _visionHitTimer?.cancel();
    _visionHitTimer = Timer(const Duration(milliseconds: 450), () {
      isVisionHitActive.value = false;
    });
  }

  void _triggerPunchHaptic() {
    if (AppConstants.enableHapticVibrationOnPunch) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Image dimensions captured from the first camera frame (default: 480x640 standard portrait).
  Size _cameraImageSize = const Size(480, 640);

  /// Close-enough frames in a row (see AppConstants.cameraMinConsecutiveNearFrames).
  int _consecutiveNearFrames = 0;

  /// Keeps a near user counted as near during a hook / side stance.
  final CameraNearLatch _nearLatch = CameraNearLatch();

  Timer? _elapsedTimer;
  final RxInt elapsedSeconds = 0.obs;

  String get formattedElapsedTime {
    final int minutes = elapsedSeconds.value ~/ 60;
    final int seconds = elapsedSeconds.value % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds.value++;
    });
  }

  @override
  void onInit() {
    super.onInit();
    // Every new / replayed session starts on default settings. The one
    // exception is the device stability switch: it is chosen on the pre-check
    // screen right before this session, so that choice is kept. (onClose
    // resets it, so it cannot leak from an older session.)
    final bool stabilityFromPreCheck = AppConstants.enableDeviceStabilityCheck;
    AppConstants.changeSettingToDefault();
    AppConstants.enableDeviceStabilityCheck = stabilityFromPreCheck;
    _applyDefaultDetectionSettings();
    _sessionStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    _startElapsedTimer();
    _readRouteArguments();
    _updateDetectorConfig();
    _recorder.begin(
      startEpochMs: _sessionStartTimeMs,
      config: _configSnapshot(),
    );
    _initPoseDetector();
    initCamera();
    _startMicrophoneStream();
    _startDeviceStabilityMonitor();
    _startDeviceVibrationMonitor();
  }

  void _startDeviceStabilityMonitor() {
    _stabilitySubscription?.cancel();
    _stabilityService.startMonitoring();
    _stabilitySubscription = _stabilityService.metricsStream.listen((metrics) {
      deviceStabilityMetrics.value = metrics;
    });
  }

  void _startDeviceVibrationMonitor() {
    if (isVibrationEffectivelyDisabled) return;
    _vibrationSubscription?.cancel();
    _vibrationService.startMonitoring(
      minVibrationThreshold: minVibrationThreshold.value,
    );
    _vibrationSubscription = _vibrationService.vibrationMagnitudeStream.listen(
      _handleVibrationSample,
    );
    _vibrationRawSubscription?.cancel();
    _vibrationRawSubscription = _vibrationService.rawSampleStream.listen(
      _traceVibrationRawSample,
    );
  }

  /// Records every accelerometer reading at the time the sensor measured it
  /// (the `vibe` events are throttled and stamped on arrival).
  void _traceVibrationRawSample(VibrationRawSample sample) {
    _vibrationGate.addRawSample(
      sensorMs: sample.sensorMs,
      rawMag: sample.rawMag,
      rawX: sample.x,
      rawY: sample.y,
      rawZ: sample.z,
    );
    _recorder.stat(
      'lag.vibe_sensor_to_dart_ms',
      (sample.arrivalMs - sample.sensorMs).toDouble(),
    );
    _recorder.record('vibe_raw', <String, Object?>{
      'raw': sample.rawMag,
      'eff': sample.effectiveMag,
      'env': sample.envelope,
      'x': sample.x,
      'y': sample.y,
      'z': sample.z,
      'lagMs': sample.arrivalMs - sample.sensorMs,
    }, atEpochMs: sample.sensorMs);
  }

  /// Handles one vibration stream sample. Every sample is kept in a short
  /// history so an impact window can look at vibration by timestamp (before and
  /// after the audio spike), which removes the audio-first / vibration-first race.
  /// [atEpochMs] lets tests supply the sample time.
  void _handleVibrationSample(double mag, {int? atEpochMs}) {
    liveVibrationMagnitude.value = mag;

    final int nowMs = atEpochMs ?? DateTime.now().millisecondsSinceEpoch;
    _noteEventClock(nowMs);
    _appendVibrationHistory(nowMs, mag);
    _vibrationGate.addEnvelopeSample(arrivalMs: nowMs, magnitude: mag);
    final bool vibeRisingEdge = _traceVibrationSample(mag, nowMs);
    // Audio + vibration (+ camera) modes: a pending impact may now be complete.
    if (_usesImpactWindow) _evaluatePendingImpact();
    final int vibrationRefractoryMs =
        sessionMode.value == DetectionMode.vibration ? 110 : 110;

    // Re-arm vibration detector after refractory window HAS PASSED
    if (nowMs - _lastPunchTimestampMs >= vibrationRefractoryMs) {
      _isVibrationArmed = true;
    }

    if (mag >= minVibrationThreshold.value &&
        _isVibrationArmed &&
        nowMs - _lastPunchTimestampMs >= vibrationRefractoryMs) {
      _isVibrationArmed = false; // Lock out until physical shockwave dies down

      if (isSettingsViewActive) {
        final String vibeRejectLog =
            '🔴 [REJECTED] VIBRATION_IMPACT (Declined: Settings open or client using mobile) | '
            'Vibe: ${mag.toStringAsFixed(2)} m/s² (Thresh: ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²) | '
            'Audio: ${liveDecibelLevel.value.toStringAsFixed(1)} dB (Base: ${liveBaselineDb.value.toStringAsFixed(1)} dB)';
        if (vibeRisingEdge) _insertSpikeLog(vibeRejectLog, atEpochMs: nowMs);
        detectionStatusText.value =
            'Impact Rejected (Settings open or client using mobile)';
        return;
      }

      final String vibeLog =
          '🟡 [CANDIDATE] VIBRATION_IMPACT | '
          'Vibe: ${mag.toStringAsFixed(2)} m/s² (Thresh: ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²) | '
          'Audio: ${liveDecibelLevel.value.toStringAsFixed(1)} dB (Base: ${liveBaselineDb.value.toStringAsFixed(1)} dB)';

      // Only the first sample of each vibration burst is logged as text; the raw
      // event file keeps every sample.
      if (vibeRisingEdge) _insertSpikeLog(vibeLog, atEpochMs: nowMs);

      // VIBRATION ONLY MODE: Increments punch count on vibration impact alone!
      if (sessionMode.value == DetectionMode.vibration) {
        _registerPunch(
          nowMs,
          '★ PUNCH CONFIRMED! (${mag.toStringAsFixed(2)} m/s² — Vibration Only)',
          telemetryLog:
              'Mode: VIBRATION_ONLY | Vibe: ${mag.toStringAsFixed(2)} m/s² (Thresh: ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²) | Audio: ${liveDecibelLevel.value.toStringAsFixed(1)} dB',
        );
        _triggerPunchHaptic();
      }
    }
  }

  void toggleVibrationGate(bool enable) {
    isVibrationGateEnabled.value = enable;
    _recordConfigChange('vibration_gate=$enable');
    if (enable) {
      _startDeviceVibrationMonitor();
    } else {
      _vibrationSubscription?.cancel();
      _vibrationRawSubscription?.cancel();
      _vibrationRawSubscription = null;
      _vibrationService.stopMonitoring();
      liveVibrationMagnitude.value = 0.0;
    }
  }

  void updateVibrationThreshold(double value) {
    minVibrationThreshold.value = value;
    _recordConfigChange('vibration_threshold');
    if (isVibrationGateEnabled.value) {
      _vibrationService.startMonitoring(minVibrationThreshold: value);
    }
  }

  /// Applies a unified environment preset, updating spike threshold, target punch dB, and physical vibration threshold.
  void applyEnvironmentPreset({required double spikeDb, double? vibrationMag}) {
    minAudioPunchSpikeDb.value = spikeDb;
    _adaptiveBaseline.spikeThresholdDb = spikeDb;
    final double newTarget = (staticCalibratedAudioDb.value + spikeDb).clamp(
      AppConstants.minCalibratedTargetPunchDb,
      AppConstants.maxCalibratedTargetPunchDb,
    );
    customTargetAudioDb.value = newTarget.roundToDouble();
    _adaptiveBaseline.fixedAudioTargetDb = newTarget.roundToDouble();
    _recordConfigChange('environment_preset');

    if (vibrationMag != null) {
      updateVibrationThreshold(
        vibrationMag.clamp(
          AppConstants.minImpactVibrationSlider,
          AppConstants.maxImpactVibrationSlider,
        ),
      );
    }
  }

  /// Effortlessly enable or disable device stability check dynamically during session
  void toggleDeviceStability(bool enable) {
    AppConstants.enableDeviceStabilityCheck = enable;
    isDeviceStabilityEnabled.value = enable;
    if (enable) {
      _startDeviceStabilityMonitor();
    } else {
      _stabilitySubscription?.cancel();
      _stabilityService.stopMonitoring();
      deviceStabilityMetrics.value = DeviceStabilityMetrics(
        linearAccelMag: 0.0,
        angularVelMag: 0.0,
        smoothedLinearAccel: 0.0,
        smoothedAngularVel: 0.0,
        state: DeviceStabilityState.stable,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        statusMessage: 'Device stability check disabled',
      );
    }
  }

  void _readRouteArguments() {
    final SessionArguments sessionArgs = SessionArguments.fromArguments(
      Get.arguments,
    );
    if (sessionArgs.promptMode != null) {
      sessionMode.value = sessionArgs.resolvedDetectionMode;
    }
    if (sessionArgs.mountType != null && sessionArgs.mountType!.isNotEmpty) {
      mountType.value = sessionArgs.resolvedMountType;
    }
    if (mountType.value.isVibrationDisabled) {
      isVibrationGateEnabled.value = false;
      _vibrationSubscription?.cancel();
      _vibrationRawSubscription?.cancel();
      _vibrationRawSubscription = null;
      _vibrationService.stopMonitoring();
      liveVibrationMagnitude.value = 0.0;
    }
    final double calibrated =
        sessionArgs.calibratedDb ?? sessionArgs.maxAudioDb;
    staticCalibratedAudioDb.value = calibrated;

    // Seed the adaptive audio baseline with calibrated environment data
    final double avgAmbient = sessionArgs.avgAmbientDb;
    final double spikeThreshold = sessionArgs.spikeThresholdDb > 0
        ? sessionArgs.spikeThresholdDb
        : AppConstants.defaultAudioSpikeThresholdDb;
    _adaptiveBaseline.seedBaseline(avgAmbient);
    _adaptiveBaseline.spikeThresholdDb = spikeThreshold;
    minAudioPunchSpikeDb.value = spikeThreshold;
    liveBaselineDb.value = avgAmbient;

    // Enforce safety floor from AppConstants
    _adaptiveBaseline.absoluteMinFloorDb = AppConstants.minAudioSafetyFloorDb;
    minPunchAudioDb.value = AppConstants.minAudioSafetyFloorDb;

    // Direct Audio Punch Target initialized as: Calibrated Base Audio + Spike Threshold
    // Strictly capped between minCalibratedTargetPunchDb and maxCalibratedTargetPunchDb
    final double calculatedTarget =
        sessionArgs.targetPunchDb ?? (calibrated + spikeThreshold);
    final double initialTarget = calculatedTarget
        .clamp(
          AppConstants.minCalibratedTargetPunchDb,
          AppConstants.maxCalibratedTargetPunchDb,
        )
        .roundToDouble();

    customTargetAudioDb.value = initialTarget;
    _adaptiveBaseline.fixedAudioTargetDb = initialTarget;
  }

  /// Sets active session detection mode
  void setSessionMode(dynamic mode) {
    final DetectionMode resolved = mode is DetectionMode
        ? mode
        : DetectionMode.fromString(mode.toString());
    sessionMode.value = resolved;
    _recordConfigChange('mode=${resolved.name}');
    final bool isCameraModeNeeded = resolved.requiresCamera;
    if (!isCameraModeNeeded) {
      isCameraUnavailable.value = true;
      isCameraInitialized.value = false;
      _stopAndDisposeCamera();
    }

    if (resolved == DetectionMode.audio) {
      toggleVibrationGate(false);
      detectionStatusText.value = 'Audio Only Mode Active';
      if (_audioLevelSubscription == null) {
        _startMicrophoneStream();
      }
    } else if (resolved == DetectionMode.audioVibration) {
      toggleVibrationGate(true);
      detectionStatusText.value = 'Audio + Vibration Mode Active';
      if (_audioLevelSubscription == null) {
        _startMicrophoneStream();
      }
    } else if (resolved == DetectionMode.vibration) {
      detectionStatusText.value = 'Vibration Only Mode Active';
      toggleVibrationGate(true);
    } else if (resolved == DetectionMode.camera) {
      if (!isCameraInitialized.value && cameraController == null) {
        initCamera();
      } else {
        isCameraUnavailable.value = false;
      }
      detectionStatusText.value = 'Camera Only Mode Active';
    } else {
      if (!isCameraInitialized.value && cameraController == null) {
        initCamera();
      } else {
        isCameraUnavailable.value = false;
      }
      if (_audioLevelSubscription == null) {
        _startMicrophoneStream();
      }
      toggleVibrationGate(true);
      detectionStatusText.value = 'Audio + Vibration + Camera Fusion Active';
    }
  }

  /// Cycles between DetectionModes in order
  void cycleDetectionMode() {
    final nextIndex =
        (sessionMode.value.index + 1) % DetectionMode.values.length;
    setSessionMode(DetectionMode.values[nextIndex]);
  }

  void _initPoseDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  /// Real-time decibel stream listener with frame-to-frame onset detection.
  Future<void> _startMicrophoneStream() async {
    if (_audioLevelSubscription != null) return;

    final bool started = await _audioLevelService.startMonitoring(
      sampleIntervalMs: audioSampleIntervalMs.value,
    );
    if (!started) {
      detectionStatusText.value = 'Microphone permission required';
      return;
    }

    _recorder.record('audio_service', <String, Object?>{
      ..._audioLevelService.diagnostics,
    });

    _audioLevelSubscription = _audioLevelService.sampleStream.listen(
      (AudioLevelSample sample) {
        final double db = sample.db;
        _traceAudioSample(sample);
        liveDecibelLevel.value = db;
        decibelHistory.add(db);
        if (decibelHistory.length > 50) {
          decibelHistory.removeAt(0);
        }
        if (db > peakAudioDbRecorded.value) {
          peakAudioDbRecorded.value = db;
        }
        if (db > 0 &&
            (minAudioDbRecorded.value == 0.0 ||
                db < minAudioDbRecorded.value)) {
          minAudioDbRecorded.value = db;
        }
        audioConfidence.value = _dbToConfidence(db);

        if (sessionMode.value == DetectionMode.audio) {
          fusedConfidence.value = audioConfidence.value;
        } else if (sessionMode.value == DetectionMode.camera) {
          fusedConfidence.value = visionConfidence.value;
        } else {
          fusedConfidence.value =
              ((audioConfidence.value * 0.7) + (visionConfidence.value * 0.3))
                  .round();
        }

        _checkPunchDetection(frameTimestampMs: sample.timestampMs);

        // Update previous frame decibels for instantaneous derivative calculation
        _prevFrameDb = db;
      },
      onError: (Object error) {
        detectionStatusText.value = 'Microphone error — check permissions';
      },
    );
  }

  /// Gap from the previous spike above which a lockout-hidden sound is likely
  /// a separate hit (not the tail of the same one) and gets a summary row.
  static const int _suppressedSummaryMinGapMs = 60;

  /// Logs a sharp sound the post-spike lockout ignored (it never reaches a
  /// decision, so without this line a lost combo punch leaves no trace).
  void _recordSuppressedSpike(SuppressedSpike spike) {
    final int? msSinceLastPunch = _lastPunchTimestampMs > 0
        ? spike.timestampMs - _lastPunchTimestampMs
        : null;
    _recorder.count('audio.spikes_suppressed');
    if (spike.wouldMeetTarget) {
      _recorder.count('audio.spikes_suppressed_target_met');
    }
    _recorder.record('spike_suppressed', <String, Object?>{
      'db': spike.db,
      'frameJump': spike.frameJump,
      'windowRise': spike.windowRise,
      'targetMet': spike.wouldMeetTarget,
      'msSinceLastSpike': spike.msSinceLastSpike,
      'msSinceLastPunch': msSinceLastPunch,
    }, atEpochMs: spike.timestampMs);
    if (spike.msSinceLastSpike >= _suppressedSummaryMinGapMs) {
      summaryTable.addRow(<String, Object?>{
        'time': SessionEventRecorder.formatElapsed(
          _recorder.elapsedForEpoch(spike.timestampMs),
        ),
        'kind': 'SUPPRESSED',
        'code': 'SPIKE_SUPPRESSED_LOCKOUT',
        'valid': false,
        'audio_db': spike.db,
        'frame_jump': spike.frameJump,
        'window_rise': spike.windowRise,
        'detail':
            '${spike.msSinceLastSpike} ms after previous spike'
            '${spike.wouldMeetTarget ? ', above target' : ', below target'}',
      });
    }
  }

  int _dbToConfidence(double db) {
    if (db <= 40.0) return 5;
    if (db <= 55.0) return 15;
    if (db <= 65.0) return 30;
    if (db <= 75.0) return 55;
    if (db <= 85.0) return 80;
    if (db <= 95.0) return 92;
    return 98;
  }

  /// Returns true when current audio frame represents a sudden volume onset
  /// (spike above the adaptive rolling baseline by at least spikeThresholdDb).
  ///
  /// [frameTimestampMs] is the time the audio frame actually happened (from the
  /// timestamped microphone stream). It drives onset timing, the lockout and the
  /// audio-vs-vibration coincidence check. Defaults to "now".
  bool _isAudioTransient({int? frameTimestampMs}) {
    final double db = liveDecibelLevel.value;
    final int nowMs = frameTimestampMs ?? DateTime.now().millisecondsSinceEpoch;

    // Sync parameters with live settings
    _adaptiveBaseline.spikeThresholdDb = minAudioPunchSpikeDb.value;
    _adaptiveBaseline.absoluteMinFloorDb = minPunchAudioDb.value;
    // Short lockout only when each punch needs its own knock (fast combos).
    _adaptiveBaseline.refractoryMs = _effectiveAudioRefractoryMs;
    _adaptiveBaseline.fixedAudioTargetDb = customTargetAudioDb.value > 0
        ? customTargetAudioDb.value
        : null;

    // Process frame using the Strict Impulse Envelope engine (Fast Rise + Fast Decay Verification)
    final CandidateSpike? confirmedSpike = _adaptiveBaseline.processFrame(
      db,
      _prevFrameDb,
      nowMs: nowMs,
    );

    liveBaselineDb.value = _adaptiveBaseline.currentBaseline;
    liveSpikeThresholdDb.value = _adaptiveBaseline.effectiveSpikeThresholdDb;

    final SuppressedSpike? suppressed = _adaptiveBaseline.takeSuppressedSpike();
    if (suppressed != null) _recordSuppressedSpike(suppressed);

    if (confirmedSpike == null) {
      return false;
    }

    final double spikeIntensity = confirmedSpike.spikeHeight;
    final int spikeTimeMs = confirmedSpike.timestampMs;

    final int audioRefractoryMs = _effectiveAudioRefractoryMs;
    final bool isAudioInRefractory =
        (nowMs - _lastAudioPunchTimestampMs < audioRefractoryMs);

    final double effectiveTargetDb = customTargetAudioDb.value > 0
        ? customTargetAudioDb.value
        : (staticCalibratedAudioDb.value + minAudioPunchSpikeDb.value);

    // Audio target check: Must strictly meet both the onset envelope target and effective decibel floor
    final bool isAudioTargetReached =
        confirmedSpike.isTargetMet &&
        confirmedSpike.peakDb >= effectiveTargetDb;

    _recorder.count('audio.spikes_seen');
    if (isAudioTargetReached) {
      _recorder.count('audio.spikes_target_met');
      if (isAudioInRefractory) _recorder.count('audio.refractory_blocks');
    }

    // Audio + vibration (+ camera) modes: one impact window gathers all three
    // sensors and decides once. See _handleSpikeForImpactWindow.
    if (_usesImpactWindow) {
      final bool comboRelaxed =
          !isAudioTargetReached &&
          _isComboSoftPunch(
            spikeTimeMs: spikeTimeMs,
            peakDb: confirmedSpike.peakDb,
            targetDb: effectiveTargetDb,
          );
      _handleSpikeForImpactWindow(
        spike: confirmedSpike,
        isAudioInRefractory: isAudioInRefractory,
        isAudioTargetReached: isAudioTargetReached || comboRelaxed,
        effectiveTargetDb: effectiveTargetDb,
        comboRelaxed: comboRelaxed,
      );
      return false;
    }

    if (!isAudioTargetReached) {
      // A sound that is not counted must not lock out the next real punch.
      _adaptiveBaseline.releaseRefractory();
    }

    if (!isAudioInRefractory && isAudioTargetReached) {
      _lastAudioPunchTimestampMs = spikeTimeMs;
      _lastPendingAudioSpikeDb = confirmedSpike.peakDb;
    } else {
      _lastPendingAudioSpikeDb = 0.0;
    }

    final evalResult = liveEvaluationResult.value;
    final bool isCamInit =
        !isCameraUnavailable.value && isCameraInitialized.value;
    final bool isBodyVisibleInFrame =
        isCamInit &&
        evalResult != null &&
        evalResult.confidenceScore > 0.0 &&
        !evalResult.debugTelemetry.contains('Pose Invalid');

    final bool isCamAvailable = isCamInit && isBodyVisibleInFrame;
    final bool hasRecentCameraPunch =
        (nowMs - _lastVisionPunchTimestampMs) <= 900;
    final bool isCamConfirmed =
        isCamAvailable &&
        (hasRecentCameraPunch ||
            evalResult.isPunchConfirmed ||
            (!AppConstants.enableExtraFaceRestrictions &&
                isBodyVisibleInFrame));
    final bool isCamRejected = isCamAvailable && !isCamConfirmed;

    // Use windowed physical vibration confirmation so microsecond decay does not drop hits.
    // Clean Impact Coincidence: Vibration peak must be temporally coincident with audio spike onset (<= 120ms).
    // Lingering mechanical sway / old peaks from past punches (> 120ms) are strictly ignored.
    final int peakVibeTime = _vibrationService.recentPeakTimestampMs;
    final bool isVibeCoincident =
        peakVibeTime > 0 && (spikeTimeMs - peakVibeTime).abs() <= 120;
    final double peakVibeInWindow = isVibeCoincident
        ? _vibrationService.recentPeakVibrationMagnitude
        : 0.0;
    final double effectiveVibeMag = max(
      peakVibeInWindow,
      liveVibrationMagnitude.value,
    );

    final String audioDetail =
        'Audio: ${confirmedSpike.peakDb.toStringAsFixed(1)} dB '
        '(Base: ${confirmedSpike.baselineDb.toStringAsFixed(1)} dB, '
        'Rise: +${spikeIntensity.toStringAsFixed(1)} dB, '
        'Target: ${effectiveTargetDb.round()} dB)';

    // Determine definitive classification based on active DetectionMode
    bool isValidPunch = false;
    bool isCandidate = false;
    bool isRejected = false;
    String decisionCode = 'UNKNOWN';
    String reasonLabel = '';

    if (isSettingsViewActive) {
      isValidPunch = false;
      isCandidate = false;
      isRejected = true;
      decisionCode = 'SETTINGS_OPEN_GATE';
      reasonLabel = 'Declined: Settings open or client using mobile';
    } else if (!isAudioTargetReached) {
      // Sub-target strike: volume is below the target threshold.
      // Must NEVER count as a valid punch under ANY mode until settings are tuned or target is reached!
      isValidPunch = false;
      isCandidate = true;
      isRejected = true;
      decisionCode = 'AUDIO_BELOW_TARGET';
      reasonLabel =
          'Spike (${confirmedSpike.peakDb.round()} dB) below target (${effectiveTargetDb.round()} dB)';
    } else if (sessionMode.value == DetectionMode.audio) {
      if (isAudioInRefractory) {
        isRejected = true;
        decisionCode = 'AUDIO_REFRACTORY';
        reasonLabel = 'Cooldown refractory period';
      } else {
        isValidPunch = true;
        decisionCode = 'AUDIO_ONLY';
        reasonLabel = 'Audio spike exceeded target';
      }
    } else {
      // Camera only or other
      if (isAudioInRefractory) {
        isRejected = true;
        decisionCode = 'CAM_REFRACTORY';
        reasonLabel = 'Cooldown refractory period';
      } else if (isCamConfirmed) {
        isValidPunch = true;
        decisionCode = 'CAMERA_ONLY';
        reasonLabel = 'Camera gesture confirmed';
      } else {
        isRejected = true;
        decisionCode = 'CAMERA_UNCONFIRMED';
        reasonLabel = 'Camera gesture unconfirmed';
      }
    }

    // Record strongly-typed event for diagnostics, log history, and Auto-Config evaluation
    final telemetryEvent = PunchTelemetryEvent(
      timestampMs: spikeTimeMs,
      peakAudioDb: confirmedSpike.peakDb,
      baselineAudioDb: confirmedSpike.baselineDb,
      audioRiseDb: spikeIntensity,
      targetAudioDb: effectiveTargetDb,
      vibrationPeakMag: effectiveVibeMag,
      vibrationLiveMag: liveVibrationMagnitude.value,
      vibrationThreshold: minVibrationThreshold.value,
      cameraConfidence: evalResult?.confidenceScore.round() ?? 0,
      cameraArm: (evalResult?.confirmedArm ?? 'none').toUpperCase(),
      isCameraConfirmed: isCamConfirmed,
      isCameraAvailable: isCamAvailable,
      isValidPunch: isValidPunch,
      isCandidate: isCandidate,
      isRejected: isRejected,
      decisionCode: decisionCode,
      reasonLabel: reasonLabel,
      sessionMode: sessionMode.value.name,
      mountType: mountType.value.name,
      isVibrationGateEnabled: isVibrationGateEnabled.value,
      isVisionConfirmationRequired: isVisionConfirmationRequired.value,
      refractoryElapsedMs: (spikeTimeMs - _lastPunchTimestampMs).clamp(
        0,
        99999,
      ),
    );
    _recordTelemetryEvent(telemetryEvent);

    // Instrumentation only: raw decision record with sensor arrival lags.
    final int? vibeRiseToSpikeMs = _lastVibeRiseMs > 0
        ? spikeTimeMs - _lastVibeRiseMs
        : null;
    if (isAudioTargetReached &&
        vibeRiseToSpikeMs != null &&
        vibeRiseToSpikeMs.abs() <= 1000) {
      _recorder.stat('lag.audio_minus_vibe_ms', vibeRiseToSpikeMs.toDouble());
    }
    _recorder.count('decision.AUDIO.$decisionCode');
    _recorder.count(
      isValidPunch
          ? 'audio_path.valid'
          : (isCandidate ? 'audio_path.candidate' : 'audio_path.rejected'),
    );
    _recorder.record('decision', <String, Object?>{
      'path': 'AUDIO',
      'code': decisionCode,
      'valid': isValidPunch,
      'candidate': isCandidate,
      'peakDb': confirmedSpike.peakDb,
      'baselineDb': confirmedSpike.baselineDb,
      'liveBaselineDb': liveBaselineDb.value,
      'riseDb': spikeIntensity,
      'frameJump': confirmedSpike.frameJump,
      'windowRise': confirmedSpike.windowRise,
      'onsetRule': confirmedSpike.onsetRule,
      'targetDb': effectiveTargetDb,
      'targetMet': isAudioTargetReached,
      'refractory': isAudioInRefractory,
      'processingLagMs': DateTime.now().millisecondsSinceEpoch - spikeTimeMs,
      'vibeEffectiveMag': effectiveVibeMag,
      'vibeLiveMag': liveVibrationMagnitude.value,
      'vibePeakAgeMs': peakVibeTime > 0 ? spikeTimeMs - peakVibeTime : null,
      'vibeCoincident': isVibeCoincident,
      'vibeRiseToSpikeMs': vibeRiseToSpikeMs,
      'camAvailable': isCamAvailable,
      'camConfirmed': isCamConfirmed,
      'camRejected': isCamRejected,
      'camBodyVisible': isBodyVisibleInFrame,
      'camEvalPunch': evalResult?.isPunchConfirmed ?? false,
      'camRecentPunch': hasRecentCameraPunch,
      'camPunchAgeMs': _lastVisionPunchTimestampMs > 0
          ? nowMs - _lastVisionPunchTimestampMs
          : null,
      'msSinceLastPunch': _lastPunchTimestampMs > 0
          ? spikeTimeMs - _lastPunchTimestampMs
          : null,
    }, atEpochMs: spikeTimeMs);

    // UNCONDITIONAL MASTER GUARD:
    // If the impact volume does not reach the Audio Target (or failed valid punch requirements),
    // it MUST NEVER be registered as a punch under ANY mode (Audio, Audio+Vibration, Fusion, Camera).
    if (!isValidPunch) {
      if (isCandidate) {
        detectionStatusText.value = 'Candidate Impact ($reasonLabel)';
      } else if (isRejected) {
        detectionStatusText.value = 'Impact Rejected ($reasonLabel)';
      }
      return false;
    }

    triggerAudioHit();

    // Audio Only Mode -> Increments punch count on valid audio spike alone!
    if (sessionMode.value == DetectionMode.audio) {
      _registerPunch(
        spikeTimeMs,
        '★ PUNCH CONFIRMED! (${confirmedSpike.peakDb.round()} dB — Audio Only)',
        telemetryLog: 'Mode: AUDIO_ONLY | $audioDetail',
      );
      _triggerPunchHaptic();
      return true;
    }

    if (AppConstants.testingFreeSessionLogs) {
      developer.log(
        '[AUDIO] Impulse Spike CONFIRMED (Fast Drop >=50% within 100ms) — ${confirmedSpike.peakDb.round()} dB (+${spikeIntensity.toStringAsFixed(1)}dB spike over ${confirmedSpike.baselineDb.round()}dB baseline)',
        name: 'FreeSessionController',
      );
    }
    return true;
  }

  // ─── Impact window: audio + vibration + camera decided once ────────────────
  //
  // Used by DetectionMode.fusion and DetectionMode.audioVibration. An audio spike
  // that reached its target opens a short window. Vibration is looked up BY
  // TIMESTAMP in a short history (from `impactVibrationBeforeMs` before the spike
  // to `impactVibrationAfterMs` after it) and the camera state is read when the
  // decision is made, so it no longer matters which sensor reports first.
  // The punch counts only when every gate that is in use confirms it:
  //   audio + vibration + camera, or audio + vibration when the camera is
  //   disabled, or audio + camera when vibration is disabled (pole mount).
  // Decided as soon as all required gates pass, otherwise when the window closes.

  static const ImpactGateEvaluator _impactGates = ImpactGateEvaluator();

  /// Impacts still waiting for vibration / camera, oldest first. With the
  /// short knock lockout a fast combo can have 2-3 open at once; each claims
  /// its own knock (see [_isKnockProtected]).
  final List<_PendingImpact> _pendingImpacts = <_PendingImpact>[];
  int _eventClockMs = 0;
  final List<_VibeSample> _vibeHistory = <_VibeSample>[];
  _CameraObservation? _cameraObservation;

  bool get _usesImpactWindow =>
      sessionMode.value == DetectionMode.fusion ||
      sessionMode.value == DetectionMode.audioVibration;

  /// True when every counted punch is guaranteed its OWN fresh vibration knock:
  /// impact-window mode, vibration in use, and the Fresh Knock gate. Only then
  /// can one physical hit never be counted twice by the knock alone, which is
  /// what makes the short audio lockout and overlapping impacts safe.
  bool get _isKnockProtected =>
      _usesImpactWindow &&
      !isVibrationEffectivelyDisabled &&
      _vibrationGate.type == VibrationGateType.knock;

  /// Hard punch → soft punch combo. A spike below the audio target still opens
  /// an impact when ALL of these hold:
  ///  - knock protection is on (it must still bring its own fresh knock, which
  ///    a voice or the previous punch's tail cannot provide),
  ///  - a punch was confirmed in the last AppConstants.comboSoftPunchWindowMs,
  ///  - it is at most AppConstants.comboSoftPunchAudioRelaxDb below the target
  ///    and not below the audio safety floor.
  /// The camera gate is applied as usual afterwards.
  bool _isComboSoftPunch({
    required int spikeTimeMs,
    required double peakDb,
    required double targetDb,
  }) {
    if (!_isKnockProtected || _lastPunchTimestampMs <= 0) return false;
    final int sinceLastPunchMs = spikeTimeMs - _lastPunchTimestampMs;
    if (sinceLastPunchMs < 0 ||
        sinceLastPunchMs > AppConstants.comboSoftPunchWindowMs) {
      return false;
    }
    final double relaxedTargetDb = max(
      targetDb - AppConstants.comboSoftPunchAudioRelaxDb,
      minPunchAudioDb.value,
    );
    return peakDb >= relaxedTargetDb;
  }

  /// Audio lockout after a counted spike: short with knock protection (fast
  /// combos), the original longer value otherwise (pole mount, vibration off,
  /// Legacy Peak gate), where the lockout is the only double-count guard.
  int get _effectiveAudioRefractoryMs => _isKnockProtected
      ? AppConstants.audioRefractoryKnockMs
      : AppConstants.audioRefractoryMs;

  /// Window after the spike. Without knock protection it is kept below the
  /// lockout so one window always closes before the next spike can open
  /// another. With knock protection windows may overlap (each impact claims a
  /// different knock), so the full wait for late vibration is kept.
  int get _impactAfterMs => _isKnockProtected
      ? AppConstants.impactVibrationAfterMs
      : min(
          AppConstants.impactVibrationAfterMs,
          AppConstants.audioRefractoryMs - 10,
        );

  /// Latest time seen on any sensor (audio frame, vibration sample). In the app
  /// this follows the real clock; it also lets tests drive time deterministically.
  void _noteEventClock(int tMs) {
    if (tMs > _eventClockMs) _eventClockMs = tMs;
  }

  void _appendVibrationHistory(int tMs, double mag) {
    _vibeHistory.add(_VibeSample(tMs, mag));
    final int cutoff = _eventClockMs - 2000;
    while (_vibeHistory.isNotEmpty && _vibeHistory.first.tMs < cutoff) {
      _vibeHistory.removeAt(0);
    }
  }

  /// Largest vibration magnitude seen between [fromMs] and [toMs], when it
  /// arrived, and whether the window holds a new rise above [threshold].
  _VibeWindowInfo _vibrationWindow(int fromMs, int toMs, double threshold) {
    double peak = 0.0;
    int peakAtMs = 0;
    bool rose = false;
    double previous = 0.0;
    for (final _VibeSample sample in _vibeHistory) {
      if (sample.tMs >= fromMs && sample.tMs <= toMs) {
        if (sample.mag > peak) {
          peak = sample.mag;
          peakAtMs = sample.tMs;
        }
        if (sample.mag >= threshold && sample.mag > previous) rose = true;
      }
      previous = sample.mag;
    }
    return _VibeWindowInfo(peak, peakAtMs, rose);
  }

  /// True when the camera takes part in the decision: the mode uses a camera,
  /// vision confirmation is on, and the camera did not fail to start (when it
  /// failed the screen already says "Camera Offline - Audio Only").
  bool get _isCameraGateRequired =>
      sessionMode.value.requiresCamera &&
      isVisionConfirmationRequired.value &&
      !isCameraUnavailable.value;

  /// Latest camera gate result from the live frames (valid / too far / no
  /// person), for the CAM status on the session screen. This is the SAME check
  /// a punch has to pass in fusion mode, so "Confirm" on screen means a punch
  /// right now would pass the camera.
  final Rx<CameraGateState> liveCameraGateState = CameraGateState.notReady.obs;

  /// True when the camera takes part in punch decisions as a person / distance
  /// gate (fusion mode with vision confirmation on). Then the CAM status shows
  /// [liveCameraGateState]. In camera-only mode punches are counted from arm
  /// motion instead, so the screen keeps showing the motion result there.
  bool get isCameraGateShownOnScreen =>
      _usesImpactWindow && _isCameraGateRequired;

  void _noteCameraObservation(
    CameraGateState state, {
    double? ratio,
    String detail = '',
    double? faceConf,
    double? shoulderConf,
    int? atMs,
  }) {
    final int at = atMs ?? DateTime.now().millisecondsSinceEpoch;
    final CameraGateState? previous = _cameraObservation?.state;
    liveCameraGateState.value = state;
    _cameraObservation = _CameraObservation(
      state,
      at,
      ratio,
      detail,
      faceConf,
      shoulderConf,
    );
    if (state != previous) {
      summaryTable.addRow(<String, Object?>{
        'time': SessionEventRecorder.formatElapsed(
          _recorder.elapsedForEpoch(at),
        ),
        'kind': 'CAMERA',
        'code': 'CAMERA_${state.name.toUpperCase()}',
        'camera_state': state.name,
        'face_conf': faceConf,
        'shoulder_conf': shoulderConf,
        'distance_ratio': ratio,
        'detail': detail,
      });
    }
  }

  CameraGateState _cameraGateState() {
    if (!_isCameraGateRequired) return CameraGateState.notRequired;
    if (!isCameraInitialized.value) return CameraGateState.notReady;
    final _CameraObservation? observation = _cameraObservation;
    if (observation == null) return CameraGateState.noPerson;
    if (_eventClockMs - observation.atMs >
        AppConstants.cameraObservationStaleMs) {
      return CameraGateState.noPerson;
    }
    return observation.state;
  }

  void _handleSpikeForImpactWindow({
    required CandidateSpike spike,
    required bool isAudioInRefractory,
    required bool isAudioTargetReached,
    required double effectiveTargetDb,
    bool comboRelaxed = false,
  }) {
    final _PendingImpact impact = _PendingImpact(
      audioTsMs: spike.timestampMs,
      peakDb: spike.peakDb,
      baselineDb: spike.baselineDb,
      riseDb: spike.spikeHeight,
      targetDb: effectiveTargetDb,
      frameJump: spike.frameJump,
      windowRise: spike.windowRise,
      onsetRule: spike.onsetRule,
      comboRelaxed: comboRelaxed,
    );

    String? rejectCode;
    String rejectReason = '';
    bool candidate = false;
    if (isSettingsViewActive) {
      rejectCode = 'SETTINGS_OPEN_GATE';
      rejectReason = 'Declined: Settings open or client using mobile';
    } else if (!isAudioTargetReached) {
      rejectCode = 'AUDIO_BELOW_TARGET';
      candidate = true;
      rejectReason =
          'Spike (${spike.peakDb.round()} dB) below target (${effectiveTargetDb.round()} dB)';
      // A sound that is not counted must not lock out the next real punch.
      _adaptiveBaseline.releaseRefractory();
    } else if (isAudioInRefractory) {
      rejectCode = 'IMPACT_REFRACTORY';
      rejectReason = 'Cooldown refractory period';
    } else if (_pendingImpacts.isNotEmpty && !_isKnockProtected) {
      // Without knock protection two open windows could both match the same
      // vibration peak, so only one impact may wait at a time (old rule).
      rejectCode = 'IMPACT_ALREADY_PENDING';
      rejectReason = 'Another impact is still being decided';
    } else if (_pendingImpacts.length >= AppConstants.maxPendingImpacts) {
      rejectCode = 'IMPACT_ALREADY_PENDING';
      rejectReason = 'Too many impacts are still being decided';
    }

    if (rejectCode != null) {
      _recordImpactDecision(
        impact: impact,
        code: rejectCode,
        reason: rejectReason,
        valid: false,
        candidate: candidate,
      );
      return;
    }

    _pendingImpacts.add(impact);
    _lastPendingAudioSpikeDb = spike.peakDb;
    _recorder.count('impact.opened');
    if (_pendingImpacts.length > 1) _recorder.count('impact.overlapping');
    _evaluatePendingImpact();
  }

  /// Re-checks every open impact against the latest vibration history and
  /// camera state. Called on every vibration sample and audio frame.
  ///
  /// Oldest first: the earlier punch gets first pick of the knocks, so a fast
  /// follow-up punch cannot take the knock that belongs to the punch before it.
  void _evaluatePendingImpact() {
    if (_pendingImpacts.isEmpty) return;
    for (final _PendingImpact impact in List<_PendingImpact>.of(
      _pendingImpacts,
    )) {
      if (!_pendingImpacts.contains(impact)) continue;
      _evaluateOneImpact(impact);
    }
  }

  /// Decides [impact] when all its gates are known (or its window closed);
  /// otherwise leaves it waiting.
  void _evaluateOneImpact(_PendingImpact impact) {
    final bool windowClosed =
        _eventClockMs >= impact.audioTsMs + _impactAfterMs;

    if (isSettingsViewActive) {
      _pendingImpacts.remove(impact);
      _recordImpactDecision(
        impact: impact,
        code: 'SETTINGS_OPEN_GATE',
        reason: 'Declined: Settings open or client using mobile',
        valid: false,
      );
      return;
    }

    final bool vibeRequired = !isVibrationEffectivelyDisabled;
    final int windowStartMs =
        impact.audioTsMs - AppConstants.impactVibrationBeforeMs;
    final int windowEndMs = impact.audioTsMs + _impactAfterMs;

    final VibrationGateEvaluation vibeEval = _vibrationGate.evaluate(
      audioTsMs: impact.audioTsMs,
      fromMs: windowStartMs,
      toMs: windowEndMs,
      threshold: minVibrationThreshold.value,
      windowClosed: windowClosed,
      isVibrationDisabled: !vibeRequired,
    );

    final _VibeWindowInfo legacyVibeWindow = _vibrationWindow(
      windowStartMs,
      windowEndMs,
      minVibrationThreshold.value,
    );
    final _VibeWindowInfo vibeWindow = vibeEval.matchedKnock != null
        ? _VibeWindowInfo(
            vibeEval.matchedKnock!.rawMag > 0
                ? vibeEval.matchedKnock!.rawMag
                : (vibeEval.peakMagnitude > 0
                      ? vibeEval.peakMagnitude
                      : legacyVibeWindow.peak),
            vibeEval.matchedKnock!.timestampMs,
            legacyVibeWindow.rose,
          )
        : legacyVibeWindow;
    final double vibePeak = vibeEval.peakMagnitude > 0.0
        ? vibeEval.peakMagnitude
        : vibeWindow.peak;
    final VibrationGateState vibeState = vibeEval.state;
    final CameraGateState cameraState = _cameraGateState();

    // Measured on every evaluation (even with the gate off, for the log).
    final BodyMotionEvaluation motionEval = _bodyMotionGate.evaluate(
      audioTsMs: impact.audioTsMs,
      minScore: bodyMotionMinScore.value,
      isRequired: _isBodyMotionRequired,
    );

    final ImpactGateResult result = _impactGates.evaluate(
      vibration: vibeState,
      camera: cameraState,
      windowClosed: windowClosed,
      motion: motionEval.state,
      motionUnknownIsValid: AppConstants.bodyMotionUnknownIsValid,
    );
    if (result.isPending) return;

    _pendingImpacts.remove(impact);
    _recordImpactDecision(
      impact: impact,
      code: result.code,
      reason: result.reasonLabel,
      valid: result.isValid,
      vibration: vibeState,
      camera: cameraState,
      vibePeak: vibePeak,
      vibeWindow: vibeWindow,
      vibeDetailOverride: vibeEval.detail,
      vibeJerk: vibeEval.matchedKnock?.deltaMag,
      motion: motionEval,
    );
  }

  /// Logs the final decision of one impact and, when valid, registers the punch.
  void _recordImpactDecision({
    required _PendingImpact impact,
    required String code,
    required String reason,
    required bool valid,
    bool candidate = false,
    VibrationGateState? vibration,
    CameraGateState? camera,
    double vibePeak = 0.0,
    _VibeWindowInfo? vibeWindow,
    String? vibeDetailOverride,
    double? vibeJerk,
    BodyMotionEvaluation? motion,
  }) {
    final TemporalPunchEvaluationResult? evalResult =
        liveEvaluationResult.value;
    final _CameraObservation? observation = _cameraObservation;
    final String cameraDetail = camera == null
        ? ''
        : switch (camera) {
            CameraGateState.notRequired => 'Cam: not used',
            CameraGateState.notReady => 'Cam: not ready',
            CameraGateState.noPerson => 'Cam: no user visible',
            CameraGateState.tooFar =>
              'Cam: too far (${observation?.detail ?? ''})',
            CameraGateState.valid =>
              'Cam: valid user (${observation?.detail ?? ''})',
          };
    // Body motion, e.g. "Motion[ON normal]: Motion 0.124 >= 0.080 (top:
    // leftShoulder, 9 frames, body 182 px)". Shown also when the gate is OFF.
    final String motionDetail = motion == null
        ? ''
        : 'Motion[${isBodyMotionGateEnabled.value ? 'ON' : 'OFF'} '
              '${bodyMotionLevel.value.name}]: ${motion.detail}';
    final String vibeDetail = vibration == null
        ? ''
        : switch (vibration) {
            VibrationGateState.notRequired =>
              'Vibe: not used (${mountType.value.isVibrationDisabled ? "Pole Mount" : "gate off"})',
            VibrationGateState.missing =>
              'Vibe: none in window (${vibeDetailOverride?.isNotEmpty == true ? vibeDetailOverride! : "peak ${vibePeak.toStringAsFixed(2)} < ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²"})',
            VibrationGateState.present =>
              'Vibe: ${vibeDetailOverride?.isNotEmpty == true ? vibeDetailOverride! : "Peak ${vibePeak.toStringAsFixed(2)} m/s² (Thresh: ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²)"}',
          };

    final PunchTelemetryEvent telemetryEvent = PunchTelemetryEvent(
      timestampMs: impact.audioTsMs,
      peakAudioDb: impact.peakDb,
      baselineAudioDb: impact.baselineDb,
      audioRiseDb: impact.riseDb,
      targetAudioDb: impact.targetDb,
      vibrationPeakMag: vibePeak,
      vibrationLiveMag: liveVibrationMagnitude.value,
      vibrationThreshold: minVibrationThreshold.value,
      cameraConfidence: evalResult?.confidenceScore.round() ?? 0,
      cameraArm: (evalResult?.confirmedArm ?? 'none').toUpperCase(),
      isCameraConfirmed: camera == CameraGateState.valid,
      isCameraAvailable:
          camera == CameraGateState.valid || camera == CameraGateState.tooFar,
      isValidPunch: valid,
      isCandidate: candidate,
      isRejected: !valid,
      decisionCode: code,
      reasonLabel: <String>[
        reason,
        if (cameraDetail.isNotEmpty) cameraDetail,
        if (motionDetail.isNotEmpty) motionDetail,
      ].join(' | '),
      sessionMode: sessionMode.value.name,
      mountType: mountType.value.name,
      isVibrationGateEnabled: isVibrationGateEnabled.value,
      isVisionConfirmationRequired: isVisionConfirmationRequired.value,
      refractoryElapsedMs: (impact.audioTsMs - _lastPunchTimestampMs).clamp(
        0,
        99999,
      ),
    );
    _recordTelemetryEvent(telemetryEvent);

    final int decidedAfterMs = _eventClockMs - impact.audioTsMs;
    _recorder.count('decision.IMPACT.$code');
    _recorder.count(
      valid
          ? 'impact.valid'
          : (candidate ? 'impact.candidate' : 'impact.rejected'),
    );
    _recorder.stat('lag.impact_decided_after_ms', decidedAfterMs.toDouble());
    // Where the strongest vibration sat relative to the audio spike
    // (negative = before; vibration time is arrival time).
    final int? vibeOffsetMs = vibeWindow != null && vibeWindow.peakAtMs > 0
        ? vibeWindow.peakAtMs - impact.audioTsMs
        : null;
    if (vibration == VibrationGateState.present && vibeOffsetMs != null) {
      _recorder.stat('lag.vibe_peak_minus_audio_ms', vibeOffsetMs.toDouble());
      if (vibeWindow?.rose == false) {
        _recorder.count('impact.vibe_tail_only');
      }
    }
    // Jerk of the knock that confirmed the punch: use its min / avg across a
    // session to tune AppConstants.knockMinJerk on a real device.
    if (valid && vibeJerk != null) {
      _recorder.stat('level.vibe_jerk_at_punch', vibeJerk);
    }
    if (impact.comboRelaxed) _recorder.count('impact.combo_soft_punch');
    // Body-motion statistics: compare `motion.score_valid_punch` (real punches)
    // with the scores of false impacts to choose the level.
    // `motion.would_reject` counts punches the gate WOULD have rejected while
    // it is OFF: if real punches show up there, the level is too strict.
    if (motion != null) {
      _recorder.count('motion.state.${motion.state.name}');
      if (motion.score != null) {
        _recorder.stat('motion.score_all', motion.score!);
        if (valid) _recorder.stat('motion.score_valid_punch', motion.score!);
      }
      if (valid &&
          motion.state == BodyMotionGateState.notRequired &&
          motion.wouldPass == false) {
        _recorder.count('motion.would_reject');
      }
      if (code == 'IMPACT_REJECTED_NO_BODY_MOTION') {
        _recorder.count('motion.rejected_still');
      }
    }
    _recorder.record('decision', <String, Object?>{
      'path': 'IMPACT',
      'code': code,
      'valid': valid,
      'candidate': candidate,
      'peakDb': impact.peakDb,
      'baselineDb': impact.baselineDb,
      'riseDb': impact.riseDb,
      'frameJump': impact.frameJump,
      'windowRise': impact.windowRise,
      'onsetRule': impact.onsetRule,
      'targetDb': impact.targetDb,
      'vibeState': vibration?.name,
      'vibeWindowPeak': vibePeak,
      'vibePeakAtMs': vibeWindow != null && vibeWindow.peakAtMs > 0
          ? vibeWindow.peakAtMs
          : null,
      'vibePeakOffsetMs': vibeOffsetMs,
      'vibeRoseInWindow': vibeWindow?.rose,
      'vibeJerk': vibeJerk,
      'comboSoftPunch': impact.comboRelaxed,
      'audioLockoutMs': _effectiveAudioRefractoryMs,
      'vibeThreshold': minVibrationThreshold.value,
      'cameraState': camera?.name,
      'cameraRatio': observation?.ratio,
      'cameraDetail': observation?.detail,
      'motionGateOn': isBodyMotionGateEnabled.value,
      'motionLevel': bodyMotionLevel.value.name,
      'motionState': motion?.state.name,
      'motionScore': motion?.score,
      'motionMinScore': motion?.minScore,
      'motionWouldPass': motion?.wouldPass,
      'motionTopPoint': motion?.topPoint?.name,
      'motionPoints': motion?.pointScoresForLog,
      'motionFrames': motion?.framesInWindow,
      'motionBodyWidthPx': motion?.bodyScale,
      'decidedAfterMs': decidedAfterMs,
      'processingLagMs':
          DateTime.now().millisecondsSinceEpoch - impact.audioTsMs,
      'msSinceLastPunch': _lastPunchTimestampMs > 0
          ? impact.audioTsMs - _lastPunchTimestampMs
          : null,
    }, atEpochMs: impact.audioTsMs);

    void addSummaryRow({int? punchNo}) => summaryTable.addRow(<String, Object?>{
      'time': SessionEventRecorder.formatElapsed(
        _recorder.elapsedForEpoch(impact.audioTsMs),
      ),
      'kind': 'IMPACT',
      'code': code,
      'valid': valid,
      'punch_no': punchNo,
      'audio_db': impact.peakDb,
      'target_db': impact.targetDb,
      'vibe_peak': vibration == null ? null : vibePeak,
      'vibe_threshold': minVibrationThreshold.value,
      'vibe_offset_ms': vibeOffsetMs,
      'vibe_rose': vibeWindow?.rose,
      'frame_jump': impact.frameJump,
      'window_rise': impact.windowRise,
      'camera_state': camera?.name,
      'face_conf': camera == null ? null : observation?.faceConf,
      'shoulder_conf': camera == null ? null : observation?.shoulderConf,
      'distance_ratio': camera == null ? null : observation?.ratio,
      'motion_score': motion?.score,
      'motion_state': motion == null
          ? null
          : (motion.state == BodyMotionGateState.notRequired
                ? 'off(${motion.wouldPass == null ? 'unknown' : (motion.wouldPass! ? 'moved' : 'still')})'
                : motion.state.name),
      'motion_top_point': motion?.topPoint?.name,
      'decided_after_ms': decidedAfterMs,
      'detail': reason,
    });

    if (!valid) {
      _vibrationGate.onImpactRejected(audioTsMs: impact.audioTsMs);
      addSummaryRow();
      if (candidate) {
        detectionStatusText.value = 'Candidate Impact ($reason)';
      } else {
        detectionStatusText.value = 'Impact Rejected ($reason)';
      }
      // A rejected impact must not lock out the next real punch. When a newer
      // impact is still open, the lockout now belongs to that newer spike, so
      // it is left alone.
      final bool newerImpactOpen = _pendingImpacts.any(
        (_PendingImpact p) => p.audioTsMs > impact.audioTsMs,
      );
      if (code != 'IMPACT_REFRACTORY' &&
          code != 'IMPACT_ALREADY_PENDING' &&
          !newerImpactOpen) {
        _adaptiveBaseline.releaseRefractory();
      }
      return;
    }

    triggerAudioHit();
    final String activeArm = evalResult?.confirmedArm ?? 'right';
    _registerPunch(
      impact.audioTsMs,
      '★ PUNCH CONFIRMED! ($reason)',
      arm: activeArm,
      telemetryLog:
          'Mode: ${sessionMode.value.name.toUpperCase()} ($reason) | Audio: ${impact.peakDb.toStringAsFixed(1)} dB (Base: ${impact.baselineDb.toStringAsFixed(1)} dB, Rise: +${impact.riseDb.toStringAsFixed(1)} dB, Target: ${impact.targetDb.round()} dB) | $vibeDetail | $cameraDetail${motionDetail.isEmpty ? '' : ' | $motionDetail'}',
    );
    _vibrationGate.onPunchConfirmed(
      audioTsMs: impact.audioTsMs,
      punchNo: punchCount.value,
    );
    addSummaryRow(punchNo: punchCount.value);
    _triggerPunchHaptic();
  }

  /// Test hook: feed a vibration sample with an explicit time.
  void ingestVibrationSampleForTesting(double mag, {required int atEpochMs}) =>
      _handleVibrationSample(mag, atEpochMs: atEpochMs);

  /// Test hook: run the camera checks on a pose as if the camera produced it.
  void analyzePoseForTesting(Pose pose, {int? frameMs}) =>
      _analyzeLivePose(pose, frameMs: frameMs);

  /// Test hook: add a body-motion frame directly (no ML Kit pose needed).
  void addBodyMotionFrameForTesting(BodyMotionFrame frame) =>
      _bodyMotionGate.addFrame(frame);

  static DistanceLandmark? _toDistanceLandmark(PoseLandmark? landmark) =>
      landmark == null
      ? null
      : DistanceLandmark(
          x: landmark.x,
          y: landmark.y,
          likelihood: landmark.likelihood,
        );

  /// Test hook: set what the camera currently sees.
  void setCameraObservationForTesting(
    CameraGateState state, {
    required int atMs,
  }) => _noteCameraObservation(state, atMs: atMs);

  void checkPunchDetectionForTesting({int? frameTimestampMs}) =>
      _checkPunchDetection(frameTimestampMs: frameTimestampMs);

  void insertSpikeLogForTesting(
    String logEntry, {
    bool isConfirmedPunch = false,
    int? atEpochMs,
  }) => _insertSpikeLog(
    logEntry,
    isConfirmedPunch: isConfirmedPunch,
    atEpochMs: atEpochMs,
  );

  void _checkPunchDetection({int? frameTimestampMs}) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    _noteEventClock(frameTimestampMs ?? nowMs);

    // Dynamic Session Start Warmup: ignore audio & vision spikes from screen transition / tap sound
    final int warmupMs = AppConstants.warmUpDurationInMiliSeconds.round();
    if (nowMs - _sessionStartTimeMs < warmupMs) {
      detectionStatusText.value = 'Warming Up Engine…';
      return;
    }

    _trackCameraAvailability(nowMs);

    // Close an open impact window whose time is up before looking at a new spike.
    if (_usesImpactWindow) _evaluatePendingImpact();

    if (isSettingsViewActive) {
      if (sessionMode.value.requiresMicrophone) {
        _isAudioTransient(frameTimestampMs: frameTimestampMs);
      }
      if (!detectionStatusText.value.startsWith('Impact Rejected')) {
        detectionStatusText.value = 'Punch Detection Disabled (Settings Open)';
      }
      return;
    }

    if (sessionMode.value.requiresMicrophone) {
      _isAudioTransient(frameTimestampMs: frameTimestampMs);
    }

    if (sessionMode.value == DetectionMode.audio) {
      detectionStatusText.value =
          'Listening to Audio… (${liveDecibelLevel.value.round()} dB)';
    } else if (sessionMode.value == DetectionMode.audioVibration) {
      detectionStatusText.value =
          'Listening to Audio + Vibration… (${liveDecibelLevel.value.round()} dB)';
    } else if (sessionMode.value == DetectionMode.vibration) {
      detectionStatusText.value =
          'Vibration Sensor Active… (Mag: ${liveVibrationMagnitude.value.toStringAsFixed(2)})';
    } else if (sessionMode.value == DetectionMode.camera) {
      // Camera-only punches are registered strictly in _processPose via TemporalPunchDetector FSM confirmation.
      detectionStatusText.value = 'Tracking Live Body Pose (Camera Only)…';
    } else {
      detectionStatusText.value =
          'Listening & Tracking Fast Combos… (${liveDecibelLevel.value.round()} dB)';
    }
  }

  void showAudioSettingsSheet(BuildContext context) =>
      showSessionSettingsSheet(context);

  /// Opens a live bottom sheet to adjust Audio & Video detection parameters on the fly.
  void showSessionSettingsSheet(BuildContext context) {
    showSessionDetectionSettingsSheet(
      context,
      staticCalibratedAudioDb: staticCalibratedAudioDb,
      customTargetAudioDb: customTargetAudioDb,
      minAudioPunchSpikeDb: minAudioPunchSpikeDb,
      audioSampleIntervalMs: audioSampleIntervalMs,
      audioIntervalOptions: audioIntervalOptions,
      onSetAudioInterval: setAudioSampleInterval,
      minPunchAudioDb: minPunchAudioDb,
      liveBaselineDb: liveBaselineDb,
      liveDecibelLevel: liveDecibelLevel,
      minVibrationThreshold: minVibrationThreshold,
      liveVibrationMagnitude: liveVibrationMagnitude,
      peakAudioDbRecorded: peakAudioDbRecorded,
      onUpdateVibrationThreshold: updateVibrationThreshold,
      isVisionConfirmationRequired: isVisionConfirmationRequired,
      isDeviceStabilityEnabled: isDeviceStabilityEnabled,
      onToggleDeviceStability: toggleDeviceStability,
      maxCameraDistanceM: maxCameraDistanceM,
      defaultMaxCameraDistanceM: defaultMaxCameraDistanceM,
      onMaxCameraDistanceChanged: updateMaxCameraDistance,
      cameraDistanceUnknownIsValid: cameraDistanceUnknownIsValid,
      onToggleCameraDistanceUnknownIsValid: toggleCameraDistanceUnknownIsValid,
      vibrationGateType: vibrationGateType,
      onSetVibrationGateType: setVibrationGateType,
      isBodyMotionGateEnabled: isBodyMotionGateEnabled,
      onToggleBodyMotionGate: toggleBodyMotionGate,
      bodyMotionLevel: bodyMotionLevel,
      onSetBodyMotionLevel: setBodyMotionLevel,
      bodyMotionMinScore: bodyMotionMinScore,
      onSetBodyMotionMinScore: setBodyMotionMinScore,
      onResetToDefaults: resetAllSettingsToDefault,
      onApplyEnvironmentPreset: applyEnvironmentPreset,
      onSpikeDbChanged: (double value) {
        minAudioPunchSpikeDb.value = value;
        _adaptiveBaseline.spikeThresholdDb = value;
        final double minAllowedTarget =
            (AppConstants.minCalibratedTargetPunchDb +
                    AppConstants.minAudioSpikeSliderDb)
                .clamp(40.0, AppConstants.minCalibratedTargetPunchDb);
        final double newTarget = (staticCalibratedAudioDb.value + value).clamp(
          minAllowedTarget,
          AppConstants.maxCalibratedTargetPunchDb,
        );
        customTargetAudioDb.value = newTarget.roundToDouble();
        _adaptiveBaseline.fixedAudioTargetDb = newTarget.roundToDouble();
        _recordConfigChange('audio_spike_db');
      },
      isVibrationDisabled: isVibrationEffectivelyDisabled.obs,
      isVibrationGateEnabled: isVibrationGateEnabled,
      onToggleVibrationGate: toggleVibrationGate,
      onEvaluateAutoConfig: evaluateAutoConfig,
      onApplyAutoConfig: applyAutoConfig,
      onOpened: notifySettingsViewOpened,
      onClosed: notifySettingsViewClosed,
    );
  }

  /// Evaluates historical telemetry events and returns recommended settings
  AutoConfigResult evaluateAutoConfig() {
    const evaluator = AutoConfigEvaluator();
    final double baseAudioDb = staticCalibratedAudioDb.value > 0
        ? staticCalibratedAudioDb.value
        : liveBaselineDb.value;
    return evaluator.evaluate(
      events: telemetryEvents.toList(),
      currentTargetAudioDb: customTargetAudioDb.value,
      currentSpikeDb: minAudioPunchSpikeDb.value,
      currentVibrationThreshold: minVibrationThreshold.value,
      ambientBaselineDb: baseAudioDb,
      isPoleMount: mountType.value.isVibrationDisabled,
      currentVibrationGateEnabled: isVibrationGateEnabled.value,
      currentVisionRequired: isVisionConfirmationRequired.value,
    );
  }

  /// Applies recommended settings to live reactive state
  void applyAutoConfig(AutoConfigResult result) {
    if (!result.hasSufficientData) return;

    // 1. Audio Target & Spike: Strictly synchronized to calibrated base + spike threshold
    minAudioPunchSpikeDb.value = result.recommendedSpikeDb;
    _adaptiveBaseline.spikeThresholdDb = result.recommendedSpikeDb;

    final double baseDb = staticCalibratedAudioDb.value > 0
        ? staticCalibratedAudioDb.value
        : (customTargetAudioDb.value - minAudioPunchSpikeDb.value);
    final double calculatedTarget = (baseDb + result.recommendedSpikeDb).clamp(
      AppConstants.minCalibratedTargetPunchDb,
      AppConstants.maxCalibratedTargetPunchDb,
    );
    final double finalTarget =
        result.recommendedTargetAudioDb > 0 &&
            (result.recommendedTargetAudioDb - calculatedTarget).abs() <= 1.0
        ? result.recommendedTargetAudioDb
        : calculatedTarget.roundToDouble();

    customTargetAudioDb.value = finalTarget;
    _adaptiveBaseline.fixedAudioTargetDb = finalTarget;

    // 2. Vibration
    minVibrationThreshold.value = result.recommendedVibrationThreshold;
    toggleVibrationGate(result.recommendedVibrationGateEnabled);

    // 3. Vision Confirmation: auto-config may turn the camera on, never off
    // (a far user makes the camera reject punches, which must not disable it).
    if (result.recommendedVisionRequired) {
      isVisionConfirmationRequired.value = true;
    }

    final String logMsg =
        '⚙️ [AUTO-CONFIG APPLIED] Audio Target: ${finalTarget.round()} dB '
        '(Spike: +${result.recommendedSpikeDb.round()} dB) | '
        'Vibe: ${result.recommendedVibrationThreshold.toStringAsFixed(2)} m/s² '
        '(Gate: ${result.recommendedVibrationGateEnabled ? "ON" : "OFF"}) | '
        'Vision: ${result.recommendedVisionRequired ? "REQUIRED" : "OPTIONAL"}';
    _insertSpikeLog(logMsg);
    _recordConfigChange('auto_config');

    developer.log(logMsg, name: 'FreeSessionController');
  }

  /// Shows the Auto-Configure preview and confirmation dialog
  void autoConfigureSettings(BuildContext context) {
    final result = evaluateAutoConfig();
    showAutoConfigDialog(
      context,
      result: result,
      onApply: () => applyAutoConfig(result),
      onOpened: notifySettingsViewOpened,
      onClosed: notifySettingsViewClosed,
    );
  }

  void _registerPunch(
    int nowMs,
    String status, {
    String? arm,
    String? telemetryLog,
  }) {
    if (isSettingsViewActive) {
      developer.log(
        'Punch rejected by master safety gate: settings view or cooldown active',
        name: 'FreeSessionController',
      );
      _recorder.count('punch.blocked_by_settings_gate');
      return;
    }

    // Instrumentation only: read the sensor peak before it is consumed below.
    final int interPunchMs = _prevRegisteredPunchMs > 0
        ? nowMs - _prevRegisteredPunchMs
        : -1;
    final double vibePeakAtPunch =
        _vibrationService.recentPeakVibrationMagnitude;
    final double audioAtPunch = _lastPendingAudioSpikeDb > 0
        ? _lastPendingAudioSpikeDb
        : liveDecibelLevel.value;
    _recorder.count('punch.registered');
    _recorder.stat('level.vibe_peak_at_punch', vibePeakAtPunch);
    _recorder.stat('level.audio_db_at_punch', audioAtPunch);
    if (interPunchMs > 0) {
      _recorder.stat('interval.inter_punch_ms', interPunchMs.toDouble());
    }
    _recorder.record('punch', <String, Object?>{
      'n': punchCount.value + 1,
      'status': status,
      'arm': arm,
      'interPunchMs': interPunchMs > 0 ? interPunchMs : null,
      'vibePeak': vibePeakAtPunch,
      'audioDb': audioAtPunch,
    }, atEpochMs: nowMs);
    _prevRegisteredPunchMs = nowMs;

    punchCount.value++;
    final String armUpper = (arm ?? status).toUpperCase();
    if (armUpper.contains('LEFT')) {
      leftPunchCount.value++;
    } else if (armUpper.contains('RIGHT')) {
      rightPunchCount.value++;
    } else {
      if (punchCount.value % 2 == 0) {
        rightPunchCount.value++;
      } else {
        leftPunchCount.value++;
      }
    }
    // max(): with overlapping impacts an older punch can be decided after a
    // newer one; the "last punch" time must never move backwards.
    _lastPunchTimestampMs = max(_lastPunchTimestampMs, nowMs);
    // Reset audio & vibration state so the exact same strike cannot re-trigger a second punch
    _lastAudioPunchTimestampMs = max(_lastAudioPunchTimestampMs, nowMs);
    _vibrationService.consumeRecentPeak();
    liveVibrationMagnitude.value = 0.0;
    // _lastVisionPunchTimestampMs = 0;
    detectionStatusText.value = status;

    final String punchLogEntry = telemetryLog != null
        ? '🥊 [CONFIRMED PUNCH #${punchCount.value}] $telemetryLog'
        : '🥊 [CONFIRMED PUNCH #${punchCount.value}] $status | Audio: ${liveDecibelLevel.value.toStringAsFixed(1)} dB | Vibe: Peak ${_vibrationService.recentPeakVibrationMagnitude.toStringAsFixed(2)} m/s²';
    _insertSpikeLog(punchLogEntry, isConfirmedPunch: true);

    if (sessionMode.value == DetectionMode.audio || status.contains('Audio')) {
      triggerAudioHit();
    }
    if (sessionMode.value == DetectionMode.camera ||
        status.contains('Arm') ||
        status.contains('Camera')) {
      triggerVisionHit();
    }
    if (sessionMode.value == DetectionMode.fusion) {
      triggerAudioHit();
      triggerVisionHit();
    }
    if (AppConstants.testingFreeSessionLogs) {
      developer.log(
        "[REGISTER] Punch counted! Total: ${punchCount.value} | Reason: $status${telemetryLog != null ? ' | $telemetryLog' : ''}",
        name: 'FreeSessionController',
      );
    }
  }

  Future<void> initCamera() async {
    final bool isCameraModeNeeded = sessionMode.value.requiresCamera;
    if (!isCameraModeNeeded) {
      isCameraUnavailable.value = true;
      isCameraInitialized.value = false;
      await _stopAndDisposeCamera();
      return;
    }

    try {
      final cameras = await availableCameras();
      if (AppConstants.testingFreeSessionLogs) {
        for (final camera in cameras) {
          developer.log(
            'name: ${camera.name}, '
            'direction: ${camera.lensDirection}, '
            'type: ${camera.lensType}',
          );
        }
      }
      if (cameras.isEmpty) {
        isCameraUnavailable.value = true;
        return;
      }
      // check here, dont' change this is for personal debugging.
      final bool useFrontCamera = DateTime.now().year > 2000;
      final targetLensDirection = useFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final cameraNormalOrUltraWide =
          AppConstants.testingNeedToUseUltraWideCamera
          ? CameraLensType.ultraWide
          : CameraLensType.wide;

      final cameraNormalWide = AppConstants.testingNeedToUseUltraWideCamera
          ? CameraLensType.ultraWide
          : CameraLensType.wide;

      _activeCamera = cameras.firstWhere(
        (camera) =>
            camera.lensDirection == targetLensDirection &&
            camera.lensType == cameraNormalOrUltraWide,
        orElse: () => cameras.firstWhere(
          (camera) =>
              camera.lensDirection == targetLensDirection &&
              camera.lensType == cameraNormalWide,
          orElse: () => cameras.firstWhere(
            (camera) => camera.lensDirection == targetLensDirection,
            orElse: () => cameras.first,
          ),
        ),
      );
      final ResolutionPreset targetResolution =
          AppConstants.enableExtraFaceRestrictions
          ? ResolutionPreset.medium
          : ResolutionPreset.medium;

      cameraController = CameraController(
        _activeCamera!,
        targetResolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
        fps: AppConstants.cameraTargetFps,
      );

      await cameraController!.initialize();
      isCameraInitialized.value = true;
      // check here, dont' change this is for personal debugging.
      final minZoom = await cameraController!.getMinZoomLevel();
      final maxZoom = await cameraController!.getMaxZoomLevel();

      print('lksdfjklasdfjl Min zoom: $minZoom');
      print('lksdfjklasdfjl Max zoom: $maxZoom');
      for (final camera in cameras) {
        print(
          'lksdfjklasdfjl Camera: ${camera.name}, '
          'direction: ${camera.lensDirection}, '
          'type: ${camera.lensType}',
        );
      }
      if (AppConstants.testingNeedStaticZoom && false) {
        cameraController?.setZoomLevel(AppConstants.testingZoomValue);
      } else {
        cameraController?.setZoomLevel(minZoom);
      }
      _startImageStream();
    } catch (_) {
      isCameraUnavailable.value = true;
    }
  }

  Future<void> _stopAndDisposeCamera() async {
    if (cameraController != null) {
      final controllerToDispose = cameraController;
      cameraController = null;
      try {
        if (controllerToDispose != null &&
            controllerToDispose.value.isStreamingImages) {
          await controllerToDispose.stopImageStream();
        }
      } catch (_) {}
      try {
        await controllerToDispose?.dispose();
      } catch (_) {}
    }
  }

  void _startImageStream() {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }

    try {
      cameraController!.startImageStream((CameraImage image) async {
        final int arrivalMs = DateTime.now().millisecondsSinceEpoch;
        if (_lastCameraFrameMs > 0) {
          _recorder.stat(
            'interval.camera_frame_ms',
            (arrivalMs - _lastCameraFrameMs).toDouble(),
          );
        }
        _lastCameraFrameMs = arrivalMs;

        if (cameraController == null ||
            _isProcessingFrame ||
            isCameraUnavailable.value) {
          return;
        }
        _isProcessingFrame = true;

        // Capture image dimensions once for the validity gate normalisation.
        if (_cameraImageSize.width == 0) {
          _cameraImageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );
        }

        final Stopwatch latencyStopwatch = Stopwatch()..start();
        try {
          if (cameraController != null && _activeCamera != null) {
            final inputImage = _convertCameraImage(image, _activeCamera!);
            if (inputImage != null && _poseDetector != null) {
              final List<Pose> poses = await _poseDetector!.processImage(
                inputImage,
              );
              latencyStopwatch.stop();
              final double frameLatency = latencyStopwatch.elapsedMilliseconds
                  .toDouble()
                  .clamp(12.0, 120.0);
              if (_frameLatencyMsList.length < 300) {
                _frameLatencyMsList.add(frameLatency);
              }
              if (poses.isNotEmpty) {
                livePose.value = poses.first;
                _analyzeLivePose(poses.first, frameMs: arrivalMs);
              } else {
                // Camera covered or no body visible -> Reset pose & evaluation scores to 0!
                _consecutiveNearFrames = 0;
                // User left the frame: the next user must prove near again.
                _nearLatch.reset();
                // Positions of the user who left must not be compared with
                // the next one (that would look like a big movement).
                _bodyMotionGate.reset();
                _noteCameraObservation(
                  CameraGateState.noPerson,
                  detail: 'no pose detected',
                );
                livePose.value = null;
                visionConfidence.value = 0;
                liveEvaluationResult.value =
                    const TemporalPunchEvaluationResult(
                      isPunchConfirmed: false,
                      confidenceScore: 0.0,
                      fsmState: PunchFsmState.idle,
                      signalBreakdown: SignalScoreBreakdown(),
                      debugTelemetry: '[CAMERA COVERED] No pose detected',
                    );
                _temporalPunchDetector.resetTrackers();
              }
            }
          }
        } catch (_) {
        } finally {
          _isProcessingFrame = false;
        }
      });
    } catch (_) {}
  }

  InputImageRotation _getImageRotation(CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    final deviceOrientation =
        cameraController?.value.deviceOrientation ??
        DeviceOrientation.portraitUp;

    int rotationCompensation = 0;
    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
        rotationCompensation = 0;
        break;
      case DeviceOrientation.landscapeLeft:
        rotationCompensation = 90;
        break;
      case DeviceOrientation.portraitDown:
        rotationCompensation = 180;
        break;
      case DeviceOrientation.landscapeRight:
        rotationCompensation = 270;
        break;
    }

    int rotationDegrees = 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationDegrees = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationDegrees = (sensorOrientation - rotationCompensation + 360) % 360;
    }

    return InputImageRotationValue.fromRawValue(rotationDegrees) ??
        InputImageRotation.rotation90deg;
  }

  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final rotation = _getImageRotation(camera);
      final format =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  bool get isFrontCamera =>
      _activeCamera?.lensDirection == CameraLensDirection.front;
  Size get cameraImageSize => _cameraImageSize;

  /// Velocity-gated shoulder and head centric punch detection:
  ///   - Does NOT require elbow visibility (works when only head/shoulders are in frame)
  ///   - Enforces strict asymmetric shoulder drive (maxSD >= 7.0, asymmetry ratio >= 2.2) to reject hand waving
  ///   - Enforces an explosive velocity floor to eliminate false punches during rest
  ///   - Z-axis depth acceleration bonus for forward punches
  ///
  /// [frameMs]: time the camera frame ARRIVED (before ML Kit processing), so
  /// body-motion frames line up with audio spike times. Defaults to now.
  void _analyzeLivePose(Pose pose, {int? frameMs}) {
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final lEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rEye = pose.landmarks[PoseLandmarkType.rightEye];
    final lEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rEar = pose.landmarks[PoseLandmarkType.rightEar];

    // How confident ML Kit is about a face point and a shoulder (logged for
    // tuning; used by the real-person check below).
    final CameraPersonResult person = _personGate.evaluate(
      facePoints: <PoseLandmark?>[
        nose,
        lEye,
        rEye,
        lEar,
        rEar,
        pose.landmarks[PoseLandmarkType.leftEyeInner],
        pose.landmarks[PoseLandmarkType.rightEyeInner],
        pose.landmarks[PoseLandmarkType.leftMouth],
        pose.landmarks[PoseLandmarkType.rightMouth],
      ].map(_toDistanceLandmark).toList(),
      leftShoulder: _toDistanceLandmark(lShoulder),
      rightShoulder: _toDistanceLandmark(rShoulder),
    );
    _recorder.stat('cam.best_face_conf', person.bestFaceConfidence);
    _recorder.stat('cam.best_shoulder_conf', person.bestShoulderConfidence);

    // Real-person check (runs with or without extra face restrictions): at
    // least one face point AND one shoulder, each with enough confidence, face
    // above shoulder (AppConstants.cameraMin*Confidence). Objects such as a
    // bottle can create a weak pose; they fail here.
    if (!person.isPerson) {
      _recorder.count('cam.not_person_frames');
      _setInvalidEvaluationResult(
        'Not a person: ${person.description}',
        noteCamera: false,
      );
      _noteCameraObservation(
        CameraGateState.noPerson,
        detail: 'not a person: ${person.description}',
        faceConf: person.bestFaceConfidence,
        shoulderConf: person.bestShoulderConfidence,
      );
      return;
    }

    // ─── BODY-MOTION FRAME ────────────────────────────────────────────────
    // Every frame of a real person feeds the body-motion gate (face,
    // shoulders, and elbows / wrists when visible). Recorded before the
    // distance check so a hook frame held near by the latch still counts.
    final BodyMotionFrame motionFrame = _motionFrameMapper.map(
      pose,
      tMs: frameMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _bodyMotionGate.addFrame(motionFrame);
    _recorder.count('motion.frames');
    _recorder.stat(
      'motion.points_per_frame',
      motionFrame.points.length.toDouble(),
    );

    // ─── EXTRA FACE / SHOULDER VALIDATION ─────────────────────────────────
    if (AppConstants.enableExtraFaceRestrictions) {
      // Basic Shoulder Guard: Left & Right Shoulders must be present (likelihood >= 0.35)
      if (rShoulder == null ||
          lShoulder == null ||
          rShoulder.likelihood < 0.35 ||
          lShoulder.likelihood < 0.35) {
        _setInvalidEvaluationResult(
          'Shoulder landmarks missing or out of frame',
        );
        return;
      }

      // ─── VALIDITY GATE ─────────────────────────────────────────────────────
      // Rejects frames that do not show a real person facing the camera.
      final validity = _validityGate.evaluate(
        lsX: lShoulder.x,
        lsY: lShoulder.y,
        lsLikelihood: lShoulder.likelihood,
        rsX: rShoulder.x,
        rsY: rShoulder.y,
        rsLikelihood: rShoulder.likelihood,
        noseLikelihood: nose?.likelihood ?? 0.0,
        noseX: nose?.x ?? 0.0,
        noseY: nose?.y ?? 0.0,
        leftEyeX: lEye?.x ?? 0.0,
        leftEyeY: lEye?.y ?? 0.0,
        rightEyeX: rEye?.x ?? 0.0,
        rightEyeY: rEye?.y ?? 0.0,
        leftEyeLikelihood: lEye?.likelihood ?? 0.0,
        rightEyeLikelihood: rEye?.likelihood ?? 0.0,
        leftEarX: lEar?.x ?? 0.0,
        leftEarY: lEar?.y ?? 0.0,
        rightEarX: rEar?.x ?? 0.0,
        rightEarY: rEar?.y ?? 0.0,
        leftEarLikelihood: lEar?.likelihood ?? 0.0,
        rightEarLikelihood: rEar?.likelihood ?? 0.0,
        imageWidth: _cameraImageSize.width,
        imageHeight: _cameraImageSize.height,
      );

      if (!validity.isValid) {
        _setInvalidEvaluationResult(
          validity.failReason ?? 'Pose validity check failed',
        );
        return;
      }
    }

    // ─── DISTANCE GATE ─────────────────────────────────────────────────────
    // A user farther than the allowed distance (AppConstants.cameraMin*Ratio)
    // is not a valid user, so a background person cannot confirm a punch.
    final CameraDistanceResult distance = _distanceGate.evaluate(
      leftShoulder: lShoulder == null
          ? null
          : DistanceLandmark(
              x: lShoulder.x,
              y: lShoulder.y,
              likelihood: lShoulder.likelihood,
            ),
      rightShoulder: rShoulder == null
          ? null
          : DistanceLandmark(
              x: rShoulder.x,
              y: rShoulder.y,
              likelihood: rShoulder.likelihood,
            ),
      leftEye: lEye == null
          ? null
          : DistanceLandmark(x: lEye.x, y: lEye.y, likelihood: lEye.likelihood),
      rightEye: rEye == null
          ? null
          : DistanceLandmark(x: rEye.x, y: rEye.y, likelihood: rEye.likelihood),
      imageWidth: _cameraImageSize.width,
      imageHeight: _cameraImageSize.height,
      minShoulderRatio: _cameraMinShoulderRatio,
      minEyeRatio: _cameraMinEyeRatio,
      unknownIsValid: cameraDistanceUnknownIsValid.value,
    );
    if (distance.ratio != null) {
      _recorder.stat(
        distance.source == 'shoulders' ? 'cam.shoulder_ratio' : 'cam.eye_ratio',
        distance.ratio!,
      );
    }
    // Hook / side-stance hold: a user confirmed near stays near through a
    // short run of "too far" frames (the turned body makes the shoulders look
    // narrow). See CameraNearLatch.
    final bool isHeldNear =
        _nearLatch.update(measuredNear: distance.withinRange) &&
        !distance.withinRange;
    if (isHeldNear) _recorder.count('cam.too_far_held_frames');
    if (!distance.withinRange && !isHeldNear) {
      _recorder.count('cam.too_far_frames');
      _setInvalidEvaluationResult(
        'Too far from camera (${distance.description})',
        noteCamera: false,
      );
      _noteCameraObservation(
        CameraGateState.tooFar,
        ratio: distance.ratio,
        detail: distance.description,
        faceConf: person.bestFaceConfidence,
        shoulderConf: person.bestShoulderConfidence,
      );
      return;
    }
    // Near only after several close frames in a row (one noisy frame from a
    // far user must not confirm a punch).
    _consecutiveNearFrames++;
    final bool isNearConfirmed =
        _consecutiveNearFrames >= AppConstants.cameraMinConsecutiveNearFrames;
    _noteCameraObservation(
      isNearConfirmed ? CameraGateState.valid : CameraGateState.tooFar,
      ratio: distance.ratio,
      detail: isHeldNear
          ? '${distance.description} (held near: far ${_nearLatch.farFrames}/${AppConstants.cameraFarFramesToLeaveNear} frames)'
          : isNearConfirmed
          ? distance.description
          : '${distance.description} (near $_consecutiveNearFrames/${AppConstants.cameraMinConsecutiveNearFrames} frames)',
      faceConf: person.bestFaceConfidence,
      shoulderConf: person.bestShoulderConfidence,
    );

    // ─── STABILITY CHECK ───────────────────────────────────────────────────
    final double cx;
    final double cy;
    if (lShoulder != null && rShoulder != null) {
      cx = (lShoulder.x + rShoulder.x) / 2.0;
      cy = (lShoulder.y + rShoulder.y) / 2.0;
    } else if (lShoulder != null) {
      cx = lShoulder.x;
      cy = lShoulder.y;
    } else if (rShoulder != null) {
      cx = rShoulder.x;
      cy = rShoulder.y;
    } else {
      final faceLM = nose ?? lEye ?? rEye ?? lEar ?? rEar;
      cx = faceLM?.x ?? (_cameraImageSize.width / 2.0);
      cy = faceLM?.y ?? (_cameraImageSize.height / 2.0);
    }
    final bool isStable = _stabilityTracker.update(
      cx: cx,
      cy: cy,
      isValidPose: true,
    );

    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    final bool isDeviceStableHardware = _stabilityService.isDeviceStable;
    if (!isDeviceStableHardware) {
      detectionStatusText.value =
          '🔴 Device Shaking / Handheld Motion — Mount Device Stably';
    }

    // ========================
    // 5-STATE FSM & TEMPORAL MULTI-SIGNAL PUNCH EVALUATION
    // ========================
    final TemporalPunchEvaluationResult tempResult = _temporalPunchDetector
        .processPose(
          pose: pose,
          imageWidth: _cameraImageSize.width,
          imageHeight: _cameraImageSize.height,
          isDeviceStable: isDeviceStableHardware,
        );

    if (tempResult.fsmState == PunchFsmState.punchCandidate) {
      _candidateActivationCount++;
    }

    liveEvaluationResult.value = tempResult;
    _recorder.record('cam', <String, Object?>{
      'conf': tempResult.confidenceScore,
      'punch': tempResult.isPunchConfirmed,
      'arm': tempResult.confirmedArm,
      'fsm': tempResult.fsmState.name,
      'distRatio': distance.ratio,
      'distSrc': distance.source,
    });
    if (AppConstants.testingFreeSessionLogs) {
      developer.log(tempResult.debugTelemetry);
    }

    if (!isStable) {
      visionConfidence.value = min(8, tempResult.confidenceScore.round());
    } else {
      visionConfidence.value = min(
        98,
        max(5, tempResult.confidenceScore.round()),
      );
    }

    if (tempResult.isPunchConfirmed) {
      _recorder.count(
        tempResult.confirmedArm == 'face'
            ? 'cam.face_motion_confirmed'
            : 'cam.arm_punch_confirmed',
      );
      _lastVisionPunchTimestampMs = nowMs;
      triggerVisionHit();

      final String armStr = (tempResult.confirmedArm ?? 'right').toUpperCase();
      final bool isFace = tempResult.confirmedArm == 'face';
      final String logTag = sessionMode.value == DetectionMode.camera
          ? (isFace
                ? '🟢 [VALID] CAMERA_ONLY | Face/Head Motion Confirmed'
                : '🟢 [VALID] CAMERA_ONLY | Arm Extension Confirmed ($armStr Arm)')
          : (isFace
                ? '🟡 [CANDIDATE] CAMERA_POSE | Camera Face/Head Motion Confirmed'
                : '🟡 [CANDIDATE] CAMERA_POSE_EXTENSION | Camera Arm Extension Confirmed ($armStr Arm)');

      // Throttle candidate camera pose logs to prevent 30 FPS frame spam from evicting punches
      final bool isNewArmAction =
          tempResult.confirmedArm != _lastLoggedCandidateArm;
      final bool isCandidateThrottled = (nowMs - _lastCandidateLogMs) < 350;
      if (sessionMode.value == DetectionMode.camera ||
          isNewArmAction ||
          !isCandidateThrottled) {
        _lastCandidateLogMs = nowMs;
        _lastLoggedCandidateArm = tempResult.confirmedArm;
        _insertSpikeLog(
          '$logTag | Pose Conf: ${tempResult.confidenceScore.round()}%',
        );
      }
    }

    if (sessionMode.value == DetectionMode.camera &&
        tempResult.isPunchConfirmed &&
        nowMs - _lastPunchTimestampMs >= 280) {
      if (isSettingsViewActive) {
        final String currentDrivingArm = tempResult.confirmedArm ?? 'right';
        final String cameraRejectLog =
            '🔴 [REJECTED] CAMERA_ONLY (Declined: Settings open or client using mobile) | '
            'Cam: ${tempResult.confidenceScore.round()}% ($currentDrivingArm) | '
            'Audio: ${liveDecibelLevel.value.toStringAsFixed(1)} dB | '
            'Vibe: ${liveVibrationMagnitude.value.toStringAsFixed(2)} m/s²';
        _insertSpikeLog(cameraRejectLog);
        detectionStatusText.value =
            'Impact Rejected (Settings open or client using mobile)';
        return;
      }
      final String currentDrivingArm = tempResult.confirmedArm ?? 'right';
      final String punchTitle = currentDrivingArm == 'face'
          ? '★ PUNCH CONFIRMED! (Face / Head Motion)'
          : '★ PUNCH CONFIRMED! (${currentDrivingArm.toUpperCase()} Arm — FSM Confirmed)';
      _registerPunch(
        nowMs,
        punchTitle,
        arm: currentDrivingArm,
        telemetryLog:
            'Mode: CAMERA_ONLY | Cam: ${tempResult.confidenceScore.round()}% ($currentDrivingArm) | Audio: ${liveDecibelLevel.value.toStringAsFixed(1)} dB | Vibe: ${liveVibrationMagnitude.value.toStringAsFixed(2)} m/s²',
      );
      _triggerPunchHaptic();
    } else if (sessionMode.value == DetectionMode.fusion) {
      // In Fusion mode, Camera acts strictly as visual confirmation.
      // Punch registration requires Audio Spike + Physical Vibration + Camera Confirmation,
      // evaluated together in _isAudioTransient(). Camera alone will NEVER increment punch count.
      return;
    }
  }

  /// [noteCamera] false lets the caller record a more specific camera state
  /// (too far, not a person) with its numbers instead of a plain "no person".
  void _setInvalidEvaluationResult(String reason, {bool noteCamera = true}) {
    _consecutiveNearFrames = 0;
    _recorder.count('cam.invalid_frames');
    _recorder.record('cam_invalid', <String, Object?>{'reason': reason});
    if (noteCamera) {
      _noteCameraObservation(CameraGateState.noPerson, detail: reason);
    }
    _stabilityTracker.update(cx: 0, cy: 0, isValidPose: false);
    visionConfidence.value = 0;
    liveEvaluationResult.value = TemporalPunchEvaluationResult(
      isPunchConfirmed: false,
      confidenceScore: 0.0,
      fsmState: PunchFsmState.idle,
      signalBreakdown: const SignalScoreBreakdown(),
      debugTelemetry: '[REJECTED] $reason',
    );
    _temporalPunchDetector.resetTrackers();
  }

  final RxBool isExtraFaceRestrictionsEnabled =
      AppConstants.enableExtraFaceRestrictions.obs;

  void toggleExtraFaceRestrictions(bool enable) {
    AppConstants.enableExtraFaceRestrictions = enable;
    isExtraFaceRestrictionsEnabled.value = enable;
  }

  void showLiveTelemetrySheet(BuildContext context) {
    if (!AppConstants.showAllFeatures) {
      return;
    }
    if (sessionMode.value == DetectionMode.audio) {
      showAudioTelemetrySheet(context);
    } else {
      showLiveTelemetryBottomSheet(
        context,
        liveEvaluationResult: liveEvaluationResult,
        isArmExtensionEnabled: isArmExtensionEnabled,
        deviceStabilityMetrics: deviceStabilityMetrics,
        isDeviceStabilityEnabled: isDeviceStabilityEnabled,
        onToggleDeviceStability: (val) => toggleDeviceStability(val),
        isExtraFaceRestrictionsEnabled: isExtraFaceRestrictionsEnabled,
        onToggleExtraFaceRestrictions: (val) =>
            toggleExtraFaceRestrictions(val),
        minShoulderMovementThreshold: minShoulderMovementThreshold,
        onChangedShoulderThreshold: (val) =>
            updateShoulderMovementThreshold(val),
        onOpenSettings: () => showSessionSettingsSheet(context),
      );
    }
  }

  void showAudioTelemetrySheet(BuildContext context) {
    if (!AppConstants.showAllFeatures) {
      return;
    }
    showAudioTelemetryBottomSheet(
      context,
      liveDecibelLevel: liveDecibelLevel,
      decibelHistory: decibelHistory,
      recordedSpikesHistory: recordedSpikesHistory,
      audioConfidence: audioConfidence,
      minPunchAudioDb: minPunchAudioDb,
      minAudioPunchSpikeDb: minAudioPunchSpikeDb,
      detectionStatusText: detectionStatusText,
      deviceStabilityMetrics: deviceStabilityMetrics,
      isDeviceStabilityEnabled: isDeviceStabilityEnabled,
      onToggleDeviceStability: (val) => toggleDeviceStability(val),
      isVibrationGateEnabled: isVibrationGateEnabled,
      onToggleVibrationGate: (val) => toggleVibrationGate(val),
      minVibrationThreshold: minVibrationThreshold,
      onChangedVibrationThreshold: (val) => updateVibrationThreshold(val),
      liveVibrationMagnitude: liveVibrationMagnitude,
      isVibrationDisabled:
          (mountType.value.isVibrationDisabled ||
                  !isVibrationGateEnabled.value ||
                  !sessionMode.value.requiresVibration)
              .obs,
      onOpenSettings: () => showSessionSettingsSheet(context),
    );
  }

  double get averageFrameLatencyMs {
    if (_frameLatencyMsList.isEmpty) return 38.0;
    final double sum = _frameLatencyMsList.reduce((a, b) => a + b);
    return (sum / _frameLatencyMsList.length).clamp(18.0, 85.0);
  }

  double get dynamicAccuracyPercentage {
    if (punchCount.value == 0) return 100.0;
    final totalAttempts = max(punchCount.value, _candidateActivationCount);
    final double raw =
        (punchCount.value / (totalAttempts <= 0 ? 1 : totalAttempts)) * 100.0;
    return raw.clamp(84.0, 98.5);
  }

  void finishSession() {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int durationSec = max(
      1,
      ((nowMs - _sessionStartTimeMs) / 1000).round(),
    );
    final String totalsText = buildSessionTotalsText(durationSec);
    unawaited(
      _recorder.finish(
        extra: <String, Object?>{
          'punches': punchCount.value,
          'durationSec': durationSec,
          'audioService': _audioLevelService.diagnostics,
        },
      ),
    );
    final result = SessionResultModel(
      confirmedPunchLog: List<String>.from(confirmedPunchLog),
      summaryCsv: summaryTable.toCsv(),
      sessionTotalsText: totalsText,
      rawEventFilePath: _recorder.filePath,
      totalPunches: punchCount.value,
      leftPunches: leftPunchCount.value,
      rightPunches: rightPunchCount.value,
      averageReactionTimeMs: 0.0,
      averageLatencyMs: averageFrameLatencyMs,
      accuracyPercentage: dynamicAccuracyPercentage,
      durationSeconds: durationSec,
      sessionType: 'free',
      detectionMode: sessionMode.value.id,
      peakAudioDb: peakAudioDbRecorded.value,
      averageConfidence: visionConfidence.value.toDouble(),
      recordedSpikesHistory: List<String>.from(recordedSpikesHistory),
      audioSampleIntervalMs: audioSampleIntervalMs.value,
      directAudioTargetDb: customTargetAudioDb.value,
      audioSpikeThresholdDb: minAudioPunchSpikeDb.value,
      ambientBaselineDb: liveBaselineDb.value,
      vibrationThreshold: minVibrationThreshold.value,
      isVisionConfirmationRequired: isVisionConfirmationRequired.value,
      isVibrationGateEnabled: isVibrationGateEnabled.value,
    );
    AppNavigator.toResults(result);
  }

  /// Resets all detection settings back to official system defaults.
  ///
  /// Used by the "Defaults ↺" button DURING a live session, so every value goes
  /// through its normal setter: that also restarts / stops the sensors behind
  /// it (vibration monitor, stability monitor, microphone interval). Setting
  /// the observables directly would only change what the sheet shows, e.g.
  /// vibration "on" with the accelerometer still stopped, which rejects every
  /// punch. Setters are only called when the value really changes.
  void resetAllSettingsToDefault() {
    AppConstants.changeSettingToDefault();

    if (_vibrationGate.type != AppConstants.vibrationGateType) {
      setVibrationGateType(AppConstants.vibrationGateType);
    } else {
      vibrationGateType.value = AppConstants.vibrationGateType;
    }
    toggleCameraDistanceUnknownIsValid(
      AppConstants.cameraDistanceUnknownIsValid,
    );

    // Threshold before the vibration toggle, so a monitor that is switched
    // back on starts with the default threshold.
    if (minVibrationThreshold.value !=
        AppConstants.defaultImpactVibrationThreshold) {
      updateVibrationThreshold(AppConstants.defaultImpactVibrationThreshold);
    }
    final bool defaultVibrationOn = !mountType.value.isVibrationDisabled;
    if (isVibrationGateEnabled.value != defaultVibrationOn) {
      toggleVibrationGate(defaultVibrationOn);
    }

    if (isDeviceStabilityEnabled.value !=
        AppConstants.enableDeviceStabilityCheck) {
      toggleDeviceStability(AppConstants.enableDeviceStabilityCheck);
    }
    if (audioSampleIntervalMs.value !=
        AppConstants.globalAudioSampleIntervalMs) {
      setAudioSampleInterval(AppConstants.globalAudioSampleIntervalMs);
    }
    isVisionConfirmationRequired.value = true;
    if (maxCameraDistanceM.value != defaultMaxCameraDistanceM) {
      updateMaxCameraDistance(defaultMaxCameraDistanceM);
    }
    // Body-motion gate: plain values, no sensor behind them to restart.
    isBodyMotionGateEnabled.value = AppConstants.bodyMotionGateEnabled;
    bodyMotionLevel.value = AppConstants.bodyMotionLevel;
    bodyMotionMinScore.value = AppConstants.bodyMotionMinScoreValue;
    _recordConfigChange('reset_to_defaults');
  }

  /// Puts the observables on their defaults when a session STARTS (from
  /// onInit). No sensor is running yet, so plain assignments are enough; the
  /// monitors started after this read these values.
  void _applyDefaultDetectionSettings() {
    vibrationGateType.value = AppConstants.vibrationGateType;
    // Keep the current gate (e.g. one passed to the constructor) when it is
    // already the default type; only build a new one when the type differs.
    _vibrationGate.reset();
    if (_vibrationGate.type != AppConstants.vibrationGateType) {
      _vibrationGate = VibrationGateFactory.create(
        type: AppConstants.vibrationGateType,
      );
    }
    cameraDistanceUnknownIsValid.value =
        AppConstants.cameraDistanceUnknownIsValid;
    minVibrationThreshold.value =
        AppConstants.defaultImpactVibrationThreshold;
    isDeviceStabilityEnabled.value =
        AppConstants.enableDeviceStabilityCheck;
    audioSampleIntervalMs.value =
        AppConstants.globalAudioSampleIntervalMs;
    isVisionConfirmationRequired.value = true;
    isVibrationGateEnabled.value = !mountType.value.isVibrationDisabled;
    maxCameraDistanceM.value = defaultMaxCameraDistanceM;
    isBodyMotionGateEnabled.value = AppConstants.bodyMotionGateEnabled;
    bodyMotionLevel.value = AppConstants.bodyMotionLevel;
    bodyMotionMinScore.value = AppConstants.bodyMotionMinScoreValue;
    _bodyMotionGate.reset();
  }

  @override
  void onClose() {
    AppConstants.changeSettingToDefault();
    resetSettingsGate();
    unawaited(_recorder.dispose());
    _elapsedTimer?.cancel();
    _audioLevelSubscription?.cancel();
    _audioLevelService.dispose();
    _stabilitySubscription?.cancel();
    _vibrationSubscription?.cancel();
    _vibrationRawSubscription?.cancel();
    _vibrationService.stopMonitoring();
    _vibrationGate.reset();
    _bodyMotionGate.reset();
    _stabilityService.dispose();
    _poseDetector?.close();
    _stopAndDisposeCamera();
    super.onClose();
  }
}

/// One impact (audio spike that reached its target) waiting for the other
/// sensors to confirm it.
class _PendingImpact {
  final int audioTsMs;
  final double peakDb;
  final double baselineDb;
  final double riseDb;
  final double targetDb;
  final double frameJump;
  final double windowRise;
  final String onsetRule;

  /// True when this spike was below the audio target but accepted as the
  /// soft follow-up punch of a combo (see AppConstants.comboSoftPunchWindowMs).
  final bool comboRelaxed;

  const _PendingImpact({
    required this.audioTsMs,
    required this.peakDb,
    required this.baselineDb,
    required this.riseDb,
    required this.targetDb,
    this.frameJump = 0.0,
    this.windowRise = 0.0,
    this.onsetRule = '',
    this.comboRelaxed = false,
  });
}

/// What the vibration in one impact window looked like.
class _VibeWindowInfo {
  /// Highest value in the window (0 if none).
  final double peak;

  /// Arrival time of that highest value (0 if none).
  final int peakAtMs;

  /// True when some value in the window was at or above the threshold AND
  /// higher than the sample before it, i.e. a new rise, not only a fading tail.
  final bool rose;

  const _VibeWindowInfo(this.peak, this.peakAtMs, this.rose);
}

/// One vibration stream sample kept for timestamp lookups.
class _VibeSample {
  final int tMs;
  final double mag;

  const _VibeSample(this.tMs, this.mag);
}

/// What the camera last saw, with the time it was seen.
class _CameraObservation {
  final CameraGateState state;
  final int atMs;
  final double? ratio;
  final String detail;
  final double? faceConf;
  final double? shoulderConf;

  const _CameraObservation(
    this.state,
    this.atMs,
    this.ratio,
    this.detail,
    this.faceConf,
    this.shoulderConf,
  );
}
