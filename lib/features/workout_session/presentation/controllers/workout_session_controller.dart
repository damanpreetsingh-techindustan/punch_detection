import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/config_service.dart';
import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fused_punch_event.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../prompt_timing/presentation/controllers/prompt_timing_controller.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/workout_session_stats.dart';
import '../../domain/entities/workout_state.dart';
import '../../domain/usecases/process_live_frame.dart';
import '../../domain/usecases/start_workout_session.dart';

class WorkoutSessionController extends GetxController {
  final StartWorkoutSession startWorkoutSessionUseCase;
  final ProcessLiveFrame processLiveFrameUseCase;
  final ConfigService configService;
  final PromptTimingController promptTimingController;

  final Rx<WorkoutState> workoutState = WorkoutState.idle.obs;
  final Rx<WorkoutSessionStats> stats = WorkoutSessionStats.initial().obs;
  final RxInt countdownSeconds = 3.obs;
  final RxInt roundSecondsRemaining = 180.obs;
  final RxString currentCallout = "GET READY".obs;
  final RxBool isCameraActive = true.obs;

  Timer? _sessionTimer;
  Timer? _promptTimer;

  WorkoutSessionController({
    required this.startWorkoutSessionUseCase,
    required this.processLiveFrameUseCase,
    required this.configService,
    required this.promptTimingController,
  });

  @override
  void onInit() {
    super.onInit();
    startCountdown();
  }

  void startCountdown() async {
    workoutState.value = WorkoutState.countdown;
    countdownSeconds.value = 3;
    currentCallout.value = "GET READY";

    const config = SessionConfig();
    await startWorkoutSessionUseCase(config);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdownSeconds.value > 1) {
        countdownSeconds.value--;
      } else {
        timer.cancel();
        _startActiveWorkout();
      }
    });
  }

  void _startActiveWorkout() {
    workoutState.value = WorkoutState.active;
    roundSecondsRemaining.value = 180;
    currentCallout.value = "1";

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (workoutState.value == WorkoutState.active) {
        if (roundSecondsRemaining.value > 0) {
          roundSecondsRemaining.value--;
          stats.value = stats.value.copyWith(
            elapsedSeconds: 180 - roundSecondsRemaining.value,
          );
        } else {
          finishWorkout();
        }
      }
    });

    // Schedule periodic TTS prompts
    _scheduleNextPrompt();
  }

  void _scheduleNextPrompt() {
    _promptTimer?.cancel();
    _promptTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (workoutState.value == WorkoutState.active) {
        final prompts = ["1", "1-2", "Jab Cross", "2-3-2", "1-1-2"];
        final next = (prompts..shuffle()).first;
        currentCallout.value = next;
        promptTimingController.triggerPrompt(next);
      }
    });
  }

  void ingestLiveFrame(AudioConfidenceScore audio, VisionConfidenceScore? vision) async {
    if (workoutState.value != WorkoutState.active) return;

    final config = FusionConfig(
      audioWeight: configService.audioWeight.value,
      visionWeight: configService.visionWeight.value,
      minFusedConfidenceThreshold: configService.minFusionConfidenceThreshold.value,
    );

    final FusedPunchEvent event = await processLiveFrameUseCase(
      ProcessLiveFrameParams(
        audioResult: audio,
        visionResult: vision,
        config: config,
      ),
    );

    if (event.isPunchConfirmed) {
      promptTimingController.recordPunchImpact(event.timestampMicroseconds);
      final lastResult = promptTimingController.lastReactionResult.value;

      stats.value = stats.value.copyWith(
        totalPunches: stats.value.totalPunches + 1,
        lastReactionMs: lastResult?.reactionTimeMs ?? 320,
        lastRating: lastResult != null
            ? lastResult.rating.name.toUpperCase()
            : 'FAST',
        averageReactionMs: promptTimingController.averageReactionTimeMs,
      );
    }
  }

  void togglePause() {
    if (workoutState.value == WorkoutState.active) {
      workoutState.value = WorkoutState.paused;
    } else if (workoutState.value == WorkoutState.paused) {
      workoutState.value = WorkoutState.active;
    }
  }

  void finishWorkout() {
    _sessionTimer?.cancel();
    _promptTimer?.cancel();
    workoutState.value = WorkoutState.completed;
    AppNavigator.toHome();
  }

  @override
  void onClose() {
    _sessionTimer?.cancel();
    _promptTimer?.cancel();
    super.onClose();
  }
}
