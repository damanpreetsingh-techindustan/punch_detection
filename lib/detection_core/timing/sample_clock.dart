/// One sync point between an audio sample index and the detection clock:
/// the first [sampleIndex] samples (indices 0 .. sampleIndex-1) had been
/// captured by time [tUs]. Usually taken from a buffer's arrival time, so it
/// is late by the delivery latency (never early).
class SyncPoint {
  final int sampleIndex;
  final int tUs;

  const SyncPoint(this.sampleIndex, this.tUs);

  List<int> toList() => <int>[sampleIndex, tUs];

  @override
  String toString() => 'SyncPoint($sampleIndex, $tUs)';
}

/// Collects one sync point per [periodUs] from a stream of buffer arrivals:
/// the arrival with the smallest latency in each period (relative to the
/// nominal sample rate), which is the most accurate one.
class SyncPointCollector {
  SyncPointCollector({required this.nominalRate, this.periodUs = 1000000});

  final int nominalRate;
  final int periodUs;

  SyncPoint? _best;
  double _bestResidual = double.infinity;
  int? _periodStartUs;
  final List<SyncPoint> _points = <SyncPoint>[];

  /// Every sync point emitted so far (one per completed period).
  List<SyncPoint> get points => List<SyncPoint>.unmodifiable(_points);

  /// The very first arrival seen (for "time of the first sample").
  SyncPoint? first;

  /// Feeds one buffer arrival; returns the sync point of a period that just
  /// completed, or null.
  SyncPoint? addArrival({required int endSampleIndex, required int arrivalUs}) {
    first ??= SyncPoint(endSampleIndex, arrivalUs);
    final int periodStart = _periodStartUs ??= arrivalUs;
    SyncPoint? emitted;
    if (arrivalUs - periodStart >= periodUs && _best != null) {
      emitted = _best;
      _points.add(emitted!);
      _best = null;
      _bestResidual = double.infinity;
      _periodStartUs = arrivalUs;
    }
    final double residual = arrivalUs - endSampleIndex * 1e6 / nominalRate;
    if (residual < _bestResidual) {
      _bestResidual = residual;
      _best = SyncPoint(endSampleIndex, arrivalUs);
    }
    return emitted;
  }

  /// Emits the pending point of the unfinished period (call at the end).
  SyncPoint? flush() {
    final SyncPoint? best = _best;
    if (best == null) return null;
    _points.add(best);
    _best = null;
    _bestResidual = double.infinity;
    return best;
  }
}

/// Linear mapping from audio sample index to detection-clock time:
///   t(i) = interceptUs + i * usPerSample
/// fitted from sync points. The slope follows the real capture rate (audio
/// clocks drift by tens of ppm against the system clock, ~30 ms over 10 min);
/// the intercept is the lower envelope of the points, i.e. the least-delayed
/// arrival, because every arrival is late by its delivery latency.
class SampleClockMapping {
  final int nominalRate;
  final double interceptUs;
  final double usPerSample;

  const SampleClockMapping({
    required this.nominalRate,
    required this.interceptUs,
    required this.usPerSample,
  });

  /// Detection-clock time (µs) of sample [sampleIndex].
  double timeUsOf(num sampleIndex) => interceptUs + sampleIndex * usPerSample;

  /// Sample index captured at detection-clock time [tUs].
  double sampleIndexAt(num tUs) => (tUs - interceptUs) / usPerSample;

  /// Capture rate measured against the detection clock.
  double get effectiveRateHz => 1e6 / usPerSample;

  Map<String, Object?> toMap() => <String, Object?>{
    'nominalRate': nominalRate,
    'interceptUs': interceptUs,
    'usPerSample': usPerSample,
    'effectiveRateHz': effectiveRateHz,
  };

  /// Fits a mapping. The slope is the least-squares fit when the points span at
  /// least one second of audio (kept within [maxRateDeviation] of nominal);
  /// otherwise the nominal rate is used.
  static SampleClockMapping fit(
    List<SyncPoint> points, {
    required int nominalRate,
    double maxRateDeviation = 0.01,
  }) {
    final double nominalUsPerSample = 1e6 / nominalRate;
    if (points.isEmpty) {
      return SampleClockMapping(
        nominalRate: nominalRate,
        interceptUs: 0,
        usPerSample: nominalUsPerSample,
      );
    }
    double slope = nominalUsPerSample;
    final int span = points.last.sampleIndex - points.first.sampleIndex;
    if (points.length >= 2 && span >= nominalRate) {
      double meanI = 0, meanT = 0;
      for (final SyncPoint p in points) {
        meanI += p.sampleIndex;
        meanT += p.tUs;
      }
      meanI /= points.length;
      meanT /= points.length;
      double cov = 0, varI = 0;
      for (final SyncPoint p in points) {
        final double di = p.sampleIndex - meanI;
        cov += di * (p.tUs - meanT);
        varI += di * di;
      }
      if (varI > 0) {
        final double fitted = cov / varI;
        final double lo = nominalUsPerSample * (1 - maxRateDeviation);
        final double hi = nominalUsPerSample * (1 + maxRateDeviation);
        slope = fitted.clamp(lo, hi);
      }
    }
    double intercept = double.infinity;
    for (final SyncPoint p in points) {
      final double candidate = p.tUs - p.sampleIndex * slope;
      if (candidate < intercept) intercept = candidate;
    }
    return SampleClockMapping(
      nominalRate: nominalRate,
      interceptUs: intercept,
      usPerSample: slope,
    );
  }
}
