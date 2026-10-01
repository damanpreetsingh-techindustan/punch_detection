import '../entities/signal_telemetry.dart';

abstract class DiagnosticsRepository {
  /// Stream emitting real-time audio/vision telemetry signals
  Stream<SignalTelemetry> getTelemetryStream();

  /// Updates algorithm sensitivity and fusion parameters
  void updateThresholds({
    double? audioWeight,
    double? visionWeight,
    double? minConfidence,
  });
}
