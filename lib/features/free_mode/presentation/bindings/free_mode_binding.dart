import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../../fusion/data/repositories/fusion_repository_impl.dart';
import '../../../fusion/domain/repositories/fusion_repository.dart';
import '../../data/repositories/free_mode_repository_impl.dart';
import '../../domain/repositories/free_mode_repository.dart';
import '../../domain/usecases/process_free_mode_impact.dart';
import '../../domain/usecases/start_free_mode_session.dart';
import '../controllers/free_mode_controller.dart';

class FreeModeBinding extends Bindings {
  @override
  void dependencies() {
    final configService = Get.find<ConfigService>();

    final fusionRepo = FusionRepositoryImpl();
    Get.lazyPut<FusionRepository>(() => fusionRepo);

    final repository = FreeModeRepositoryImpl(fusionRepository: fusionRepo);
    Get.lazyPut<FreeModeRepository>(() => repository);

    final startUseCase = StartFreeModeSession(repository);
    final processUseCase = ProcessFreeModeImpact(repository);

    Get.lazyPut<StartFreeModeSession>(() => startUseCase);
    Get.lazyPut<ProcessFreeModeImpact>(() => processUseCase);

    Get.lazyPut<FreeModeController>(
      () => FreeModeController(
        startFreeModeSessionUseCase: startUseCase,
        processFreeModeImpactUseCase: processUseCase,
        configService: configService,
      ),
    );
  }
}
