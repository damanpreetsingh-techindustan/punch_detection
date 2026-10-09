import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/widgets/common_permission_dialog.dart';

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
  StreamSubscription<double>? _audioLevelSubscription;

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
  final List<double> _calibrationDbSamples = [];
  final RxList<double> decibelHistory = <double>[].obs;
  final RxDouble maxCalibratedDb = 0.0.obs;
  final RxDouble avgAmbientDb = 48.0.obs;
  final RxDouble spikeThresholdDb = 20.0.obs;

  SessionPreCheckController({
    this.sessionType = 'prompt',
    IAudioLevelService? audioLevelService,
    IDeviceStabilityService? stabilityService,
  }) : _audioLevelService = audioLevelService ?? RecordAudioLevelService(),
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

    _audioLevelSubscription = _audioLevelService.decibelStream.listen(
      (double safeDb) {
        decibelHistory.add(safeDb);
        if (decibelHistory.length > 50) {
          decibelHistory.removeAt(0);
        }

        // Controlled by AppConstants.useAvarageAudioFormate:
        // When enabled: Uses rolling average dB to prevent jitter on display.
        // When disabled: Uses raw instantaneous safeDb directly.
        final double effectiveDb = AppConstants.useAvarageAudioFormate
            ? (decibelHistory.isNotEmpty
                ? decibelHistory.reduce((a, b) => a + b) / decibelHistory.length
                : safeDb)
            : safeDb;
        final int db = effectiveDb.round();
        decibels.value = db;

        if (!isCalibrating.value) {
          noiseStatusText.value = 'Live mic: $db dB';
        } else {
          // Track highest dB reached on screen during calibration
          if (db > maxCalibratedDb.value) {
            maxCalibratedDb.value = db.toDouble();
          }
          // Ignore first 400ms so physical finger tap on "Start Calibration" button is ignored
          if (_calibrationElapsedMs >= 400) {
            _calibrationDbSamples.add(safeDb);
          }
        }
      },
      onError: (Object error) {
        noiseStatusText.value = 'Microphone error — check permissions';
      },
    );

    noiseStatusText.value = 'Live audio monitoring active';
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
      // Base audio is the max calibrated average dB recorded during pre-check.
      // Initial target is Base + Default Spike Threshold (+6 dB, e.g. 80 -> 86 dB).
      // Strictly clamped between minCalibratedTargetPunchDb and maxCalibratedTargetPunchDb.
      final double baseAudioDb = maxCalibratedDb.value > 0
          ? maxCalibratedDb.value
          : avgAmbientDb.value;
      final double defaultSpike = AppConstants.defaultAudioSpikeThresholdDb;
      final double initialTarget = (baseAudioDb + defaultSpike)
          .clamp(
            AppConstants.minCalibratedTargetPunchDb,
            AppConstants.maxCalibratedTargetPunchDb,
          )
          .roundToDouble();

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
    _calibrationDbSamples.clear();
    maxCalibratedDb.value = 0.0;
    avgAmbientDb.value = 48.0;
    spikeThresholdDb.value = 20.0;
    _calibrationElapsedMs = 0;

    _calibrationTimer?.cancel();
    _calibrationTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) {
      _calibrationElapsedMs += 250;

      calibrationProgress.value = (_calibrationElapsedMs / 5000.0).clamp(
        0.0,
        1.0,
      );

      if (_calibrationElapsedMs >= 5000) {
        calibrationProgress.value = 1.0;
        _calibrationTimer?.cancel();

        // Calculate AVERAGE ambient baseline from calibration samples
        final double avgDb = _calibrationDbSamples.isNotEmpty
            ? _calibrationDbSamples.reduce((a, b) => a + b) /
                  _calibrationDbSamples.length
            : 40.0;

        final double safeAvgDb = (avgDb.isNaN || !avgDb.isFinite)
            ? 40.0
            : avgDb;
        avgAmbientDb.value = safeAvgDb;

        // If maxCalibratedDb was not recorded, fallback to safeAvgDb
        if (maxCalibratedDb.value <= 0) {
          maxCalibratedDb.value = safeAvgDb;
        }

        // Default spike threshold (+6 dB)
        spikeThresholdDb.value = AppConstants.defaultAudioSpikeThresholdDb;

        final int safeBase = maxCalibratedDb.value.round();
        final int initialTarget =
            (maxCalibratedDb.value + AppConstants.defaultAudioSpikeThresholdDb)
                .clamp(
                  AppConstants.minCalibratedTargetPunchDb,
                  AppConstants.maxCalibratedTargetPunchDb,
                )
                .round();

        noiseStatusText.value =
            'Calibrated — Base: $safeBase dB, Target: $initialTarget dB (+${AppConstants.defaultAudioSpikeThresholdDb.round()} dB)';

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
