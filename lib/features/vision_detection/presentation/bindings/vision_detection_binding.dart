import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../data/datasources/mlkit_pose_datasource.dart';
import '../../data/repositories/vision_analyzer_repository_impl.dart';
import '../../domain/repositories/vision_analyzer_repository.dart';
import '../../domain/usecases/analyze_vision_pose.dart';
import '../controllers/vision_detection_controller.dart';

class VisionDetectionBinding extends Bindings {
  @override
  void dependencies() {
    final clockService = Get.find<MonotonicClockService>();
    final configService = Get.find<ConfigService>();

    final mlKitDatasource = MLKitPoseDatasource(clockService: clockService);
    final repository = VisionAnalyzerRepositoryImpl(mlKitDatasource: mlKitDatasource);
    Get.lazyPut<VisionAnalyzerRepository>(() => repository);

    final analyzeUseCase = AnalyzeVisionPose(repository);
    Get.lazyPut<AnalyzeVisionPose>(() => analyzeUseCase);

    Get.lazyPut<VisionDetectionController>(
      () => VisionDetectionController(
        analyzeVisionPoseUseCase: analyzeUseCase,
        configService: configService,
      ),
    );
  }
}
