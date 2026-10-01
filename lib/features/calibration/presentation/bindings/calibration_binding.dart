import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../data/datasources/audio_calibration_datasource.dart';
import '../../data/datasources/vision_calibration_datasource.dart';
import '../../data/repositories/calibration_repository_impl.dart';
import '../../domain/repositories/calibration_repository.dart';
import '../../domain/usecases/run_ambient_calibration.dart';
import '../controllers/calibration_controller.dart';

class CalibrationBinding extends Bindings {
  @override
  void dependencies() {
    final configService = Get.find<ConfigService>();
    final clockService = Get.find<MonotonicClockService>();

    final audioDatasource = AudioCalibrationDatasource();
    final visionDatasource = VisionCalibrationDatasource();

    final repository = CalibrationRepositoryImpl(
      audioDatasource: audioDatasource,
      visionDatasource: visionDatasource,
      configService: configService,
      clockService: clockService,
    );

    Get.lazyPut<CalibrationRepository>(() => repository);

    final useCase = RunAmbientCalibration(repository);
    Get.lazyPut<RunAmbientCalibration>(() => useCase);

    Get.lazyPut<CalibrationController>(
      () => CalibrationController(
        runAmbientCalibrationUseCase: useCase,
        configService: configService,
      ),
    );
  }
}
