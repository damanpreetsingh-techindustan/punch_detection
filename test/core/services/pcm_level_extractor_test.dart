import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/audio_level/pcm_level_extractor.dart';

/// Builds PCM16 little-endian bytes from sample values.
Uint8List pcm(List<int> samples) {
  final ByteData data = ByteData(samples.length * 2);
  for (int i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

/// `count` samples of a constant magnitude.
List<int> tone(int count, int value) => List<int>.filled(count, value);

void main() {
  // 16 kHz, 10 ms blocks -> 160 samples per block (the app's Android rate).
  const int sampleRate = 16000;
  const int blockSamples = 160;

  PcmLevelExtractor newExtractor({int channels = 1}) => PcmLevelExtractor(
    sampleRate: sampleRate,
    channels: channels,
    blockMs: 10,
  );

  group('block size', () {
    test('10 ms at 16 kHz is 160 samples and 10 ms at 44.1 kHz is 441', () {
      expect(newExtractor().blockSamples, blockSamples);
      expect(
        PcmLevelExtractor(sampleRate: 44100, blockMs: 10).blockSamples,
        441,
      );
    });
  });

  group('levels', () {
    test('silence maps to the floor of the app scale', () {
      final blocks = newExtractor().extract(pcm(tone(blockSamples * 3, 0)));
      expect(blocks.length, 3);
      for (final b in blocks) {
        expect(b.db, 35.0);
        expect(b.clipped, isFalse);
      }
    });

    test('a click shows up in exactly the block that contains it', () {
      final List<int> samples = <int>[
        ...tone(blockSamples, 0),
        ...tone(blockSamples, 20000),
        ...tone(blockSamples, 0),
      ];
      final blocks = newExtractor().extract(pcm(samples));
      expect(blocks.length, 3);
      expect(blocks[0].db, 35.0);
      expect(blocks[1].db, greaterThan(100.0));
      expect(blocks[2].db, 35.0);
    });

    test('negative samples count by magnitude', () {
      final blocks = newExtractor().extract(pcm(tone(blockSamples, -20000)));
      expect(blocks.single.db, greaterThan(100.0));
    });

    test('a full-scale block is flagged clipped and reads 110', () {
      final blocks = newExtractor().extract(pcm(tone(blockSamples, 32767)));
      expect(blocks.single.clipped, isTrue);
      expect(blocks.single.db, closeTo(110.0, 0.05));
    });

    test('a loud but not clipped block is not flagged', () {
      final blocks = newExtractor().extract(pcm(tone(blockSamples, 12000)));
      expect(blocks.single.clipped, isFalse);
    });
  });

  group('two punches 150 ms apart (the missed-punch case)', () {
    test('a quiet valley is visible between them at 10 ms resolution', () {
      // 150 ms = 15 blocks. Click, 14 quiet blocks, click.
      final List<int> samples = <int>[
        ...tone(blockSamples * 2, 0),
        ...tone(blockSamples, 30000), // punch 1 (block 2)
        ...tone(blockSamples * 14, 400), // tail / room noise
        ...tone(blockSamples, 30000), // punch 2 (block 17)
        ...tone(blockSamples * 2, 0),
      ];
      final blocks = newExtractor().extract(pcm(samples));
      expect(blocks.length, 20);

      final List<double> dbs = blocks.map((b) => b.db).toList();
      expect(dbs[2], greaterThan(100.0));
      expect(dbs[17], greaterThan(100.0));
      // The dip between the punches is far below both peaks, so a rise of at
      // least the onset threshold (>= 10 dB) is measurable for the second one.
      final double valley = dbs.sublist(3, 17).reduce((a, b) => a < b ? a : b);
      expect(dbs[17] - valley, greaterThan(40.0));
    });

    test('with one 80 ms chunk-wide peak the dip disappears (legacy behaviour)', () {
      // Peak over the whole 150 ms window: what the whole-chunk amplitude sees.
      final List<int> samples = <int>[
        ...tone(blockSamples, 30000),
        ...tone(blockSamples * 14, 400),
        ...tone(blockSamples, 30000),
      ];
      final PcmLevelExtractor wide = PcmLevelExtractor(
        sampleRate: sampleRate,
        blockMs: 160,
      );
      final blocks = wide.extract(pcm(samples));
      expect(blocks.length, 1);
      // One reading for both punches: no valley, so no onset between them.
      expect(blocks.single.db, greaterThan(100.0));
    });
  });

  group('chunk boundaries', () {
    test('a block split across two chunks gives the same result as one chunk', () {
      final List<int> samples = <int>[
        ...tone(blockSamples, 0),
        ...tone(blockSamples, 25000),
        ...tone(blockSamples, 0),
      ];
      final Uint8List bytes = pcm(samples);

      final whole = newExtractor().extract(bytes);
      final PcmLevelExtractor split = newExtractor();
      final List<PcmLevelBlock> parts = <PcmLevelBlock>[
        ...split.extract(bytes.sublist(0, 250)), // even cut
        ...split.extract(bytes.sublist(250, 701)), // odd length
        ...split.extract(bytes.sublist(701)),
      ];

      expect(parts.length, whole.length);
      for (int i = 0; i < whole.length; i++) {
        expect(parts[i].db, closeTo(whole[i].db, 1e-9));
      }
    });

    test('odd-length chunks keep the dangling byte for the next chunk', () {
      final Uint8List bytes = pcm(tone(blockSamples * 2, 20000)); // 640 bytes
      final PcmLevelExtractor extractor = newExtractor();
      final a = extractor.extract(bytes.sublist(0, 321)); // 160.5 samples
      final b = extractor.extract(bytes.sublist(321));
      expect(a.length + b.length, 2);
      for (final PcmLevelBlock block in a + b) {
        expect(block.db, greaterThan(100.0));
      }
    });

    test('empty chunk returns no blocks', () {
      expect(newExtractor().extract(Uint8List(0)), isEmpty);
    });

    test('samplesAfterBlockEnd lets callers back-date each block', () {
      final PcmLevelExtractor extractor = newExtractor();
      // 400 samples: blocks end at 160 and 320, leaving 80 carried over.
      final first = extractor.extract(pcm(tone(400, 100)));
      expect(first.length, 2);
      expect(first[0].samplesAfterBlockEnd, 240);
      expect(first[1].samplesAfterBlockEnd, 80);

      // Next chunk of 200: the carried 80 + 80 more close a block, 120 remain
      // (less than a block, so they are carried again).
      final second = extractor.extract(pcm(tone(200, 100)));
      expect(second.length, 1);
      expect(second.single.samplesAfterBlockEnd, 120);

      // A chunk of 240 then closes two blocks: one after 40 frames (120 + 40),
      // the next exactly at the end of the chunk.
      final third = extractor.extract(pcm(tone(240, 100)));
      expect(third.length, 2);
      expect(third[0].samplesAfterBlockEnd, 200);
      expect(third[1].samplesAfterBlockEnd, 40);
    });

    test('reset drops carried-over samples', () {
      final PcmLevelExtractor extractor = newExtractor();
      extractor.extract(pcm(tone(100, 30000)));
      extractor.reset();
      final blocks = extractor.extract(pcm(tone(blockSamples, 0)));
      expect(blocks.single.db, 35.0);
    });
  });

  group('channels', () {
    test('stereo frames use the louder channel and count frames, not samples', () {
      // 160 stereo frames: left silent, right loud.
      final List<int> interleaved = <int>[];
      for (int i = 0; i < blockSamples; i++) {
        interleaved
          ..add(0)
          ..add(20000);
      }
      final blocks = newExtractor(channels: 2).extract(pcm(interleaved));
      expect(blocks.length, 1);
      expect(blocks.single.db, greaterThan(100.0));
    });
  });

  group('dB mapping', () {
    test('matches the legacy amplitude formula across the dBFS range', () {
      for (double dbfs = -80.0; dbfs <= 0.0; dbfs += 2.5) {
        final double legacy =
            ((dbfs.clamp(-60.0, 0.0) + 60.0) * 1.25 + 35.0).clamp(30.0, 110.0);
        expect(
          PcmLevelExtractor.mapDbfsToDb(dbfs),
          closeTo(legacy, 1e-9),
          reason: 'dBFS $dbfs',
        );
      }
    });

    test('peakToDbfs is 0 at full scale and clamped to <= 0', () {
      expect(PcmLevelExtractor.peakToDbfs(32768), closeTo(0.0, 1e-9));
      expect(PcmLevelExtractor.peakToDbfs(40000), 0.0);
      expect(PcmLevelExtractor.peakToDbfs(16384), closeTo(-6.0206, 1e-3));
      expect(PcmLevelExtractor.peakToDbfs(0), -160.0);
    });
  });
}
