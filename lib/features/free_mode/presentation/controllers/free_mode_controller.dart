import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/config_service.dart';
import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fused_punch_event.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../../domain/entities/free_mode_config.dart';
import '../../domain/entities/free_mode_stats.dart';
import '../../domain/usecases/process_free_mode_impact.dart';
import '../../domain/usecases/start_free_mode_session.dart';

class FreeModeController extends GetxController {
  final StartFreeModeSession startFreeModeSessionUseCase;
  final ProcessFreeModeImpact processFreeModeImpactUseCase;
  final ConfigService configService;

  final Rx<FreeModeStats> stats = FreeModeStats.initial().obs;
  final RxInt elapsedSeconds = 0.obs;
  final RxBool isPaused = false.obs;

  Timer? _timer;

  FreeModeController({
    required this.startFreeModeSessionUseCase,
    required this.processFreeModeImpactUseCase,
    required this.configService,
  });

  @override
  void onInit() {
    super.onInit();
    startFreeMode();
  }

  void startFreeMode() async {
    const config = FreeModeConfig();
    await startFreeModeSessionUseCase(config);

    elapsedSeconds.value = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused.value) {
        elapsedSeconds.value++;
        stats.value = stats.value.copyWith(elapsedSeconds: elapsedSeconds.value);
      }
    });
  }

  void ingestFrame(AudioConfidenceScore audio, VisionConfidenceScore? vision) async {
    if (isPaused.value) return;

    final config = FusionConfig(
      audioWeight: configService.audioWeight.value,
      visionWeight: configService.visionWeight.value,
      minFusedConfidenceThreshold: configService.minFusionConfidenceThreshold.value,
    );

    final FusedPunchEvent event = await processFreeModeImpactUseCase(
      ProcessFreeModeImpactParams(
        audioResult: audio,
        visionResult: vision,
        config: config,
      ),
    );

    if (event.isPunchConfirmed) {
      final currentPpm = stats.value.punchesPerMinute + 6;
      stats.value = stats.value.copyWith(
        totalPunches: stats.value.totalPunches + 1,
        punchesPerMinute: currentPpm,
        intensityLevel: FreeModeStats.getIntensity(currentPpm),
      );
    }
  }

  void togglePause() {
    isPaused.value = !isPaused.value;
  }

  void endSession() {
    _timer?.cancel();
    AppNavigator.toHome();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
