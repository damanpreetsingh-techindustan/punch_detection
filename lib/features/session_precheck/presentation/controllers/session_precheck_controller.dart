import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/monotonic_clock.dart';
import '../../../../core/widgets/common_permission_dialog.dart';
import '../../../../detection_core/calibration/ambient_floor.dart';

import '../../../../core/services/audio_level/audio_level_sample.dart';
import '../../../../core/services/audio_level/i_audio_level_service.dart';
import '../../../../core/services/audio_level/record_audio_level_service.dart';
import '../../../../core/services/device_stability/device_stability_models.dart';
import '../../../../core/services/device_stability/device_stability_service.dart';
import '../../../../core/services/device_stability/i_device_stability_service.dart';

import '../../../../core/enums/detection_enums.dart';

import '../../../workout_setup/presentation/controllers/workout_setup_controller.dart';

class SessionPreCheckController extends GetxController {
  PageController pageController = PageController();
  final RxInt currentStep = 0.obs;

  // Selected detection mode and mount type using strongly-typed enums
  final Rx<DetectionMode> selectedMode = DetectionMode.fusion.obs;
  final Rx<MountType> selectedMountType = MountType.wall.obs;
  final String sessionType; // 'prompt' or 'free'

  // Permissions state
  final RxBool micGranted = false.obs;
  final RxBool cameraGranted = false.obs;
  final RxBool storageGranted = true.obs;

  bool _isRequesting = false;

  // Real-time Audio Level Sensor Service (DIP: Injected abstract contract)
  final IAudioLevelService _audioLevelService;
  StreamSubscription<AudioLevelSample>? _audioLevelSubscription;

  // Device Stability & Motion Check State (DIP: Injected abstract contract)
  final IDeviceStabilityService _stabilityService;
  final Rx<DeviceStabilityMetrics> deviceStabilityMetrics =
      DeviceStabilityMetrics.initial().obs;
  final RxBool isDeviceStabilityEnabled =
      AppConstants.enableDeviceStabilityCheck.obs;
  StreamSubscription<DeviceStabilityMetrics>? _stabilitySubscription;

  // 5-Second Calibration & Live Audio Monitor State
  final RxInt decibels = 0.obs;
  final RxDouble calibrationProgress = 0.0.obs;
  final RxString noiseStatusText = 'Waiting for microphone…'.obs;
  final RxString calibrationButtonText = 'Start 5-second calibration'.obs;
  final RxBool isCalibrating = false.obs;
  Timer? _calibrationTimer;

  // Calibration data collection
  int _calibrationElapsedMs = 0;
  int _calibrationStartMs = 0;

  /// Every 10 ms block level seen during the 5 s calibration (raw, for logging).
  final List<TimedLevel> _calibrationBlocks = <TimedLevel>[];
  final RxList<double> decibelHistory = <double>[].obs;

  /// Loudest block of the calibration (display and logs only; not the target base).
  final RxDouble maxCalibratedDb = 0.0.obs;

  /// Room floor from the calibration: mean of the 20th–50th percentile blocks.
  final RxDouble avgAmbientDb = 48.0.obs;
  final RxDouble spikeThresholdDb = 20.0.obs;

  /// Result of the last completed calibration (null until one completes).
  AmbientFloorResult? _calibrationResult;

  /// Raw calibration data handed to the session so its recorder logs it.
  Map<String, Object?>? _calibrationReport;
  Map<String, Object?>? get calibrationReport => _calibrationReport;

  /// True while the mic has read the bottom of the scale for more than 1 s:
  /// it is not delivering audio, so a calibration would be meaningless.
  final RxBool isMicAtScaleFloor = false.obs;
  final MicFloorWatchdog _micFloorWatchdog = MicFloorWatchdog(
    floorDb: AppConstants.micScaleFloorDb,
    maxDurationMs: AppConstants.micFloorWarningMs,
  );

