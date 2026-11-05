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

/// One raw 3D reading, kept briefly for [VibrationKnockTracker.claimRiseNear].
class _RawSample {
  final int tMs;
  final double rawMag;
  final double delta;
  const _RawSample(this.tMs, this.rawMag, this.delta);
}

/// Pure mathematical tracker that identifies impulsive physical shockwaves (knocks)
/// from sample-to-sample jerk (delta) in raw accelerometer readings.
///
/// Distinguishes high-frequency collision knocks (punch impact duration ~20ms) from
/// low-frequency pendulum bag swings (~0.5Hz sinusoidal motion with smooth delta).
///
/// ONE PHYSICAL HIT = ONE KNOCK. Three rules guarantee it:
///  1. Merge: jerks within [knockMergeMs] of the START of the last knock are
///     the same hit (shockwave rise + rebound), even when that knock was
///     already used by a confirmed punch. Without this the rebound became a
///     new, unused knock. The window does not slide with later jerks, or it
///     swallows the next punch of a fast combo.
///  2. Ring-down: after the merge window the mount keeps shaking with
///     SHRINKING jerks. A jerk only starts a new knock when it is at least
///     [riseFactor] × the biggest jerk of the last [ringDownWindowMs]. A
///     new punch landing on the tail passes; the tail itself never does.
///     Exception: a reading that jumps from near rest to a hard level
///     ([onsetMinRawMag], [onsetMaxPrevFraction]) is a new punch.
///  3. Gaps: a missed sensor reading is compared with the previous reading
///     (never with 0, which turned any bag swing into a fake knock). After a
///     long pause ([reseedGapMs]) the reading only becomes the new start.
///
/// A punch landing on a bag that is still shaking can fail rule 2. Only for a
/// loud sound that found no knock, [claimRiseNear] looks for a fresh rise in
/// the raw readings right at that sound.
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

  /// Rule 2 exception: minimum new reading (m/s²) of a jump from near rest.
  final double onsetMinRawMag;

  /// Rule 2 exception: previous reading at most this fraction of the new one.
  final double onsetMaxPrevFraction;

  /// [claimRiseNear]: minimum reading (m/s²).
  final double riseMinRawMag;

  /// [claimRiseNear]: reading at least this many times the recent lowest one.
  final double riseOverTroughFactor;

  /// [claimRiseNear]: how far back (ms) the lowest reading is looked for.
  final int riseLookbackMs;

  /// [claimRiseNear]: search window around the sound (ms).
  final int riseBeforeMs;
  final int riseAfterMs;

  final List<VibrationKnock> _knocks = [];
  final List<_RawSample> _rawHistory = [];
  int _mergeAnchorMs = 0;
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
    this.onsetMinRawMag = AppConstants.knockOnsetMinRawMag,
    this.onsetMaxPrevFraction = AppConstants.knockOnsetMaxPrevFraction,
    this.riseMinRawMag = AppConstants.knockRiseMinRawMag,
    this.riseOverTroughFactor = AppConstants.knockRiseOverTroughFactor,
    this.riseLookbackMs = AppConstants.knockRiseLookbackMs,
    this.riseBeforeMs = AppConstants.knockRiseBeforeMs,
    this.riseAfterMs = AppConstants.knockRiseAfterMs,
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
      _rawHistory.clear();
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
    final bool isOnsetFromRest =
        has3d &&
        rawMag >= onsetMinRawMag &&
        _prevMag <= onsetMaxPrevFraction * rawMag;
    _setPrevious(sensorMs, rawMag, x, y, z);
    _rememberJerk(sensorMs, delta);
    if (has3d) _rememberRaw(sensorMs, rawMag, delta);

    // 2. Sudden collision threshold check
    if (delta >= minKnockDelta) {
      if (_knocks.isNotEmpty) {
        final last = _knocks.last;
        if ((sensorMs - _mergeAnchorMs).abs() <= knockMergeMs) {
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
      if (recentJerk > 0 &&
          delta < riseFactor * recentJerk &&
          !isOnsetFromRest) {
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

  void _rememberRaw(int sensorMs, double rawMag, double delta) {
    _rawHistory.add(_RawSample(sensorMs, rawMag, delta));
    while (_rawHistory.isNotEmpty &&
        sensorMs - _rawHistory.first.tMs > _rawHistoryMs) {
      _rawHistory.removeAt(0);
    }
  }

  /// Raw readings are kept long enough for an impact window to close.
  static const int _rawHistoryMs = 1000;

  /// For a loud sound at [audioTsMs] that found no knock: the reading closest
  /// to the sound that rises clearly above the recent shake and is not part of
  /// another hit. It becomes a knock claimed by this sound (so no other sound
  /// can use it). Null when there is none.
  VibrationKnock? claimRiseNear({
    required int audioTsMs,
    List<int> rivalAudioTsMs = const <int>[],
  }) {
    final int fromMs = audioTsMs - riseBeforeMs;
    final int toMs = audioTsMs + riseAfterMs;
    _RawSample? best;
    int bestDistance = 1 << 30;
    for (int i = 1; i < _rawHistory.length; i++) {
      final _RawSample s = _rawHistory[i];
      if (s.tMs < fromMs || s.tMs > toMs || s.rawMag < riseMinRawMag) continue;
      double trough = double.infinity;
      for (int j = i - 1; j >= 0 && s.tMs - _rawHistory[j].tMs <= riseLookbackMs; j--) {
        trough = min(trough, _rawHistory[j].rawMag);
      }
      if (trough == double.infinity || s.rawMag < riseOverTroughFactor * trough) {
        continue;
      }
      if (_knocks.any((k) => (k.timestampMs - s.tMs).abs() <= knockMergeMs) ||
          _closerToRival(s.tMs, audioTsMs, rivalAudioTsMs)) {
        continue;
      }
      final int distance = (s.tMs - audioTsMs).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = s;
      }
    }
    if (best == null || best.delta < minKnockDelta) return null;
    final VibrationKnock knock = VibrationKnock(
      id: ++_knockIdCounter,
      timestampMs: best.tMs,
      deltaMag: best.delta,
      rawMag: best.rawMag,
      claimedByAudioTsMs: audioTsMs,
    );
    // Keep time order: pruning and rule 1 rely on the newest knock being last.
    final int at = _knocks.indexWhere((k) => k.timestampMs > best!.tMs);
    _knocks.insert(at == -1 ? _knocks.length : at, knock);
    return knock;
  }

  static bool _closerToRival(int tMs, int audioTsMs, List<int> rivals) {
    final int own = (tMs - audioTsMs).abs();
    return rivals.any((int r) => (tMs - r).abs() < own);
  }

  void _addKnock(int sensorMs, double delta, double rawMag) {
    _mergeAnchorMs = sensorMs;
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
  /// the unclaimed knock closest to [audioTsMs] is returned, skipping knocks
  /// that are closer to one of [rivalAudioTsMs] (other waiting sounds).
  VibrationKnock? findUnusedKnock({
    required int fromMs,
    required int toMs,
    required int audioTsMs,
    double? minRawMag,
    double? minDelta,
    List<int> rivalAudioTsMs = const <int>[],
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
            knock.rawMag >= effectiveMinRaw &&
            !_closerToRival(knock.timestampMs, audioTsMs, rivalAudioTsMs)) {
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
    _rawHistory.clear();
    _mergeAnchorMs = 0;
    _hasPrevious = false;
    _prevX = 0.0;
    _prevY = 0.0;
    _prevZ = 0.0;
    _prevMag = 0.0;
    _prevSensorMs = 0;
    _knockIdCounter = 0;
  }
}
