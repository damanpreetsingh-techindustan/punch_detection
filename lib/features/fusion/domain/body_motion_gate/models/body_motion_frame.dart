import 'dart:math';

/// Upper-body points the body-motion gate follows.
///
/// [face], [leftShoulder], [rightShoulder] are (almost) always visible in the
/// session setup; elbows / wrists only during some punches and are used when
/// present, never required.
enum BodyMotionPoint {
  face,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
}

/// One camera frame reduced to what the body-motion gate needs.
///
/// Pure data (no ML Kit types), so the gate can be unit tested with plain
/// numbers. Built from an ML Kit pose by `PoseMotionFrameMapper`.
class BodyMotionFrame {
  /// Time the camera frame arrived (epoch ms, same clock as audio spikes).
  final int tMs;

  /// Image-pixel positions of the points ML Kit saw confidently in this frame.
  final Map<BodyMotionPoint, Point<double>> points;

  /// User's body width in image pixels (shoulder span, or a face-based
  /// estimate). Movement is divided by it so the score does not depend on the
  /// distance to the camera. Null when it could not be measured.
  final double? bodyScale;

  const BodyMotionFrame({
    required this.tMs,
    required this.points,
    this.bodyScale,
  });
}
