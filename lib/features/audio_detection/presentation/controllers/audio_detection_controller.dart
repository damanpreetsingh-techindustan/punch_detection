import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../domain/entities/audio_confidence_score.dart';
import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';
import '../../domain/usecases/analyze_audio_frame.dart';

class AudioDetectionController extends GetxController {
  final AnalyzeAudioFrame analyzeAudioFrameUseCase;
  final ConfigService configService;

  final RxDouble currentRms = 0.0.obs;
  final RxDouble noiseFloor = 0.02.obs;
  final RxDouble confidenceScore = 0.0.obs;
  final RxBool isPunchDetected = false.obs;
  final RxMap<String, bool> filterResults = <String, bool>{}.obs;

  StreamSubscription<AudioFrame>? _audioSubscription;

  AudioDetectionController({
    required this.analyzeAudioFrameUseCase,
    required this.configService,
  });

  void processFrame(AudioFrame frame) async {
    currentRms.value = frame.rmsEnergy;

    final config = AudioFilterConfig(
      energyThresholdDelta: configService.audioRmsSpikeThreshold.value,
      proximityGateMinRms: configService.audioRmsSpikeThreshold.value * 0.4,
    );

    final AudioConfidenceScore result = await analyzeAudioFrameUseCase(
      AnalyzeAudioFrameParams(frame: frame, config: config),
    );

    confidenceScore.value = result.score;
    isPunchDetected.value = result.isPunchCandidate;
    filterResults.assignAll(result.filterResults);
    noiseFloor.value = result.metrics['noiseFloorRms'] as double? ?? 0.02;
  }

  @override
  void onClose() {
    _audioSubscription?.cancel();
    super.onClose();
  }
}
