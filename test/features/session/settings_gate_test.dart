import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
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

  @override
  Future<void> updateSampleInterval(int sampleIntervalMs) async {}

  void emitDecibels(double db) {
    _mockDb = db;
    _controller.add(db);
  }

  @override
  void dispose() {
    _controller.close();
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
    late FreeSessionController controller;

    setUp(() {
      AppConstants.changeSettingToDefault();
      AppConstants.warmUpDurationInMiliSeconds = 0;
      mockAudio = _MockAudioLevelService();
      controller = FreeSessionController(audioLevelService: mockAudio);
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
