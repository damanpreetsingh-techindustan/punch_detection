import 'dart:async';
import 'dart:math';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../domain/entities/audio_frame.dart';

class TestClipAudioDatasource {
  final MonotonicClockService clockService;

  TestClipAudioDatasource({required this.clockService});

  /// Generates a synthetic quiet ambient baseline frame (low background noise, RMS ~0.01-0.02).
  AudioFrame generateQuietAmbientFrame() {
    final List<int> pcmBytes = [];
    final Random random = Random();
    const int numSamples = 1600; // 100ms at 16kHz

    for (int i = 0; i < numSamples; i++) {
      final int sampleInt = (random.nextInt(600) - 300);
      pcmBytes.add(sampleInt & 0xFF);
      pcmBytes.add((sampleInt >> 8) & 0xFF);
    }

    return AudioFrame(
      pcmBytes: pcmBytes,
      sampleRate: 16000,
      timestampMicroseconds: clockService.nowUs(),
    );
  }

  /// Generates a synthetic audio frame representing a real punch impact transient (fast attack, high peak, wideband noise).
  AudioFrame generatePunchFrame() {
    final List<int> pcmBytes = [];
    final Random random = Random();
    const int numSamples = 1600; // 100ms at 16kHz

    for (int i = 0; i < numSamples; i++) {
      // Impulsive transient: sharp rise at sample 50, rapid decay over 400 samples
      double envelope = 0.0;
      if (i >= 50 && i < 450) {
        envelope = exp(-(i - 50) / 40.0);
      }
      final double sampleVal = ((random.nextDouble() * 2 - 1) * envelope * 31000);
      final int sampleInt = sampleVal.toInt().clamp(-32768, 32767);
      
      pcmBytes.add(sampleInt & 0xFF);
      pcmBytes.add((sampleInt >> 8) & 0xFF);
    }

    return AudioFrame(
      pcmBytes: pcmBytes,
      sampleRate: 16000,
      timestampMicroseconds: clockService.nowUs(),
    );
  }

  /// Generates a synthetic audio frame representing sustained background speech or music (slow envelope, low peak).
  AudioFrame generateSpeechOrMusicFrame() {
    final List<int> pcmBytes = [];
    const int numSamples = 1600; // 100ms at 16kHz

    for (int i = 0; i < numSamples; i++) {
      // Sustained sine wave (narrowband 440Hz tone)
      final double sampleVal = sin(2 * pi * 440 * i / 16000) * 8000;
      final int sampleInt = sampleVal.toInt().clamp(-32768, 32767);

      pcmBytes.add(sampleInt & 0xFF);
      pcmBytes.add((sampleInt >> 8) & 0xFF);
    }

    return AudioFrame(
      pcmBytes: pcmBytes,
      sampleRate: 16000,
      timestampMicroseconds: clockService.nowUs(),
    );
  }

  /// Stream continuous synthetic audio frames for testing
  Stream<AudioFrame> streamTestFrames({int intervalMs = 100}) {
    late StreamController<AudioFrame> controller;
    Timer? timer;

    controller = StreamController<AudioFrame>(
      onListen: () {
        timer = Timer.periodic(Duration(milliseconds: intervalMs), (t) {
          if (!controller.isClosed) {
            controller.add(generateQuietAmbientFrame());
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }
}
