import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../../domain/entities/fused_punch_event.dart';
import '../../domain/entities/fusion_config.dart';
import '../../domain/usecases/combine_signals.dart';

class FusionController extends GetxController {
  final CombineSignals combineSignalsUseCase;
  final ConfigService configService;

  final RxDouble lastFusedScore = 0.0.obs;
  final RxBool isPunchConfirmed = false.obs;
  final RxInt totalPunchCount = 0.obs;
  final Rx<FusionMode> currentMode = FusionMode.fusion.obs;

  FusionController({
    required this.combineSignalsUseCase,
    required this.configService,
  });

  void processSignals(AudioConfidenceScore audio, VisionConfidenceScore? vision) async {
    final config = FusionConfig(
      audioWeight: configService.audioWeight.value,
      visionWeight: configService.visionWeight.value,
      minFusedConfidenceThreshold: configService.minFusionConfidenceThreshold.value,
    );

    final FusedPunchEvent event = await combineSignalsUseCase(
      CombineSignalsParams(
        audioResult: audio,
        visionResult: vision,
        config: config,
      ),
    );

    lastFusedScore.value = event.fusedConfidenceScore;
    isPunchConfirmed.value = event.isPunchConfirmed;
    currentMode.value = event.fusionMode;

    if (event.isPunchConfirmed) {
      totalPunchCount.value++;
    }
  }

  void resetCounter() {
    totalPunchCount.value = 0;
    lastFusedScore.value = 0.0;
    isPunchConfirmed.value = false;
  }
}
