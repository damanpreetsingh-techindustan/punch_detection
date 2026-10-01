import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../data/datasources/telemetry_datasource.dart';
import '../../data/repositories/diagnostics_repository_impl.dart';
import '../../domain/repositories/diagnostics_repository.dart';
import '../../domain/usecases/get_live_telemetry.dart';
import '../../domain/usecases/update_detection_thresholds.dart';
import '../controllers/diagnostics_controller.dart';

class DiagnosticsBinding extends Bindings {
  @override
  void dependencies() {
    final configService = Get.find<ConfigService>();
    final datasource = TelemetryDatasource();

    final repository = DiagnosticsRepositoryImpl(
      datasource: datasource,
      configService: configService,
    );
    Get.lazyPut<DiagnosticsRepository>(() => repository);

    final getTelemetryUseCase = GetLiveTelemetry(repository);
    final updateThresholdsUseCase = UpdateDetectionThresholds(repository);

    Get.lazyPut<GetLiveTelemetry>(() => getTelemetryUseCase);
    Get.lazyPut<UpdateDetectionThresholds>(() => updateThresholdsUseCase);

    Get.lazyPut<DiagnosticsController>(
      () => DiagnosticsController(
        getLiveTelemetryUseCase: getTelemetryUseCase,
        updateDetectionThresholdsUseCase: updateThresholdsUseCase,
        configService: configService,
      ),
    );
  }
}
