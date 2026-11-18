import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/widgets/common_permission_dialog.dart';

import '../../../../core/services/audio_level/i_audio_level_service.dart';
import '../../../../core/services/audio_level/record_audio_level_service.dart';
import '../../../../core/services/device_stability/device_stability_models.dart';
import '../../../../core/services/device_stability/device_stability_service.dart';
import '../../../../core/services/device_stability/i_device_stability_service.dart';

import '../../../../core/enums/detection_enums.dart';

import '../../../vision_detection/data/subject_enrollment/subject_capture_service.dart';
import '../../../vision_detection/domain/subject_lock/subject_enrollment_store.dart';

import '../../../workout_setup/presentation/controllers/workout_setup_controller.dart';

class SessionPreCheckController extends GetxController {
  PageController pageController = PageController();
  final RxInt currentStep = 0.obs;

  // Selected detection mode and mount type using strongly-typed enums
  final Rx<DetectionMode> selectedMode = DetectionMode.fusion.obs;
  final Rx<MountType> selectedMountType = MountType.wall.obs;
  final String sessionType; // 'prompt' or 'free'

  /// True for the one-screen "Get Ready" flow: photo and room calibration
  /// run together and the session starts on its own. False = the step-by-step
  /// pre-check (Developer mode).
  final bool express;

  /// Prompt drill pace passed from Home ('beginner' / 'intermediate' /
  /// 'advanced'); falls back to the Workout Setup page's choice.
  final String? difficulty;

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

  // Reference photo for the subject lock (free and prompt sessions, camera modes), taken
  // here so the session starts already locked on the user.
  final SubjectCaptureService captureService = SubjectCaptureService();

  /// True when the user skipped the photo: the session runs without the lock.
  final RxBool captureSkipped = false.obs;
  bool _captureHandedOver = false;

  // Express ("Get Ready") flow state
  final RxBool expressStarted = false.obs;
  final RxBool captureDone = false.obs;
  final RxBool calibrationDone = false.obs;
  final RxBool isLaunching = false.obs;

  /// 3-2-1 before the session opens; 0 = not counting.
  final RxInt launchCountdown = 0.obs;

  /// After GO: the camera is handed over and the session screen is opening.
  final RxBool isStartingSession = false.obs;

  /// A session finished a few minutes ago ([AppConstants.quickStartWindowMinutes])
  /// and a room check is saved: offer to skip the photo and the room check.
  final RxBool quickStartAvailable = false.obs;

  /// The user's choice on Get Ready (on by default when available).
  final RxBool useQuickStart = true.obs;

  /// Seconds of countdown for a quick start: time to step back into place.
  static const int quickStartCountdown = 5;

  static const int _countdownStepMs = 800;

  /// The first room check caught a loud moment (talking, a door): the room is
  /// measured once more.
  final RxBool roomRechecking = false.obs;
  bool _roomRetried = false;

  /// The room is loud enough to push the punch target to its upper limit, so
  /// soft punches may be missed. The session shows a hint.
  final RxBool roomNoisy = false.obs;
  Worker? _captureStepWorker;

