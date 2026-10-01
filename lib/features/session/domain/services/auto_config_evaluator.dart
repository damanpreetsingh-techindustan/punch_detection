import 'dart:math';
import '../../../../core/utils/constants.dart';
import '../entities/punch_telemetry_event.dart';

/// Result of evaluating recent punch telemetry logs for auto-configuration.
class AutoConfigResult {
  final bool hasSufficientData;
  final String statusMessage;
  final double currentTargetAudioDb;
  final double recommendedTargetAudioDb;
  final double currentSpikeDb;
  final double recommendedSpikeDb;
  final double currentVibrationThreshold;
  final double recommendedVibrationThreshold;
  final bool currentVibrationGateEnabled;
  final bool recommendedVibrationGateEnabled;
  final bool currentVisionRequired;
  final bool recommendedVisionRequired;
  final int totalEventsAnalyzed;
  final int validPunchesCount;
  final double averagePunchDb;
  final double averagePunchVibration;
  final String explanationSummary;

  const AutoConfigResult({
    required this.hasSufficientData,
    required this.statusMessage,
    required this.currentTargetAudioDb,
    required this.recommendedTargetAudioDb,
    required this.currentSpikeDb,
    required this.recommendedSpikeDb,
    required this.currentVibrationThreshold,
    required this.recommendedVibrationThreshold,
    required this.currentVibrationGateEnabled,
    required this.recommendedVibrationGateEnabled,
    required this.currentVisionRequired,
    required this.recommendedVisionRequired,
    required this.totalEventsAnalyzed,
    required this.validPunchesCount,
    required this.averagePunchDb,
    required this.averagePunchVibration,
    required this.explanationSummary,
  });

  /// Factory for when insufficient data has been collected (< 2 impact attempts).
  factory AutoConfigResult.insufficientData({
    required double currentTargetDb,
    required double currentSpikeDb,
    required double currentVibeThresh,
    required bool currentVibeEnabled,
    required bool currentVisionReq,
    required int eventCount,
  }) {
    return AutoConfigResult(
      hasSufficientData: false,
      statusMessage: eventCount == 0
          ? 'No punch activity detected yet.\nThrow 3–5 punches at your normal power, then tap Tune.'
          : 'Only $eventCount impact event(s) recorded.\nNeed at least 3–4 punches to tune audio accurately. Throw 3–5 punches at your normal power, then tap Tune again.',
      currentTargetAudioDb: currentTargetDb,
      recommendedTargetAudioDb: currentTargetDb,
      currentSpikeDb: currentSpikeDb,
      recommendedSpikeDb: currentSpikeDb,
      currentVibrationThreshold: currentVibeThresh,
      recommendedVibrationThreshold: currentVibeThresh,
      currentVibrationGateEnabled: currentVibeEnabled,
      recommendedVibrationGateEnabled: currentVibeEnabled,
      currentVisionRequired: currentVisionReq,
      recommendedVisionRequired: currentVisionReq,
      totalEventsAnalyzed: eventCount,
      validPunchesCount: 0,
      averagePunchDb: 0.0,
      averagePunchVibration: 0.0,
      explanationSummary:
          'Throw 3–5 punches at your normal power, then tap Tune to optimize your settings.',
    );
  }
}

/// Pure domain evaluator that calculates optimal detection thresholds and sensor configurations
/// from empirical punch and sensor logs.
class AutoConfigEvaluator {
  const AutoConfigEvaluator();