  static const AmbientFloorEstimator _floorEstimator = AmbientFloorEstimator(
    ignoreFirstMs: AppConstants.calibrationIgnoreFirstMs,
    lowPercentile: AppConstants.calibrationFloorLowPercentile,
    highPercentile: AppConstants.calibrationFloorHighPercentile,
  );

  // The live meter is refreshed at most every [_uiRefreshMs] with the loudest
  // block since the last refresh (blocks arrive every 10 ms).
  static const int _uiRefreshMs = 100;
  int _lastUiRefreshMs = 0;
  double _uiPeakDb = 0.0;

  SessionPreCheckController({
    this.sessionType = 'prompt',
    IAudioLevelService? audioLevelService,
    IDeviceStabilityService? stabilityService,
  }) : _audioLevelService =
           audioLevelService ??
           // Same capture path as the Free session, so calibration hears the
           // room exactly the way detection does.
           RecordAudioLevelService(
             enableSubBlockPcm: AppConstants.useSubBlockPcmLevels,
           ),
       _stabilityService = stabilityService ?? DeviceStabilityService();

  /// Returns true if all required permissions for the active mode are granted
  bool get hasRequiredPermissions {
    final mode = selectedMode.value;
    if (mode == DetectionMode.fusion) {
      return micGranted.value && cameraGranted.value;
    } else if (mode == DetectionMode.audio ||
        mode == DetectionMode.audioVibration) {
      return micGranted.value;
    } else if (mode == DetectionMode.camera) {
      return cameraGranted.value;
    } else if (mode == DetectionMode.vibration) {
      return true; // Accelerometer / vibration sensor requires no runtime privacy permissions
    }
    return micGranted.value && cameraGranted.value;
  }

  /// Returns true if the permission step should be shown in precheck
  bool get needsPermissionsStep => !hasRequiredPermissions;

  /// Total setup steps: Dynamic based on permissions status, selected mode, and AppConstants.showAllFeatures
  int get totalSteps {
    final mode = selectedMode.value;
    final int baseSteps;
    if (AppConstants.showAllFeatures) {
      if (mode == DetectionMode.fusion) {
        baseSteps = 3;
      } else if (mode == DetectionMode.vibration) {
        baseSteps = 1;
      } else if (mode == DetectionMode.camera) {
        baseSteps = 2;
      } else {
        baseSteps = 2;
      }
    } else {
      if (mode == DetectionMode.fusion ||
          mode == DetectionMode.audio ||
          mode == DetectionMode.audioVibration) {
        baseSteps = 2;
      } else {
        baseSteps = 1;
      }
    }
    return needsPermissionsStep ? (baseSteps + 1) : baseSteps;
  }

  @override
  void onInit() {
    super.onInit();
    AppConstants.changeSettingToDefault();
    selectedMountType.value = MountType.wall;
    pageController = PageController();
    checkPermissions();
    _startDeviceStabilityMonitor();
  }

  void _startDeviceStabilityMonitor() {
    _stabilitySubscription?.cancel();
    _stabilityService.startMonitoring();
    _stabilitySubscription = _stabilityService.metricsStream.listen((metrics) {
      deviceStabilityMetrics.value = metrics;
    });
  }

  /// Effortlessly enable or disable device stability tracking at runtime
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

  /// Starts real-time audio monitoring from injected audio level service
  Future<void> _startLiveAudioMonitor() async {
    _audioLevelSubscription?.cancel();

    final bool started = await _audioLevelService.startMonitoring(
      sampleIntervalMs: AppConstants.globalAudioSampleIntervalMs,
    );
    if (!started) {
      noiseStatusText.value = 'Microphone permission required';
      return;
    }

    _audioLevelSubscription = _audioLevelService.sampleStream.listen(
      onAudioSample,
      onError: (Object error) {
        noiseStatusText.value = 'Microphone error — check permissions';
      },
    );

    developer.log(
      'Pre-check audio service: ${_audioLevelService.diagnostics}',
      name: 'SessionPreCheckController',
    );
    noiseStatusText.value = 'Live audio monitoring active';
  }

