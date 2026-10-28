import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/services/session_recording/session_event_recorder.dart';
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

const String _punchLine =
    '🥊 [CONFIRMED PUNCH #1] Mode: FUSION | Audio: 100.0 dB | Vibe: Peak 1.00 m/s²';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SessionEventRecorder recorder;
  late FreeSessionController controller;

  setUp(() async {
    AppConstants.changeSettingToDefault();
    tempDir = await Directory.systemTemp.createTemp('instrumentation_test');
    recorder = SessionEventRecorder(directoryProvider: () async => tempDir);
    controller = FreeSessionController(
      audioLevelService: _MockAudioLevelService(),
      recorder: recorder,
    );
  });

  tearDown(() async {
    controller.onClose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Spike log retention', () {
    test('confirmed punch lines survive more than 500 non-punch entries', () {
      recorder.begin(startEpochMs: 0);
      for (int i = 0; i < 3; i++) {
        controller.insertSpikeLogForTesting(
          '$_punchLine #$i',
          isConfirmedPunch: true,
          atEpochMs: i * 1000,
        );
      }
      for (int i = 0; i < 1200; i++) {
        controller.insertSpikeLogForTesting(
          '🟡 [CANDIDATE] VIBRATION_IMPACT | Vibe: 0.20 m/s² #$i',
          atEpochMs: 5000 + i,
        );
      }

      final int punchLinesInUi = controller.recordedSpikesHistory
          .where((String e) => e.contains('🥊 [CONFIRMED PUNCH'))
          .length;
      expect(punchLinesInUi, 3);
      expect(controller.recordedSpikesHistory.length, 500);
      expect(controller.confirmedPunchLog.length, 3);
    });

    test('punch lines are never dropped even when only punches remain', () {
      recorder.begin(startEpochMs: 0);
      for (int i = 0; i < 520; i++) {
        controller.insertSpikeLogForTesting(
          '$_punchLine #$i',
          isConfirmedPunch: true,
          atEpochMs: i,
        );
      }
      expect(controller.confirmedPunchLog.length, 520);
      expect(
        controller.recordedSpikesHistory
            .where((String e) => e.contains('🥊 [CONFIRMED PUNCH'))
            .length,
        520,
      );
    });

    test('confirmed log is chronological and keeps all punches', () {
      recorder.begin(startEpochMs: 0);
      controller.insertSpikeLogForTesting('$_punchLine A', atEpochMs: 100);
      controller.insertSpikeLogForTesting('$_punchLine B', atEpochMs: 200);
      expect(controller.confirmedPunchLog.first, contains(' A'));
      expect(controller.confirmedPunchLog.last, contains(' B'));
    });
  });

  group('Elapsed time prefix', () {
    test('every line starts with [+mm:ss.mmm] relative to session start', () {
      recorder.begin(startEpochMs: 10000);
      controller.insertSpikeLogForTesting('first', atEpochMs: 10000);
      controller.insertSpikeLogForTesting('second', atEpochMs: 71234);

      expect(controller.recordedSpikesHistory.last, '[+00:00.000] first');
      expect(controller.recordedSpikesHistory.first, '[+01:01.234] second');
    });

    test('the prefix is added at the front so punch-marker checks still match', () {
      recorder.begin(startEpochMs: 0);
      controller.insertSpikeLogForTesting(_punchLine, atEpochMs: 2500);
      final String line = controller.recordedSpikesHistory.first;
      expect(line.startsWith('[+00:02.500] 🥊'), isTrue);
      expect(line.contains('PUNCH'), isTrue);
    });

    test('no prefix is added before the session timeline has begun', () {
      controller.insertSpikeLogForTesting('plain');
      expect(controller.recordedSpikesHistory.first, 'plain');
    });
  });

  group('Session totals text', () {
    test('includes duration, punch count and recorded counters', () {
      recorder.begin(startEpochMs: 0);
      recorder.count('audio.spikes_seen', 4);
      recorder.count('time.camera_tracked_ms', 1000);
      recorder.count('time.camera_unavailable_ms', 250);
      final String text = controller.buildSessionTotalsText(90);

      expect(text, contains('Duration (s)'));
      expect(text, contains('90'));
      expect(text, contains('audio.spikes_seen'));
      expect(text, contains('Camera unavailable'));
      expect(text, contains('25.0'));
    });
  });
}
