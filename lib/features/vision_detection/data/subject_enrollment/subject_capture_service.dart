import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/constants.dart';
import '../../domain/services/camera_distance_gate.dart';
import '../../domain/services/camera_person_gate.dart';
import '../../domain/services/camera_tracker_guard.dart';
import '../../domain/subject_lock/appearance_signature.dart';
import '../../domain/subject_lock/subject_lock.dart';
import '../face/subject_face_checker.dart';
import '../mappers/pose_subject_mapper.dart';
import '../mappers/reference_photo_builder.dart';

/// Where the capture is, for the screen.
enum CaptureStep {
  /// Waiting for the Capture tap.
  idle,

  /// Tapped: time to step back into position (countdown).
  prepare,

  /// Looking for the user (near, face and shoulders in view).
  findUser,

  /// Hold-still countdown before the photo.
  holdStill,

  /// Photo taken: learning the look and the face.
  learning,

  /// Done: the lock can be handed over.
  ready,
}

/// Takes the subject-lock reference photo before the session (pre-check
/// screen), so the session starts already locked on the user.
///
/// Runs the same steps the session runs on a frame before the lock: real
/// person check, near check, [SubjectLock.observe], face checks. The camera
/// is opened exactly like the session's (same lens, resolution, format), so
/// the colours and face learned here match what the session sees.
///
/// Nothing is learned until [beginCapture] (the user's tap). Once ready the
/// lock is frozen; [takeLock] hands it over.
class SubjectCaptureService {
  /// Waiting this long for the face template, ask the user to show it.
  static const int faceTemplateHintMs = 3000;

  /// How often the countdown on screen is updated (between camera frames).
  static const Duration _tick = Duration(milliseconds: 50);

  final PoseSubjectMapper _mapper = const PoseSubjectMapper();
  final CameraPersonGate _personGate = CameraPersonGate.fromConstants();
  final CameraDistanceGate _distanceGate = CameraDistanceGate.fromConstants();
  final CameraTrackerGuard _trackerGuard = CameraTrackerGuard();

  SubjectLock _lock = SubjectLock();
  SubjectFaceChecker? _faceChecker;
  CameraController? cameraController;
  CameraDescription? _activeCamera;
  PoseDetector? _poseDetector;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _isStopped = true;
  int _lockedAtMs = 0;
  int _photoGeneration = 0;
  Size _cameraImageSize = Size.zero;
  Timer? _ticker;
  int _prepareUntilMs = 0;
  int? _holdStillDeadlineMs;
  int _hintUntilMs = 0;

  final RxBool isCameraReady = false.obs;
  final RxBool isCameraUnavailable = false.obs;
  final Rx<SubjectLockState> state = SubjectLockState.waitingForUser.obs;
  final Rx<CaptureStep> step = CaptureStep.idle.obs;

  /// Time left of the current countdown (prepare / hold still), ms.
  final RxInt countdownMs = 0.obs;

  /// Progress of the current step, 0-1 (countdown or learning).
  final RxDouble progress = 0.0.obs;

  /// What the user should do now ("Come a little closer", ...).
  final RxString hint = ''.obs;
  final Rx<ui.Image?> photo = Rx<ui.Image?>(null);
  final Rx<Pose?> livePose = Rx<Pose?>(null);

  /// True while the user tapped Capture and the photo is not finished.
  final RxBool isCapturing = false.obs;

  /// True when the lock is learned and can be handed over.
  final RxBool isReady = false.obs;

  bool get isFrontCamera =>
      _activeCamera?.lensDirection == CameraLensDirection.front;
  Size get cameraImageSize => _cameraImageSize;
  bool get hasFaceTemplate => _lock.hasFaceTemplate;