  SessionPreCheckController({
    this.sessionType = 'prompt',
    this.express = false,
    this.difficulty,
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
    final int steps = baseSteps + (needsCaptureStep ? 1 : 0);
    return needsPermissionsStep ? (steps + 1) : steps;
  }

  /// The reference-photo step: free or prompt session (both use the same
  /// detection), a mode that uses the camera, subject lock on by default.
  bool get needsCaptureStep =>
      selectedMode.value.requiresCamera &&
      AppConstants.subjectLockEnabledDefault;

  /// Page index of the reference-photo step, or -1 when there is none.
  int get captureStepIndex {
    if (!needsCaptureStep) return -1;
    // Permissions (when shown), mode selection, then the photo.
    return (needsPermissionsStep ? 1 : 0) + 1;
  }

  @override
  void onInit() {
    super.onInit();
    AppConstants.changeSettingToDefault();
    _applySensitivity();
    selectedMountType.value = MountType.wall;
    pageController = PageController();
    if (express) {
      quickStartAvailable.value = _canQuickStart();
      unawaited(_prepareExpress());
    } else {
      checkPermissions();
    }
    _startDeviceStabilityMonitor();
  }

  /// The user's Sensitivity setting (Settings). Normal keeps the defaults.
  void _applySensitivity() {
    final preset = StorageService.to.sensitivity.preset;
    if (preset != null) {
      AppConstants.defaultImpactVibrationThreshold = preset.vibrationMag;
    }
  }

  double get _spikeThresholdDb =>
      StorageService.to.sensitivity.preset?.spikeDb ??
      AppConstants.defaultAudioSpikeThresholdDb;

  // ─── Express ("Get Ready") flow ────────────────────────────────────────────
  // One screen: the camera opens, the user taps "I'm ready", the reference
  // photo is taken and, while the user holds still, the room noise is
  // measured (every session, so a new room is never judged by an old check).
  // The 3-2-1 starts as soon as the photo is done and overlaps the end of the
  // room check; the session opens when both are finished.

  Future<void> _prepareExpress() async {
    await checkPermissions();
    if (!hasRequiredPermissions) await requestPermissions();
    if (isClosed || !cameraGranted.value) return;
    unawaited(captureService.start());
    _captureStepWorker = ever<CaptureStep>(
      captureService.step,
      _onExpressCaptureStep,
    );
  }

  bool _canQuickStart() {
    const window = AppConstants.quickStartWindowMinutes;
    if (window <= 0) return false;
    final last = StorageService.to.lastSessionEnd;
    if (last == null || StorageService.to.lastCalibration == null) {
      return false;
    }
    final age = DateTime.now().difference(last);
    return !age.isNegative && age.inMinutes < window;
  }

  /// "I'm ready" button.
  Future<void> startExpress() async {
    if (expressStarted.value) return;
    if (!hasRequiredPermissions) {
      await requestPermissions();
      if (!hasRequiredPermissions) {
        Get.snackbar(
          'Camera and microphone needed',
          'Allow both so KnockUp can see and hear your punches.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      _captureStepWorker ??= ever<CaptureStep>(
        captureService.step,
        _onExpressCaptureStep,
      );
      await captureService.start();
    }
    expressStarted.value = true;
    captureDone.value = false;
    calibrationDone.value = false;
    roomRechecking.value = false;
    roomNoisy.value = false;
    _roomRetried = false;

    if (quickStartAvailable.value && useQuickStart.value) {
      _quickStart();
      return;
    }

    if (captureService.isCameraUnavailable.value) {
      skipReferencePhoto();
      return;
    }
    captureReferencePhoto();
  }

  void _onExpressCaptureStep(CaptureStep step) {
    if (!expressStarted.value) return;
    // The user is still and quiet from here on: measure the room.
    if (step == CaptureStep.holdStill) _startExpressCalibration();
    if (step == CaptureStep.ready) {
      captureDone.value = true;
      HapticFeedback.mediumImpact();
      _startExpressCalibration();
      _maybeLaunch();
    }
  }

  void _startExpressCalibration() {
    if (calibrationDone.value || isCalibrating.value) return;
    start5sCalibration();
  }

  /// Starts the 3-2-1 once the photo is done; the room check may still run.
  void _maybeLaunch() {
    if (!express || isLaunching.value || !captureDone.value) return;
    unawaited(_runLaunchCountdown());
  }

  /// Same room, a few minutes later: reuse the last room check and run the
  /// session without the photo (exactly like "Skip photo"), after a 5 s
  /// countdown to get back into position.
  void _quickStart() {
    final saved = StorageService.to.lastCalibration!;
    maxCalibratedDb.value = saved.maxDb;
    avgAmbientDb.value = saved.avgDb;
    roomNoisy.value =
        saved.maxDb + _spikeThresholdDb >=
        AppConstants.maxCalibratedTargetPunchDb;
    calibrationDone.value = true;
    captureService.retake();
    captureSkipped.value = true;
    captureDone.value = true;
    unawaited(_runLaunchCountdown(from: quickStartCountdown));
  }

  Future<void> _runLaunchCountdown({int from = 3}) async {
    isLaunching.value = true;
    // Line the 3-2-1 up with the end of the room check, so GO is followed
    // by the session straight away instead of a silent wait (e.g. after
    // "Skip photo" the check has only just started). The "Stay quiet" ring
    // shows meanwhile.
    while (!calibrationDone.value &&
        isCalibrating.value &&
        5000 - _calibrationElapsedMs > _countdownStepMs * 3) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (isClosed) return;
    }
    for (var n = from; n >= 1; n--) {
      if (isClosed) return;
      launchCountdown.value = n;
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: _countdownStepMs));
    }
    if (isClosed) return;
    launchCountdown.value = 0;
    // The session needs the room check: wait for its last moments.
    while (!calibrationDone.value) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (isClosed) return;
    }
    HapticFeedback.heavyImpact();
    await launchSession();
  }

  /// Room check finished (express flow). A loud moment during the check
  /// (talking, a door) inflates the punch target, so the room is measured once
  /// more. With no microphone samples, the last good check is used instead of
  /// the fixed fallback.
  void _onExpressRoomChecked({required bool hadSamples}) {
    if (!hadSamples) {
      final saved = StorageService.to.lastCalibration;
      if (saved != null) {
        maxCalibratedDb.value = saved.maxDb;
        avgAmbientDb.value = saved.avgDb;
      }
    } else if (!_roomRetried &&
        maxCalibratedDb.value - avgAmbientDb.value >=
            AppConstants.roomCheckSpikeRetryDb) {
      _roomRetried = true;
      roomRechecking.value = true;
      HapticFeedback.lightImpact();
      start5sCalibration();
      return;
    }
    roomRechecking.value = false;
    roomNoisy.value =
        maxCalibratedDb.value + _spikeThresholdDb >=
        AppConstants.maxCalibratedTargetPunchDb;
    calibrationDone.value = true;
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
                  ? decibelHistory.reduce((a, b) => a + b) /
                        decibelHistory.length
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
    // No photo step for this mode any more: forget the photo.
    if (!needsCaptureStep) {
      captureService.retake();
      captureSkipped.value = false;
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
    // The camera is only open while the photo step is on screen.
    if (index == captureStepIndex) {
      unawaited(captureService.start());
    } else {
      unawaited(captureService.stop());
    }
  }

  /// Capture button: hold still → photo → learning (automatic).
  void captureReferencePhoto() {
    captureSkipped.value = false;
    captureService.beginCapture();
  }

  void retakeReferencePhoto() => captureService.retake();

  /// Skip button: the session runs without the subject lock.
  Future<void> skipReferencePhoto() async {
    captureService.retake();
    captureSkipped.value = true;
    if (express) {
      expressStarted.value = true;
      captureDone.value = true;
      _startExpressCalibration();
      _maybeLaunch();
      return;
    }
    await nextStep();
  }

  /// Hands the photo step's result to the session (store is read once by
  /// FreeSessionController). Nothing stored = the session takes the photo
  /// itself, as before.
  void _handOverReferencePhoto() {
    if (!needsCaptureStep) {
      SubjectEnrollmentStore.clear();
      return;
    }
    if (captureSkipped.value) {
      SubjectEnrollmentStore.put(const SubjectEnrollment.skipped());
      _captureHandedOver = true;
      return;
    }
    final result = captureService.takeLock();
    if (result == null) {
      SubjectEnrollmentStore.clear();
      return;
    }
    SubjectEnrollmentStore.put(
      SubjectEnrollment.captured(result.lock, result.photo),
    );
    _captureHandedOver = true;
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
      await launchSession();
    }
  }

  /// Setup complete: hands everything to the session and opens it.
  Future<void> launchSession() async {
    isStartingSession.value = true;
    // Setup complete -> Stop PreCheck audio monitor immediately before navigating so mic is completely free!
    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;
    // The session opens the mic and camera next: release both, at the same
    // time (the camera release is the slow part).
    await Future.wait([
      _audioLevelService.stopMonitoring(),
      captureService.stop(),
    ]);
    _handOverReferencePhoto();

    // DYNAMIC AUDIO TARGET:
    // Base audio is the max calibrated average dB recorded during pre-check.
    // Initial target is Base + Default Spike Threshold (+6 dB, e.g. 80 -> 86 dB).
    // Strictly clamped between minCalibratedTargetPunchDb and maxCalibratedTargetPunchDb.
    final double baseAudioDb = maxCalibratedDb.value > 0
        ? maxCalibratedDb.value
        : avgAmbientDb.value;
    final double defaultSpike = _spikeThresholdDb;
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

    String? resolvedDifficulty = difficulty;
    if (resolvedDifficulty == null &&
        Get.isRegistered<WorkoutSetupController>()) {
      resolvedDifficulty = Get.find<WorkoutSetupController>().difficulty.value;
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
      noisyRoom: roomNoisy.value,
    );
    if (sessionType == 'prompt') {
      AppNavigator.toPromptSession(arguments: args);
    } else {
      AppNavigator.toFreeSession(arguments: args);
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
      unawaited(captureService.stop());
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

        final bool hadSamples = _calibrationDbSamples.isNotEmpty;

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

        // Keep the last real measurement as a backup (not the 40 dB fallback).
        if (hadSamples) {
          unawaited(
            StorageService.to.saveCalibration(
              SavedCalibration(
                maxDb: maxCalibratedDb.value,
                avgDb: avgAmbientDb.value,
              ),
            ),
          );
        }

        if (express) {
          _onExpressRoomChecked(hadSamples: hadSamples);
          return;
        }

        Future.delayed(const Duration(milliseconds: 600), () {
          nextStep(); // Launch session!
        });
      }
    });
  }

  @override
  void onClose() {
    _captureStepWorker?.dispose();
    _audioLevelSubscription?.cancel();
    _audioLevelService.dispose();
    _calibrationTimer?.cancel();
    _stabilitySubscription?.cancel();
    _stabilityService.dispose();
    unawaited(captureService.dispose());
    if (!_captureHandedOver) SubjectEnrollmentStore.clear();
    pageController.dispose();
    super.onClose();
  }
}
