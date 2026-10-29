import 'dart:typed_data';

/// One raw PCM16 buffer exactly as the microphone delivered it.
class RawPcmChunk {
  /// Little-endian 16-bit samples.
  final Uint8List bytes;
  final int sampleRate;
  final int channels;

  /// Detection-clock time (`MonotonicClock.epochUs`) the buffer arrived in Dart.
  final int arrivalUs;

  /// 1-based index of the buffer in this capture.
  final int chunkIndex;

  const RawPcmChunk({
    required this.bytes,
    required this.sampleRate,
    required this.channels,
    required this.arrivalUs,
    required this.chunkIndex,
  });

  /// Samples per channel in this buffer.
  int get frames => bytes.length ~/ (2 * channels);
}

/// Implemented by audio services that can hand out the raw PCM they capture
/// (used by the raw session recorder; detection uses the level streams).
abstract class IRawPcmSource {
  /// Raw buffers while a PCM capture is running (broadcast).
  Stream<RawPcmChunk> get rawPcmStream;
}
