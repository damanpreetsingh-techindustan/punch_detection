import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/appearance_signature.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/face_alignment.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/face_identity.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/user_match_stats.dart';

/// A unit vector at [cosine] from the first axis (so its cosine with
/// [axis] is exactly [cosine]).
List<double> atCosine(double cosine, {int size = 8}) =>
    <double>[cosine, sqrt(1 - cosine * cosine), ...List<double>.filled(size - 2, 0)];
final List<double> axis = atCosine(1);

void main() {
  group('Similarity2D', () {
    test('recovers a rotation + scale + shift and inverts it', () {
      const Similarity2D truth = Similarity2D(1.2, 0.4, 30, -12);
      final List<Point<double>> src = <Point<double>>[
        const Point<double>(10, 20),
        const Point<double>(60, 25),
        const Point<double>(35, 50),
        const Point<double>(15, 80),
        const Point<double>(58, 78),
      ];
      final Similarity2D fit = Similarity2D.fit(src, src.map(truth.apply).toList());
      expect(fit.a, closeTo(1.2, 1e-9));
      expect(fit.b, closeTo(0.4, 1e-9));
      final Point<double> p = const Point<double>(7, 9);
      final Point<double> back = fit.inverse().apply(fit.apply(p));
      expect(back.x, closeTo(7, 1e-9));
      expect(back.y, closeTo(9, 1e-9));
    });

    test('FacePoints.ordered puts the image-left eye / mouth corner first', () {
      final FacePoints f = FacePoints.ordered(
        eyeA: const Point<double>(80, 50),
        eyeB: const Point<double>(40, 52),
        nose: const Point<double>(60, 70),
        mouthA: const Point<double>(75, 90),
        mouthB: const Point<double>(45, 90),
      );
      expect(f.leftEye.x, 40);
      expect(f.leftMouth.x, 45);
    });
  });

  test('alignedRgb puts the face points where the template expects them', () {
    // A 200×200 frame: grey, with a white dot at each of the five face
    // points of a face that is shifted, scaled ~1.5× and tilted.
    const int w = 200, h = 200;
    final Uint8List bytes = Uint8List(w * 4 * h)..fillRange(0, w * 4 * h, 60);
    const Similarity2D place = Similarity2D(1.5, 0.3, 30, 10);
    final List<Point<double>> facePts = FaceAlignment.template
        .map(place.apply)
        .toList();
    for (final Point<double> p in facePts) {
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          final int i = ((p.y.round() + dy) * w + p.x.round() + dx) * 4;
          bytes.fillRange(i, i + 3, 255);
        }
      }
    }
    final FramePixels frame = FramePixels(
      bytes: bytes,
      width: w,
      height: h,
      bytesPerRow: w * 4,
      format: FramePixelFormat.bgra8888,
    );
    final Float32List rgb = FaceAlignment.alignedRgb(
      frame,
      FacePoints(
        leftEye: facePts[0],
        rightEye: facePts[1],
        nose: facePts[2],
        leftMouth: facePts[3],
        rightMouth: facePts[4],
      ),
    );
    expect(rgb.length, 112 * 112 * 3);
    for (final Point<double> t in FaceAlignment.template) {
      final int i = (t.y.round() * 112 + t.x.round()) * 3;
      expect(rgb[i], greaterThan(200), reason: 'dot at template $t');
    }
    // Between the eyes there is no dot.
    expect(rgb[(52 * 112 + 56) * 3], lessThan(100));
  });

  group('FaceIdentity', () {
    test('needs the template faces before it can score', () {
      final FaceIdentity face = FaceIdentity();
      expect(face.score(axis), isNull);
      face.enroll(axis);
      face.enroll(axis);
      expect(face.hasTemplate, isFalse);
      face.enroll(atCosine(0.95));
      expect(face.hasTemplate, isTrue);
      expect(face.score(axis)!, greaterThan(0.95));
    });

    test('each check decides on its own', () {
      final FaceIdentity face = FaceIdentity();
      expect(face.verdictFor(0.72), FaceVerdict.user);
      expect(face.verdictFor(face.userCosine), FaceVerdict.user);
      expect(face.verdictFor(0.43), FaceVerdict.other);
      expect(face.verdictFor(0.165), FaceVerdict.other);
    });

    test('only a score below the other level is clearly someone else', () {
      final FaceIdentity face = FaceIdentity();
      expect(face.isClearlyOther(0.27), isTrue);
      expect(face.isClearlyOther(face.otherCosine), isFalse);
      // Below the user level, but also seen for the user off-angle.
      expect(face.isClearlyOther(0.49), isFalse);
    });

    test('the template is never a blend: a different face is refused', () {
      final FaceIdentity face = FaceIdentity();
      expect(face.enroll(axis), isTrue);
      expect(face.enroll(atCosine(0.1)), isFalse);
      expect(face.enrolledFaces, 1);
      expect(face.enroll(atCosine(0.9)), isTrue);
      expect(face.enroll(atCosine(0.9)), isTrue);
      expect(face.hasTemplate, isTrue);
      expect(face.score(axis)!, greaterThan(0.9));
      face.reset();
      expect(face.hasTemplate, isFalse);
      expect(face.enrolledFaces, 0);
    });

    test('the face checked is the one on the pose, not the biggest', () {
      const FacePoints pose = FacePoints(
        leftEye: Point<double>(90, 90),
        rightEye: Point<double>(110, 90),
        nose: Point<double>(100, 100),
        leftMouth: Point<double>(92, 112),
        rightMouth: Point<double>(108, 112),
      );
      const Rectangle<double> own = Rectangle<double>(80, 70, 40, 50);
      const Rectangle<double> biggerNeighbour = Rectangle<double>(125, 20, 90, 110);
      expect(pose.indexOfOwnFace(const <Rectangle<double>>[biggerNeighbour, own]), 1);
      expect(pose.indexOfOwnFace(const <Rectangle<double>>[biggerNeighbour]), isNull);
      expect(pose.indexOfOwnFace(const <Rectangle<double>>[]), isNull);
    });
  });

  group('UserMatchStats', () {
    test('starts wide from the photo frames, then follows the boxing frames',
        () {
      final UserMatchStats stats = UserMatchStats();
      stats.bootstrap(List<double>.filled(20, 0.95));
      // Still photo frames say little about boxing: wide floor.
      expect(stats.accept, closeTo(0.95 - 2 * stats.bootstrapMinSpread, 1e-9));
      expect(stats.reject, closeTo(0.95 - 4 * stats.bootstrapMinSpread, 1e-9));
      // A user whose look varies a lot while punching.
      final Random rng = Random(1);
      for (int i = 0; i < stats.minSamples; i++) {
        stats.add(0.85 + (rng.nextDouble() - 0.5) * 0.3);
      }
      expect(stats.reject, lessThan(0.7));
      expect(stats.accept, greaterThan(stats.reject));
    });

    test('a steady look gives tight levels, never tighter than the floor', () {
      final UserMatchStats stats = UserMatchStats();
      for (int i = 0; i < 40; i++) {
        stats.add(0.97);
      }
      expect(stats.accept, closeTo(0.97 - 2 * stats.minSpread, 1e-9));
      expect(stats.reject, closeTo(0.97 - 4 * stats.minSpread, 1e-9));
    });

    test('a few outliers do not move the levels (median / MAD)', () {
      final UserMatchStats a = UserMatchStats(), b = UserMatchStats();
      for (int i = 0; i < 60; i++) {
        a.add(0.9 + (i % 5) * 0.01);
        b.add(i % 20 == 0 ? 0.2 : 0.9 + (i % 5) * 0.01);
      }
      expect(b.reject, closeTo(a.reject, 0.02));
    });
  });
}
