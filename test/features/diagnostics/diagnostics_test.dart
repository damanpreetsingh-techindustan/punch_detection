import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/config_service.dart';
import 'package:punch_detection_demo/features/diagnostics/data/datasources/telemetry_datasource.dart';
import 'package:punch_detection_demo/features/diagnostics/data/repositories/diagnostics_repository_impl.dart';
import 'package:punch_detection_demo/features/diagnostics/domain/entities/signal_telemetry.dart';

void main() {
  late TelemetryDatasource datasource;
  late ConfigService configService;
  late DiagnosticsRepositoryImpl repository;

  setUp(() {
    datasource = TelemetryDatasource();
    configService = ConfigService();
    repository = DiagnosticsRepositoryImpl(
      datasource: datasource,
      configService: configService,
    );
  });

  tearDown(() {
    datasource.dispose();
  });

  group('Phase 10: Diagnostics & Tuning UI Unit Tests', () {
    test('1. TelemetryDatasource emits live SignalTelemetry stream events', () async {
      final SignalTelemetry firstEvent = await repository.getTelemetryStream().first;

      expect(firstEvent.audioRms, isNotNull);
      expect(firstEvent.peakAmplitude, isNotNull);
      expect(firstEvent.spectralFlatness, isNotNull);
    });

    test('2. updateThresholds modifies ConfigService reactive properties in real time', () {
      repository.updateThresholds(
        audioWeight: 0.80,
        visionWeight: 0.20,
        minConfidence: 0.85,
      );

      expect(configService.audioWeight.value, equals(0.80));
      expect(configService.visionWeight.value, equals(0.20));
      expect(configService.minFusionConfidenceThreshold.value, equals(0.85));
    });
  });
}
