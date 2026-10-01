import 'dart:ui';

/// A normalized single-frame landmark snapshot for temporal kinetic analysis.
class PoseFrameSample {
  final int timestampMs;
  final Offset shoulder;
  final Offset? head;
  final Offset? elbow;
  final Offset? wrist;
  final double shoulderZ;
  final double? wristZ;

  PoseFrameSample({
    required this.timestampMs,
    required this.shoulder,
    this.head,
    this.elbow,
    this.wrist,
    required this.shoulderZ,
    this.wristZ,
  });
}
