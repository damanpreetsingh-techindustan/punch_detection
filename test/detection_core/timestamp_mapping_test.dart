import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/timing/clock_offset_estimator.dart';
import 'package:punch_detection_demo/detection_core/timing/sample_clock.dart';

void main() {
  group('ClockOffsetEstimator (native sensor clock -> detection clock)', () {
    test('the fastest message gives the offset; latency is never added', () {
      const int trueOffset = 1700000000000000; // detection = native + offset
      final ClockOffsetEstimator estimator = ClockOffsetEstimator();
      final Random rng = Random(1);
      for (int i = 0; i < 200; i++) {
        final int nativeUs = 5000000 + i * 20000;
        final int latency = 300 + rng.nextInt(4000); // 0.3-4.3 ms channel delay
        estimator.addObservation(
          nativeUs: nativeUs,
          receivedUs: nativeUs + trueOffset + latency,
        );
      }
      expect(estimator.offsetUs! - trueOffset, inInclusiveRange(300, 400));
      // A sensor event 10 ms before a batch was sent maps 10 ms earlier.
      expect(
        estimator.toDetectionUs(9000000)! - (9000000 + trueOffset),
        lessThan(400),
      );
      expect(estimator.medianExtraLatencyUs, greaterThan(1000));
    });

    test('no observation yet -> no mapping', () {
      final ClockOffsetEstimator estimator = ClockOffsetEstimator();
      expect(estimator.offsetUs, isNull);
      expect(estimator.toDetectionUs(123), isNull);
    });

    test('the window follows a clock step (old minimum expires)', () {
      final ClockOffsetEstimator estimator = ClockOffsetEstimator(
        windowSize: 10,
      );
      for (int i = 0; i < 10; i++) {
        estimator.addObservation(nativeUs: i * 1000, receivedUs: i * 1000 + 50);
      }
      expect(estimator.offsetUs, 50);
      for (int i = 10; i < 20; i++) {
        estimator.addObservation(
          nativeUs: i * 1000,
          receivedUs: i * 1000 + 900,
        );
      }
      expect(estimator.offsetUs, 900);
    });
  });

  group('SampleClockMapping (audio sample index -> detection clock)', () {
    /// Arrivals of 20 ms buffers from a capture whose real rate is
    /// [realRate], each delivered 2-12 ms late.
    List<SyncPoint> arrivals({
      required double realRate,
      required int t0Us,
      int seconds = 60,
    }) {
      final Random rng = Random(7);
      final List<SyncPoint> points = <SyncPoint>[];
      const int chunk = 320; // 20 ms at 16 kHz
      for (int end = chunk; end <= realRate * seconds; end += chunk) {
        final double captureUs = t0Us + end * 1e6 / realRate;
        final int latency = 2000 + rng.nextInt(10000);
        points.add(SyncPoint(end, (captureUs + latency).round()));
      }
      return points;
    }

    test('recovers the real rate and the least-delayed intercept', () {
      const int t0 = 1000000000;
      // Capture clock runs 60 ppm fast against the system clock.
      const double realRate = 16000 * 1.00006;
      final SyncPointCollector collector = SyncPointCollector(
        nominalRate: 16000,
      );
      for (final SyncPoint p in arrivals(realRate: realRate, t0Us: t0)) {
        collector.addArrival(endSampleIndex: p.sampleIndex, arrivalUs: p.tUs);
      }
      collector.flush();
      expect(collector.points.length, inInclusiveRange(59, 61));

      final SampleClockMapping mapping = SampleClockMapping.fit(
        collector.points,
        nominalRate: 16000,
      );
      expect(mapping.effectiveRateHz, closeTo(realRate, 0.5));
      // Sample 0 was captured at t0; the mapping is at most ~3 ms late
      // (only the fastest arrival of each second is kept).
      expect(mapping.timeUsOf(0) - t0, inInclusiveRange(1900, 3000));
      // 59 s later the error stays the same (drift handled by the slope).
      final double captured = t0 + 944000 * 1e6 / realRate;
      expect(mapping.timeUsOf(944000) - captured, inInclusiveRange(1500, 3500));
      expect(
        mapping.sampleIndexAt(mapping.timeUsOf(5000)),
        closeTo(5000, 1e-6),
      );
    });

    test('one second per sync point, keeping the least-delayed arrival', () {
      final SyncPointCollector collector = SyncPointCollector(
        nominalRate: 1000,
        periodUs: 1000000,
      );
      // Three arrivals in the first second; the middle one is the fastest.
      expect(
        collector.addArrival(endSampleIndex: 100, arrivalUs: 110000),
        isNull,
      );
      collector.addArrival(endSampleIndex: 200, arrivalUs: 201000);
      collector.addArrival(endSampleIndex: 300, arrivalUs: 330000);
      final SyncPoint? emitted = collector.addArrival(
        endSampleIndex: 1100,
        arrivalUs: 1120000,
      );
      expect(emitted?.sampleIndex, 200);
      expect(emitted?.tUs, 201000);
      expect(collector.first!.sampleIndex, 100);
    });

    test('short recordings fall back to the nominal rate', () {
      final SampleClockMapping mapping = SampleClockMapping.fit(
        const <SyncPoint>[SyncPoint(320, 50000), SyncPoint(640, 70500)],
        nominalRate: 16000,
      );
      expect(mapping.usPerSample, 62.5);
      expect(mapping.timeUsOf(320), 50000);
    });

    test('an absurd fitted rate is clamped to 1% of nominal', () {
      final SampleClockMapping mapping = SampleClockMapping.fit(
        const <SyncPoint>[SyncPoint(0, 0), SyncPoint(16000, 2000000)],
        nominalRate: 16000,
      );
      expect(mapping.effectiveRateHz, closeTo(16000 / 1.01, 0.5));
    });
  });
}
