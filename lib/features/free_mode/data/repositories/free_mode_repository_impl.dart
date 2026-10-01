import 'dart:math';
import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fused_punch_event.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../fusion/domain/repositories/fusion_repository.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../../domain/entities/free_mode_config.dart';
import '../../domain/entities/free_mode_stats.dart';
import '../../domain/repositories/free_mode_repository.dart';

class FreeModeRepositoryImpl implements FreeModeRepository {
  final FusionRepository fusionRepository;

  FreeModeStats _stats = FreeModeStats.initial();
  final List<int> _punchTimestampsUs = [];

  FreeModeRepositoryImpl({required this.fusionRepository});

  @override
  Future<void> startSession(FreeModeConfig config) async {
    _stats = FreeModeStats.initial();
    _punchTimestampsUs.clear();
  }

  @override
  FusedPunchEvent processLiveFrame({
    required AudioConfidenceScore audioResult,
    VisionConfidenceScore? visionResult,
    required FusionConfig config,
  }) {
    final FusedPunchEvent event = fusionRepository.fuseSignals(
      audioResult: audioResult,
      visionResult: visionResult,
      config: config,
    );

    if (event.isPunchConfirmed) {
      final int nowUs = event.timestampMicroseconds;
      _punchTimestampsUs.add(nowUs);

      // Purge punch timestamps older than 10 seconds (10,000,000 us)
      final int cutoffUs = nowUs - 10000000;
      _punchTimestampsUs.removeWhere((t) => t < cutoffUs);

      final int currentPpm = _punchTimestampsUs.length * 6;
      final int peakPpm = max(_stats.peakCadencePpm, currentPpm);
      final WorkoutIntensity intensity = FreeModeStats.getIntensity(currentPpm);

      _stats = _stats.copyWith(
        totalPunches: _stats.totalPunches + 1,
        punchesPerMinute: currentPpm,
        peakCadencePpm: peakPpm,
        intensityLevel: intensity,
      );
    }

    return event;
  }

  @override
  FreeModeStats getStats() => _stats;

  @override
  FreeModeStats endSession() => _stats;
}
