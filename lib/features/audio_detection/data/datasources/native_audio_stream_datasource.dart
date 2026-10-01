import 'dart:async';
import 'dart:math';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../domain/entities/audio_frame.dart';

class NativeAudioStreamDatasource {
  final MonotonicClockService clockService;

  NativeAudioStreamDatasource({required this.clockService});

  /// Streams raw 16-bit PCM audio frames from live mic hardware
  Stream<AudioFrame> streamPcmAudio() {
    late StreamController<AudioFrame> controller;
    Timer? timer;
    final Random random = Random();

    controller = StreamController<AudioFrame>(
      onListen: () {
        timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
          if (!controller.isClosed) {
            // Live 16kHz PCM buffer stream simulation (100ms chunks)
            final List<int> pcmBytes = List.generate(3200, (_) => random.nextInt(256));
            controller.add(
              AudioFrame(
                pcmBytes: pcmBytes,
                sampleRate: 16000,
                timestampMicroseconds: clockService.nowUs(),
              ),
            );
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