  /// Handles one microphone block (10 ms with the PCM path). Public so tests
  /// can feed blocks with explicit times.
  void onAudioSample(AudioLevelSample sample) {
    final double safeDb = sample.db;
    isMicAtScaleFloor.value = _micFloorWatchdog.update(
      safeDb,
      sample.timestampMs,
    );
    if (isCalibrating.value &&
        sample.timestampMs >= _calibrationStartMs &&
        sample.timestampMs <= _calibrationStartMs + _calibrationDurationMs) {
      _calibrationBlocks.add(TimedLevel(sample.timestampMs, safeDb));
    }

    // Live meter: loudest block since the last refresh, at most every 100 ms.
    _uiPeakDb = max(_uiPeakDb, safeDb);
    if (sample.timestampMs - _lastUiRefreshMs < _uiRefreshMs) return;
    _lastUiRefreshMs = sample.timestampMs;
    final double shownDb = _uiPeakDb;
    _uiPeakDb = 0.0;

    decibelHistory.add(shownDb);
    if (decibelHistory.length > 50) {
      decibelHistory.removeAt(0);
    }
    final int db = shownDb.round();
    decibels.value = db;
    if (!isCalibrating.value) {
      noiseStatusText.value = 'Live mic: $db dB';
    }
  }

  static const int _calibrationDurationMs = 5000;

  /// Room floor and target from the collected blocks; logs the raw values.
  void _finishCalibration() {
    final AmbientFloorResult result = _floorEstimator.estimate(
      _calibrationBlocks,
      startMs: _calibrationStartMs,
    );
    _calibrationResult = result;
    avgAmbientDb.value = result.floorDb;
    maxCalibratedDb.value = result.maxDb;
    spikeThresholdDb.value = AppConstants.defaultAudioSpikeThresholdDb;

    _calibrationReport = <String, Object?>{
      ...result.toMap(),
      'startMs': _calibrationStartMs,
      'durationMs': _calibrationDurationMs,
      'ignoreFirstMs': AppConstants.calibrationIgnoreFirstMs,
      'lowPercentile': AppConstants.calibrationFloorLowPercentile,
      'highPercentile': AppConstants.calibrationFloorHighPercentile,
      'micAtScaleFloor': isMicAtScaleFloor.value,
      'audioService': _audioLevelService.diagnostics,
      // Raw block levels: [ms since calibration start, app-dB].
      'blocks': <List<num>>[
        for (final TimedLevel block in _calibrationBlocks)
          <num>[block.tMs - _calibrationStartMs, block.db],
      ],
    };
    developer.log(
      'Calibration: ${result.toMap()} from ${_calibrationBlocks.length} blocks',
      name: 'SessionPreCheckController',
    );
    developer.log(
      'Calibration raw blocks (ms, dB): '
      '${_calibrationBlocks.map((TimedLevel b) => '${b.tMs - _calibrationStartMs}:${b.db.toStringAsFixed(1)}').join(' ')}',
      name: 'SessionPreCheckController',
    );
  }

  /// Base of the legacy audio target: the calibrated room floor, or the
  /// default ambient level when no calibration completed.
  double get calibratedBaseDb => _calibrationResult?.floorDb ?? avgAmbientDb.value;

  /// Legacy audio target handed to the session: floor + default spike,
  /// clamped to the unchanged min/max target constants.
  double get initialTargetDb =>
      (calibratedBaseDb + AppConstants.defaultAudioSpikeThresholdDb)
          .clamp(
            AppConstants.minCalibratedTargetPunchDb,
            AppConstants.maxCalibratedTargetPunchDb,
          )
          .roundToDouble();

  /// Test hook: run the end-of-calibration computation on given blocks.
  void calibrateFromBlocksForTesting(
    List<TimedLevel> blocks, {
    required int startMs,
  }) {
    _calibrationStartMs = startMs;
    _calibrationBlocks
      ..clear()
      ..addAll(blocks);
    _finishCalibration();
  }

  Future<void> checkPermissions() async {
    final mic = await Permission.microphone.status;
    final cam = await Permission.camera.status;

    micGranted.value = mic.isGranted;
    cameraGranted.value = cam.isGranted;

    if (mic.isGranted) {
      _startLiveAudioMonitor();
    }
  }