  /// Evaluates recent telemetry events and computes personalized detection parameters.
  /// Requires at least 3–4 strikes in the analysis pool to avoid acting on isolated anomalies.
  AutoConfigResult evaluate({
    required List<PunchTelemetryEvent> events,
    required double currentTargetAudioDb,
    required double currentSpikeDb,
    required double currentVibrationThreshold,
    required double ambientBaselineDb,
    required bool isPoleMount,
    required bool currentVibrationGateEnabled,
    required bool currentVisionRequired,
  }) {
    if (events.length < 3) {
      return AutoConfigResult.insufficientData(
        currentTargetDb: currentTargetAudioDb,
        currentSpikeDb: currentSpikeDb,
        currentVibeThresh: currentVibrationThreshold,
        currentVibeEnabled: currentVibrationGateEnabled,
        currentVisionReq: currentVisionRequired,
        eventCount: events.length,
      );
    }

    // 1. Separate valid punches and genuine strike attempts
    final validPunches = events.where((e) => e.isValidPunch).toList();
    // Genuine strike attempts include confirmed punches, candidate impacts,
    // or events with noticeable acoustic rise (>= 5 dB) or physical vibration (>= 0.04 m/s²)
    final strikeAttempts = events.where((e) =>
        e.isValidPunch ||
        e.isCandidate ||
        e.vibrationPeakMag >= 0.04 ||
        e.audioRiseDb >= 5.0 ||
        e.isCameraConfirmed
    ).toList();

    // Prefer strike attempts pool so even missed punches (e.g. threshold was set too strictly) are analyzed
    final List<PunchTelemetryEvent> analysisPool =
        strikeAttempts.isNotEmpty ? strikeAttempts : events;

    if (analysisPool.length < 3) {
      return AutoConfigResult.insufficientData(
        currentTargetDb: currentTargetAudioDb,
        currentSpikeDb: currentSpikeDb,
        currentVibeThresh: currentVibrationThreshold,
        currentVibeEnabled: currentVibrationGateEnabled,
        currentVisionReq: currentVisionRequired,
        eventCount: events.length,
      );
    }


    // 2. Audio Optimization: Calculate 25th percentile or safe target
    final List<double> audioPeaks = analysisPool.map((e) => e.peakAudioDb).toList()..sort();
    final double avgAudio =
        audioPeaks.reduce((a, b) => a + b) / audioPeaks.length;

    // 25th percentile index so ~75% of user's punches comfortably exceed target
    final int p25Index = (audioPeaks.length * 0.25).floor().clamp(0, audioPeaks.length - 1);
    final double p25Audio = audioPeaks[p25Index];

    // Set recommended target slightly below the 25th percentile (or average - 2.5 dB)
    double targetAudio = min(p25Audio - 1.0, avgAudio - 2.5);
    // Ensure target audio has at least 5 dB headroom above ambient baseline
    targetAudio = max(targetAudio, ambientBaselineDb + 5.0);
    targetAudio = targetAudio.clamp(
      AppConstants.minCalibratedTargetPunchDb,
      AppConstants.maxCalibratedTargetPunchDb,
    );

    // Calculate corresponding spike threshold relative to calibrated ambient baseline
    final double recommendedSpikeDb =
        (targetAudio - ambientBaselineDb).clamp(
          AppConstants.minAudioSpikeSliderDb,
          AppConstants.maxAudioSpikeSliderDb,
        ).roundToDouble();

    // The recommended target audio is strictly locked to ambientBaselineDb + recommendedSpikeDb
    // so that changing or auto-configuring spike threshold directly moves the audio target line.
    final double finalTargetAudio =
        (ambientBaselineDb + recommendedSpikeDb).clamp(
          AppConstants.minCalibratedTargetPunchDb,
          AppConstants.maxCalibratedTargetPunchDb,
        ).roundToDouble();

    // 3. Vibration Optimization:
    final List<double> vibePeaks = analysisPool.map((e) => e.vibrationPeakMag).toList();
    final double avgVibe = vibePeaks.isNotEmpty
        ? vibePeaks.reduce((a, b) => a + b) / vibePeaks.length
        : 0.0;
    final double maxVibe = vibePeaks.isNotEmpty
        ? vibePeaks.reduce(max)
        : 0.0;

    double recommendedVibeThresh = currentVibrationThreshold;
    bool recommendedVibeEnabled = currentVibrationGateEnabled;

    if (isPoleMount) {
      recommendedVibeEnabled = false;
    } else {
      // If user punches produce healthy vibration shockwave
      if (avgVibe >= 0.05 || maxVibe >= 0.08) {
        recommendedVibeEnabled = true;
        // Target ~40% of average vibration shockwave
        recommendedVibeThresh = (avgVibe * 0.40).clamp(0.03, 0.40);
      } else if (avgVibe < 0.02 && maxVibe < 0.03 && analysisPool.length >= 3) {
        // Very low or zero vibration recorded across hits (sensor unmounted or isolated)
        recommendedVibeEnabled = false;
      }
    }

    // 4. Camera Vision Optimization:
    bool recommendedVision = currentVisionRequired;
    final int cameraAvailableCount =
        analysisPool.where((e) => e.isCameraAvailable).length;
    final int cameraConfirmedCount =
        analysisPool.where((e) => e.isCameraConfirmed).length;

    if (cameraAvailableCount > 0) {
      final double cameraSuccessRate =
          cameraConfirmedCount / cameraAvailableCount;
      // If camera confirmed > 60% of punches, camera confirmation is viable
      if (cameraSuccessRate >= 0.60) {
        recommendedVision = true;
      } else if (cameraSuccessRate < 0.35 && analysisPool.length >= 3) {
        // Camera is frequently failing / user out of angle -> make confirmation optional
        recommendedVision = false;
      }
    } else {
      // Camera is not initialized or user not visible in frame
      recommendedVision = false;
    }

    // Format human-friendly explanation
    final StringBuffer explanation = StringBuffer();
    explanation.writeln('Analyzed ${analysisPool.length} impacts (Avg: ${avgAudio.toStringAsFixed(1)} dB, ${avgVibe.toStringAsFixed(2)} m/s²).');

    if ((finalTargetAudio - currentTargetAudioDb).abs() >= 1.0) {
      explanation.writeln('• Audio Target tuned to ${finalTargetAudio.round()} dB (Spike: +${recommendedSpikeDb.round()} dB).');
    } else {
      explanation.writeln('• Audio Target is already optimal at ${finalTargetAudio.round()} dB.');
    }

    if (!isPoleMount) {
      if (recommendedVibeEnabled != currentVibrationGateEnabled) {
        explanation.writeln(
          '• Vibration Gate ${recommendedVibeEnabled ? 'enabled' : 'disabled (low signal — switched to Audio + Camera)'}.',
        );
      } else {
        explanation.writeln(
          '• Vibration Threshold adjusted to ${recommendedVibeThresh.toStringAsFixed(2)} m/s².',
        );
      }
    }

    if (recommendedVision != currentVisionRequired) {
      explanation.writeln('• Camera Confirmation ${recommendedVision ? 'enabled' : 'relaxed'}.');
    }

    return AutoConfigResult(
      hasSufficientData: true,
      statusMessage: 'Optimal settings computed from recent punch activity.',
      currentTargetAudioDb: currentTargetAudioDb,
      recommendedTargetAudioDb: finalTargetAudio,
      currentSpikeDb: currentSpikeDb,
      recommendedSpikeDb: recommendedSpikeDb,
      currentVibrationThreshold: currentVibrationThreshold,
      recommendedVibrationThreshold: double.parse(recommendedVibeThresh.toStringAsFixed(2)),
      currentVibrationGateEnabled: currentVibrationGateEnabled,
      recommendedVibrationGateEnabled: recommendedVibeEnabled,
      currentVisionRequired: currentVisionRequired,
      recommendedVisionRequired: recommendedVision,
      totalEventsAnalyzed: events.length,
      validPunchesCount: validPunches.length,
      averagePunchDb: double.parse(avgAudio.toStringAsFixed(1)),
      averagePunchVibration: double.parse(avgVibe.toStringAsFixed(2)),
      explanationSummary: explanation.toString().trim(),
    );
  }
}
