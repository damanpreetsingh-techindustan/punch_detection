import 'dart:math';
import 'dart:typed_data';

import 'appearance_signature.dart';

/// The five points a face embedding model is aligned on (upright image
/// pixels). "Left" / "right" mean the image's left / right, whatever the
/// person's anatomy or camera mirroring: that is how the template is laid out.
class FacePoints {
  final Point<double> leftEye;
  final Point<double> rightEye;
  final Point<double> nose;
  final Point<double> leftMouth;
  final Point<double> rightMouth;

  const FacePoints({
    required this.leftEye,
    required this.rightEye,
    required this.nose,
    required this.leftMouth,
    required this.rightMouth,
  });

  /// Orders the two eyes and the two mouth corners by image x.
  factory FacePoints.ordered({
    required Point<double> eyeA,
    required Point<double> eyeB,
    required Point<double> nose,
    required Point<double> mouthA,
    required Point<double> mouthB,
  }) => FacePoints(
    leftEye: eyeA.x <= eyeB.x ? eyeA : eyeB,
    rightEye: eyeA.x <= eyeB.x ? eyeB : eyeA,
    nose: nose,
    leftMouth: mouthA.x <= mouthB.x ? mouthA : mouthB,
    rightMouth: mouthA.x <= mouthB.x ? mouthB : mouthA,
  );

  List<Point<double>> get list => <Point<double>>[
    leftEye,
    rightEye,
    nose,
    leftMouth,
    rightMouth,
  ];

  double get eyeDistance => leftEye.distanceTo(rightEye);

  /// Index of the detected face that belongs to this (pose) face: the box
  /// around [nose] nearest its centre, null when no box contains it. A head
  /// cut-out can also show a neighbour's face, and checking that one would
  /// judge the wrong person.
  int? indexOfOwnFace(List<Rectangle<double>> boxes) {
    int? best;
    double bestDistance = double.infinity;
    for (int i = 0; i < boxes.length; i++) {
      final Rectangle<double> box = boxes[i];
      if (!box.containsPoint(nose)) continue;
      final double distance = nose.distanceTo(
        Point<double>(box.left + box.width / 2, box.top + box.height / 2),
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }
}

/// Rotation + uniform scale + translation:
/// x' = a·x − b·y + tx, y' = b·x + a·y + ty.
class Similarity2D {
  final double a;
  final double b;
  final double tx;
  final double ty;

  const Similarity2D(this.a, this.b, this.tx, this.ty);

  /// Least-squares fit that maps [src] onto [dst] (no reflection).
  factory Similarity2D.fit(List<Point<double>> src, List<Point<double>> dst) {
    final int n = src.length;
    double sx = 0, sy = 0, dx = 0, dy = 0;
    for (int i = 0; i < n; i++) {
      sx += src[i].x;
      sy += src[i].y;
      dx += dst[i].x;
      dy += dst[i].y;
    }
    sx /= n;
    sy /= n;
    dx /= n;
    dy /= n;
    double dot = 0, cross = 0, norm = 0;
    for (int i = 0; i < n; i++) {
      final double px = src[i].x - sx, py = src[i].y - sy;
      final double qx = dst[i].x - dx, qy = dst[i].y - dy;
      dot += px * qx + py * qy;
      cross += px * qy - py * qx;
      norm += px * px + py * py;
    }
    final double a = norm == 0 ? 1 : dot / norm;
    final double b = norm == 0 ? 0 : cross / norm;
    return Similarity2D(a, b, dx - (a * sx - b * sy), dy - (b * sx + a * sy));
  }

  Point<double> apply(Point<double> p) =>
      Point<double>(a * p.x - b * p.y + tx, b * p.x + a * p.y + ty);

  Similarity2D inverse() {
    final double d = a * a + b * b;
    final double ia = a / d, ib = -b / d;
    return Similarity2D(ia, ib, -(ia * tx - ib * ty), -(ib * tx + ia * ty));
  }
}

/// Aligns a face to the standard 112 × 112 five-point template used by
/// SFace / ArcFace-family models.
class FaceAlignment {
  static const int size = 112;

  static const List<Point<double>> template = <Point<double>>[
    Point<double>(38.2946, 51.6963),
    Point<double>(73.5318, 51.5014),
    Point<double>(56.0252, 71.7366),
    Point<double>(41.5493, 92.3655),
    Point<double>(70.7299, 92.2041),
  ];

  /// Eye distance in the template (≈ 35 px).
  static double get templateEyeDistance => template[0].distanceTo(template[1]);

  /// Aligned face as RGB floats 0–255, 112 × 112 × 3 (row-major, NHWC):
  /// each output pixel is read from the frame (bilinear) through the inverse
  /// of the face → template transform. Outside the frame is black.
  static Float32List alignedRgb(FramePixels pixels, FacePoints face) {
    final Similarity2D back = Similarity2D.fit(face.list, template).inverse();
    final Float32List out = Float32List(size * size * 3);
    for (int oy = 0; oy < size; oy++) {
      for (int ox = 0; ox < size; ox++) {
        final double x = back.a * ox - back.b * oy + back.tx;
        final double y = back.b * ox + back.a * oy + back.ty;
        final int x0 = x.floor(), y0 = y.floor();
        final double fx = x - x0, fy = y - y0;
        final int c00 = pixels.rgbAt(x0, y0);
        final int c10 = pixels.rgbAt(x0 + 1, y0);
        final int c01 = pixels.rgbAt(x0, y0 + 1);
        final int c11 = pixels.rgbAt(x0 + 1, y0 + 1);
        final int o = (oy * size + ox) * 3;
        for (int ch = 0; ch < 3; ch++) {
          final int shift = 16 - 8 * ch;
          double v(int c) => c < 0 ? 0 : ((c >> shift) & 0xFF).toDouble();
          out[o + ch] =
              (v(c00) * (1 - fx) + v(c10) * fx) * (1 - fy) +
              (v(c01) * (1 - fx) + v(c11) * fx) * fy;
        }
      }
    }
    return out;
  }
}
