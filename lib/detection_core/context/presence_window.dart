/// Camera presence as a soft, time-windowed check instead of a per-frame gate.
///
/// A person counts as present at time t when a valid person was observed at
/// least once in the [windowMs] before t (or after it, while a decision is
/// still open). A glove covering the face for a few frames during a punch
/// therefore no longer rejects the punch.
///
/// During the first [startupGraceMs] of a session the camera is often still
/// starting; callers may treat "camera not ready" as a pass in that period.
///
/// Pure: times are passed in (detection clock, milliseconds).
class PresenceWindow {
  final int windowMs;
  final int startupGraceMs;

  PresenceWindow({this.windowMs = 1500, this.startupGraceMs = 3000});

  int? _lastValidMs;

  /// Time of the most recent valid-person observation, or null.
  int? get lastValidMs => _lastValidMs;

  void noteValid(int tMs) {
    final int? last = _lastValidMs;
    if (last == null || tMs > last) _lastValidMs = tMs;
  }

  /// True when a valid person was seen at or after `tMs - windowMs`.
  bool isPresentAt(int tMs) {
    final int? last = _lastValidMs;
    return last != null && last >= tMs - windowMs;
  }

  /// Milliseconds from the last valid observation to [tMs] (null if never).
  int? msSinceValid(int tMs) {
    final int? last = _lastValidMs;
    return last == null ? null : tMs - last;
  }

  /// True during the first [startupGraceMs] after [sessionStartMs].
  /// A non-positive [sessionStartMs] means the session start is unknown.
  bool isInStartupGrace(int tMs, int sessionStartMs) =>
      sessionStartMs > 0 &&
      tMs >= sessionStartMs &&
      tMs - sessionStartMs < startupGraceMs;

  void reset() => _lastValidMs = null;
}
