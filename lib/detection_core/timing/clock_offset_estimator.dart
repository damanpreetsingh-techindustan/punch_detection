import 'dart:collection';

/// Maps timestamps of another monotonic clock (for example the native sensor
/// clock) onto the detection clock.
///
/// Each observation pairs a native "now" with the detection-clock time at which
/// it was received:  received = native + offset + latency,  latency >= 0.
/// The smallest (received - native) seen is therefore the best estimate of the
/// offset: it comes from the message that travelled fastest. A sliding window
/// lets the estimate follow slow drift between the two clocks.
///
/// Pure: all times are passed in (microseconds).
class ClockOffsetEstimator {
  ClockOffsetEstimator({this.windowSize = 500});

  /// Number of most recent observations the minimum is taken over.
  final int windowSize;

  final ListQueue<int> _deltasUs = ListQueue<int>();
  int? _offsetUs;
  int _count = 0;

  /// Current offset (detection = native + offset), or null before the first
  /// observation.
  int? get offsetUs => _offsetUs;

  /// Observations seen in total.
  int get count => _count;

  void addObservation({required int nativeUs, required int receivedUs}) {
    final int delta = receivedUs - nativeUs;
    _count++;
    _deltasUs.addLast(delta);
    if (_deltasUs.length > windowSize) {
      final int dropped = _deltasUs.removeFirst();
      if (dropped == _offsetUs) {
        _offsetUs = _deltasUs.reduce((int a, int b) => a < b ? a : b);
        return;
      }
    }
    final int? current = _offsetUs;
    if (current == null || delta < current) _offsetUs = delta;
  }

  /// [nativeUs] on the detection clock, or null before the first observation.
  int? toDetectionUs(int nativeUs) {
    final int? offset = _offsetUs;
    return offset == null ? null : nativeUs + offset;
  }

  /// Median latency above the fastest observation in the window (diagnostics).
  int? get medianExtraLatencyUs {
    final int? offset = _offsetUs;
    if (offset == null || _deltasUs.isEmpty) return null;
    final List<int> sorted = _deltasUs.toList()..sort();
    return sorted[sorted.length ~/ 2] - offset;
  }
}
