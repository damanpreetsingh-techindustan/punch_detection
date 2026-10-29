import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/accel/shock_tracker.dart';
import 'package:punch_detection_demo/detection_core/audio/audio_onset_tracker.dart';
import 'package:punch_detection_demo/detection_core/config/detector_config.dart';
import 'package:punch_detection_demo/detection_core/dsp/dsp.dart';

const int t0 = 1000000000;
const DetectorConfig config = DetectorConfig();

/// White noise at [rms] with optional decaying 110 Hz hits (amplitude, time s).
Int16List audioSignal(
  double seconds, {
  double rms = 0.01,
  List<(double, double)> hits = const <(double, double)>[],
  double decayDbPerS = 60,
  int seed = 1,
}) {
  final Random rng = Random(seed);
  final int n = (seconds * 16000).round();
  final Float64List x = Float64List(n);
  for (int i = 0; i < n; i++) {
    x[i] = rms * (rng.nextDouble() * 2 - 1) * sqrt(3);
  }
  for (final (double amp, double at) in hits) {
    final int i0 = (at * 16000).round();
    for (int k = 0; i0 + k < n; k++) {
      final double t = k / 16000;
      x[i0 + k] +=
          amp *
          min(1.0, t * 1000 / 1.5) *
          exp(-decayDbPerS / 8.686 * t) *
          sin(2 * pi * 110 * t);
    }
  }
  return Int16List.fromList(<int>[
    for (final double v in x) (v * 32767).round().clamp(-32768, 32767),
  ]);
}

List<AudioCandidate> runAudio(AudioOnsetTracker tr, Int16List pcm) {
  final List<AudioCandidate> out = <AudioCandidate>[];
  for (int i = 0; i < pcm.length; i += 160) {
    out.addAll(
      tr.process(
        Int16List.sublistView(pcm, i, min(pcm.length, i + 160)),
        t0 + (i * 62.5).round(),
      ),
    );
  }
  return out;
}

