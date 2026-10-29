class MonotonicClock {
  static final _Anchor _anchor = _Anchor();

  /// Returns current elapsed time in milliseconds since app launch.
  static int nowMilliseconds() {
    return _anchor.stopwatch.elapsedMilliseconds;
  }

  /// Returns current elapsed time in microseconds since app launch.
  static int nowMicroseconds() {
    return _anchor.stopwatch.elapsedMicroseconds;
  }

  /// Monotonic time expressed in epoch milliseconds: the wall clock read once
  /// at first use plus a monotonic stopwatch. It has the same range as
  /// `DateTime.now().millisecondsSinceEpoch` (so logs and exported files keep
  /// their meaning) but never jumps when the wall clock is changed or synced.
  /// Every detection timestamp uses this clock.
  static int epochMs() => epochUs() ~/ 1000;

  /// Microsecond version of [epochMs].
  static int epochUs() =>
      _anchor.epochUs + _anchor.stopwatch.elapsedMicroseconds;
}

/// Wall-clock anchor and stopwatch created together, so they share one origin.
class _Anchor {
  final int epochUs = DateTime.now().microsecondsSinceEpoch;
  final Stopwatch stopwatch = Stopwatch()..start();
}
