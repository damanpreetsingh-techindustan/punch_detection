import '../entities/signal_telemetry.dart';
import '../repositories/diagnostics_repository.dart';

class GetLiveTelemetry {
  final DiagnosticsRepository repository;

  GetLiveTelemetry(this.repository);

  Stream<SignalTelemetry> call() {
    return repository.getTelemetryStream();
  }
}