  Future<void> requestMicrophone() async {
    if (_isRequesting) return;
    _isRequesting = true;
    try {
      final isGranted = await CommonPermissionDialog.requestAndCheckPermission(
        Permission.microphone,
        permissionName: 'Microphone',
      );
      micGranted.value = isGranted;
      if (isGranted) {
        _startLiveAudioMonitor();
      }
    } finally {
      _isRequesting = false;
    }
  }

  Future<void> requestCamera() async {
    if (_isRequesting) return;
    _isRequesting = true;
    try {
      final isGranted = await CommonPermissionDialog.requestAndCheckPermission(
        Permission.camera,
        permissionName: 'Camera',
      );
      cameraGranted.value = isGranted;
    } finally {
      _isRequesting = false;
    }
  }

  Future<void> requestPermissions() async {
    if (_isRequesting) return;
    _isRequesting = true;
    try {
      final Map<Permission, String> mapToRequest = {};
      if (selectedMode.value.requiresMicrophone && !micGranted.value) {
        mapToRequest[Permission.microphone] = 'Microphone';
      }
      if (selectedMode.value.requiresCamera && !cameraGranted.value) {
        mapToRequest[Permission.camera] = 'Camera';
      }

      if (mapToRequest.isNotEmpty) {
        final results =
            await CommonPermissionDialog.checkAndRequestMultiplePermissions(
              permissionNames: mapToRequest,
            );
        if (results.containsKey(Permission.microphone)) {
          micGranted.value = results[Permission.microphone] ?? false;
          if (micGranted.value) {
            _startLiveAudioMonitor();
          }
        }
        if (results.containsKey(Permission.camera)) {
          cameraGranted.value = results[Permission.camera] ?? false;
        }
      }
    } finally {
      _isRequesting = false;
    }
  }

  void selectMode(dynamic mode) {
    if (mode is DetectionMode) {
      selectedMode.value = mode;
    } else if (mode is String) {
      selectedMode.value = DetectionMode.fromString(mode);
    }
  }

  void selectMountType(dynamic mountType) {
    if (mountType is MountType) {
      selectedMountType.value = mountType;
    } else if (mountType is String) {
      selectedMountType.value = MountType.fromString(mountType);
    }
  }

  void onPageChanged(int index) {
    currentStep.value = index;
  }

