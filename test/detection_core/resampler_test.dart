import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/audio/resampler.dart';

Int16List tone(double hz, int rate, int n, {double amplitude = 10000}) =>
    Int16List.fromList(<int>[
      for (int i = 0; i < n; i++)
        (amplitude * sin(2 * pi * hz * i / rate)).round(),
    ]);

double rms(Int16List x, {int skip = 0}) {
  double sum = 0;
  for (int i = skip; i < x.length - skip; i++) {
    sum += x[i] * x[i];
  }
  return sqrt(sum / (x.length - 2 * skip));
}

int zeroCrossings(Int16List x, {int skip = 0}) {
  int n = 0;
  for (int i = skip + 1; i < x.length - skip; i++) {
    if ((x[i - 1] < 0) != (x[i] < 0)) n++;
  }
  return n;
}

void main() {
  group('StreamingResampler 44.1 kHz -> 16 kHz', () {
    test('a 1 kHz tone keeps its frequency and level', () {
      final StreamingResampler r = StreamingResampler(
        inRate: 44100,
        outRate: 16000,
      );
      final Int16List out = r.process(tone(1000, 44100, 44100));
      expect(out.length, closeTo(16000, 40));
      // 1 kHz -> 2000 zero crossings per second.
      expect(
        zeroCrossings(out, skip: 100),
        closeTo(2000 * (out.length - 200) / 16000, 6),
      );
      expect(rms(out, skip: 100), closeTo(10000 / sqrt2, 250));
    });

    test('a 12 kHz tone (above the new Nyquist) is filtered out', () {
      final StreamingResampler r = StreamingResampler(
        inRate: 44100,
        outRate: 16000,
      );
      final Int16List out = r.process(tone(12000, 44100, 44100));
      expect(rms(out, skip: 100), lessThan(10000 / sqrt2 * 0.02));
    });

    test('output does not depend on chunk sizes', () {
      final Int16List input = tone(440, 44100, 8820);
      final Int16List whole = StreamingResampler(
        inRate: 44100,
        outRate: 16000,
      ).process(input);
      final StreamingResampler chunked = StreamingResampler(
        inRate: 44100,
        outRate: 16000,
      );
      final List<int> parts = <int>[];
      int i = 0;
      final Random rng = Random(3);
      while (i < input.length) {
        final int n = min(input.length - i, 1 + rng.nextInt(900));
        parts.addAll(chunked.process(Int16List.sublistView(input, i, i + n)));
        i += n;
      }
      expect(parts, whole);
    });

    test('equal rates pass samples through unchanged', () {
      final StreamingResampler r = StreamingResampler(
        inRate: 16000,
        outRate: 16000,
      );
      final Int16List input = tone(500, 16000, 1000);
      expect(r.process(input), input);
      expect(r.outputSamples, 1000);
    });
  });
}
