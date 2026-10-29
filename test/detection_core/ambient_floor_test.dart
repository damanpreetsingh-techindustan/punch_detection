import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/calibration/ambient_floor.dart';

/// 5 s of 10 ms blocks starting at [start]: the first 400 ms at [tapDb] (the
/// tap on "Start calibration"), then levels cycling through [levels].
List<TimedLevel> calibrationBlocks({
  required int start,
  required List<double> levels,
  double tapDb = 100.0,
}) {
  final List<TimedLevel> blocks = <TimedLevel>[];
  int i = 0;
  for (int t = 0; t < 5000; t += 10) {
    final double db = t < 400 ? tapDb : levels[i++ % levels.length];
    blocks.add(TimedLevel(start + t, db));
  }
  return blocks;
}

void main() {
  const int start = 1000000;
  const AmbientFloorEstimator estimator = AmbientFloorEstimator();

  group('percentile', () {
    test('interpolates linearly between ranks', () {
      expect(percentile(<double>[1, 2, 3, 4], 0), 1.0);
      expect(percentile(<double>[1, 2, 3, 4], 50), 2.5);
      expect(percentile(<double>[1, 2, 3, 4], 100), 4.0);
      expect(percentile(<double>[5], 20), 5.0);
    });

    test('rejects an empty list', () {
      expect(() => percentile(<double>[], 50), throwsArgumentError);
    });
  });

  group('AmbientFloorEstimator', () {
    test('floor is the mean of the 20th-50th percentile blocks', () {
      // 460 usable blocks, 46 of each level 70, 72, ... 88.
      // p20 = 73.6, p50 = 79 -> blocks 74, 76, 78 -> mean 76.
      final AmbientFloorResult result = estimator.estimate(
        calibrationBlocks(
          start: start,
          levels: <double>[70, 72, 74, 76, 78, 80, 82, 84, 86, 88],
        ),
        startMs: start,
      );
      expect(result.isValid, isTrue);
      expect(result.usedBlocks, 460);
      expect(result.ignoredBlocks, 40);
      expect(result.lowPercentileDb, closeTo(73.6, 1e-9));
      expect(result.highPercentileDb, closeTo(79.0, 1e-9));
      expect(result.floorDb, closeTo(76.0, 1e-9));
    });

    test('the first 400 ms are ignored for the floor AND the max', () {
      final AmbientFloorResult result = estimator.estimate(
        calibrationBlocks(start: start, levels: <double>[60, 62], tapDb: 105),
        startMs: start,
      );
      expect(result.maxDb, 62.0, reason: 'the 105 dB tap must not count');
      expect(result.floorDb, lessThan(62.0));
    });

    test('loud events in the room do not move the floor', () {
      // Gym: mostly 76 dB, with 15% loud clangs at 100 dB and 5% drop-outs.
      final List<double> levels = <double>[
        for (int i = 0; i < 80; i++) 76,
        for (int i = 0; i < 15; i++) 100,
        for (int i = 0; i < 5; i++) 40,
      ];
      final AmbientFloorResult result = estimator.estimate(
        calibrationBlocks(start: start, levels: levels),
        startMs: start,
      );
      expect(result.floorDb, closeTo(76.0, 1e-9));
      expect(result.maxDb, 100.0);
    });

    test('a silent mic (scale floor) gives a floor at the scale floor', () {
      final AmbientFloorResult result = estimator.estimate(
        calibrationBlocks(start: start, levels: <double>[35]),
        startMs: start,
      );
      expect(result.floorDb, 35.0);
    });

    test('no usable blocks -> fallback value, marked invalid', () {
      final AmbientFloorResult result = estimator.estimate(<TimedLevel>[
        const TimedLevel(start + 100, 80),
      ], startMs: start);
      expect(result.isValid, isFalse);
      expect(result.floorDb, estimator.fallbackDb);
      expect(result.ignoredBlocks, 1);
    });
  });

  group('MicFloorWatchdog', () {
    test('trips only after more than 1 s at the scale floor', () {
      final MicFloorWatchdog watchdog = MicFloorWatchdog();
      for (int t = 0; t <= 1000; t += 10) {
        expect(watchdog.update(35.0, start + t), isFalse, reason: 't=$t');
      }
      expect(watchdog.update(35.0, start + 1010), isTrue);
    });

    test('any block above the floor resets it', () {
      final MicFloorWatchdog watchdog = MicFloorWatchdog();
      for (int t = 0; t <= 1200; t += 10) {
        watchdog.update(35.0, start + t);
      }
      expect(watchdog.isAtFloorTooLong, isTrue);
      expect(watchdog.update(52.0, start + 1210), isFalse);
      expect(watchdog.update(35.0, start + 1220), isFalse);
    });
  });
}
