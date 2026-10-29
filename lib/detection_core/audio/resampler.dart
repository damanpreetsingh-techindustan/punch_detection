import 'dart:math' as math;
import 'dart:typed_data';

/// Streaming band-limited resampler (windowed-sinc, Blackman window) for 16-bit
/// mono PCM. Used to store iOS audio (captured at 44.1 kHz) as 16 kHz and to
/// feed the detector core at its fixed input rate.
///
/// Output depends only on the input samples, not on how they are chunked.
class StreamingResampler {
  StreamingResampler({
    required this.inRate,
    required this.outRate,
    this.zeroCrossings = 16,
  }) : _step = inRate / outRate,
       _cutoff = math.min(1.0, outRate / inRate) * 0.92,
       _halfWidth = 0 {
    _halfWidth = (zeroCrossings / _cutoff).ceil();
    _table = Float64List(_halfWidth * _tableResolution + 2);
    for (int i = 0; i < _table.length; i++) {
      _table[i] = _kernelExact(i / _tableResolution);
    }
  }

  /// Kernel table entries per input sample of distance.
  static const int _tableResolution = 256;
  late final Float64List _table;

  final int inRate;
  final int outRate;

  /// Zero crossings of the sinc kept on each side (filter quality).
  final int zeroCrossings;

  /// Input samples per output sample.
  final double _step;

  /// Low-pass cutoff relative to the input Nyquist frequency.
  final double _cutoff;

  /// Kernel half width in input samples.
  int _halfWidth;

  final List<double> _buffer = <double>[];
  int _bufferStart = 0; // absolute input index of _buffer[0]
  int _nextOut = 0; // absolute output index of the next output sample

  bool get isPassthrough => inRate == outRate;

  /// Total input samples consumed.
  int get inputSamples => _bufferStart + _buffer.length;

  /// Total output samples produced.
  int get outputSamples => _nextOut;

  Int16List process(Int16List input) {
    if (isPassthrough) {
      _bufferStart += input.length;
      _nextOut += input.length;
      return Int16List.fromList(input);
    }
    for (final int s in input) {
      _buffer.add(s.toDouble());
    }
    final int available = _bufferStart + _buffer.length;
    final List<int> out = <int>[];
    while (true) {
      final double x = _nextOut * _step;
      final int centre = x.floor();
      if (centre + _halfWidth >= available) break;
      double acc = 0.0;
      for (
        int k = math.max(_bufferStart, centre - _halfWidth + 1);
        k <= centre + _halfWidth;
        k++
      ) {
        acc += _buffer[k - _bufferStart] * _kernel(x - k);
      }
      out.add(acc.round().clamp(-32768, 32767));
      _nextOut++;
    }
    // Keep only what the next output still needs.
    final int keepFrom = (_nextOut * _step).floor() - _halfWidth + 1;
    final int drop = math.min(keepFrom - _bufferStart, _buffer.length);
    if (drop > 0) {
      _buffer.removeRange(0, drop);
      _bufferStart += drop;
    }
    return Int16List.fromList(out);
  }

  double _kernel(double d) {
    final int i = (d.abs() * _tableResolution).round();
    return i < _table.length ? _table[i] : 0.0;
  }

  double _kernelExact(double d) {
    final double t = d / _halfWidth;
    if (t <= -1.0 || t >= 1.0) return 0.0;
    final double arg = math.pi * _cutoff * d;
    final double sinc = d == 0 ? 1.0 : math.sin(arg) / arg;
    final double window =
        0.42 + 0.5 * math.cos(math.pi * t) + 0.08 * math.cos(2 * math.pi * t);
    return _cutoff * sinc * window;
  }
}
