import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/detection_core/calibration/ambient_floor.dart';
import 'package:punch_detection_demo/features/session_precheck/presentation/controllers/session_precheck_controller.dart';

class _SilentAudioService implements IAudioLevelService {
  @override
  Stream<double> get decibelStream => const Stream<double>.empty();
  @override
  Stream<AudioLevelSample> get sampleStream =>
      const Stream<AudioLevelSample>.empty();
  @override
  Map<String, Object?> get diagnostics => const <String, Object?>{
    'mode': 'test',
  };
  @override
  double get currentDecibels => 0;
  @override
  bool get isMonitoring => false;
  @override
  bool get isEarbudsConnected => false;
  @override
  Future<bool> checkEarbudsConnected() async => false;
  @override
  Future<bool> startMonitoring({int? sampleIntervalMs}) async => true;
  @override
  Future<void> stopMonitoring() async {}
  @override
  Future<void> updateSampleInterval(int newIntervalMs) async {}
  @override
  void dispose() {}
}

/// 5 s of 10 ms blocks: a loud tap for the first 400 ms, then [levels] cycling.
List<TimedLevel> blocks(int start, List<double> levels) => <TimedLevel>[
  for (int t = 0, i = 0; t < 5000; t += 10)
    TimedLevel(start + t, t < 400 ? 104.0 : levels[i++ % levels.length]),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionPreCheckController controller;
  const int start = 2000000;

  setUp(() {
    controller = SessionPreCheckController(
      sessionType: 'free',
      audioLevelService: _SilentAudioService(),
    );
  });

  test(
    'busy gym: the floor (not the 35 dB scale bottom) drives the target',
    () {
      // Gym that measured 75-80 app-dB during the field test.
      controller.calibrateFromBlocksForTesting(
        blocks(start, <double>[75, 76, 77, 78, 79, 80, 96, 99]),
        startMs: start,
      );
      expect(controller.avgAmbientDb.value, closeTo(76.5, 0.6));
      expect(controller.calibratedBaseDb, controller.avgAmbientDb.value);
      expect(controller.initialTargetDb, 85.0, reason: 'floor 76.5 + 8');
      expect(
        controller.maxCalibratedDb.value,
        99.0,
        reason: 'max is logged, but the 104 dB tap in the first 400 ms is not',
      );
    },
  );

  test('quiet room: the target stays clamped at its unchanged minimum', () {
    controller.calibrateFromBlocksForTesting(
      blocks(start, <double>[44, 45, 46]),
      startMs: start,
    );
    expect(controller.initialTargetDb, 66.0);
  });

  test('loud room: the target stays clamped at its unchanged maximum', () {
    controller.calibrateFromBlocksForTesting(
      blocks(start, <double>[88, 89, 90]),
      startMs: start,
    );
    expect(controller.initialTargetDb, 90.0);
  });

  test('the raw calibration values are kept for the session log', () {
    controller.calibrateFromBlocksForTesting(
      blocks(start, <double>[70, 71]),
      startMs: start,
    );
    final Map<String, Object?> report = controller.calibrationReport!;
    expect(report['floorDb'], isA<double>());
    expect(report['ignoredBlocks'], 40);
    expect((report['blocks']! as List<Object?>).length, 500);
    expect((report['blocks']! as List<Object?>).first, <num>[0, 104.0]);
    expect(report['audioService'], <String, Object?>{'mode': 'test'});
  });

  test(
    'mic stuck at the 35 dB scale floor for over 1 s raises the warning',
    () {
      for (int t = 0; t <= 1100; t += 10) {
        controller.onAudioSample(
          AudioLevelSample(db: 35.0, timestampMs: start + t),
        );
      }
      expect(controller.isMicAtScaleFloor.value, isTrue);
      controller.onAudioSample(
        const AudioLevelSample(db: 58.0, timestampMs: start + 1110),
      );
      expect(controller.isMicAtScaleFloor.value, isFalse);
    },
  );
}
