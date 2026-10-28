import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';

class _MockAudioLevelService implements IAudioLevelService {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

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
  double get currentDecibels => 45.0;

  @override
  bool get isMonitoring => true;

  @override
  bool get isEarbudsConnected => false;

  @override
  Future<bool> checkEarbudsConnected() async => false;

  @override
  Future<bool> startMonitoring({int sampleIntervalMs = 50}) async => true;

  @override
  Future<void> stopMonitoring() async {}

  @override
  Future<void> updateSampleInterval(int newIntervalMs) async {}

  @override
  void dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FreeSessionController controller;
  const int t0 = 1000000000000;

  void feed(double db, {int? atMs}) {
    controller.liveDecibelLevel.value = db;
    controller.checkPunchDetectionForTesting(frameTimestampMs: atMs);
  }

  setUp(() {
    AppConstants.changeSettingToDefault();
    AppConstants.warmUpDurationInMiliSeconds = 0;
    controller = FreeSessionController(
      audioLevelService: _MockAudioLevelService(),
    );
    controller.sessionMode.value = DetectionMode.audio;
    controller.staticCalibratedAudioDb.value = 70.0;
    controller.customTargetAudioDb.value = 75.0;
    controller.minAudioPunchSpikeDb.value = 5.0;
  });

  tearDown(() => controller.onClose());

  /// Strike at [strikeMs], quiet frames (10 ms apart) in between.
  void quietUntil(int fromMs, int toMs) {
    for (int t = fromMs; t < toMs; t += 10) {
      feed(50.0, atMs: t0 + t);
    }
  }

  test('frame timestamps decide the lockout: strikes 200 ms apart both count', () {
    quietUntil(0, 60); // baseline
    feed(95.0, atMs: t0 + 60); // strike A
    expect(controller.punchCount.value, 1);

    quietUntil(70, 100);
    feed(95.0, atMs: t0 + 100); // 40 ms after A: inside the 160 ms lockout
    expect(controller.punchCount.value, 1);

    quietUntil(110, 260);
    feed(95.0, atMs: t0 + 260); // 200 ms after A: lockout over, valley before it
    expect(controller.punchCount.value, 2);
  });

  test('a strike inside the lockout by frame time is not counted', () {
    quietUntil(0, 60);
    feed(95.0, atMs: t0 + 60);
    quietUntil(70, 150);
    feed(95.0, atMs: t0 + 150); // 90 ms after A
    expect(controller.punchCount.value, 1);
  });

  test('without frame timestamps the whole burst is stamped "now" and the second strike is lost', () {
    // Legacy delivery-time stamping: everything is processed within a few
    // milliseconds of real time, so a strike 200 ms later in the audio is still
    // inside the 160 ms lockout. This is the loss the timestamps remove.
    for (int i = 0; i < 6; i++) {
      feed(50.0);
    }
    feed(95.0);
    expect(controller.punchCount.value, 1);
    for (int i = 0; i < 15; i++) {
      feed(50.0);
    }
    feed(95.0);
    expect(controller.punchCount.value, 1);
  });

  test('the lockout length comes from AppConstants.audioRefractoryMs', () {
    expect(AppConstants.audioRefractoryMs, 160);
  });
}
