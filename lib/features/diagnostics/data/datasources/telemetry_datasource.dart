import 'dart:async';
import 'dart:math';
import '../../domain/entities/signal_telemetry.dart';

class TelemetryDatasource {
  final _controller = StreamController<SignalTelemetry>.broadcast();
  Timer? _timer;
  final Random _random = Random();

  TelemetryDatasource() {
    _startSimulatedStream();
  }

  void _startSimulatedStream() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final double rms = 0.01 + _random.nextDouble() * 0.25;
      final double peak = rms * 2.5;
      final double flat = 0.4 + _random.nextDouble() * 0.55;
      final double angle = 80.0 + _random.nextDouble() * 90.0;
      final double vel = _random.nextDouble() * 2.5;

      final bool isAudio = rms > 0.12 && flat > 0.60;
      final bool isVision = angle > 150.0 && vel > 1.2;

      final telemetry = SignalTelemetry(
        audioRms: double.parse(rms.toStringAsFixed(4)),
        peakAmplitude: double.parse(peak.toStringAsFixed(4)),
        spectralFlatness: double.parse(flat.toStringAsFixed(4)),
        elbowAngle: double.parse(angle.toStringAsFixed(1)),
        wristVelocity: double.parse(vel.toStringAsFixed(2)),
        isAudioCandidate: isAudio,
        isVisionCandidate: isVision,
        isFusedPunch: isAudio && isVision,
      );

      _controller.add(telemetry);
    });
  }

  Stream<SignalTelemetry> get stream => _controller.stream;

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
