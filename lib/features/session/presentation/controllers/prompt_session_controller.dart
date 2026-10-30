import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import '../../../../core/enums/detection_enums.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../vision_detection/data/geometric_rules/pose_validity_gate.dart';
import '../../../vision_detection/data/geometric_rules/shoulder_stability_tracker.dart';
import '../../../vision_detection/domain/entities/temporal_punch_detector.dart';
import '../../../vision_detection/domain/entities/punch_detection_config.dart';
import '../../../vision_detection/domain/services/person_focus/i_person_focus_strategy.dart';
import '../../../vision_detection/data/datasources/mlkit_face_locator.dart';
import '../../../vision_detection/data/person_focus/nearest_face_person_focus.dart';
import '../../../fusion/domain/services/tri_sensor_matrix_evaluator.dart';
import '../../../fusion/domain/services/fast_combo_fusion_synchronizer.dart';
import '../../../../core/services/audio_level/i_audio_level_service.dart';
import '../../../../core/services/audio_level/adaptive_audio_baseline.dart';
import '../../../../core/services/audio_level/record_audio_level_service.dart';
import '../../../../core/services/device_stability/device_stability_models.dart';
import '../../../../core/services/device_stability/device_stability_service.dart';
import '../../../../core/services/device_stability/i_device_stability_service.dart';
import '../../../../core/services/device_vibration/device_vibration_service.dart';
import '../../../../core/services/device_vibration/i_device_vibration_service.dart';
import '../../domain/entities/punch_telemetry_event.dart';
import '../../domain/services/auto_config_evaluator.dart';
import '../widgets/auto_config_dialog.dart';
import '../widgets/live_telemetry_sheet.dart';
import '../widgets/session_detection_settings_sheet.dart';

class PromptSessionController extends GetxController {
  CameraController? cameraController;
  PoseDetector? _poseDetector;

  // TTS Engine for speaking prompt numbers
  final FlutterTts _flutterTts;
  final RxBool isTtsEnabled = true.obs;
  bool _isTtsSpeaking = false;
  int _lastTtsSpeechStartTimeMs = 0;
  int _lastTtsSpeechEndTimeMs = 0;

  bool get isTtsSpeaking => _isTtsSpeaking;
  int get lastTtsSpeechStartTimeMs => _lastTtsSpeechStartTimeMs;
  int get lastTtsSpeechEndTimeMs => _lastTtsSpeechEndTimeMs;

  // Real-time Audio Level Sensor Service (DIP: Injected abstract contract)
  final IAudioLevelService _audioLevelService;
  StreamSubscription<double>? _audioLevelSubscription;

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

  /// Returns true if physical vibration is disabled due to mount type (pole),
  /// manual toggle switch OFF, or non-vibration detection mode.
  bool get isVibrationEffectivelyDisabled =>
      mountType.value.isVibrationDisabled ||
      !isVibrationGateEnabled.value ||
      !sessionMode.value.requiresVibration;

  final TemporalPunchDetector _temporalPunchDetector;
  final FastComboFusionSynchronizer _fusionSynchronizer;
  final PoseValidityGate _validityGate;
  final ShoulderStabilityTracker _stabilityTracker;
  final AdaptiveAudioBaseline _adaptiveBaseline;

  // Nearest-person focus (SOLID: depends on IPersonFocusStrategy only).
  // Keeps the pose detector / skeleton on the closest person when several
  // people are in view. See NearestFacePersonFocus.
  final IPersonFocusStrategy _personFocus;

  /// Settings switch "Focus on Nearest Person". false = the pose detector
  /// always gets the full frame (original behaviour).
  final RxBool isPersonFocusEnabled =
      AppConstants.personFocusEnabledDefault.obs;

  void togglePersonFocus(bool enable) {
    isPersonFocusEnabled.value = enable;
    AppConstants.personFocusEnabled = enable;
    // Start clean: no person held from before the switch.
    _personFocus.reset();
    developer.log(
      'Nearest-person focus ${enable ? 'ON' : 'OFF'}',
      name: 'PromptSessionController',
    );
  }

  PromptSessionController({
    IAudioLevelService? audioLevelService,
    IDeviceStabilityService? stabilityService,
    IDeviceVibrationService? vibrationService,
    TemporalPunchDetector? temporalPunchDetector,
    FastComboFusionSynchronizer? fusionSynchronizer,
    PoseValidityGate? validityGate,
    ShoulderStabilityTracker? stabilityTracker,
    AdaptiveAudioBaseline? adaptiveBaseline,
    FlutterTts? flutterTts,
    IPersonFocusStrategy? personFocus,
  }) : _audioLevelService = audioLevelService ?? RecordAudioLevelService(),
       _stabilityService = stabilityService ?? DeviceStabilityService(),
       _vibrationService = vibrationService ?? DeviceVibrationService(),
       _flutterTts = flutterTts ?? FlutterTts(),
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
       _stabilityTracker =
           stabilityTracker ?? ShoulderStabilityTracker(windowFrames: 5),
       _adaptiveBaseline = adaptiveBaseline ?? AdaptiveAudioBaseline(),
       _personFocus =
           personFocus ??
           NearestFacePersonFocus(faceLocator: MlKitFaceLocator());

  FastComboFusionSynchronizer get fusionSynchronizer => _fusionSynchronizer;

