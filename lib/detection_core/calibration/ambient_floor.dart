import 'dart:math' as math;

/// One microphone level reading (app-dB) with its time on the detection clock.
class TimedLevel {
  final int tMs;
  final double db;

  const TimedLevel(this.tMs, this.db);
}

/// Outcome of [AmbientFloorEstimator.estimate].
class AmbientFloorResult {
  /// Mean of the blocks between the low and high percentile: the room floor.
  final double floorDb;
  final double lowPercentileDb;
  final double highPercentileDb;
  final double medianDb;

  /// Loudest block after the ignored start (logged only, never the target base).
  final double maxDb;

  /// Blocks used / blocks dropped because they fell in the ignored start.
  final int usedBlocks;
  final int ignoredBlocks;

  /// False when no usable block was seen; [floorDb] is then the fallback value.
  final bool isValid;

  const AmbientFloorResult({
    required this.floorDb,
    required this.lowPercentileDb,
    required this.highPercentileDb,
    required this.medianDb,
    required this.maxDb,
    required this.usedBlocks,
    required this.ignoredBlocks,
    required this.isValid,
  });

  Map<String, Object?> toMap() => <String, Object?>{
    'floorDb': floorDb,
    'lowPercentileDb': lowPercentileDb,
    'highPercentileDb': highPercentileDb,
    'medianDb': medianDb,
    'maxDb': maxDb,
    'usedBlocks': usedBlocks,
    'ignoredBlocks': ignoredBlocks,
    'isValid': isValid,
  };
}

/// Room noise floor from a few seconds of 10 ms block levels.
///
/// The floor is the mean of the blocks whose level lies between the
/// [lowPercentile] and [highPercentile] of all usable blocks. Unlike the mean or
/// the max, this ignores both the quietest drop-outs and every loud event
/// (a shout, a bag hit, the tap that started the calibration).
/// Blocks within [ignoreFirstMs] of the start are dropped for every statistic.
class AmbientFloorEstimator {
  final int ignoreFirstMs;
  final double lowPercentile;
  final double highPercentile;
  final double fallbackDb;

  const AmbientFloorEstimator({
    this.ignoreFirstMs = 400,
    this.lowPercentile = 20.0,
    this.highPercentile = 50.0,
    this.fallbackDb = 40.0,
  }) : assert(lowPercentile <= highPercentile);

  AmbientFloorResult estimate(List<TimedLevel> blocks, {required int startMs}) {
    final List<double> levels = <double>[];
    int ignored = 0;
    for (final TimedLevel block in blocks) {
      if (block.tMs - startMs < ignoreFirstMs) {
        ignored++;
        continue;
      }
      if (block.db.isFinite) levels.add(block.db);
    }
    if (levels.isEmpty) {
      return AmbientFloorResult(
        floorDb: fallbackDb,
        lowPercentileDb: fallbackDb,
        highPercentileDb: fallbackDb,
        medianDb: fallbackDb,
        maxDb: fallbackDb,
        usedBlocks: 0,
        ignoredBlocks: ignored,
        isValid: false,
      );
    }
    levels.sort();
    final double low = percentile(levels, lowPercentile);
    final double high = percentile(levels, highPercentile);
    double sum = 0.0;
    int n = 0;
    for (final double level in levels) {
      if (level >= low && level <= high) {
        sum += level;
        n++;
      }
    }
    return AmbientFloorResult(
      floorDb: n == 0 ? low : sum / n,
      lowPercentileDb: low,
      highPercentileDb: high,
      medianDb: percentile(levels, 50.0),
      maxDb: levels.last,
      usedBlocks: levels.length,
      ignoredBlocks: ignored,
      isValid: true,
    );
  }
}

/// Percentile [p] (0–100) of an ascending list, linearly interpolated.
double percentile(List<double> sortedAscending, double p) {
  if (sortedAscending.isEmpty) {
    throw ArgumentError('percentile of an empty list');
  }
  final double rank =
      (p.clamp(0.0, 100.0) / 100.0) * (sortedAscending.length - 1);
  final int lo = rank.floor();
  final int hi = math.min(lo + 1, sortedAscending.length - 1);
  final double frac = rank - lo;
  return sortedAscending[lo] +
      (sortedAscending[hi] - sortedAscending[lo]) * frac;
}

/// Flags a microphone that is not delivering audio: the level sits at the
/// bottom of the app scale continuously for longer than [maxDurationMs].
class MicFloorWatchdog {
  final double floorDb;
  final double toleranceDb;
  final int maxDurationMs;

  MicFloorWatchdog({
    this.floorDb = 35.0,
    this.toleranceDb = 0.05,
    this.maxDurationMs = 1000,
  });

  int? _floorSinceMs;
  bool _tripped = false;

  /// True while the level has been at the floor for more than [maxDurationMs].
  bool get isAtFloorTooLong => _tripped;

  /// Feeds one level; returns [isAtFloorTooLong].
  bool update(double db, int tMs) {
    if (db <= floorDb + toleranceDb) {
      _floorSinceMs ??= tMs;
      _tripped = tMs - _floorSinceMs! > maxDurationMs;
    } else {
      _floorSinceMs = null;
      _tripped = false;
    }
    return _tripped;
  }

  void reset() {
    _floorSinceMs = null;
    _tripped = false;
  }
}