void main() {
  group('AudioOnsetTracker', () {
    test('a hit over the room floor is a candidate dated to its onset', () {
      final AudioOnsetTracker tr = AudioOnsetTracker(
        config: config,
        initialDecayDbPerS: 60,
      );
      final List<AudioCandidate> c = runAudio(
        tr,
        audioSignal(2, hits: const <(double, double)>[(0.3, 1.0)]),
      );
      expect(c, hasLength(1));
      expect((c.first.onsetUs - (t0 + 1000000)).abs(), lessThan(2000));
      expect(c.first.noveltyDb, greaterThan(15));
    });

    test('the ringing tail alone never re-triggers', () {
      final AudioOnsetTracker tr = AudioOnsetTracker(
        config: config,
        initialDecayDbPerS: 60,
      );
      final List<AudioCandidate> c = runAudio(
        tr,
        audioSignal(3, hits: const <(double, double)>[(0.3, 1.0)]),
      );
      expect(c, hasLength(1));
    });

    test('a second hit inside the tail registers (decay prediction)', () {
      final AudioOnsetTracker tr = AudioOnsetTracker(
        config: config,
        initialDecayDbPerS: 60,
      );
      final List<AudioCandidate> c = runAudio(
        tr,
        audioSignal(2, hits: const <(double, double)>[(0.3, 1.0), (0.3, 1.25)]),
      );
      expect(c, hasLength(2));
      expect((c[1].onsetUs - (t0 + 1250000)).abs(), lessThan(2000));
    });

    test('the floor follows the room (20th percentile, not the hits)', () {
      final AudioOnsetTracker tr = AudioOnsetTracker(
        config: config,
        initialDecayDbPerS: 60,
      );
      runAudio(tr, audioSignal(4, rms: 0.01));
      final double quiet = tr.fullFloorDb;
      expect(quiet, closeTo(-40, 1.5)); // 0.01 rms = -40 dBFS
      final AudioOnsetTracker loud = AudioOnsetTracker(
        config: config,
        initialDecayDbPerS: 60,
      );
      runAudio(loud, audioSignal(4, rms: 0.05));
      expect(loud.fullFloorDb, closeTo(quiet + 14, 1.5));
    });

    test('frames right after an accepted hit stay out of the floor', () {
      // 1 s of room, then a fast combo: a hit every 200 ms ringing at
      // 120 dB/s, so without the exclusion most frames sit above the room.
      AudioOnsetTracker run({required bool accept}) {
        final AudioOnsetTracker tr = AudioOnsetTracker(
          config: config,
          initialDecayDbPerS: 120,
        );
        final Int16List pcm = audioSignal(
          3.5,
          hits: <(double, double)>[
            for (double t = 1.0; t < 3.5; t += 0.2) (0.3, t),
          ],
          decayDbPerS: 120,
        );
        for (int i = 0; i < pcm.length; i += 160) {
          for (final AudioCandidate c in tr.process(
            Int16List.sublistView(pcm, i, min(pcm.length, i + 160)),
            t0 + (i * 62.5).round(),
          )) {
            if (accept) tr.notifyAccepted(c.onsetUs, isolated: false);
          }
        }
        return tr;
      }

      final double withExclusion = run(accept: true).fullFloorDb;
      final double without = run(accept: false).fullFloorDb;
      expect(withExclusion, closeTo(-40, 2));
      expect(without, greaterThan(withExclusion + 1));
    });
  });

  group('ShockTracker', () {
    List<AccelSampleIn> accel(
      double seconds, {
      List<(double, double)> shocks = const <(double, double)>[],
      double tauS = 0.15,
      double tilt = 0,
    }) {
      final Random rng = Random(5);
      final int n = (seconds * 200).round();
      return <AccelSampleIn>[
        for (int i = 0; i < n; i++)
          () {
            final double t = i / 200;
            double z = 9.81 + 0.02 * (rng.nextDouble() * 2 - 1);
            for (final (double g, double at) in shocks) {
              if (t >= at) {
                z +=
                    g * exp(-(t - at) / tauS) * sin(2 * pi * 25 * (t - at) + 1);
              }
            }
            return AccelSampleIn(
              t0 + (t * 1e6).round(),
              tilt * t,
              0.01 * (rng.nextDouble() * 2 - 1),
              z,
            );
          }(),
      ];
    }

    List<ShockCandidate> run(ShockTracker tr, List<AccelSampleIn> s) =>
        <ShockCandidate>[for (final AccelSampleIn a in s) ...tr.add(a)];

    test('gravity and a slow tilt are not shocks', () {
      final ShockTracker tr = ShockTracker(
        config: config,
        initialRingTauMs: 150,
      );
      expect(run(tr, accel(5, tilt: 0.5)), isEmpty);
    });

    test('one shock -> one candidate; its ringing does not re-trigger', () {
      final ShockTracker tr = ShockTracker(
        config: config,
        initialRingTauMs: 150,
      );
      final List<ShockCandidate> c = run(
        tr,
        accel(4, shocks: const <(double, double)>[(2.0, 2.0)]),
      );
      expect(c, hasLength(1));
      expect((c.first.onsetUs - (t0 + 2000000)).abs(), lessThanOrEqualTo(5000));
    });

    test('a second shock inside the ring registers', () {
      final ShockTracker tr = ShockTracker(
        config: config,
        initialRingTauMs: 150,
      );
      final List<ShockCandidate> c = run(
        tr,
        accel(4, shocks: const <(double, double)>[(2.0, 2.0), (2.0, 2.25)]),
      );
      expect(c, hasLength(2));
    });

    test('the ring time constant is learned from isolated hits', () {
      final ShockTracker tr = ShockTracker(
        config: config,
        initialRingTauMs: 60,
      );
      final List<(double, double)> shocks = <(double, double)>[
        for (double t = 1; t < 15; t += 1.2) (2.0, t),
      ];
      for (final AccelSampleIn a in accel(16, shocks: shocks, tauS: 0.2)) {
        for (final ShockCandidate c in tr.add(a)) {
          tr.notifyAccepted(c.onsetUs, isolated: true);
        }
      }
      expect(tr.ringTauMs, closeTo(200, 40));
    });
  });

  group('DSP helpers', () {
    test('rolling percentile over a time window', () {
      final RollingPercentile p = RollingPercentile(
        minValue: 0,
        maxValue: 100,
        binWidth: 1,
        windowUs: 1000000,
      );
      for (int i = 0; i < 100; i++) {
        p.add(i.toDouble(), i * 1000);
      }
      expect(p.percentile(20), closeTo(19.5, 1));
      p.add(50, 2000000); // everything older than 1 s drops out
      expect(p.count, 1);
      expect(p.percentile(20), closeTo(50.5, 0.01));
    });

    test('running median drops its seed after real values arrive', () {
      final RunningMedian m = RunningMedian(capacity: 5, seed: 20);
      expect(m.median, 20);
      m.add(40);
      expect(m.median, 20, reason: 'seed still dominates');
      m
        ..add(40)
        ..add(40);
      expect(m.median, 40);
      expect(m.count, 3);
    });

    test('FFT finds a pure tone', () {
      final Float64List power = powerSpectrum(<double>[
        for (int i = 0; i < 512; i++) sin(2 * pi * 1000 * i / 16000),
      ], 512);
      int peak = 0;
      for (int k = 1; k < power.length; k++) {
        if (power[k] > power[peak]) peak = k;
      }
      expect(peak * 16000 / 512, closeTo(1000, 31.25));
    });
  });
}
