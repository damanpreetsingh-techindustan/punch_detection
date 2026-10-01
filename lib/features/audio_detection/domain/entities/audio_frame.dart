import 'dart:math';
import 'package:equatable/equatable.dart';

class AudioFrame extends Equatable {
  final List<int> pcmBytes;
  final int sampleRate;
  final int channels;
  final int timestampMicroseconds;

  const AudioFrame({
    required this.pcmBytes,
    this.sampleRate = 16000,
    this.channels = 1,
    required this.timestampMicroseconds,
  });

  /// Calculates Root Mean Square (RMS) energy normalized between 0.0 and 1.0.
  double get rmsEnergy {
    if (pcmBytes.isEmpty) return 0.0;

    double sum = 0;
    final int sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount == 0) return 0.0;

    for (int i = 0; i < pcmBytes.length - 1; i += 2) {
      // 16-bit PCM Little Endian
      final int sample = (pcmBytes[i + 1] << 8) | (pcmBytes[i] & 0xFF);
      final int signSample = sample.toSigned(16);
      final double normalized = signSample / 32768.0;
      sum += normalized * normalized;
    }

    return sqrt(sum / sampleCount);
  }

  /// Calculates Peak Amplitude normalized between 0.0 and 1.0.
  double get peakAmplitude {
    if (pcmBytes.isEmpty) return 0.0;

    int maxSample = 0;
    for (int i = 0; i < pcmBytes.length - 1; i += 2) {
      final int sample = ((pcmBytes[i + 1] << 8) | (pcmBytes[i] & 0xFF)).toSigned(16);
      final int absSample = sample.abs();
      if (absSample > maxSample) {
        maxSample = absSample;
      }
    }

    return maxSample / 32768.0;
  }

  @override
  List<Object?> get props => [sampleRate, channels, timestampMicroseconds, pcmBytes.length];
}
