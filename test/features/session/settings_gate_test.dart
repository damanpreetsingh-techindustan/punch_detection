import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/services/device_vibration/i_device_vibration_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/fusion/domain/vibration_gate/services/fresh_knock_gate.dart';
import 'package:punch_detection_demo/features/fusion/domain/vibration_gate/services/peak_threshold_gate.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/prompt_session_controller.dart';

class _MockAudioLevelService implements IAudioLevelService {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();
  double _mockDb = 45.0;
  bool _monitoring = false;

  @override
  Stream<double> get decibelStream => _controller.stream;

  @override
  Stream<AudioLevelSample> get sampleStream => _controller.stream.map(
    (double db) => AudioLevelSample(
      db: db,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  @override
  Map<String, Object?> get diagnostics => const <String, Object?>{};

  @override
  double get currentDecibels => _mockDb;

  @override
  bool get isMonitoring => _monitoring;

  @override
  bool get isEarbudsConnected => false;

  @override
  Future<bool> checkEarbudsConnected() async => false;

  @override
  Future<bool> startMonitoring({int sampleIntervalMs = 50}) async {
    _monitoring = true;
    return true;
  }

  @override
  Future<void> stopMonitoring() async {
    _monitoring = false;
  }

  /// Last interval pushed to the microphone (null = never changed).
  int? lastSampleIntervalMs;

  @override
  Future<void> updateSampleInterval(int sampleIntervalMs) async {
    lastSampleIntervalMs = sampleIntervalMs;
  }

  void emitDecibels(double db) {
    _mockDb = db;
    _controller.add(db);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// Vibration service that records start / stop calls instead of touching the
/// real accelerometer plugin (not available in unit tests).
class _FakeVibrationService implements IDeviceVibrationService {
  final StreamController<double> _magnitudes =
      StreamController<double>.broadcast();
  final StreamController<VibrationRawSample> _raw =
      StreamController<VibrationRawSample>.broadcast();

  bool isMonitoring = false;
  int startCalls = 0;
  double? lastThreshold;

  @override
  Stream<double> get vibrationMagnitudeStream => _magnitudes.stream;

  @override
  Stream<VibrationRawSample> get rawSampleStream => _raw.stream;

  @override
  double get currentVibrationMagnitude => 0.0;

  @override
  double get recentPeakVibrationMagnitude => 0.0;

  @override
  int get lastVibrationTimestampMs => 0;

  @override
  int get recentPeakTimestampMs => 0;

  @override
  bool hasRecentVibration(int nowMs, {int maxAgeMs = 350}) => false;

  @override
  void startMonitoring({double minVibrationThreshold = 0.35}) {
    isMonitoring = true;
    startCalls++;
    lastThreshold = minVibrationThreshold;
  }

  @override
  void stopMonitoring() => isMonitoring = false;

  @override
  void consumeRecentPeak() {}

  @override
  void resetMagnitude() {}

  @override
  void dispose() {
    _magnitudes.close();
    _raw.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConstants Dynamic Settings Cooldown', () {
    test('default postSettingsCooldownMs is 1000 and can be adjusted dynamically', () {
      expect(AppConstants.postSettingsCooldownMs, equals(1000));
      AppConstants.postSettingsCooldownMs = 1500;
      expect(AppConstants.postSettingsCooldownMs, equals(1500));
      AppConstants.changeSettingToDefault();
      expect(AppConstants.postSettingsCooldownMs, equals(1000));
    });
  });

  group('FreeSessionController Settings Gate Lifecycle & Rejection', () {
    late _MockAudioLevelService mockAudio;
    late _FakeVibrationService fakeVibration;
    late FreeSessionController controller;

    setUp(() {
      AppConstants.changeSettingToDefault();
      AppConstants.warmUpDurationInMiliSeconds = 0;
      mockAudio = _MockAudioLevelService();
      fakeVibration = _FakeVibrationService();
      controller = FreeSessionController(
        audioLevelService: mockAudio,
        vibrationService: fakeVibration,
      );
    });

    tearDown(() {
      controller.onClose();
      mockAudio.dispose();
    });

    test('initial state has inactive settings gate and 0 count', () {
      expect(controller.isSettingsViewActive, isFalse);
      expect(controller.openSettingsViewsCount, equals(0));
    });

    test('opening settings instantly activates gate and suppresses punch detection', () {
      controller.notifySettingsViewOpened();
      expect(controller.isSettingsViewActive, isTrue);
      expect(controller.openSettingsViewsCount, equals(1));

      // Attempt punch while open: punch count must not increment
      final initialCount = controller.punchCount.value;
      controller.notifySettingsViewOpened(); // e.g. nested tune dialog
      expect(controller.openSettingsViewsCount, equals(2));
      expect(controller.isSettingsViewActive, isTrue);

      controller.notifySettingsViewClosed(); // close tune dialog
      expect(controller.openSettingsViewsCount, equals(1));
      expect(controller.isSettingsViewActive, isTrue);

      controller.notifySettingsViewClosed(); // close settings sheet
      expect(controller.openSettingsViewsCount, equals(0));
      // Still active during 1000ms post-settings cooldown
      expect(controller.isSettingsViewActive, isTrue);
      expect(controller.punchCount.value, equals(initialCount));
    });

    test('punches evaluated during active settings are rejected with SETTINGS_OPEN_GATE in telemetry', () {
      controller.sessionMode.value = DetectionMode.audio;
      controller.staticCalibratedAudioDb.value = 70.0;
      controller.customTargetAudioDb.value = 75.0;
      controller.minAudioPunchSpikeDb.value = 5.0;

      // Prime baseline with quiet ambient noise
      for (int i = 0; i < 5; i++) {
        controller.liveDecibelLevel.value = 50.0;
        controller.checkPunchDetectionForTesting();
      }

      // Open settings
      controller.notifySettingsViewOpened();
      expect(controller.isSettingsViewActive, isTrue);

      // Simulate a 95 dB strike (spike well above target) while settings are open
      controller.liveDecibelLevel.value = 95.0;
      controller.checkPunchDetectionForTesting();

      // Verify that while settings gate is active, punch count remains 0
      expect(controller.punchCount.value, equals(0));

      // After closing settings, cooldown is active for 1000ms
      controller.notifySettingsViewClosed();
      expect(controller.isSettingsViewActive, isTrue);

      // Re-testing punch during 1s cooldown
      controller.liveDecibelLevel.value = 96.0;
      controller.checkPunchDetectionForTesting();

      expect(controller.punchCount.value, equals(0));

      // Verify telemetry records declined event due to settings open
      final settingsRejections = controller.telemetryEvents
          .where((e) => e.decisionCode == 'SETTINGS_OPEN_GATE')
          .toList();

      expect(settingsRejections, isNotEmpty);
      expect(settingsRejections.first.isValidPunch, isFalse);
      expect(settingsRejections.first.isRejected, isTrue);
      expect(
        settingsRejections.first.reasonLabel,
        contains('Declined: Settings open or client using mobile'),
      );
    });

    test('post-settings cooldown duration honors dynamic AppConstants setting', () async {
      AppConstants.postSettingsCooldownMs = 80; // short for testing expiry
      controller.notifySettingsViewOpened();
      expect(controller.isSettingsViewActive, isTrue);

      controller.notifySettingsViewClosed();
      expect(controller.isSettingsViewActive, isTrue);

      await Future.delayed(const Duration(milliseconds: 120));
      expect(controller.isSettingsViewActive, isFalse);
    });

    test('setVibrationGateType updates observable and swaps active IVibrationGate instance', () {
      expect(controller.vibrationGateType.value, equals(VibrationGateType.knock));
      expect(controller.vibrationGate, isA<FreshKnockGate>());

      controller.setVibrationGateType(VibrationGateType.peakThreshold);
      expect(controller.vibrationGateType.value, equals(VibrationGateType.peakThreshold));
      expect(AppConstants.vibrationGateType, equals(VibrationGateType.peakThreshold));
      expect(controller.vibrationGate, isA<PeakThresholdGate>());

      controller.setVibrationGateType(VibrationGateType.knock);
      expect(controller.vibrationGateType.value, equals(VibrationGateType.knock));
      expect(AppConstants.vibrationGateType, equals(VibrationGateType.knock));
      expect(controller.vibrationGate, isA<FreshKnockGate>());
    });

    test('toggleCameraDistanceUnknownIsValid updates observable and AppConstants', () {
      final initialVal = controller.cameraDistanceUnknownIsValid.value;
      controller.toggleCameraDistanceUnknownIsValid(!initialVal);
      expect(controller.cameraDistanceUnknownIsValid.value, equals(!initialVal));
      expect(AppConstants.cameraDistanceUnknownIsValid, equals(!initialVal));

      controller.toggleCameraDistanceUnknownIsValid(initialVal);
      expect(controller.cameraDistanceUnknownIsValid.value, equals(initialVal));
      expect(AppConstants.cameraDistanceUnknownIsValid, equals(initialVal));
    });

    test('resetAllSettingsToDefault restores all detection settings to official defaults', () {
      // Mutate settings away from defaults
      controller.setVibrationGateType(VibrationGateType.peakThreshold);
      controller.toggleCameraDistanceUnknownIsValid(false);
      controller.minVibrationThreshold.value = 0.55;
      controller.isVisionConfirmationRequired.value = false;
      controller.audioSampleIntervalMs.value = 80;
      controller.maxCameraDistanceM.value = 2.5;

      expect(controller.vibrationGateType.value, equals(VibrationGateType.peakThreshold));
      expect(controller.cameraDistanceUnknownIsValid.value, isFalse);
      expect(controller.minVibrationThreshold.value, equals(0.55));
      expect(controller.isVisionConfirmationRequired.value, isFalse);
      expect(controller.maxCameraDistanceM.value, equals(2.5));

      // Reset to defaults
      controller.resetAllSettingsToDefault();

      expect(controller.vibrationGateType.value, equals(VibrationGateType.knock));
      expect(controller.vibrationGate, isA<FreshKnockGate>());
      expect(controller.cameraDistanceUnknownIsValid.value, isTrue);
      expect(controller.minVibrationThreshold.value, equals(AppConstants.defaultImpactVibrationThreshold));
      expect(controller.isVisionConfirmationRequired.value, isTrue);
      expect(controller.maxCameraDistanceM.value, equals(FreeSessionController.defaultMaxCameraDistanceM));
      expect(AppConstants.vibrationGateType, equals(VibrationGateType.knock));
      expect(AppConstants.cameraDistanceUnknownIsValid, isTrue);
    });

    test('Defaults restarts the accelerometer when vibration had been turned off', () {
      controller.mountType.value = MountType.wall;
      controller.toggleVibrationGate(false);
      expect(fakeVibration.isMonitoring, isFalse);

      controller.resetAllSettingsToDefault();

      // Before the fix only the switch flipped back on; the sensor stayed
      // stopped and every punch was rejected for missing vibration.
      expect(controller.isVibrationGateEnabled.value, isTrue);
      expect(fakeVibration.isMonitoring, isTrue);
      expect(
        fakeVibration.lastThreshold,
        equals(AppConstants.defaultImpactVibrationThreshold),
      );
    });

    test('Defaults pushes the default audio interval to the microphone', () {
      controller.setAudioSampleInterval(80);
      expect(mockAudio.lastSampleIntervalMs, equals(80));

      controller.resetAllSettingsToDefault();

      expect(controller.audioSampleIntervalMs.value, AppConstants.globalStaticAudioMsg);
      expect(mockAudio.lastSampleIntervalMs, AppConstants.globalStaticAudioMsg);
    });

    test('Defaults keeps the vibration gate on pole mount OFF', () {
      controller.mountType.value = MountType.pole;
      controller.toggleVibrationGate(false);

      controller.resetAllSettingsToDefault();

      expect(controller.isVibrationGateEnabled.value, isFalse);
      expect(fakeVibration.isMonitoring, isFalse);
    });

    test('Defaults keeps an injected gate of the default type (no silent swap)', () {
      final FreshKnockGate injected = FreshKnockGate();
      final FreeSessionController withGate = FreeSessionController(
        audioLevelService: _MockAudioLevelService(),
        vibrationService: _FakeVibrationService(),
        vibrationGate: injected,
      );
      withGate.resetAllSettingsToDefault();
      expect(identical(withGate.vibrationGate, injected), isTrue);
      withGate.onClose();
    });

    test('restarting session / onClose restores AppConstants to default', () {
      controller.setVibrationGateType(VibrationGateType.peakThreshold);
      controller.toggleCameraDistanceUnknownIsValid(false);
      expect(AppConstants.vibrationGateType, equals(VibrationGateType.peakThreshold));
      expect(AppConstants.cameraDistanceUnknownIsValid, isFalse);

      controller.onClose();

      expect(AppConstants.vibrationGateType, equals(VibrationGateType.knock));
      expect(AppConstants.cameraDistanceUnknownIsValid, isTrue);
    });
  });

  group('PromptSessionController Settings Gate Lifecycle & Rejection', () {
    late _MockAudioLevelService mockAudio;
    late PromptSessionController controller;

    setUp(() {
      AppConstants.changeSettingToDefault();
      mockAudio = _MockAudioLevelService();
      controller = PromptSessionController(audioLevelService: mockAudio);
    });

    tearDown(() {
      controller.onClose();
      mockAudio.dispose();
    });

    test('initial state has inactive settings gate and 0 count', () {
      expect(controller.isSettingsViewActive, isFalse);
      expect(controller.openSettingsViewsCount, equals(0));
    });

    test('opening settings instantly activates gate and cooldown suppresses punches', () {
      controller.notifySettingsViewOpened();
      expect(controller.isSettingsViewActive, isTrue);

      controller.notifySettingsViewClosed();
      expect(controller.openSettingsViewsCount, equals(0));
      expect(controller.isSettingsViewActive, isTrue);

      controller.resetSettingsGate();
      expect(controller.isSettingsViewActive, isFalse);
    });

    test('PromptSessionController rejects punches with SETTINGS_OPEN_GATE during settings open', () {
      controller.sessionMode.value = DetectionMode.audio;
      controller.staticCalibratedAudioDb.value = 70.0;
      controller.customTargetAudioDb.value = 75.0;
      controller.minAudioPunchSpikeDb.value = 5.0;

      for (int i = 0; i < 5; i++) {
        controller.liveDecibelLevel.value = 50.0;
        controller.checkPunchDetectionForTesting();
      }

      controller.notifySettingsViewOpened();
      expect(controller.isSettingsViewActive, isTrue);

      controller.liveDecibelLevel.value = 95.0;
      controller.checkPunchDetectionForTesting();

      expect(controller.punchCount.value, equals(0));

      final settingsRejections = controller.telemetryEvents
          .where((e) => e.decisionCode == 'SETTINGS_OPEN_GATE')
          .toList();

      expect(settingsRejections, isNotEmpty);
      expect(settingsRejections.first.isValidPunch, isFalse);
      expect(settingsRejections.first.isRejected, isTrue);
      expect(
        settingsRejections.first.reasonLabel,
        contains('Declined: Settings open or client using mobile'),
      );
    });
  });
}
