import 'dart:math';
import '../../../../../core/utils/constants.dart';
import '../models/vibration_knock.dart';

/// One sample-to-sample jerk, kept briefly to judge whether a new jerk is a
/// fresh rise (new hit) or part of the fading shake of the previous hit.
class _JerkSample {
  final int tMs;
  final double delta;
  const _JerkSample(this.tMs, this.delta);
}

/// Pure mathematical tracker that identifies impulsive physical shockwaves (knocks)
/// from sample-to-sample jerk (delta) in raw accelerometer readings.
///
/// Distinguishes high-frequency collision knocks (punch impact duration ~20ms) from
/// low-frequency pendulum bag swings (~0.5Hz sinusoidal motion with smooth delta).
///
/// ONE PHYSICAL HIT = ONE KNOCK. Three rules guarantee it:
///  1. Merge: jerks within [knockMergeMs] of the last knock are the same hit
///     (shockwave rise + rebound), even when that knock was already used by a
///     confirmed punch. Without this the rebound became a new, unused knock.
///  2. Ring-down: after the merge window the mount keeps shaking with
///     SHRINKING jerks. A jerk only starts a new knock when it is at least
///     [riseFactor] × the biggest jerk of the last [ringDownWindowMs]. A
///     new punch landing on the tail passes; the tail itself never does.
///  3. Gaps: a missed sensor reading is compared with the previous reading
///     (never with 0, which turned any bag swing into a fake knock). After a
///     long pause ([reseedGapMs]) the reading only becomes the new start.
class VibrationKnockTracker {
  /// Minimum sample-to-sample delta (m/s²) required to classify a knock.
  final double minKnockDelta;

  /// Time window within which consecutive jerk peaks are merged into one single hit (ms).
  final int knockMergeMs;

  /// Maximum age of historical knocks to retain (ms).
  final int maxKnockAgeMs;

  /// Rule 2: a new knock needs a jerk this many times the recent jerk.
  final double riseFactor;

  /// Rule 2: how far back (ms) the recent jerk is measured.
  final int ringDownWindowMs;

  /// Rule 3: gap (ms) after which a reading only re-seeds the tracker.
  final int reseedGapMs;

  final List<VibrationKnock> _knocks = [];
  final List<_JerkSample> _recentJerks = [];
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
    this.riseFactor = AppConstants.knockRiseFactor,
    this.ringDownWindowMs = AppConstants.knockRingDownWindowMs,
    this.reseedGapMs = AppConstants.knockReseedGapMs,
  });

  /// Ingests a raw accelerometer sample (before deadband).
  ///
  /// The app always passes [x], [y], [z] (3D jerk). Without them a scalar
  /// magnitude jump is used; that path only serves tests / simulations that
  /// feed sparse magnitudes, and keeps its old "settled back to rest" rule.
  void addSample({
    required int sensorMs,
    required double rawMag,
    double? x,
    double? y,
    double? z,
  }) {
    final bool has3d = x != null && y != null && z != null;

    if (!_hasPrevious) {
      _hasPrevious = true;
      _prevSensorMs = sensorMs;
      _prevMag = rawMag;
      if (has3d) {
        _prevX = x;
        _prevY = y;
        _prevZ = z;
      }
      // If the very first sample is already a large impact jump from rest (0.0):
      if (rawMag >= minKnockDelta) {
        _addKnock(sensorMs, rawMag, rawMag);
      }
      return;
    }

    final int gapMs = (sensorMs - _prevSensorMs).abs();

    if (has3d && gapMs > reseedGapMs) {
      // Rule 3: sensor was paused / restarted. The old reading says nothing
      // about this one, so only take it as the new starting point.
      _setPrevious(sensorMs, rawMag, x, y, z);
      _recentJerks.clear();
      return;
    }

    if (!has3d && gapMs >= 40) {
      // Scalar (test / simulation) path only: sparse samples mean the mount
      // settled back to rest in between.
      _prevMag = 0.0;
    }

    // 1. Compute 3D vector jerk if coordinates are provided, otherwise scalar jump
    final double delta;
    if (has3d) {
      final dx = x - _prevX;
      final dy = y - _prevY;
      final dz = z - _prevZ;
      delta = sqrt(dx * dx + dy * dy + dz * dz);
    } else {
      delta = (rawMag - _prevMag).abs();
    }
    // Biggest jerk just before this one (rule 2), read before adding this one.
    final double recentJerk = _recentJerkMax(sensorMs);
    _setPrevious(sensorMs, rawMag, x, y, z);
    _rememberJerk(sensorMs, delta);

    // 2. Sudden collision threshold check
    if (delta >= minKnockDelta) {
      if (_knocks.isNotEmpty) {
        final last = _knocks.last;
        if ((sensorMs - last.timestampMs).abs() <= knockMergeMs) {
          // Rule 1: same hit. Keep the strongest jerk, but never touch a knock
          // that a confirmed punch already used.
          if (!last.isUsed && delta > last.deltaMag) {
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

      // Rule 2: the fading shake of the previous hit is not a new knock.
      if (recentJerk > 0 && delta < riseFactor * recentJerk) {
        return;
      }

      // Register new distinct knock
      _addKnock(sensorMs, delta, rawMag);
    }

    // 3. Prune old historical knocks
    final cutoff = sensorMs - maxKnockAgeMs;
    while (_knocks.isNotEmpty && _knocks.first.timestampMs < cutoff) {
      _knocks.removeAt(0);
    }
  }

  void _addKnock(int sensorMs, double delta, double rawMag) {
    _knocks.add(VibrationKnock(
      id: ++_knockIdCounter,
      timestampMs: sensorMs,
      deltaMag: delta,
      rawMag: rawMag,
    ));
  }

  void _setPrevious(int sensorMs, double rawMag, double? x, double? y, double? z) {
    _prevSensorMs = sensorMs;
    _prevMag = rawMag;
    if (x != null && y != null && z != null) {
      _prevX = x;
      _prevY = y;
      _prevZ = z;
    }
  }

  void _rememberJerk(int sensorMs, double delta) {
    _recentJerks.add(_JerkSample(sensorMs, delta));
    while (_recentJerks.isNotEmpty &&
        sensorMs - _recentJerks.first.tMs > ringDownWindowMs) {
      _recentJerks.removeAt(0);
    }
  }

  /// Biggest jerk in the last [ringDownWindowMs] before [sensorMs] (0 if none).
  double _recentJerkMax(int sensorMs) {
    double best = 0.0;
    for (final _JerkSample s in _recentJerks) {
      if (sensorMs - s.tMs <= ringDownWindowMs && s.delta > best) {
        best = s.delta;
      }
    }
    return best;
  }

  /// Searches for an UNUSED knock in the specified impact window.
  ///
  /// A knock this impact already claimed is returned first, so an impact keeps
  /// the knock it was matched with and cannot collect a second one. Otherwise
  /// the unclaimed knock closest to [audioTsMs] is returned.
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
      if (!knock.isUsed && knock.claimedByAudioTsMs == audioTsMs) {
        return knock;
      }
    }

    for (final knock in _knocks) {
      if (knock.timestampMs >= fromMs && knock.timestampMs <= toMs) {
        final bool isClaimable =
            !knock.isUsed && knock.claimedByAudioTsMs == null;
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
    _recentJerks.clear();
    _hasPrevious = false;
    _prevX = 0.0;
    _prevY = 0.0;
    _prevZ = 0.0;
    _prevMag = 0.0;
    _prevSensorMs = 0;
    _knockIdCounter = 0;
  }
}
