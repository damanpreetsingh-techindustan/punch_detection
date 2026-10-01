class MonotonicClock {
  static final Stopwatch _stopwatch = Stopwatch()..start();

  /// Returns current elapsed time in milliseconds since app launch.
  static int nowMilliseconds() {
    return _stopwatch.elapsedMilliseconds;
  }

  /// Returns current elapsed time in microseconds since app launch.
  static int nowMicroseconds() {
    return _stopwatch.elapsedMicroseconds;
  }
}
