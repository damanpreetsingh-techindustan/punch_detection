/// Screen-touch lockout: a phone tap makes a sharp sound and a shock in the
/// phone itself, so no impact may count from [beforeMs] before to [afterMs]
/// after any pointer-down. "Before" covers the touch event being delivered
/// slightly later than the tap sound.
///
/// Pure: times are passed in (detection clock, milliseconds).
class TouchLockout {
  final int beforeMs;
  final int afterMs;

  /// Touches older than this are forgotten.
  final int historyMs;

  TouchLockout({
    this.beforeMs = 100,
    this.afterMs = 400,
    this.historyMs = 5000,
  });

  final List<int> _touches = <int>[];

  /// Touch times currently remembered, oldest first.
  List<int> get touches => List<int>.unmodifiable(_touches);

  void addTouch(int tMs) {
    _touches.add(tMs);
    _touches.sort();
    final int cutoff = _touches.last - historyMs;
    _touches.removeWhere((int t) => t < cutoff);
  }

  /// The touch whose lockout window contains [tMs], or null.
  int? touchCovering(int tMs) {
    for (int i = _touches.length - 1; i >= 0; i--) {
      final int touch = _touches[i];
      if (tMs >= touch - beforeMs && tMs <= touch + afterMs) return touch;
    }
    return null;
  }

  bool isLocked(int tMs) => touchCovering(tMs) != null;

  void reset() => _touches.clear();
}
