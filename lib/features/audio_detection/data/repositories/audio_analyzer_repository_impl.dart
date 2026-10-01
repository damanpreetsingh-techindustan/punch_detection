import 'dart:async';
import '../../domain/entities/audio_confidence_score.dart';
import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';
import '../../domain/repositories/audio_analyzer_repository.dart';
import '../datasources/native_audio_stream_datasource.dart';
import '../filters/adaptive_noise_floor_filter.dart';
import '../filters/audio_filter_stage.dart';
import '../filters/chassis_vibration_filter.dart';
import '../filters/energy_threshold_filter.dart';
import '../filters/proximity_amplitude_gate.dart';
import '../filters/spectral_flatness_filter.dart';
import '../filters/transient_envelope_filter.dart';

class AudioAnalyzerRepositoryImpl implements AudioAnalyzerRepository {
  final NativeAudioStreamDatasource nativeDatasource;
  final AdaptiveNoiseFloorTracker noiseFloorTracker = AdaptiveNoiseFloorTracker();
  final List<AudioFilterStage> stages;

  AudioAnalyzerRepositoryImpl({
    required this.nativeDatasource,
    List<AudioFilterStage>? customStages,
  }) : stages = customStages ??
            [
              AdaptiveNoiseFloorFilter(),
              EnergyThresholdFilter(),
              TransientEnvelopeFilter(),
              SpectralFlatnessFilter(),
              ProximityAmplitudeGate(),
              ChassisVibrationFilter(),
            ];

  @override
  Stream<AudioFrame> streamAudioFrames() {
    return nativeDatasource.streamPcmAudio();
  }

  @override
  AudioConfidenceScore analyzeFrame(AudioFrame frame, AudioFilterConfig config) {
    // 1. Update rolling adaptive noise floor tracker with current RMS
    noiseFloorTracker.addFrame(frame.rmsEnergy);
    final double currentFloor = noiseFloorTracker.currentNoiseFloor;

    // 2. Process frame through all 6 filter stages
    final Map<String, bool> filterResults = {};
    final Map<String, dynamic> metrics = {
      'noiseFloorRms': currentFloor,
      'rmsEnergy': frame.rmsEnergy,
      'peakAmplitude': frame.peakAmplitude,
    };

    double totalScore = 0.0;
    int passCount = 0;

    for (final stage in stages) {
      final result = stage.process(frame, config, currentFloor);
      filterResults[stage.name] = result.passed;
      metrics[stage.name] = result.metrics;
      totalScore += result.score;
      if (result.passed) {
        passCount++;
      }
    }

    final double overallScore = (totalScore / stages.length).clamp(0.0, 1.0);
    // A punch candidate requires passing all primary filter stages (at least 5 out of 6)
    final bool isPunchCandidate = passCount >= 5 && overallScore >= 0.65;

    return AudioConfidenceScore(
      score: overallScore,
      isPunchCandidate: isPunchCandidate,
      timestampMicroseconds: frame.timestampMicroseconds,
      filterResults: filterResults,
      metrics: metrics,
    );
  }

  @override
  void resetNoiseFloor() {
    noiseFloorTracker.reset();
  }
}
