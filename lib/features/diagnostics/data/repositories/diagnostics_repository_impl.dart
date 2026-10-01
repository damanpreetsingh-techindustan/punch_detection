import '../../../../core/services/config_service.dart';
import '../datasources/telemetry_datasource.dart';
import '../../domain/entities/signal_telemetry.dart';
import '../../domain/repositories/diagnostics_repository.dart';

class DiagnosticsRepositoryImpl implements DiagnosticsRepository {
  final TelemetryDatasource datasource;
  final ConfigService configService;

  DiagnosticsRepositoryImpl({
    required this.datasource,
    required this.configService,
  });

  @override
  Stream<SignalTelemetry> getTelemetryStream() {
    return datasource.stream;
  }

  @override
  void updateThresholds({
    double? audioWeight,
    double? visionWeight,
    double? minConfidence,
  }) {
    if (audioWeight != null) {
      configService.setAudioWeight(audioWeight);
    }
    if (visionWeight != null) {
      configService.setVisionWeight(visionWeight);
    }
    if (minConfidence != null) {
      configService.setMinFusionConfidenceThreshold(minConfidence);
    }
  }
}
