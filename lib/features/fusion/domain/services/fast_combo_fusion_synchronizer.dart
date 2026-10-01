import 'dart:collection';

/// Represents an audio impact event detected by the microphone stream.
class AudioImpactEntry {
  final int timestampMs;
  final double decibelLevel;
  final double onsetSpikeDb;

  const AudioImpactEntry({
    required this.timestampMs,
    required this.decibelLevel,
    required this.onsetSpikeDb,
  });
}

/// Represents a vision motion evaluation event from the camera stream.
class VisionMotionEntry {
  final int timestampMs;
  final String drivingArm;
  final double score;
  final bool isConfirmed;

  const VisionMotionEntry({
    required this.timestampMs,
    required this.drivingArm,
    required this.score,
    required this.isConfirmed,
  });
}

/// Result of evaluating audio & vision signal fusion.
class FusionMatchResult {
  final bool isMatched;
  final String? drivingArm;
  final String matchReason;
  final int timestampMs;

  const FusionMatchResult({
    required this.isMatched,
    this.drivingArm,
    required this.matchReason,
    required this.timestampMs,
  });

  static const FusionMatchResult none = FusionMatchResult(
    isMatched: false,
    matchReason: 'NO_MATCH',
    timestampMs: 0,
  );
}

/// Domain Service for Audio-Vision Temporal Synchronization & Fast Combo Punch Matching.
///
/// Principles Applied:
///  - Single Responsibility: Pure temporal signal matching and refractory window governance.
///  - Open/Closed: Easily configurable refractory windows and coincidence thresholds.
class FastComboFusionSynchronizer {
  final int audioWindowMs;
  final int sameArmRefractoryMs;
  final int comboArmRefractoryMs;
  final double minShoulderDriveScore;

  final Queue<AudioImpactEntry> _audioBuffer = Queue<AudioImpactEntry>();
  final Queue<VisionMotionEntry> _visionBuffer = Queue<VisionMotionEntry>();

  int _lastConfirmedPunchTimeMs = 0;
  String _lastConfirmedArm = 'right';

  FastComboFusionSynchronizer({
    this.audioWindowMs = 350,
    this.sameArmRefractoryMs = 210,
    this.comboArmRefractoryMs = 140,
    this.minShoulderDriveScore = 35.0,
  });

  /// Resets all internal queues and refractory markers.
  void reset() {
    _audioBuffer.clear();
    _visionBuffer.clear();
    _lastConfirmedPunchTimeMs = 0;
    _lastConfirmedArm = 'right';
  }

  /// Pushes a new audio impact transient into the ring buffer and evaluates immediate fusion match.
  FusionMatchResult pushAudioImpact({
    required int nowMs,
    required double decibelLevel,
    required double onsetSpikeDb,
    required String activeDrivingArm,
    required double currentVisionScore,
  }) {
    _pruneExpiredEntries(nowMs);

    final AudioImpactEntry audioEntry = AudioImpactEntry(
      timestampMs: nowMs,
      decibelLevel: decibelLevel,
      onsetSpikeDb: onsetSpikeDb,
    );
    _audioBuffer.addLast(audioEntry);

    return _tryMatchSignals(
      nowMs: nowMs,
      preferredArm: activeDrivingArm,
      currentVisionScore: currentVisionScore,
      triggeredByAudio: true,
    );
  }

  /// Pushes a new camera pose evaluation frame and evaluates immediate fusion match.
  FusionMatchResult pushVisionMotion({
    required int nowMs,
    required String drivingArm,
    required double score,
    required bool isConfirmed,
  }) {
    _pruneExpiredEntries(nowMs);

    final VisionMotionEntry visionEntry = VisionMotionEntry(
      timestampMs: nowMs,
      drivingArm: drivingArm,
      score: score,
      isConfirmed: isConfirmed,
    );
    _visionBuffer.addLast(visionEntry);

    return _tryMatchSignals(
      nowMs: nowMs,
      preferredArm: drivingArm,
      currentVisionScore: score,
      triggeredByAudio: false,
    );
  }

  /// Core Fusion Logic: Pairs recent audio impact with active vision motion while respecting
  /// dynamic refractory periods (160ms for alternating combo vs 280ms for same arm).
  FusionMatchResult _tryMatchSignals({
    required int nowMs,
    required String preferredArm,
    required double currentVisionScore,
    required bool triggeredByAudio,
  }) {
    if (_audioBuffer.isEmpty) return FusionMatchResult.none;

    final String targetArm = preferredArm.toLowerCase();

    // Calculate dynamic refractory period based on whether the arm is alternating (fast 1-2 combo)
    final bool isAlternatingArm = (targetArm != _lastConfirmedArm);
    final int requiredRefractoryMs =
        isAlternatingArm ? comboArmRefractoryMs : sameArmRefractoryMs;

    if (nowMs - _lastConfirmedPunchTimeMs < requiredRefractoryMs) {
      return FusionMatchResult.none;
    }

    // Check if there is a matching vision motion within buffer
    bool hasMatchingVision = false;
    VisionMotionEntry? matchedVisionEntry;

    for (final visionEntry in _visionBuffer) {
      if ((nowMs - visionEntry.timestampMs).abs() <= audioWindowMs) {
        if (visionEntry.isConfirmed || visionEntry.score >= minShoulderDriveScore) {
          hasMatchingVision = true;
          matchedVisionEntry = visionEntry;
          break;
        }
      }
    }

    // If no queued vision entry yet, check current vision score (audio pre-trigger)
    if (!hasMatchingVision && currentVisionScore >= minShoulderDriveScore) {
      hasMatchingVision = true;
    }

    if (hasMatchingVision) {
      // Consume matched entries from buffers
      _audioBuffer.clear();
      _visionBuffer.clear();

      _lastConfirmedPunchTimeMs = nowMs;
      _lastConfirmedArm = targetArm;

      final String finalArm = matchedVisionEntry?.drivingArm ?? targetArm;
      final String reason =
          isAlternatingArm
              ? '★ FAST COMBO FUSED (${finalArm.toUpperCase()} Arm — 160ms Window)'
              : '★ PUNCH FUSED (${finalArm.toUpperCase()} Arm — 280ms Window)';

      return FusionMatchResult(
        isMatched: true,
        drivingArm: finalArm,
        matchReason: reason,
        timestampMs: nowMs,
      );
    }

    return FusionMatchResult.none;
  }

  /// Removes entries older than [audioWindowMs] from internal buffers.
  void _pruneExpiredEntries(int nowMs) {
    while (_audioBuffer.isNotEmpty &&
        (nowMs - _audioBuffer.first.timestampMs) > audioWindowMs) {
      _audioBuffer.removeFirst();
    }
    while (_visionBuffer.isNotEmpty &&
        (nowMs - _visionBuffer.first.timestampMs) > audioWindowMs) {
      _visionBuffer.removeFirst();
    }
  }
}
