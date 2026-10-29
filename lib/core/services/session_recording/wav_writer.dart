import 'dart:io';
import 'dart:typed_data';

/// Streams 16-bit PCM to a WAV file. The 44-byte header is written first with
/// zero sizes and patched with the real sizes in [close], so a file whose
/// session crashed is still readable by tools that ignore the size fields.
class WavWriter {
  WavWriter({required this.path, required this.sampleRate, this.channels = 1});

  final String path;
  final int sampleRate;
  final int channels;

  RandomAccessFile? _file;
  Future<void> _pending = Future<void>.value();
  int _samplesWritten = 0;
  bool _closed = false;

  /// Samples (per channel) written so far.
  int get samplesWritten => _samplesWritten;

  Future<void> open() async {
    final RandomAccessFile file = await File(path).open(mode: FileMode.write);
    await file.writeFrom(
      buildHeader(sampleRate: sampleRate, channels: channels, dataBytes: 0),
    );
    _file = file;
  }

  /// Appends samples (host order is little-endian on every supported target).
  void write(Int16List samples) {
    final RandomAccessFile? file = _file;
    if (file == null || _closed || samples.isEmpty) return;
    final Uint8List bytes = Uint8List.fromList(
      samples.buffer.asUint8List(samples.offsetInBytes, samples.lengthInBytes),
    );
    _samplesWritten += samples.length ~/ channels;
    _pending = _pending.then((_) => file.writeFrom(bytes)).then((_) {});
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final RandomAccessFile? file = _file;
    if (file == null) return;
    await _pending;
    await file.setPosition(0);
    await file.writeFrom(
      buildHeader(
        sampleRate: sampleRate,
        channels: channels,
        dataBytes: _samplesWritten * channels * 2,
      ),
    );
    await file.close();
    _file = null;
  }

  /// Canonical 44-byte PCM WAV header.
  static Uint8List buildHeader({
    required int sampleRate,
    required int channels,
    required int dataBytes,
  }) {
    final ByteData header = ByteData(44);
    void ascii(int offset, String text) {
      for (int i = 0; i < text.length; i++) {
        header.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    const int bitsPerSample = 16;
    final int blockAlign = channels * bitsPerSample ~/ 8;
    ascii(0, 'RIFF');
    header.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * blockAlign, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, dataBytes, Endian.little);
    return header.buffer.asUint8List();
  }
}
