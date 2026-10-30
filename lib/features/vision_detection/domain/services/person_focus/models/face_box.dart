import 'dart:ui';

/// One detected face, reduced to what nearest-person focus needs.
///
/// [box] is in UPRIGHT image coordinates (the image after the rotation given to
/// ML Kit), the same space as pose landmarks.
class FaceBox {
  final Rect box;

  /// Stable id across frames when face tracking is on, null otherwise.
  final int? trackingId;

  const FaceBox({required this.box, this.trackingId});

  /// Face width in pixels: a bigger face means a person closer to the camera.
  double get size => box.width;

  /// True when [other] is most likely the same person: same tracking id, or
  /// (without ids) boxes that overlap enough.
  bool isSamePersonAs(FaceBox other, {double minOverlap = 0.3}) {
    if (trackingId != null && other.trackingId != null) {
      return trackingId == other.trackingId;
    }
    return overlapRatio(other) >= minOverlap;
  }

  /// Intersection over union of the two boxes (0 = apart, 1 = identical).
  double overlapRatio(FaceBox other) {
    final Rect inter = box.intersect(other.box);
    if (inter.width <= 0 || inter.height <= 0) return 0.0;
    final double interArea = inter.width * inter.height;
    final double unionArea =
        box.width * box.height + other.box.width * other.box.height - interArea;
    return unionArea <= 0 ? 0.0 : interArea / unionArea;
  }
}
