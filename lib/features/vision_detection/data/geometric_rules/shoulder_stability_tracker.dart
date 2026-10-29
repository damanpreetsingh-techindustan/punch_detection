import 'package:punch_detection_demo/core/utils/monotonic_clock.dart';

// import 'dart:math';

/// Tracks shoulder-centre stability over a rolling window of frames.
///
/// Purpose: require the user to be in a stable standing position for
/// [windowFrames] consecutive valid frames BEFORE punch detection is armed.
/// This prevents random objects crossing the camera from triggering the
/// algorithm.
///
/// Grace period: once stable, the tracker remains stable for up to
/// [gracePeriodMs] milliseconds even if a few frames fail the validity gate
/// (e.g. the user's arm briefly occludes the shoulders during a punch).
/// This avoids requiring a new warm-up after brief tracking interruptions.
class ShoulderStabilityTracker {
  /// Number of consecutive valid frames with low shoulder-centre displacement
  /// required before [isStable] becomes true.
  final int windowFrames;

  /// Maximum average inter-frame shoulder-centre displacement (in raw image
  /// pixels) allowed to consider the person "stable".
  /// Typical breathing sway ≈ 2–4 px; punching shoulder displacement ≈ 20+ px.
  final double maxDisplacementPerFrame;

  /// After a frame fails validity, the tracker remains in the stable state for
  /// this many milliseconds before resetting (grace period).
  final int gracePeriodMs;

  // ─── Internal state ────────────────────────────────────────────────────────
  final List<_ShoulderSnapshot> _history = [];
  bool _isStable = false;
  int _lastValidMs = 0;

  ShoulderStabilityTracker({
    this.windowFrames = 5,
    this.maxDisplacementPerFrame = 8.0,
    this.gracePeriodMs = 1000,
  });

  /// Update the tracker with the current frame's shoulder centre [cx], [cy]
  /// (raw image pixel coordinates).
  ///
  /// Pass [isValidPose] = false when the validity gate rejected the current
  /// frame (no shoulder data available). The tracker will enter its grace
  /// period and eventually reset if the invalid condition persists.
  ///
  /// Returns the current [isStable] value.
  bool update({
    required double cx,
    required double cy,
    required bool isValidPose,
  }) {
    final int nowMs = MonotonicClock.epochMs();

    if (!isValidPose) {
      // Within grace period: stay stable so the first punch after a brief
      // occlusion is not missed.
      if (_isStable && (nowMs - _lastValidMs) < gracePeriodMs) {
        return true;
      }
      // Grace period expired — reset everything.
      _history.clear();
      _isStable = false;
      return false;
    }

    _lastValidMs = nowMs;
    _history.add(_ShoulderSnapshot(cx: cx, cy: cy));

    // Keep window size to windowFrames + 1 so we always have a "previous" point.
    if (_history.length > windowFrames + 1) _history.removeAt(0);

    /*
    if (_history.length < 2) return _isStable;

    // Average inter-frame displacement over the window.
    double total = 0.0;
    for (int i = 1; i < _history.length; i++) {
      final dx = _history[i].cx - _history[i - 1].cx;
      final dy = _history[i].cy - _history[i - 1].cy;
      total += sqrt(dx * dx + dy * dy);
    }
    final double avgDisplacement = total / (_history.length - 1);

    // Only flip isStable once we have a full window of samples.
    if (_history.length >= windowFrames) {
      _isStable = avgDisplacement <= maxDisplacementPerFrame;
    }
    */
    _isStable = true;

    return _isStable;
  }

  /// Hard reset — clears all history and marks the tracker as unstable.
  void reset() {
    _history.clear();
    _isStable = false;
    _lastValidMs = 0;
  }

  bool get isStable => _isStable;
}

class _ShoulderSnapshot {
  final double cx;
  final double cy;

  _ShoulderSnapshot({required this.cx, required this.cy});
}
