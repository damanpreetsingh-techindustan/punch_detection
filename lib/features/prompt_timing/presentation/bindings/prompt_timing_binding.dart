import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../data/datasources/tts_prompt_datasource.dart';
import '../../data/repositories/prompt_timing_repository_impl.dart';
import '../../domain/repositories/prompt_timing_repository.dart';
import '../../domain/usecases/calculate_reaction_time.dart';
import '../../domain/usecases/play_prompt_callout.dart';
import '../controllers/prompt_timing_controller.dart';

class PromptTimingBinding extends Bindings {
  @override
  void dependencies() {
    final clockService = Get.find<MonotonicClockService>();
    final configService = Get.find<ConfigService>();

    final ttsDatasource = TTSPromptDatasource(clockService: clockService);
    final repository = PromptTimingRepositoryImpl(ttsDatasource: ttsDatasource);
    Get.lazyPut<PromptTimingRepository>(() => repository);

    final playUseCase = PlayPromptCallout(repository);
    final calcUseCase = CalculateReactionTime(repository);

    Get.lazyPut<PlayPromptCallout>(() => playUseCase);
    Get.lazyPut<CalculateReactionTime>(() => calcUseCase);

    Get.lazyPut<PromptTimingController>(
      () => PromptTimingController(
        playPromptCalloutUseCase: playUseCase,
        calculateReactionTimeUseCase: calcUseCase,
        configService: configService,
      ),
    );
  }
}
