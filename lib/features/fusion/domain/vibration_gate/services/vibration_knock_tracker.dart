import 'dart:math';
import '../models/vibration_knock.dart';

/// Pure mathematical tracker that identifies impulsive physical shockwaves (knocks)
/// from sample-to-sample jerk (delta) in raw accelerometer readings.
///
/// Distinguishes high-frequency collision knocks (punch impact duration ~20ms) from
/// low-frequency pendulum bag swings (~0.5Hz sinusoidal motion with smooth delta).
class VibrationKnockTracker {
  /// Minimum sample-to-sample delta (m/s²) required to classify a knock.
  final double minKnockDelta;

  /// Time window within which consecutive jerk peaks are merged into one single hit (ms).
  final int knockMergeMs;

  /// Maximum age of historical knocks to retain (ms).
  final int maxKnockAgeMs;

  final List<VibrationKnock> _knocks = [];
  double _prevX = 0.0;
  double _prevY = 0.0;
  double _prevZ = 0.0;
  double _prevMag = 0.0;
  int _prevSensorMs = 0;
  bool _hasPrevious = false;
  int _knockIdCounter = 0;

  VibrationKnockTracker({
    this.minKnockDelta = 0.15,
    this.knockMergeMs = 40,
    this.maxKnockAgeMs = 3000,
  });

  /// Ingests a raw accelerometer sample (before deadband).
  void addSample({
    required int sensorMs,
    required double rawMag,
    double? x,
    double? y,
    double? z,
  }) {
    if (!_hasPrevious) {
      _hasPrevious = true;
      _prevSensorMs = sensorMs;
      _prevMag = rawMag;
      if (x != null && y != null && z != null) {
        _prevX = x;
        _prevY = y;
        _prevZ = z;
      }
      // If the very first sample is already a large impact jump from rest (0.0):
      if (rawMag >= minKnockDelta) {
        _knocks.add(VibrationKnock(
          id: ++_knockIdCounter,
          timestampMs: sensorMs,
          deltaMag: rawMag,
          rawMag: rawMag,
        ));
      }
      return;
    }

    // Physical acceleration decays rapidly (< 30ms). If more than 40ms have elapsed
    // since the last sample, any previous mechanical spike has settled back to rest.
    if ((sensorMs - _prevSensorMs).abs() >= 40) {
      _prevMag = 0.0;
      _prevX = 0.0;
      _prevY = 0.0;
      _prevZ = 0.0;
    }
    _prevSensorMs = sensorMs;

    // 1. Compute 3D vector jerk if coordinates are provided, otherwise scalar jump
    final double delta;
    if (x != null && y != null && z != null) {
      final dx = x - _prevX;
      final dy = y - _prevY;
      final dz = z - _prevZ;
      delta = sqrt(dx * dx + dy * dy + dz * dz);
      _prevX = x;
      _prevY = y;
      _prevZ = z;
    } else {
      delta = (rawMag - _prevMag).abs();
    }
    _prevMag = rawMag;

    // 2. Sudden collision threshold check
    if (delta >= minKnockDelta) {
      // If there is already a recent knock within knockMergeMs, merge with it
      // (shockwave rise and rebound fall of the exact same hit).
      if (_knocks.isNotEmpty) {
        final last = _knocks.last;
        if (!last.isUsed && (sensorMs - last.timestampMs).abs() <= knockMergeMs) {
          // Merge by updating to the highest delta and raw magnitude
          if (delta > last.deltaMag) {
            _knocks[_knocks.length - 1] = VibrationKnock(
              id: last.id,
              timestampMs: sensorMs,
              deltaMag: delta,
              rawMag: max(last.rawMag, rawMag),
              isUsed: false,
              claimedByAudioTsMs: last.claimedByAudioTsMs,
            );
          }
          return;
        }
      }

      // Register new distinct knock
      _knocks.add(VibrationKnock(
        id: ++_knockIdCounter,
        timestampMs: sensorMs,
        deltaMag: delta,
        rawMag: rawMag,
      ));
    }

    // 3. Prune old historical knocks
    final cutoff = sensorMs - maxKnockAgeMs;
    while (_knocks.isNotEmpty && _knocks.first.timestampMs < cutoff) {
      _knocks.removeAt(0);
    }
  }

  /// Searches for an UNUSED knock in the specified impact window.
  /// If multiple unused knocks are present, returns the one closest to [audioTsMs].
  VibrationKnock? findUnusedKnock({
    required int fromMs,
    required int toMs,
    required int audioTsMs,
    double? minRawMag,
    double? minDelta,
  }) {
    final effectiveMinDelta = minDelta ?? minKnockDelta;
    final effectiveMinRaw = minRawMag ?? 0.0;
    VibrationKnock? bestKnock;
    int bestDistance = 999999;

    for (final knock in _knocks) {
      if (knock.timestampMs >= fromMs && knock.timestampMs <= toMs) {
        final bool isClaimable = !knock.isUsed &&
            (knock.claimedByAudioTsMs == null ||
                knock.claimedByAudioTsMs == audioTsMs);
        if (isClaimable &&
            knock.deltaMag >= effectiveMinDelta &&
            knock.rawMag >= effectiveMinRaw) {
          final distance = (knock.timestampMs - audioTsMs).abs();
          if (distance < bestDistance) {
            bestDistance = distance;
            bestKnock = knock;
          }
        }
      }
    }

    return bestKnock;
  }

  /// Marks any knock claimed by [audioTsMs] as permanently used.
  void markKnockUsed({required int audioTsMs, required int punchNo}) {
    for (final knock in _knocks) {
      if (knock.claimedByAudioTsMs == audioTsMs) {
        knock.isUsed = true;
        knock.confirmedPunchNo = punchNo;
      }
    }
  }

  /// Releases temporary claim on knocks when an impact is rejected.
  void releaseClaim(int audioTsMs) {
    for (final knock in _knocks) {
      if (knock.claimedByAudioTsMs == audioTsMs) {
        knock.claimedByAudioTsMs = null;
      }
    }
  }

  /// Read-only snapshot of all tracked knocks (for diagnostics and unit testing).
  List<VibrationKnock> get allKnocks => List.unmodifiable(_knocks);

  /// Resets state.
  void reset() {
    _knocks.clear();
    _hasPrevious = false;
    _prevX = 0.0;
    _prevY = 0.0;
    _prevZ = 0.0;
    _prevMag = 0.0;
    _prevSensorMs = 0;
    _knockIdCounter = 0;
  }
}
