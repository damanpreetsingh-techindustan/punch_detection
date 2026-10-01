import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../data/repositories/fusion_repository_impl.dart';
import '../../domain/repositories/fusion_repository.dart';
import '../../domain/usecases/combine_signals.dart';
import '../controllers/fusion_controller.dart';

class FusionBinding extends Bindings {
  @override
  void dependencies() {
    final configService = Get.find<ConfigService>();

    final repository = FusionRepositoryImpl();
    Get.lazyPut<FusionRepository>(() => repository);

    final combineUseCase = CombineSignals(repository);
    Get.lazyPut<CombineSignals>(() => combineUseCase);

    Get.lazyPut<FusionController>(
      () => FusionController(
        combineSignalsUseCase: combineUseCase,
        configService: configService,
      ),
    );
  }
}