  Future<void> nextStep() async {
    // Step 1: Permission check
    if (currentStep.value == 0 && needsPermissionsStep) {
      final bool hadMissingPermissions = !hasRequiredPermissions;

      final DetectionMode mode = selectedMode.value;
      if (mode != DetectionMode.vibration) {
        if ((mode.requiresMicrophone && !micGranted.value) ||
            (mode.requiresCamera && !cameraGranted.value)) {
          await requestPermissions();
        }

        if (mode.requiresMicrophone && !micGranted.value) {
          Get.snackbar(
            'Microphone Required',
            'Microphone permission is required for audio punch detection.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
        if (mode.requiresCamera && !cameraGranted.value) {
          Get.snackbar(
            'Camera Required',
            'Camera permission is required for camera vision tracking.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      }
      // IMPORTANT:
      // Permission page is removed from PageView after permission is granted.
      // Therefore the new PageView index 0 is Mode Selection.
      if (hadMissingPermissions && hasRequiredPermissions) {
        currentStep.value = 0;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (pageController.hasClients) {
            pageController.jumpToPage(0);
          }
        });

        return;
      }
    }
    final maxStepIndex = totalSteps - 1;

    if (currentStep.value < maxStepIndex) {
      final targetStep = currentStep.value + 1;
      if (pageController.hasClients) {
        pageController.animateToPage(
          targetStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        currentStep.value = targetStep;
      }
    } else {
      // Setup complete -> Stop PreCheck audio monitor immediately before navigating so mic is completely free!
      _audioLevelSubscription?.cancel();
      _audioLevelSubscription = null;
      await _audioLevelService.stopMonitoring();

      // DYNAMIC AUDIO TARGET:
      // Base audio is the calibrated room floor (20th–50th percentile of the
      // 10 ms blocks), so the target sits above the room instead of below it.
      // Initial target is Base + Default Spike Threshold (+8 dB, e.g. 77 -> 85 dB).
      // Strictly clamped between minCalibratedTargetPunchDb and maxCalibratedTargetPunchDb.
      final double baseAudioDb = calibratedBaseDb;
      final double defaultSpike = AppConstants.defaultAudioSpikeThresholdDb;
      final double initialTarget = initialTargetDb;

      final double safeMaxAudioDb = min(
        AppConstants.maxCalibratedTargetPunchDb,
        max(initialTarget, maxCalibratedDb.value.round().toDouble()),
      );

      String? resolvedDifficulty;
      if (Get.isRegistered<WorkoutSetupController>()) {
        resolvedDifficulty =
            Get.find<WorkoutSetupController>().difficulty.value;
      }

      final args = SessionArguments(
        sessionType: sessionType,
        promptMode: selectedMode.value.id,
        mountType: selectedMountType.value.id,
        difficulty: resolvedDifficulty,
        maxAudioDb: safeMaxAudioDb,
        avgAmbientDb: avgAmbientDb.value,
        spikeThresholdDb: defaultSpike,
        targetPunchDb: initialTarget,
        calibratedDb: baseAudioDb,
        calibrationReport: _calibrationReport,
      );
      if (sessionType == 'prompt') {
        AppNavigator.toPromptSession(arguments: args);
      } else {
        AppNavigator.toFreeSession(arguments: args);
      }
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      final targetStep = currentStep.value - 1;
      if (pageController.hasClients) {
        pageController.animateToPage(
          targetStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        currentStep.value = targetStep;
      }
    } else {
      _audioLevelSubscription?.cancel();
      _audioLevelSubscription = null;
      _audioLevelService.stopMonitoring();
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back();
      } else {
        AppNavigator.toHome();
      }
    }
  }

  void start5sCalibration() {
    if (isCalibrating.value) return;

    isCalibrating.value = true;
    calibrationButtonText.value = 'Sampling 5s environment…';
    noiseStatusText.value = 'Capturing ambient environment baseline…';
    calibrationProgress.value = 0.0;
    _calibrationBlocks.clear();
    _calibrationResult = null;
    _calibrationReport = null;
    maxCalibratedDb.value = 0.0;
    avgAmbientDb.value = 48.0;
    spikeThresholdDb.value = 20.0;
    _calibrationElapsedMs = 0;
    _calibrationStartMs = MonotonicClock.epochMs();

    _calibrationTimer?.cancel();
    _calibrationTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) {
      _calibrationElapsedMs += 250;

      calibrationProgress.value =
          (_calibrationElapsedMs / _calibrationDurationMs).clamp(0.0, 1.0);

      if (_calibrationElapsedMs >= _calibrationDurationMs) {
        calibrationProgress.value = 1.0;
        _calibrationTimer?.cancel();

        // Room floor = mean of the 20th–50th percentile blocks (first 400 ms
        // dropped), not the mean or the max.
        _finishCalibration();

        final int safeBase = calibratedBaseDb.round();
        final int initialTarget = initialTargetDb.round();

        noiseStatusText.value =
            'Calibrated — Floor: $safeBase dB, Target: $initialTarget dB (+${AppConstants.defaultAudioSpikeThresholdDb.round()} dB)';

        calibrationButtonText.value = 'Calibration complete';
        isCalibrating.value = false;

        Future.delayed(const Duration(milliseconds: 600), () {
          nextStep(); // Launch session!
        });
      }
    });
  }

  @override
  void onClose() {
    _audioLevelSubscription?.cancel();
    _audioLevelService.dispose();
    _calibrationTimer?.cancel();
    _stabilitySubscription?.cancel();
    _stabilityService.dispose();
    pageController.dispose();
    super.onClose();
  }
}
