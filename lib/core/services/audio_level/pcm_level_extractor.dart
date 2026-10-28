import 'dart:math';
import 'dart:typed_data';

/// Level of one fixed-length block of PCM audio.
class PcmLevelBlock {
  /// Level on the app's 30–110 dB scale.
  final double db;

  /// Peak level in dBFS (0 = digital full scale, clamped to <= 0).
  final double dbfs;

  /// True when the block peak reached (almost) full scale.
  final bool clipped;

  /// Number of samples (per channel) that were received *after* the end of this
  /// block, within the same chunk. Used to back-date the block: its end time is
  /// the chunk arrival time minus `samplesAfterBlockEnd / sampleRate`.
  final int samplesAfterBlockEnd;

  const PcmLevelBlock({
    required this.db,
    required this.dbfs,
    required this.clipped,
    required this.samplesAfterBlockEnd,
  });
}

/// Turns a stream of raw PCM16 chunks into per-block peak levels.
///
/// Why: the native amplitude API reports one peak per whole plugin chunk (tens of
/// milliseconds), so two punches 150 ms apart can end up in neighbouring chunks
/// with no visible dip between them. Splitting every chunk into short blocks
/// (default 10 ms) restores the dip and the onset the detector looks for.
///
/// Pure: no clocks and no I/O, so it is unit-testable. Partial blocks and odd
/// bytes are carried over to the next chunk.
class PcmLevelExtractor {
  PcmLevelExtractor({
    required this.sampleRate,
    this.channels = 1,
    required int blockMs,
  }) : blockSamples = max(1, (sampleRate * blockMs / 1000).round());

  final int sampleRate;
  final int channels;

  /// Samples per channel in one output block.
  final int blockSamples;

  /// Peak magnitude at or above which a block counts as clipped (~ -0.5 dBFS).
  static const int clipThreshold = 32000;

  static const double _fullScale = 32768.0;

  int _blockPeak = 0;
  int _blockFill = 0; // frames accumulated in the current partial block
  int? _danglingByte;
  final List<int> _partialFrame = <int>[];

  /// Maps a dBFS peak to the app's 30–110 dB scale (the formula the legacy
  /// amplitude path uses, so thresholds and calibration stay valid).
  static double mapDbfsToDb(double rawDbFS, {double maxDb = 110.0}) {
    return ((rawDbFS.clamp(-60.0, 0.0) + 60.0) * 1.25 + 35.0).clamp(
      30.0,
      maxDb,
    );
  }

  /// Converts a peak magnitude (0..32768) to dBFS, clamped to <= 0.
  static double peakToDbfs(int peak) {
    if (peak <= 0) return -160.0;
    return min(0.0, 20 * log(peak / _fullScale) / ln10);
  }

  /// Consumes one PCM16 little-endian chunk and returns every block it completed.
  List<PcmLevelBlock> extract(Uint8List chunk) {
    final List<PcmLevelBlock> blocks = <PcmLevelBlock>[];
    if (chunk.isEmpty) return blocks;

    // Rebuild samples, honouring a byte left over from the previous odd chunk.
    final int dangling = _danglingByte == null ? 0 : 1;
    final int totalBytes = chunk.length + dangling;
    final int sampleCount = totalBytes ~/ 2;
    final Int16List samples = Int16List(sampleCount);
    int byteIndex = 0;
    int sampleIndex = 0;
    if (_danglingByte != null && sampleCount > 0) {
      final int lo = _danglingByte!;
      final int hi = chunk[byteIndex++];
      samples[sampleIndex++] = _toInt16(lo | (hi << 8));
      _danglingByte = null;
    }
    while (sampleIndex < sampleCount) {
      final int lo = chunk[byteIndex++];
      final int hi = chunk[byteIndex++];
      samples[sampleIndex++] = _toInt16(lo | (hi << 8));
    }
    if (byteIndex < chunk.length) {
      _danglingByte = chunk[byteIndex];
    }

    // Group samples into frames (one sample per channel), then into blocks.
    final List<_PendingBlock> completed = <_PendingBlock>[];
    int framesConsumed = 0;
    int i = 0;
    while (i < sampleCount) {
      _partialFrame.add(samples[i].abs());
      i++;
      if (_partialFrame.length < channels) continue;
      for (final int mag in _partialFrame) {
        if (mag > _blockPeak) _blockPeak = mag;
      }
      _partialFrame.clear();
      _blockFill++;
      framesConsumed++;
      if (_blockFill >= blockSamples) {
        completed.add(_PendingBlock(_blockPeak, framesConsumed));
        _blockPeak = 0;
        _blockFill = 0;
      }
    }

    final int totalFrames = framesConsumed;
    for (final _PendingBlock pending in completed) {
      final double dbfs = peakToDbfs(pending.peak);
      blocks.add(
        PcmLevelBlock(
          db: mapDbfsToDb(dbfs),
          dbfs: dbfs,
          clipped: pending.peak >= clipThreshold,
          samplesAfterBlockEnd: totalFrames - pending.endFrame,
        ),
      );
    }
    return blocks;
  }

  /// Clears carried-over state (call when the stream restarts).
  void reset() {
    _blockPeak = 0;
    _blockFill = 0;
    _danglingByte = null;
    _partialFrame.clear();
  }

  static int _toInt16(int value) => value >= 0x8000 ? value - 0x10000 : value;
}

class _PendingBlock {
  final int peak;
  final int endFrame; // frames of this chunk consumed when the block closed
  const _PendingBlock(this.peak, this.endFrame);
}
