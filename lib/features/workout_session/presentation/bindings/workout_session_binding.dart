import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../../fusion/data/repositories/fusion_repository_impl.dart';
import '../../../fusion/domain/repositories/fusion_repository.dart';
import '../../../prompt_timing/data/datasources/tts_prompt_datasource.dart';
import '../../../prompt_timing/data/repositories/prompt_timing_repository_impl.dart';
import '../../../prompt_timing/domain/repositories/prompt_timing_repository.dart';
import '../../../prompt_timing/domain/usecases/calculate_reaction_time.dart';
import '../../../prompt_timing/domain/usecases/play_prompt_callout.dart';
import '../../../prompt_timing/presentation/controllers/prompt_timing_controller.dart';
import '../../data/repositories/workout_session_repository_impl.dart';
import '../../domain/repositories/workout_session_repository.dart';
import '../../domain/usecases/process_live_frame.dart';
import '../../domain/usecases/start_workout_session.dart';
import '../controllers/workout_session_controller.dart';

class WorkoutSessionBinding extends Bindings {
  @override
  void dependencies() {
    final configService = Get.find<ConfigService>();
    final clockService = Get.find<MonotonicClockService>();

    // 1. Fusion dependencies
    final fusionRepo = FusionRepositoryImpl();
    Get.lazyPut<FusionRepository>(() => fusionRepo);

    // 2. Prompt Timing dependencies
    final ttsDatasource = TTSPromptDatasource(clockService: clockService);
    final promptRepo = PromptTimingRepositoryImpl(ttsDatasource: ttsDatasource);
    Get.lazyPut<PromptTimingRepository>(() => promptRepo);

    final playUseCase = PlayPromptCallout(promptRepo);
    final calcUseCase = CalculateReactionTime(promptRepo);

    final promptController = PromptTimingController(
      playPromptCalloutUseCase: playUseCase,
      calculateReactionTimeUseCase: calcUseCase,
      configService: configService,
    );
    Get.lazyPut<PromptTimingController>(() => promptController);

    // 3. Workout Session dependencies
    final sessionRepo = WorkoutSessionRepositoryImpl(fusionRepository: fusionRepo);
    Get.lazyPut<WorkoutSessionRepository>(() => sessionRepo);

    final startUseCase = StartWorkoutSession(sessionRepo);
    final processUseCase = ProcessLiveFrame(sessionRepo);

    Get.lazyPut<WorkoutSessionController>(
      () => WorkoutSessionController(
        startWorkoutSessionUseCase: startUseCase,
        processLiveFrameUseCase: processUseCase,
        configService: configService,
        promptTimingController: promptController,
      ),
    );
  }
}