  // Selected session mode: strongly-typed DetectionMode enum
  final Rx<DetectionMode> sessionMode = DetectionMode.fusion.obs;
  // Selected mount type: strongly-typed MountType enum
  final Rx<MountType> mountType = MountType.wall.obs;
  // Prompt difficulty tier: 'beginner' (1.2s), 'intermediate' (0.6s), 'advanced' (0.3s)
  final RxString difficulty = 'beginner'.obs;

  final RxBool isCameraInitialized = false.obs;
  final RxBool isCameraUnavailable = false.obs;
  final Rx<Pose?> livePose = Rx<Pose?>(null);

  final RxInt punchCount = 0.obs;
  final RxInt leftPunchCount = 0.obs;
  final RxInt rightPunchCount = 0.obs;

  void resetPunchCount() {
    punchCount.value = 0;
    leftPunchCount.value = 0;
    rightPunchCount.value = 0;
    detectionStatusText.value = 'Count reset to 0';
  }

  final RxInt promptNumber = 1.obs;
  final RxString promptText = '1 - 2'.obs;
  final RxList<int> currentComboSequence = <int>[1, 2].obs;
  List<int> _activeCombo = [1, 2];
  int _currentComboStepIndex = 0;
  final RxInt audioConfidence = 0.obs;
  final RxInt visionConfidence = 0.obs;
  final RxInt fusedConfidence = 0.obs;
  final RxInt reactionMs = 0.obs;
  final RxDouble liveDecibelLevel = 0.0.obs;
  final RxDouble liveBaselineDb = 48.0.obs;
  final RxDouble liveSpikeThresholdDb = 10.0.obs;
  final RxList<double> decibelHistory = <double>[].obs;
  final RxList<String> recordedSpikesHistory = <String>[].obs;
  final RxList<PunchTelemetryEvent> telemetryEvents = <PunchTelemetryEvent>[].obs;
  final RxString detectionStatusText = 'Initializing Session Engine…'.obs;

  int _lastCandidateLogMs = 0;
  String? _lastLoggedCandidateArm;

  /// Centralized logging into recordedSpikesHistory.
  /// Prevents buffer overflow and ensures confirmed punches are never evicted.
  void _insertSpikeLog(String logEntry, {bool isConfirmedPunch = false}) {
    recordedSpikesHistory.insert(0, logEntry);
    const int maxCapacity = 500;
    if (recordedSpikesHistory.length > maxCapacity) {
      if (isConfirmedPunch) {
        final int oldestNonPunchIdx = recordedSpikesHistory.lastIndexWhere(
          (entry) => !entry.contains('🥊 [CONFIRMED PUNCH'),
        );
        if (oldestNonPunchIdx != -1) {
          recordedSpikesHistory.removeAt(oldestNonPunchIdx);
        } else {
          recordedSpikesHistory.removeLast();
        }
      } else {
        recordedSpikesHistory.removeLast();
      }
    }
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
    );
    developer.log(
      '[PUNCH TELEMETRY] ${event.isValidPunch ? '🟢 VALID' : (event.isCandidate ? '🟡 CANDIDATE' : '🔴 REJECTED')} '
      '${event.decisionCode} (${event.reasonLabel}) | Audio: ${event.peakAudioDb.toStringAsFixed(1)} dB (Rise: +${event.audioRiseDb.toStringAsFixed(1)} dB, Target: ${event.targetAudioDb.round()} dB) | '
      'Vibe: ${event.vibrationPeakMag.toStringAsFixed(2)} m/s² (Thresh: ${event.vibrationThreshold.toStringAsFixed(2)} m/s²) | '
      'Cam: ${event.cameraConfidence}% (${event.cameraArm}, Confirmed: ${event.isCameraConfirmed})',
      name: 'PromptSessionController',
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
    developer.log(
      'Settings view opened (active count: $_openSettingsViewsCount). Punch detection paused.',
      name: 'PromptSessionController',
    );
  }

  void notifySettingsViewClosed() {
    if (_openSettingsViewsCount > 0) {
      _openSettingsViewsCount--;
      if (_openSettingsViewsCount == 0) {
        _settingsCooldownUntilMs =
            DateTime.now().millisecondsSinceEpoch + AppConstants.postSettingsCooldownMs;
        developer.log(
          'Settings view closed. Post-settings cooldown active until $_settingsCooldownUntilMs (${AppConstants.postSettingsCooldownMs}ms).',
          name: 'PromptSessionController',
        );
      }
    }
  }

  void resetSettingsGate() {
    _openSettingsViewsCount = 0;
    _settingsCooldownUntilMs = 0;
  }

  bool _isProcessingFrame = false;
  CameraDescription? _activeCamera;
  Timer? _promptTimer;

  // Dynamic Audio & Video Punch Settings (Tunable live during session)
  final RxDouble staticCalibratedAudioDb =
      0.0.obs; // Static base audio dB captured during precheck calibration
  final RxDouble minPunchAudioDb = AppConstants
      .minAudioSafetyFloorDb
      .obs; // Absolute safety floor dB from AppConstants
  final RxDouble minAudioPunchSpikeDb = AppConstants
      .defaultAudioSpikeThresholdDb
      .obs; // Spike threshold: dB jump above baseline required
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

  double _prevFrameDb = 48.0; // Decibel level of previous 100ms frame
  int _lastAudioPunchTimestampMs = 0;
  int _lastPendingAudioSpikeMs = 0;
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