  /// Opens the camera and shows the preview. Learned state is kept (coming
  /// back to the page after a capture).
  Future<void> start() async {
    if (!_isStopped) return;
    _isStopped = false;
    isCameraUnavailable.value = false;
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    final SubjectFaceChecker checker = SubjectFaceChecker();
    _faceChecker = checker;
    unawaited(checker.load());
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (_isStopped) return;
      if (cameras.isEmpty) {
        isCameraUnavailable.value = true;
        return;
      }
      // Same choice as FreeSessionController.initCamera.
      const CameraLensDirection direction = CameraLensDirection.front;
      final CameraLensType lensType =
          AppConstants.testingNeedToUseUltraWideCamera
          ? CameraLensType.ultraWide
          : CameraLensType.wide;
      _activeCamera = cameras.firstWhere(
        (c) => c.lensDirection == direction && c.lensType == lensType,
        orElse: () => cameras.firstWhere(
          (c) => c.lensDirection == direction,
          orElse: () => cameras.first,
        ),
      );
      final CameraController controller = CameraController(
        _activeCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
        fps: AppConstants.cameraTargetFps,
      );
      cameraController = controller;
      await controller.initialize();
      if (_isStopped) {
        await _disposeCamera();
        return;
      }
      await controller.setZoomLevel(await controller.getMinZoomLevel());
      isCameraReady.value = true;
      await controller.startImageStream(_onFrame);
    } catch (_) {
      isCameraUnavailable.value = true;
      isCameraReady.value = false;
    }
  }

  /// The user tapped Capture: from now on frames build the reference photo
  /// (hold still → photo → learning → face template).
  void beginCapture() {
    if (isReady.value) return;
    _resetLock();
    _isCapturing = true;
    isCapturing.value = true;
    _prepareUntilMs =
        DateTime.now().millisecondsSinceEpoch +
        AppConstants.subjectCapturePrepareMs;
    _setStep(CaptureStep.prepare);
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) => _onTick());
    _onTick();
  }

  /// Forget the photo and wait for a new Capture tap.
  void retake() {
    _resetLock();
    _isCapturing = false;
    isCapturing.value = false;
    _ticker?.cancel();
    _ticker = null;
    _setStep(CaptureStep.idle);
  }

  /// Hands over the learned lock (null when not ready). The service starts
  /// over with a new lock; the photo is handed over too (caller owns it).
  ({SubjectLock lock, ui.Image? photo})? takeLock() {
    if (!isReady.value) return null;
    final SubjectLock lock = _lock;
    final ui.Image? image = photo.value;
    _lock = SubjectLock();
    _photoGeneration++;
    photo.value = null;
    isReady.value = false;
    state.value = SubjectLockState.waitingForUser;
    _setStep(CaptureStep.idle);
    return (lock: lock, photo: image);
  }

  /// Closes the camera, pose detector and face model (learned state kept).
  Future<void> stop() async {
    if (_isStopped) return;
    _isStopped = true;
    _ticker?.cancel();
    _ticker = null;
    isCameraReady.value = false;
    livePose.value = null;
    _faceChecker?.cancelRunning();
    final SubjectFaceChecker? checker = _faceChecker;
    _faceChecker = null;
    // A capture that was not finished must start again on return.
    if (!isReady.value && _isCapturing) retake();
    await _disposeCamera();
    final PoseDetector? detector = _poseDetector;
    _poseDetector = null;
    try {
      await detector?.close();
    } catch (_) {}
    await checker?.close();
  }

  /// [stop] plus drop the photo (screen closed without handing over).
  Future<void> dispose() async {
    await stop();
    _photoGeneration++;
    photo.value?.dispose();
    photo.value = null;
  }

  void _resetLock() {
    _lock.reset();
    _faceChecker?.cancelRunning();
    _photoGeneration++;
    photo.value?.dispose();
    photo.value = null;
    _lockedAtMs = 0;
    _holdStillDeadlineMs = null;
    _hintUntilMs = 0;
    isReady.value = false;
    state.value = SubjectLockState.waitingForUser;
  }

  void _setStep(CaptureStep next) {
    if (step.value == next) return;
    step.value = next;
    progress.value = 0;
    countdownMs.value = 0;
  }

  /// Shows [text]; [holdMs] keeps it on screen over later frames' hints.
  void _setHint(String text, int nowMs, {int holdMs = 0}) {
    if (holdMs == 0 && nowMs < _hintUntilMs) return;
    hint.value = text;
    if (holdMs > 0) _hintUntilMs = nowMs + holdMs;
  }

  /// Smooth countdowns: updated by a timer, not only when a frame arrives.
  void _onTick() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    switch (step.value) {
      case CaptureStep.prepare:
        final int prepareMs = AppConstants.subjectCapturePrepareMs;
        final int left = max(0, _prepareUntilMs - now);
        countdownMs.value = left;
        progress.value = prepareMs <= 0 ? 1 : 1 - left / prepareMs;
        hint.value = 'Step back into position';
        if (left == 0) {
          _setStep(CaptureStep.findUser);
          hint.value = 'Face and shoulders in view';
        }
      case CaptureStep.holdStill:
        final int? deadline = _holdStillDeadlineMs;
        if (deadline == null) return;
        final int left = max(0, deadline - now);
        countdownMs.value = left;
        progress.value = 1 - left / max(1, _lock.holdStillMs);
      case CaptureStep.learning:
        _updateLearningProgress();
      case CaptureStep.idle:
      case CaptureStep.findUser:
      case CaptureStep.ready:
        break;
    }
  }

  void _updateLearningProgress() {
    final double look = _lock.enrollProgress;
    final double face = (_faceChecker?.isAvailable ?? false)
        ? _lock.faceTemplateProgress
        : 1.0;
    progress.value = 0.6 * look + 0.4 * face;
  }

  Future<void> _disposeCamera() async {
    final CameraController? controller = cameraController;
    cameraController = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isStopped || _isProcessingFrame) return;
    final CameraDescription? camera = _activeCamera;
    final PoseDetector? detector = _poseDetector;
    if (camera == null || detector == null) return;
    _isProcessingFrame = true;
    final int frameMs = DateTime.now().millisecondsSinceEpoch;
    try {
      if (_cameraImageSize.width == 0) {
        _cameraImageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
      }
      final InputImageRotation rotation = _imageRotation(camera);
      final FramePixels? pixels = PoseSubjectMapper.framePixelsOf(
        image,
        rotation,
      );
      // Stuck on something that is not a person: one blank frame makes the
      // tracker detect from scratch.
      final InputImage? input = _toInputImage(
        image,
        rotation,
        bytes: pixels != null && _trackerGuard.takeReset()
            ? pixels.blankCopy()
            : null,
      );
      if (input == null) return;
      final List<Pose> poses = await detector.processImage(input);
      if (_isStopped) return;
      final Pose? pose = poses.isEmpty ? null : poses.first;
      livePose.value = pose;
      if (pose == null) {
        // The tracker lost the person: the next pose may be someone else.
        if (_isCapturing) _lock.poseLost();
        _trackerGuard.clear();
        if (step.value == CaptureStep.findUser) {
          _setHint('Step into the camera view', frameMs);
        }
      } else if (pixels != null) {
        _observe(pose, pixels, frameMs);
      }
    } catch (_) {
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _observe(Pose pose, FramePixels pixels, int frameMs) {
    if (!_isCapturing || isReady.value || frameMs < _prepareUntilMs) return;
    final CameraPersonResult person = _personGate.evaluate(
      facePoints: <PoseLandmarkType>[
        PoseLandmarkType.nose,
        PoseLandmarkType.leftEye,
        PoseLandmarkType.rightEye,
        PoseLandmarkType.leftEar,
        PoseLandmarkType.rightEar,
        PoseLandmarkType.leftEyeInner,
        PoseLandmarkType.rightEyeInner,
        PoseLandmarkType.leftMouth,
        PoseLandmarkType.rightMouth,
      ].map((t) => _landmark(pose, t)).toList(),
      leftShoulder: _landmark(pose, PoseLandmarkType.leftShoulder),
      rightShoulder: _landmark(pose, PoseLandmarkType.rightShoulder),
    );
    if (!person.isPerson) {
      _trackerGuard.noteRefused(frameMs);
      if (step.value == CaptureStep.findUser) {
        _setHint('Face and shoulders in view', frameMs);
      }
      return;
    }
    _trackerGuard.clear();
    // Same near check the session uses for its photo (default max distance).
    final double minShoulderRatio =
        AppConstants.cameraDistanceMetresFactor /
        AppConstants.defaultMaxCameraDistanceM;
    final CameraDistanceResult distance = _distanceGate.evaluate(
      leftShoulder: _landmark(pose, PoseLandmarkType.leftShoulder),
      rightShoulder: _landmark(pose, PoseLandmarkType.rightShoulder),
      leftEye: _landmark(pose, PoseLandmarkType.leftEye),
      rightEye: _landmark(pose, PoseLandmarkType.rightEye),
      imageWidth: _cameraImageSize.width,
      imageHeight: _cameraImageSize.height,
      minShoulderRatio: minShoulderRatio,
      minEyeRatio:
          minShoulderRatio *
          (AppConstants.cameraMinEyeSpanRatio /
              AppConstants.cameraMinShoulderWidthRatio),
      unknownIsValid: AppConstants.cameraDistanceUnknownIsValid,
    );
    final SubjectObservation? observation = _mapper.map(
      pose,
      tMs: frameMs,
      pixels: pixels,
      enrollEligible: distance.withinRange,
    );
    if (observation == null) return;
    final CaptureStep before = step.value;
    final SubjectDecision decision = _lock.observe(observation);
    // The tracked person may have changed before their face was learned, so
    // the face would have to be learned from someone else: start over.
    if (decision.isBreak && _lock.isLocked && !_lock.hasFaceTemplate) {
      _restartPhoto('You moved — hold still', frameMs);
      return;
    }
    if (decision.isPhotoFrame) {
      unawaited(_takePhoto(pixels, observation));
    }
    state.value = decision.state;
    switch (decision.state) {
      case SubjectLockState.waitingForUser:
        _holdStillDeadlineMs = null;
        _setStep(CaptureStep.findUser);
        if (before == CaptureStep.holdStill) {
          _setHint('You moved — hold still', frameMs, holdMs: 1500);
        } else if (!distance.withinRange) {
          _setHint('Come a little closer', frameMs);
        } else {
          _setHint('Face and shoulders in view', frameMs);
        }
      case SubjectLockState.holdStill:
        // The same deadline every frame (photo time); the timer counts down.
        _holdStillDeadlineMs = frameMs + (decision.holdStillRemainingMs ?? 0);
        _setStep(CaptureStep.holdStill);
        _hintUntilMs = 0;
        hint.value = 'Hold still';
      case SubjectLockState.enrolling:
      case SubjectLockState.locked:
      case SubjectLockState.verifying:
      case SubjectLockState.otherPerson:
        _holdStillDeadlineMs = null;
        _setStep(CaptureStep.learning);
        _setHint('Keep facing the camera', frameMs);
    }
    // Faces for the template are collected while holding still, learning
    // and after the lock until the template is ready.
    _faceChecker?.maybeCheck(
      _lock,
      pose,
      pixels,
      frameMs,
      (FaceCheckResult result, int _) {
        state.value = result.state;
        if (result.faceConflict) {
          _restartPhoto(
            'Two faces seen — stay closest to the camera',
            DateTime.now().millisecondsSinceEpoch,
          );
        }
      },
    );
    _updateReady(frameMs);
  }

  /// Throws the photo away and looks for the user again, keeping [message] on
  /// screen for a moment.
  void _restartPhoto(String message, int nowMs) {
    _resetLock();
    _setStep(CaptureStep.findUser);
    _setHint(message, nowMs, holdMs: 2000);
  }

  void _updateReady(int nowMs) {
    if (_lock.state != SubjectLockState.locked) {
      _lockedAtMs = 0;
      return;
    }
    if (_lockedAtMs == 0) _lockedAtMs = nowMs;
    final bool faceModelMissing = !(_faceChecker?.isAvailable ?? false);
    // The face is the only proof of who is tracked, so the photo is not done
    // without it while the model can run. Cancel and Skip stay available.
    if (!_lock.hasFaceTemplate && !faceModelMissing) {
      if (nowMs - _lockedAtMs >= faceTemplateHintMs) {
        _setHint(
          'Look at the camera so your face can be learned',
          nowMs,
          holdMs: 1000,
        );
      }
      return;
    }
    // Freeze: later frames must not change the learned lock.
    _faceChecker?.cancelRunning();
    _isCapturing = false;
    isCapturing.value = false;
    isReady.value = true;
    _ticker?.cancel();
    _ticker = null;
    _setStep(CaptureStep.ready);
    progress.value = 1;
    hint.value = '';
  }

  Future<void> _takePhoto(FramePixels pixels, SubjectObservation obs) async {
    final int generation = _photoGeneration;
    final ui.Image? image = await ReferencePhotoBuilder.build(
      pixels,
      obs,
      // Same as the session preview: Android front frames are not mirrored.
      mirror: isFrontCamera && defaultTargetPlatform == TargetPlatform.android,
    );
    if (image == null) return;
    if (generation != _photoGeneration) {
      image.dispose();
      return;
    }
    photo.value?.dispose();
    photo.value = image;
  }

  static DistanceLandmark? _landmark(Pose pose, PoseLandmarkType type) {
    final PoseLandmark? l = pose.landmarks[type];
    return l == null
        ? null
        : DistanceLandmark(x: l.x, y: l.y, likelihood: l.likelihood);
  }

  /// Same as FreeSessionController._getImageRotation.
  InputImageRotation _imageRotation(CameraDescription camera) {
    final DeviceOrientation deviceOrientation =
        cameraController?.value.deviceOrientation ??
        DeviceOrientation.portraitUp;
    final int compensation = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final int degrees = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + compensation) % 360
        : (camera.sensorOrientation - compensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees) ??
        InputImageRotation.rotation90deg;
  }

  /// Same as FreeSessionController._convertCameraImage.
  InputImage? _toInputImage(
    CameraImage image,
    InputImageRotation rotation, {
    Uint8List? bytes,
  }) {
    try {
      final InputImageFormat format =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;
      final Plane plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: bytes ?? plane.bytes,
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
}
