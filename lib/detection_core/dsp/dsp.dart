import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

/// Second-order IIR section (RBJ audio-EQ cookbook), transposed direct form II.
class Biquad {
  Biquad._(this._b0, this._b1, this._b2, this._a1, this._a2);

  factory Biquad.lowPass(double fs, double f0, {double q = 0.70710678}) {
    final double w = 2 * math.pi * f0 / fs;
    final double alpha = math.sin(w) / (2 * q);
    final double c = math.cos(w);
    final double a0 = 1 + alpha;
    return Biquad._(
      (1 - c) / 2 / a0,
      (1 - c) / a0,
      (1 - c) / 2 / a0,
      -2 * c / a0,
      (1 - alpha) / a0,
    );
  }

  factory Biquad.highPass(double fs, double f0, {double q = 0.70710678}) {
    final double w = 2 * math.pi * f0 / fs;
    final double alpha = math.sin(w) / (2 * q);
    final double c = math.cos(w);
    final double a0 = 1 + alpha;
    return Biquad._(
      (1 + c) / 2 / a0,
      -(1 + c) / a0,
      (1 + c) / 2 / a0,
      -2 * c / a0,
      (1 - alpha) / a0,
    );
  }

  final double _b0, _b1, _b2, _a1, _a2;
  double _z1 = 0, _z2 = 0;

  double process(double x) {
    final double y = _b0 * x + _z1;
    _z1 = _b1 * x - _a1 * y + _z2;
    _z2 = _b2 * x - _a2 * y;
    return y;
  }

  void reset() {
    _z1 = 0;
    _z2 = 0;
  }
}

/// In-place iterative radix-2 FFT. [re] and [im] must have a power-of-two length.
void fftInPlace(Float64List re, Float64List im) {
  final int n = re.length;
  for (int i = 1, j = 0; i < n; i++) {
    int bit = n >> 1;
    for (; (j & bit) != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final double tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final double ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (int len = 2; len <= n; len <<= 1) {
    final double ang = -2 * math.pi / len;
    final double wr = math.cos(ang), wi = math.sin(ang);
    for (int i = 0; i < n; i += len) {
      double cr = 1, ci = 0;
      for (int k = 0; k < len ~/ 2; k++) {
        final int a = i + k, b = i + k + len ~/ 2;
        final double xr = re[b] * cr - im[b] * ci;
        final double xi = re[b] * ci + im[b] * cr;
        re[b] = re[a] - xr;
        im[b] = im[a] - xi;
        re[a] += xr;
        im[a] += xi;
        final double ncr = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = ncr;
      }
    }
  }
}

/// Power spectrum (|X|², bins 0..n/2) of [samples], Hann-windowed and
/// zero-padded to [fftSize].
Float64List powerSpectrum(List<double> samples, int fftSize) {
  final Float64List re = Float64List(fftSize);
  final Float64List im = Float64List(fftSize);
  final int n = math.min(samples.length, fftSize);
  for (int i = 0; i < n; i++) {
    final double w = n > 1
        ? 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1))
        : 1;
    re[i] = samples[i] * w;
  }
  fftInPlace(re, im);
  final Float64List power = Float64List(fftSize ~/ 2 + 1);
  for (int k = 0; k < power.length; k++) {
    power[k] = re[k] * re[k] + im[k] * im[k];
  }
  return power;
}

/// Percentile of the values added over the last [windowUs], from a histogram:
/// O(1) per update, O(bins) per query, [binWidth] resolution.
class RollingPercentile {
  RollingPercentile({
    required this.minValue,
    required this.maxValue,
    required this.binWidth,
    required this.windowUs,
  }) : _bins = Int32List(((maxValue - minValue) / binWidth).ceil() + 1);

  final double minValue;
  final double maxValue;
  final double binWidth;
  final int windowUs;

  final Int32List _bins;
  final ListQueue<(int, int)> _entries = ListQueue<(int, int)>();

  int get count => _entries.length;

  void add(double value, int tUs) {
    final int bin = ((value.clamp(minValue, maxValue) - minValue) / binWidth)
        .floor()
        .clamp(0, _bins.length - 1);
    _bins[bin]++;
    _entries.addLast((tUs, bin));
    prune(tUs);
  }

  /// Drops values older than `nowUs - windowUs`.
  void prune(int nowUs) {
    while (_entries.isNotEmpty && _entries.first.$1 < nowUs - windowUs) {
      _bins[_entries.removeFirst().$2]--;
    }
  }

  /// Percentile [p] (0-100), or null when empty.
  double? percentile(double p) {
    final int n = _entries.length;
    if (n == 0) return null;
    final int target = math.max(1, (p / 100 * n).ceil());
    int cumulative = 0;
    for (int i = 0; i < _bins.length; i++) {
      cumulative += _bins[i];
      if (cumulative >= target) return minValue + (i + 0.5) * binWidth;
    }
    return maxValue;
  }
}

/// Running median of the last [capacity] values. Starts with [seedCount] copies
/// of [seed], which are dropped once that many real values have arrived, so a
/// single odd first value cannot set the scale.
class RunningMedian {
  RunningMedian({
    required this.capacity,
    required double seed,
    this.seedCount = 3,
  }) : _seedsLeft = seedCount {
    for (int i = 0; i < seedCount; i++) {
      _values.addLast(seed);
    }
  }

  final int capacity;
  final int seedCount;
  final ListQueue<double> _values = ListQueue<double>();
  int _seedsLeft;
  int _real = 0;

  void add(double value) {
    if (!value.isFinite) return;
    _values.addLast(value);
    _real++;
    if (_seedsLeft > 0 && _real >= seedCount) {
      while (_seedsLeft > 0) {
        _values.removeFirst();
        _seedsLeft--;
      }
    }
    while (_values.length > capacity) {
      _values.removeFirst();
      if (_seedsLeft > 0) _seedsLeft--;
    }
  }

  double get median {
    final List<double> sorted = _values.toList()..sort();
    final int n = sorted.length;
    return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }

  /// Real (non-seed) values currently held.
  int get count => math.min(_real, capacity);

  /// Starts over from a new seed (e.g. after a quick calibration).
  void reseed(double seed) {
    _values.clear();
    for (int i = 0; i < seedCount; i++) {
      _values.addLast(seed);
    }
    _seedsLeft = seedCount;
    _real = 0;
  }
}

double dbFromPower(double meanSquare) =>
    10 * math.log(meanSquare + 1e-12) / math.ln10;

double dbFromAmplitude(double amplitude) =>
    20 * math.log(amplitude + 1e-9) / math.ln10;

double log2(double x) => math.log(x) / math.ln2;