  /// Image dimensions captured from the first camera frame.
  Size _cameraImageSize = Size.zero;

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
    // Every session starts with nearest-person focus on its default.
    AppConstants.personFocusEnabled = AppConstants.personFocusEnabledDefault;
    isPersonFocusEnabled.value = AppConstants.personFocusEnabledDefault;
    _sessionStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    _initTts();
    _startElapsedTimer();
    _readRouteArguments();
    _updateDetectorConfig();
    _initPoseDetector();
    initCamera();
    _startMicrophoneStream();
    _startPromptRotation();
    _startDeviceStabilityMonitor();
    _startDeviceVibrationMonitor();
  }

  void _startDeviceVibrationMonitor() {
    _vibrationSubscription?.cancel();
    _vibrationService.startMonitoring(
      minVibrationThreshold: minVibrationThreshold.value,
    );
    _vibrationSubscription = _vibrationService.vibrationMagnitudeStream.listen((
      mag,
    ) {
      liveVibrationMagnitude.value = mag;

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final int vibrationRefractoryMs =
          sessionMode.value == DetectionMode.vibration ? 110 : 110;

      // Re-arm vibration detector after refractory window HAS PASSED
      if (nowMs - _lastPunchTimestampMs >= vibrationRefractoryMs) {
        _isVibrationArmed = true;
      }

      if (mag >= minVibrationThreshold.value &&
          _isVibrationArmed &&
          nowMs - _lastPunchTimestampMs >= vibrationRefractoryMs) {
        _isVibrationArmed =
            false; // Lock out until physical shockwave dies down

        if (isSettingsViewActive) {
          final String vibeRejectLog =
              '🔴 [REJECTED] VIBRATION_IMPACT (Declined: Settings open or client using mobile) | '
              'Vibe: ${mag.toStringAsFixed(2)} m/s² (Thresh: ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²) | '
              'Audio: ${liveDecibelLevel.value.toStringAsFixed(1)} dB (Base: ${liveBaselineDb.value.toStringAsFixed(1)} dB)';
          _insertSpikeLog(vibeRejectLog);
          detectionStatusText.value =
              'Impact Rejected (Settings open or client using mobile)';
          return;
        }

        final String vibeLog =
            '🟡 [CANDIDATE] VIBRATION_IMPACT | '
            'Vibe: ${mag.toStringAsFixed(2)} m/s² (Thresh: ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²) | '
            'Audio: ${liveDecibelLevel.value.toStringAsFixed(1)} dB (Base: ${liveBaselineDb.value.toStringAsFixed(1)} dB)';

        _insertSpikeLog(vibeLog);

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

        // BIDIRECTIONAL SYNC: Check if audio spike occurred slightly before vibration (within 120ms)
        final double effectiveTargetDb = customTargetAudioDb.value > 0
            ? customTargetAudioDb.value
            : (staticCalibratedAudioDb.value + minAudioPunchSpikeDb.value);

        final bool hasRecentAudio = (nowMs - _lastPendingAudioSpikeMs) <= 120 &&
            _lastPendingAudioSpikeMs > 0 &&
            _lastPendingAudioSpikeDb >= effectiveTargetDb;

        if (hasRecentAudio) {
          if (sessionMode.value == DetectionMode.audioVibration) {

            final syncEvent = PunchTelemetryEvent(
              timestampMs: nowMs,
              peakAudioDb: _lastPendingAudioSpikeDb,
              baselineAudioDb: liveBaselineDb.value,
              audioRiseDb: max(
                minAudioPunchSpikeDb.value,
                _lastPendingAudioSpikeDb - liveBaselineDb.value,
              ),
              targetAudioDb: customTargetAudioDb.value,
              vibrationPeakMag: mag,
              vibrationLiveMag: liveVibrationMagnitude.value,
              vibrationThreshold: minVibrationThreshold.value,
              cameraConfidence: 0,
              cameraArm: 'NONE',
              isCameraConfirmed: false,
              isCameraAvailable: false,
              isValidPunch: true,
              decisionCode: 'AUDIO_VIBE_SYNC',
              reasonLabel: 'Audio + Vibration Sync',
              sessionMode: sessionMode.value.name,
              mountType: mountType.value.name,
              isVibrationGateEnabled: isVibrationGateEnabled.value,
              isVisionConfirmationRequired: isVisionConfirmationRequired.value,
              refractoryElapsedMs: (nowMs - _lastPunchTimestampMs).clamp(0, 99999),
            );
            _recordTelemetryEvent(syncEvent);

            _registerPunch(
              nowMs,
              '★ PUNCH CONFIRMED! (${_lastPendingAudioSpikeDb.round()} dB — Audio + Vibration)',
              telemetryLog:
                  'Mode: AUDIO_VIBRATION (Sync) | Audio: ${_lastPendingAudioSpikeDb.toStringAsFixed(1)} dB | Vibe: Peak ${_vibrationService.recentPeakVibrationMagnitude.toStringAsFixed(2)} m/s² (Thresh: ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²)',
            );
            _triggerPunchHaptic();
          } else if (sessionMode.value == DetectionMode.fusion) {
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
                (hasRecentCameraPunch || evalResult.isPunchConfirmed);
            final bool isCamRejected = isCamAvailable && !isCamConfirmed;

            final matrixEvaluator = TriSensorMatrixEvaluator(
              strongAudioSpikeDb: minAudioPunchSpikeDb.value,
              strongVibrationMag: minVibrationThreshold.value,
              requireVisionConfirmation: isVisionConfirmationRequired.value,
              isVibrationDisabled: isVibrationEffectivelyDisabled,
              isPoleMount: mountType.value.isVibrationDisabled,
            );
            final matrixResult = matrixEvaluator.evaluate(
              audioSpikeDb: max(
                minAudioPunchSpikeDb.value,
                _lastPendingAudioSpikeDb > 0
                    ? _lastPendingAudioSpikeDb - liveBaselineDb.value
                    : minAudioPunchSpikeDb.value,
              ),
              vibrationMag: mag,
              isCameraAvailable: isCamAvailable,
              isCameraConfirmed: isCamConfirmed,
              isCameraRejected: isCamRejected,
              timestampMs: nowMs,
            );

            if (matrixResult.isValidPunch) {
              final String activeArm = evalResult?.confirmedArm ?? 'right';
              final syncEvent = PunchTelemetryEvent(
                timestampMs: nowMs,
                peakAudioDb: _lastPendingAudioSpikeDb,
                baselineAudioDb: liveBaselineDb.value,
                audioRiseDb: max(
                  minAudioPunchSpikeDb.value,
                  _lastPendingAudioSpikeDb - liveBaselineDb.value,
                ),
                targetAudioDb: customTargetAudioDb.value,
                vibrationPeakMag: mag,
                vibrationLiveMag: liveVibrationMagnitude.value,
                vibrationThreshold: minVibrationThreshold.value,
                cameraConfidence: evalResult?.confidenceScore.round() ?? 0,
                cameraArm: activeArm.toUpperCase(),
                isCameraConfirmed: isCamConfirmed,
                isCameraAvailable: isCamAvailable,
                isValidPunch: true,
                decisionCode: 'FUSION_VIBE_SYNC',
                reasonLabel: matrixResult.reasonLabel,
                sessionMode: sessionMode.value.name,
                mountType: mountType.value.name,
                isVibrationGateEnabled: isVibrationGateEnabled.value,
                isVisionConfirmationRequired: isVisionConfirmationRequired.value,
                refractoryElapsedMs: (nowMs - _lastPunchTimestampMs).clamp(0, 99999),
              );
              _recordTelemetryEvent(syncEvent);

              _registerPunch(
                nowMs,
                '★ PUNCH CONFIRMED! (${matrixResult.reasonLabel})',
                arm: activeArm,
                telemetryLog:
                    'Mode: FUSION (Sync) | Code: ${matrixResult.combinationCode} (${matrixResult.reasonLabel}) | Audio: ${_lastPendingAudioSpikeDb.toStringAsFixed(1)} dB | Vibe: Peak ${_vibrationService.recentPeakVibrationMagnitude.toStringAsFixed(2)} m/s² | Cam: ${evalResult?.confidenceScore.round() ?? 0}% ($activeArm)',
              );
              _lastPendingAudioSpikeMs = 0;
              _triggerPunchHaptic();
            }
          }
        }
      }
    });
  }

  void toggleVibrationGate(bool enable) {
    isVibrationGateEnabled.value = enable;
    if (enable) {
      _startDeviceVibrationMonitor();
    } else {
      _vibrationSubscription?.cancel();
      _vibrationService.stopMonitoring();
      liveVibrationMagnitude.value = 0.0;
    }
  }

  void updateVibrationThreshold(double value) {
    minVibrationThreshold.value = value;
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

    if (vibrationMag != null) {
      updateVibrationThreshold(
        vibrationMag.clamp(
          AppConstants.minImpactVibrationSlider,
          AppConstants.maxImpactVibrationSlider,
        ),
      );
    }
  }

  void _startDeviceStabilityMonitor() {
    _stabilitySubscription?.cancel();
    _stabilityService.startMonitoring();
    _stabilitySubscription = _stabilityService.metricsStream.listen((metrics) {
      deviceStabilityMetrics.value = metrics;
    });
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
    isTtsEnabled.value = sessionArgs.ttsEnabled;
    if (sessionArgs.difficulty != null && sessionArgs.difficulty!.isNotEmpty) {
      difficulty.value = sessionArgs.difficulty!;
    }
    if (sessionArgs.promptMode != null) {
      sessionMode.value = sessionArgs.resolvedDetectionMode;
    }
    if (sessionArgs.mountType != null && sessionArgs.mountType!.isNotEmpty) {
      mountType.value = sessionArgs.resolvedMountType;
    }
    if (mountType.value.isVibrationDisabled) {
      isVibrationGateEnabled.value = false;
      _vibrationSubscription?.cancel();
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

    _audioLevelSubscription = _audioLevelService.decibelStream.listen(
      (double db) {
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

        _checkPunchDetection();

        // Update previous frame decibels for instantaneous derivative calculation
        _prevFrameDb = db;
      },
      onError: (Object error) {
        detectionStatusText.value = 'Microphone error — check permissions';
      },
    );
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
  bool _isAudioTransient() {
    final double db = liveDecibelLevel.value;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    // SIMULTANEOUS PLAYBACK + LISTEN WITHOUT GATING:
    // Microphone punch detection operates 100% continuously and ungated.
    // Hardware Acoustic Echo Cancellation (echoCancel: true) in RecordConfig filters speaker echo natively.
    // (TTS speaker echo gating disabled for simultaneous callouts & immediate punch detection).

    // Sync parameters with live settings
    _adaptiveBaseline.spikeThresholdDb = minAudioPunchSpikeDb.value;
    _adaptiveBaseline.absoluteMinFloorDb = minPunchAudioDb.value;
    _adaptiveBaseline.refractoryMs = sessionMode.value == DetectionMode.audio
        ? 140
        : 160;
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

    if (confirmedSpike == null) {
      return false;
    }

    final double spikeIntensity = confirmedSpike.spikeHeight;
    final int spikeTimeMs = confirmedSpike.timestampMs;

    final int audioRefractoryMs = sessionMode.value == DetectionMode.audio
        ? 140
        : 160;
    final bool isAudioInRefractory =
        (nowMs - _lastAudioPunchTimestampMs < audioRefractoryMs);

    final double effectiveTargetDb = customTargetAudioDb.value > 0
        ? customTargetAudioDb.value
        : (staticCalibratedAudioDb.value + minAudioPunchSpikeDb.value);

    // Audio target check: Must strictly meet both the onset envelope target and effective decibel floor
    final bool isAudioTargetReached =
        confirmedSpike.isTargetMet && confirmedSpike.peakDb >= effectiveTargetDb;

    if (!isAudioInRefractory && isAudioTargetReached) {
      _lastAudioPunchTimestampMs = spikeTimeMs;
      _lastPendingAudioSpikeMs = spikeTimeMs;
      _lastPendingAudioSpikeDb = confirmedSpike.peakDb;
    } else {
      _lastPendingAudioSpikeMs = 0;
      _lastPendingAudioSpikeDb = 0.0;
    }

    final bool hasRecentVibe = _vibrationService.hasRecentVibration(
      nowMs,
      maxAgeMs: 600,
    );
    final bool isVibeDisabled = isVibrationEffectivelyDisabled;

    final matrixEvaluator = TriSensorMatrixEvaluator(
      strongAudioSpikeDb: minAudioPunchSpikeDb.value,
      strongVibrationMag: minVibrationThreshold.value,
      requireVisionConfirmation: isVisionConfirmationRequired.value,
      isVibrationDisabled: isVibeDisabled,
      isPoleMount: mountType.value.isVibrationDisabled,
    );
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
    final bool isVibeCoincident = peakVibeTime > 0 &&
        (spikeTimeMs - peakVibeTime).abs() <= 120;
    final double peakVibeInWindow = isVibeCoincident
        ? _vibrationService.recentPeakVibrationMagnitude
        : 0.0;
    final double effectiveVibeMag = max(
      peakVibeInWindow,
      liveVibrationMagnitude.value,
    );

    final matrixResult = matrixEvaluator.evaluate(
      audioSpikeDb: isAudioTargetReached ? spikeIntensity : 0.0,
      vibrationMag: effectiveVibeMag,
      isCameraAvailable: isCamAvailable,
      isCameraConfirmed: isCamConfirmed,
      isCameraRejected: isCamRejected,
      timestampMs: spikeTimeMs,
    );

    // Unconditionally log EVERY detected audio spike into recordedSpikesHistory with rich telemetry
    final String vibeDetail = isVibeDisabled
        ? 'Vibe: Disabled (${mountType.value.isVibrationDisabled ? "Pole Mount" : "Vibe Gate OFF"})'
        : (hasRecentVibe || effectiveVibeMag >= minVibrationThreshold.value
              ? 'Vibe: Peak ${effectiveVibeMag.toStringAsFixed(2)} m/s² (Current: ${liveVibrationMagnitude.value.toStringAsFixed(2)} m/s², Thresh: ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²)'
              : 'Vibe: Peak ${effectiveVibeMag.toStringAsFixed(2)} m/s² (Below ${minVibrationThreshold.value.toStringAsFixed(2)} m/s², Current: ${liveVibrationMagnitude.value.toStringAsFixed(2)} m/s²)');

    final String audioDetail =
        'Audio: ${confirmedSpike.peakDb.toStringAsFixed(1)} dB '
        '(Base: ${confirmedSpike.baselineDb.toStringAsFixed(1)} dB, '
        'Rise: +${spikeIntensity.toStringAsFixed(1)} dB, '
        'Target: ${effectiveTargetDb.round()} dB)';

    String visionDetail = '';
    if (sessionMode.value.requiresCamera) {
      final int conf = evalResult?.confidenceScore.round() ?? 0;
      final String arm = (evalResult?.confirmedArm ?? 'none').toUpperCase();
      visionDetail = ' | Cam: $conf% ($arm Arm, Confirmed: $isCamConfirmed)';
    }

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
    } else if (sessionMode.value == DetectionMode.audioVibration) {
      final bool isVibeValid = isVibeDisabled || hasRecentVibe || effectiveVibeMag >= minVibrationThreshold.value;
      if (isAudioInRefractory) {
        isRejected = true;
        decisionCode = 'VIBE_REFRACTORY';
        reasonLabel = 'Cooldown refractory period';
      } else if (isVibeValid) {
        isValidPunch = true;
        decisionCode = isVibeDisabled ? 'AUDIO_POLE_DUAL' : 'AUDIO_VIBE_DUAL';
        reasonLabel = isVibeDisabled ? 'Vibration Bypass' : 'Audio + Vibration confirmed';
      } else {
        isRejected = true;
        decisionCode = 'VIBE_BELOW_THRESHOLD';
        reasonLabel = 'Vibration below ${minVibrationThreshold.value.toStringAsFixed(2)} m/s²';
      }
    } else if (sessionMode.value == DetectionMode.fusion) {
      if (isAudioInRefractory) {
        isRejected = true;
        decisionCode = 'FUSION_REFRACTORY';
        reasonLabel = 'Cooldown refractory period';
      } else {
        isValidPunch = matrixResult.isValidPunch;
        isCandidate = matrixResult.isCandidate;
        isRejected = matrixResult.isRejected;
        decisionCode = matrixResult.combinationCode;
        reasonLabel = matrixResult.reasonLabel;
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
      refractoryElapsedMs: (spikeTimeMs - _lastPunchTimestampMs).clamp(0, 99999),
    );
    _recordTelemetryEvent(telemetryEvent);

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

    // MODE 1: Audio Only Mode -> Increments punch count on valid audio spike alone!
    if (sessionMode.value == DetectionMode.audio) {
      _registerPunch(
        spikeTimeMs,
        '★ PUNCH CONFIRMED! (${confirmedSpike.peakDb.round()} dB — Audio Only)',
        telemetryLog: 'Mode: AUDIO_ONLY | $audioDetail',
      );
      _lastPendingAudioSpikeMs = 0;
      _triggerPunchHaptic();
      return true;
    }

    // MODE 2: Audio + Vibration Dual Mode -> Requires BOTH Audio AND Physical Phone Vibration!
    if (sessionMode.value == DetectionMode.audioVibration) {
      _registerPunch(
        spikeTimeMs,
        '★ PUNCH CONFIRMED! (${confirmedSpike.peakDb.round()} dB — Audio + Vibration)',
        telemetryLog: 'Mode: AUDIO_VIBRATION | $audioDetail | $vibeDetail',
      );
      _lastPendingAudioSpikeMs = 0;
      _triggerPunchHaptic();
      return true;
    }

    // MODE 3: Tri-Sensor Fusion Mode -> Evaluated by TriSensorMatrixEvaluator
    if (sessionMode.value == DetectionMode.fusion) {
      if (!isValidPunch || isAudioInRefractory || !matrixResult.isValidPunch) {
        if (matrixResult.isCandidate) {
          detectionStatusText.value =
              'Candidate Impact (${matrixResult.reasonLabel})';
          developer.log(
            '[TRI-SENSOR MATRIX LOG] 🟡 CANDIDATE — Code: ${matrixResult.combinationCode} | Reason: ${matrixResult.reasonLabel} | Audio:${matrixResult.audioState.name}, Vibe:${matrixResult.vibrationState.name}, Cam:${matrixResult.cameraState.name}',
            name: 'PromptSessionController',
          );
        } else if (matrixResult.isRejected) {
          detectionStatusText.value =
              'Impact Rejected (${matrixResult.reasonLabel})';
          developer.log(
            '[TRI-SENSOR MATRIX LOG] 🔴 REJECTED — Code: ${matrixResult.combinationCode} | Reason: ${matrixResult.reasonLabel} | Audio:${matrixResult.audioState.name}, Vibe:${matrixResult.vibrationState.name}, Cam:${matrixResult.cameraState.name}',
            name: 'PromptSessionController',
          );
        }
        return false;
      }

      final String activeArm =
          liveEvaluationResult.value?.confirmedArm ?? 'right';
      _registerPunch(
        spikeTimeMs,
        '★ PUNCH CONFIRMED! (${matrixResult.reasonLabel})',
        arm: activeArm,
        telemetryLog:
            'Mode: FUSION (${matrixResult.reasonLabel}) | $audioDetail | $vibeDetail$visionDetail',
      );
      _lastPendingAudioSpikeMs = 0;
      _triggerPunchHaptic();
      developer.log(
        '[TRI-SENSOR MATRIX LOG] 🟢 VALID PUNCH REGISTERED — Code: ${matrixResult.combinationCode} | Reason: ${matrixResult.reasonLabel} | Audio:${matrixResult.audioState.name}, Vibe:${matrixResult.vibrationState.name}, Cam:${matrixResult.cameraState.name}',
        name: 'PromptSessionController',
      );
    }

    if (AppConstants.testingPromptSessionLogs) {
      developer.log(
        '[AUDIO] Impulse Spike CONFIRMED (Fast Drop >=50% within 100ms) — ${confirmedSpike.peakDb.round()} dB (+${spikeIntensity.toStringAsFixed(1)}dB spike over ${confirmedSpike.baselineDb.round()}dB baseline)',
      );
    }
    return true;
  }

  void checkPunchDetectionForTesting() => _checkPunchDetection();

  /// Check for real punch detection based on active session mode
  void _checkPunchDetection() {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    // Dynamic Session Start Warmup: ignore audio & vision spikes from screen transition / tap sound
    final int warmupMs = AppConstants.warmUpDurationInMiliSeconds.round();
    if (nowMs - _sessionStartTimeMs < warmupMs) {
      detectionStatusText.value = 'Warming Up Engine…';
      return;
    }

    if (isSettingsViewActive) {
      if (sessionMode.value.requiresMicrophone) {
        _isAudioTransient();
      }
      if (!detectionStatusText.value.startsWith('Impact Rejected')) {
        detectionStatusText.value = 'Punch Detection Disabled (Settings Open)';
      }
      return;
    }

    if (sessionMode.value.requiresMicrophone) {
      _isAudioTransient();
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
      onApplyEnvironmentPreset: applyEnvironmentPreset,
      onSpikeDbChanged: (double value) {
        minAudioPunchSpikeDb.value = value;
        _adaptiveBaseline.spikeThresholdDb = value;
        final double minAllowedTarget =
            (AppConstants.minCalibratedTargetPunchDb + AppConstants.minAudioSpikeSliderDb)
                .clamp(40.0, AppConstants.minCalibratedTargetPunchDb);
        final double newTarget = (staticCalibratedAudioDb.value + value).clamp(
          minAllowedTarget,
          AppConstants.maxCalibratedTargetPunchDb,
        );
        customTargetAudioDb.value = newTarget.roundToDouble();
        _adaptiveBaseline.fixedAudioTargetDb = newTarget.roundToDouble();
      },
      isVibrationDisabled: isVibrationEffectivelyDisabled.obs,
      isVibrationGateEnabled: isVibrationGateEnabled,
      onToggleVibrationGate: toggleVibrationGate,
      onEvaluateAutoConfig: evaluateAutoConfig,
      onApplyAutoConfig: applyAutoConfig,
      isPersonFocusEnabled: isPersonFocusEnabled,
      onTogglePersonFocus: togglePersonFocus,
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
    final double calculatedTarget =
        (baseDb + result.recommendedSpikeDb).clamp(
      AppConstants.minCalibratedTargetPunchDb,
      AppConstants.maxCalibratedTargetPunchDb,
    );
    final double finalTarget = result.recommendedTargetAudioDb > 0 &&
            (result.recommendedTargetAudioDb - calculatedTarget).abs() <= 1.0
        ? result.recommendedTargetAudioDb
        : calculatedTarget.roundToDouble();

    customTargetAudioDb.value = finalTarget;
    _adaptiveBaseline.fixedAudioTargetDb = finalTarget;

    // 2. Vibration
    minVibrationThreshold.value = result.recommendedVibrationThreshold;
    toggleVibrationGate(result.recommendedVibrationGateEnabled);

    // 3. Vision Confirmation
    isVisionConfirmationRequired.value = result.recommendedVisionRequired;

    final String logMsg =
        '⚙️ [AUTO-CONFIG APPLIED] Audio Target: ${finalTarget.round()} dB '
        '(Spike: +${result.recommendedSpikeDb.round()} dB) | '
        'Vibe: ${result.recommendedVibrationThreshold.toStringAsFixed(2)} m/s² '
        '(Gate: ${result.recommendedVibrationGateEnabled ? "ON" : "OFF"}) | '
        'Vision: ${result.recommendedVisionRequired ? "REQUIRED" : "OPTIONAL"}';
    _insertSpikeLog(logMsg);

    developer.log(logMsg, name: 'PromptSessionController');
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
        name: 'PromptSessionController',
      );
      return;
    }
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
    _lastPunchTimestampMs = nowMs;
    // Reset audio & vibration state so the exact same strike cannot re-trigger a second punch
    _lastAudioPunchTimestampMs = nowMs;
    _lastPendingAudioSpikeMs = 0;
    _vibrationService.resetMagnitude();
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
    if (AppConstants.testingPromptSessionLogs) {
      developer.log(
        "[REGISTER] Punch counted! Total: ${punchCount.value} | Reason: $status${telemetryLog != null ? ' | $telemetryLog' : ''}",
        name: 'PromptSessionController',
      );
    }
    reactionMs.value = 280 + Random().nextInt(150);
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
          : ResolutionPreset.low;

      cameraController = CameraController(
        _activeCamera!,
        targetResolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
        fps: AppConstants.globalAudioSampleIntervalMs,
      );

      await cameraController!.initialize();
      isCameraInitialized.value = true;
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

        try {
          if (cameraController != null && _activeCamera != null) {
            final inputImage = _convertCameraImage(image, _activeCamera!);
            if (inputImage != null && _poseDetector != null) {
              // With several people in view, hide everyone but the nearest
              // so the pose detector (and skeleton) stays on them.
              InputImage poseInput = inputImage;
              if (isPersonFocusEnabled.value) {
                final PersonFocusResult focus = await _personFocus.prepare(
                  inputImage,
                );
                poseInput = focus.image;
              }
              final List<Pose> poses = await _poseDetector!.processImage(
                poseInput,
              );
              if (poses.isNotEmpty) {
                livePose.value = poses.first;
                _analyzeLivePose(poses.first);
              } else {
                // Camera covered or no body visible -> Reset pose & evaluation scores to 0!
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
  ///   - Torso rotation contraction & head-drop bonus
  void _analyzeLivePose(Pose pose) {
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final lEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rEye = pose.landmarks[PoseLandmarkType.rightEye];
    final lEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rEar = pose.landmarks[PoseLandmarkType.rightEar];

    // ─── USER IN FRAME & FACE / SHOULDER VALIDATION ───────────────────────
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
    } else {
      // Relaxed Single-Point Validation:
      // Validates user in frame if AT LEAST ONE landmark of face (nose, eye, ear, mouth)
      // OR shoulder (left or right) is detected in frame with likelihood >= 0.20.
      final bool hasShoulder =
          (lShoulder != null && lShoulder.likelihood >= 0.20) ||
          (rShoulder != null && rShoulder.likelihood >= 0.20);
      final bool hasFace =
          (nose != null && nose.likelihood >= 0.20) ||
          (lEye != null && lEye.likelihood >= 0.20) ||
          (rEye != null && rEye.likelihood >= 0.20) ||
          (lEar != null && lEar.likelihood >= 0.20) ||
          (rEar != null && rEar.likelihood >= 0.20) ||
          (pose.landmarks[PoseLandmarkType.leftEyeInner]?.likelihood ?? 0) >=
              0.20 ||
          (pose.landmarks[PoseLandmarkType.rightEyeInner]?.likelihood ?? 0) >=
              0.20 ||
          (pose.landmarks[PoseLandmarkType.leftMouth]?.likelihood ?? 0) >=
              0.20 ||
          (pose.landmarks[PoseLandmarkType.rightMouth]?.likelihood ?? 0) >=
              0.20;

      if (!hasShoulder && !hasFace) {
        _setInvalidEvaluationResult(
          'User not in frame: No face or shoulder landmark detected',
        );
        return;
      }
    }

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
    if (AppConstants.testingPromptSessionLogs) {
      developer.log(tempResult.debugTelemetry, name: 'PromptSessionController');
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
      final bool isNewArmAction = tempResult.confirmedArm != _lastLoggedCandidateArm;
      final bool isCandidateThrottled = (nowMs - _lastCandidateLogMs) < 350;
      if (sessionMode.value == DetectionMode.camera || isNewArmAction || !isCandidateThrottled) {
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

  void _setInvalidEvaluationResult(String reason) {
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

  final Rx<TemporalPunchEvaluationResult?> liveEvaluationResult =
      Rx<TemporalPunchEvaluationResult?>(null);

  final RxBool isExtraFaceRestrictionsEnabled =
      AppConstants.enableExtraFaceRestrictions.obs;

  void toggleExtraFaceRestrictions(bool enable) {
    AppConstants.enableExtraFaceRestrictions = enable;
    isExtraFaceRestrictionsEnabled.value = enable;
  }

  void showLiveTelemetrySheet(BuildContext context) {
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

  void _initTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      // On iOS: Configure Audio Session Category so TTS audio playback routes to connected Bluetooth Earbuds/Headphones!
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );

      _flutterTts.setStartHandler(() {
        _isTtsSpeaking = true;
        _lastTtsSpeechStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      });

      _flutterTts.setCompletionHandler(() {
        _isTtsSpeaking = false;
        _lastTtsSpeechEndTimeMs = DateTime.now().millisecondsSinceEpoch;
      });

      _flutterTts.setErrorHandler((msg) {
        _isTtsSpeaking = false;
        _lastTtsSpeechEndTimeMs = DateTime.now().millisecondsSinceEpoch;
      });

      _flutterTts.setCancelHandler(() {
        _isTtsSpeaking = false;
        _lastTtsSpeechEndTimeMs = DateTime.now().millisecondsSinceEpoch;
      });
    } catch (e) {
      developer.log('TTS init error: $e', name: 'PromptSessionController');
    }
  }

  void _speakSingleNumber(int number) async {
    if (!isTtsEnabled.value) return;
    try {
      _isTtsSpeaking = true;
      _lastTtsSpeechStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      await _flutterTts.stop();
      await _flutterTts.speak('$number');
    } catch (e) {
      _isTtsSpeaking = false;
      developer.log('TTS speak error: $e', name: 'PromptSessionController');
    }
  }

  void _tickComboStep() {
    // If we reached the end of the current active combo sequence, pick a new random combination from comboList
    if (_currentComboStepIndex >= _activeCombo.length) {
      final List<List<int>> list = AppConstants.comboList;
      _activeCombo = list[Random().nextInt(list.length)];
      _currentComboStepIndex = 0;
      currentComboSequence.assignAll(_activeCombo);
    }

    final int numberToSpeak = _activeCombo[_currentComboStepIndex];
    promptNumber.value = numberToSpeak;
    promptText.value = '$numberToSpeak'; // Show ONLY ONE number on UI

    _speakSingleNumber(numberToSpeak);
    _currentComboStepIndex++;
  }

  int get promptRotationIntervalMs {
    final String diff = difficulty.value.toLowerCase().trim();
    if (diff == 'advanced') return 300; // 0.3s cadence per number
    if (diff == 'intermediate') return 600; // 0.6s cadence per number
    return 1200; // 1.2s cadence per number - Beginner default
  }

  Timer? _promptWarmupTimer;

  void _startPromptRotation() {
    _promptTimer?.cancel();
    _promptWarmupTimer?.cancel();
    final int warmupMs = AppConstants.warmUpDurationInMiliSeconds.round();
    _promptWarmupTimer = Timer(Duration(milliseconds: warmupMs), () {
      if (isClosed) return;
      _currentComboStepIndex =
          _activeCombo.length; // Force fresh combo selection on session start
      _tickComboStep();
      _promptTimer?.cancel();
      _promptTimer = Timer.periodic(
        Duration(milliseconds: promptRotationIntervalMs),
        (timer) {
          _tickComboStep();
        },
      );
    });
  }

  double get averageFrameLatencyMs {
    if (_frameLatencyMsList.isEmpty) return 40.0;
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
    final result = SessionResultModel(
      totalPunches: punchCount.value,
      leftPunches: leftPunchCount.value,
      rightPunches: rightPunchCount.value,
      averageReactionTimeMs: reactionMs.value > 0
          ? reactionMs.value.toDouble()
          : 310.0,
      averageLatencyMs: averageFrameLatencyMs,
      accuracyPercentage: dynamicAccuracyPercentage,
      durationSeconds: durationSec,
      sessionType: 'prompt',
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

  @override
  void onClose() {
    resetSettingsGate();
    _elapsedTimer?.cancel();
    _promptTimer?.cancel();
    _promptWarmupTimer?.cancel();
    try {
      _flutterTts.stop().catchError((_) {});
    } catch (_) {}
    _audioLevelSubscription?.cancel();
    _audioLevelService.dispose();
    _stabilitySubscription?.cancel();
    _stabilityService.dispose();
    _poseDetector?.close();
    unawaited(_personFocus.close());
    AppConstants.personFocusEnabled = AppConstants.personFocusEnabledDefault;
    _stopAndDisposeCamera();
    super.onClose();
  }
}
