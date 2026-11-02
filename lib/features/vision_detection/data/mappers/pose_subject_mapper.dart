import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/constants.dart';
import '../../domain/subject_lock/appearance_signature.dart';
import '../../domain/subject_lock/face_alignment.dart';
import '../../domain/subject_lock/subject_lock.dart';
import 'pose_motion_frame_mapper.dart';

/// Converts an ML Kit [Pose] (plus the camera frame it came from) into a
/// [SubjectObservation] for the subject lock.
///
/// Kept in the data layer so the lock itself never depends on ML Kit
/// (same split as [PoseMotionFrameMapper]).
///
/// Where the colours are read (all relative to the person's own landmarks,
/// so the same spots are read near or far from the camera):
///  - clothing: a 9 × 4 grid in the band just below the shoulder line, plus
///    both sleeves (shoulder → elbow), which stay visible in guard when the
///    forearms hide the chest;
///  - head: a 4 × 3 grid above the eyes: hair / headgear / forehead.
/// Samples close to an elbow → wrist line (and the glove past the wrist) are
/// skipped, so gloves and forearms never become part of the user's look.
class PoseSubjectMapper {
  /// Points below this confidence are not used for position or look.
  final double minLikelihood;

  /// Arms are avoided even when weakly seen (skipping more is harmless).
  final double armLikelihood;

  const PoseSubjectMapper({
    this.minLikelihood = AppConstants.bodyMotionMinLikelihood,
    this.armLikelihood = 0.3,
  });

  /// The camera frame as the subject lock reads it, or null for a format it
  /// cannot read. [rotation] is the rotation given to ML Kit for this frame.
  static FramePixels? framePixelsOf(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    final FramePixelFormat? format = switch (image.format.group) {
      ImageFormatGroup.nv21 => FramePixelFormat.nv21,
      ImageFormatGroup.bgra8888 => FramePixelFormat.bgra8888,
      _ => null,
    };
    if (format == null || image.planes.isEmpty) return null;
    final Plane plane = image.planes.first;
    return FramePixels(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      format: format,
      // ML Kit turns byte images by the rotation on Android only. On iOS
      // google_mlkit_commons ignores it, so landmarks are buffer pixels.
      rotationDegrees: defaultTargetPlatform == TargetPlatform.iOS
          ? 0
          : rotation.rawValue,
    );
  }

  /// Null when the pose has no usable anchor (no confident shoulder or face).
  /// Without [pixels] (tests, unknown format) only movement is checked.
  SubjectObservation? map(
    Pose pose, {
    required int tMs,
    FramePixels? pixels,
    bool enrollEligible = true,
  }) {
    final _PoseGeometry? g = _PoseGeometry.of(pose, minLikelihood);
    if (g == null) return null;

    AppearanceHistogram? torso;
    AppearanceHistogram? head;
    if (pixels != null) {
      final SubjectSamplePoints points = _samplePoints(pose, g);
      if (points.torso.isNotEmpty) {
        torso = AppearanceHistogram();
        pixels.sampleInto(torso, points.torso);
      }
      if (points.head.isNotEmpty) {
        head = AppearanceHistogram();
        pixels.sampleInto(head, points.head);
      }
    }

    return SubjectObservation(
      tMs: tMs,
      anchor: g.anchor,
      anchorIsShoulders: g.hasShoulders,
      bodyScale: g.bodyScale,
      torso: torso != null && torso.sampleCount > 0 ? torso : null,
      head: head != null && head.sampleCount > 0 ? head : null,
      box: _box(pose, g.bodyScale, pixels),
      enrollEligible: enrollEligible,
    );
  }

  /// Where [map] reads the colours for [pose] (upright pixels, arms already
  /// skipped). For debug overlays and the video test tool.
  SubjectSamplePoints samplePoints(Pose pose) {
    final _PoseGeometry? g = _PoseGeometry.of(pose, minLikelihood);
    return g == null ? const SubjectSamplePoints() : _samplePoints(pose, g);
  }

  /// The pose's face when it is clear enough for a face check, else null:
  /// eyes, nose and mouth corners confident and inside the frame; the eyes
  /// at least half as far apart as in the face model's template (so the
  /// face is never enlarged more than 2×); roughly frontal (nose at most
  /// [AppConstants.subjectFaceMaxTurn] eye distances beside the middle of
  /// the eyes); and no hand / glove point over it.
  FacePoints? checkableFace(Pose pose, FramePixels pixels) {
    Point<double>? at(PoseLandmarkType type) {
      final PoseLandmark? lm = pose.landmarks[type];
      if (lm == null || lm.likelihood < minLikelihood) return null;
      if (lm.x < 0 || lm.y < 0) return null;
      if (lm.x >= pixels.uprightWidth || lm.y >= pixels.uprightHeight) {
        return null;
      }
      return Point<double>(lm.x, lm.y);
    }

    final Point<double>? eyeA = at(PoseLandmarkType.leftEye);
    final Point<double>? eyeB = at(PoseLandmarkType.rightEye);
    final Point<double>? nose = at(PoseLandmarkType.nose);
    final Point<double>? mouthA = at(PoseLandmarkType.leftMouth);
    final Point<double>? mouthB = at(PoseLandmarkType.rightMouth);
    if (eyeA == null ||
        eyeB == null ||
        nose == null ||
        mouthA == null ||
        mouthB == null) {
      return null;
    }
    final FacePoints face = FacePoints.ordered(
      eyeA: eyeA,
      eyeB: eyeB,
      nose: nose,
      mouthA: mouthA,
      mouthB: mouthB,
    );
    final double eyes = face.eyeDistance;
    if (eyes < FaceAlignment.templateEyeDistance / 2) return null;
    final double eyesMidX = (face.leftEye.x + face.rightEye.x) / 2;
    if ((nose.x - eyesMidX).abs() / eyes > AppConstants.subjectFaceMaxTurn) {
      return null;
    }
    final Rectangle<double> faceBox = _faceBox(face);
    for (final PoseLandmarkType hand in const <PoseLandmarkType>[
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftPinky,
      PoseLandmarkType.rightPinky,
      PoseLandmarkType.leftIndex,
      PoseLandmarkType.rightIndex,
      PoseLandmarkType.leftThumb,
      PoseLandmarkType.rightThumb,
    ]) {
      final PoseLandmark? lm = pose.landmarks[hand];
      if (lm != null &&
          lm.likelihood >= armLikelihood &&
          faceBox.containsPoint(Point<double>(lm.x, lm.y))) {
        return null;
      }
    }
    return face;
  }

  /// The head around [face]: about two eye distances wide, from above the
  /// eyes to below the mouth.
  static Rectangle<double> _faceBox(FacePoints face) {
    final double eyes = face.eyeDistance;
    final Point<double> mid = Point<double>(
      (face.leftEye.x + face.rightEye.x) / 2,
      (face.leftEye.y + face.rightEye.y) / 2,
    );
    final double mouthY = (face.leftMouth.y + face.rightMouth.y) / 2;
    return Rectangle<double>.fromPoints(
      Point<double>(mid.x - 1.1 * eyes, mid.y - 1.0 * eyes),
      Point<double>(mid.x + 1.1 * eyes, mouthY + 0.6 * eyes),
    );
  }

  SubjectSamplePoints _samplePoints(Pose pose, _PoseGeometry g) {
    final List<_ArmZone> arms = _armZones(pose, g.bodyScale);
    bool clear(Point<double> p) => arms.every((_ArmZone a) => !a.covers(p));
    final List<Point<double>> torso = <Point<double>>[];
    final List<Point<double>> head = <Point<double>>[];

    final double? shoulderSpan = g.shoulderSpan;
    if (shoulderSpan != null && shoulderSpan > 1.0) {
      final Point<double> l = g.lShoulder!;
      final Point<double> along = g.rShoulder! - l;
      // Perpendicular to the shoulder line, pointing down the body.
      Point<double> down = Point<double>(-along.y, along.x) * (1 / shoulderSpan);
      if (down.y < 0) down = down * -1;
      for (int i = 0; i < 9; i++) {
        final Point<double> onLine = l + along * (0.15 + 0.7 * i / 8);
        for (int j = 0; j < 4; j++) {
          final Point<double> p =
              onLine + down * ((0.08 + 0.09 * j) * shoulderSpan);
          if (clear(p)) torso.add(p);
        }
      }
    }

    // Sleeves: in guard the forearms hide the chest, but the upper arms
    // (shoulder → elbow) stay visible. Without a confident elbow, a small
    // patch just below the shoulder.
    void addSleeve(Point<double>? shoulder, PoseLandmarkType elbowType) {
      if (shoulder == null) return;
      final PoseLandmark? e = pose.landmarks[elbowType];
      final double bs = g.bodyScale;
      if (e != null && e.likelihood >= minLikelihood) {
        final Point<double> along = Point<double>(e.x, e.y) - shoulder;
        final double length = sqrt(along.x * along.x + along.y * along.y);
        if (length > 1.0) {
          final Point<double> side = Point<double>(-along.y, along.x) *
              (1 / length);
          for (final double f in const <double>[0.2, 0.4, 0.6]) {
            for (final double o in const <double>[-0.07, 0, 0.07]) {
              final Point<double> p = shoulder + along * f + side * (o * bs);
              if (clear(p)) torso.add(p);
            }
          }
          return;
        }
      }
      for (final double dy in const <double>[0.08, 0.16]) {
        for (final double dx in const <double>[-0.06, 0, 0.06]) {
          final Point<double> p = shoulder + Point<double>(dx * bs, dy * bs);
          if (clear(p)) torso.add(p);
        }
      }
    }

    addSleeve(g.lShoulder, PoseLandmarkType.leftElbow);
    addSleeve(g.rShoulder, PoseLandmarkType.rightElbow);

    final double? eyeSpan = g.eyeSpan;
    if (eyeSpan != null && eyeSpan > 1.0) {
      final Point<double> le = g.lEye!;
      final Point<double> re = g.rEye!;
      final Point<double> mid = Point<double>(
        (le.x + re.x) / 2,
        (le.y + re.y) / 2,
      );
      final Point<double> along = (re - le) * (1 / eyeSpan);
      // Perpendicular to the eye line, pointing up the head.
      Point<double> up = Point<double>(-along.y, along.x);
      if (up.y > 0) up = up * -1;
      for (int i = 0; i < 4; i++) {
        final Point<double> onLine = mid + along * ((-0.6 + 0.4 * i) * eyeSpan);
        for (int j = 0; j < 3; j++) {
          final Point<double> p = onLine + up * ((1.3 + 0.4 * j) * eyeSpan);
          if (clear(p)) head.add(p);
        }
      }
    }
    return SubjectSamplePoints(torso: torso, head: head);
  }

  List<_ArmZone> _armZones(Pose pose, double bodyScale) {
    final List<_ArmZone> zones = <_ArmZone>[];
    void addArm(PoseLandmarkType elbowType, PoseLandmarkType wristType) {
      final PoseLandmark? elbow = pose.landmarks[elbowType];
      final PoseLandmark? wrist = pose.landmarks[wristType];
      final bool hasElbow = elbow != null && elbow.likelihood >= armLikelihood;
      final bool hasWrist = wrist != null && wrist.likelihood >= armLikelihood;
      if (hasWrist) {
        final Point<double> w = Point<double>(wrist.x, wrist.y);
        if (hasElbow) {
          final Point<double> e = Point<double>(elbow.x, elbow.y);
          final double length = e.distanceTo(w);
          // The glove reaches past the wrist landmark.
          final Point<double> gloveEnd = length > 1.0
              ? w + (w - e) * (0.3 * bodyScale / length)
              : w;
          zones.add(_ArmZone(e, gloveEnd, 0.25 * bodyScale));
        }
        zones.add(_ArmZone(w, w, 0.35 * bodyScale));
      } else if (hasElbow) {
        final Point<double> e = Point<double>(elbow.x, elbow.y);
        zones.add(_ArmZone(e, e, 0.25 * bodyScale));
      }
    }

    addArm(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    addArm(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    return zones;
  }

  /// Box around the confident landmarks, widened by about a third of a body
  /// width and stretched to the bottom of the image (the body continues
  /// below the last visible point).
  Rectangle<double>? _box(Pose pose, double bodyScale, FramePixels? pixels) {
    double? minX, minY, maxX, maxY;
    for (final PoseLandmark lm in pose.landmarks.values) {
      if (lm.likelihood < minLikelihood) continue;
      minX = min(minX ?? lm.x, lm.x);
      minY = min(minY ?? lm.y, lm.y);
      maxX = max(maxX ?? lm.x, lm.x);
      maxY = max(maxY ?? lm.y, lm.y);
    }
    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }
    final double margin = 0.35 * bodyScale;
    final double left = minX - margin;
    final double top = minY - margin * 2; // top of the head is above the eyes
    final double bottom = pixels != null
        ? pixels.uprightHeight.toDouble()
        : maxY + 2 * bodyScale;
    return Rectangle<double>(
      left,
      top,
      (maxX + margin) - left,
      bottom - top,
    );
  }
}

/// Where the colours of one pose are read (upright image pixels).
class SubjectSamplePoints {
  final List<Point<double>> torso;
  final List<Point<double>> head;

  const SubjectSamplePoints({
    this.torso = const <Point<double>>[],
    this.head = const <Point<double>>[],
  });
}

/// Anchor, body width and the confident shoulder / eye points of one pose.
class _PoseGeometry {
  final Point<double> anchor;
  final bool hasShoulders;
  final Point<double>? lShoulder;
  final Point<double>? rShoulder;
  final Point<double>? lEye;
  final Point<double>? rEye;
  final double bodyScale;

  const _PoseGeometry({
    required this.anchor,
    required this.hasShoulders,
    required this.bodyScale,
    this.lShoulder,
    this.rShoulder,
    this.lEye,
    this.rEye,
  });

  double? get shoulderSpan =>
      hasShoulders ? lShoulder!.distanceTo(rShoulder!) : null;
  double? get eyeSpan =>
      lEye != null && rEye != null ? lEye!.distanceTo(rEye!) : null;

  /// Null when the pose has no confident shoulder or face point.
  static _PoseGeometry? of(Pose pose, double minLikelihood) {
    Point<double>? confident(PoseLandmarkType type) {
      final PoseLandmark? lm = pose.landmarks[type];
      return lm != null && lm.likelihood >= minLikelihood
          ? Point<double>(lm.x, lm.y)
          : null;
    }

    final Point<double>? lShoulder = confident(PoseLandmarkType.leftShoulder);
    final Point<double>? rShoulder = confident(PoseLandmarkType.rightShoulder);
    final Point<double>? lEye = confident(PoseLandmarkType.leftEye);
    final Point<double>? rEye = confident(PoseLandmarkType.rightEye);
    final Point<double>? face =
        confident(PoseLandmarkType.nose) ??
        lEye ??
        rEye ??
        confident(PoseLandmarkType.leftEar) ??
        confident(PoseLandmarkType.rightEar);

    final bool hasShoulders = lShoulder != null && rShoulder != null;
    final Point<double>? anchor = hasShoulders
        ? Point<double>(
            (lShoulder.x + rShoulder.x) / 2,
            (lShoulder.y + rShoulder.y) / 2,
          )
        : face;
    if (anchor == null) return null;

    final List<double> widths = <double>[
      if (hasShoulders) lShoulder.distanceTo(rShoulder),
      if (lEye != null && rEye != null)
        lEye.distanceTo(rEye) * PoseMotionFrameMapper.eyeSpanToBodyWidth,
    ].where((double w) => w > 1.0).toList();
    final Point<double>? oneShoulder = lShoulder ?? rShoulder;
    // Last resort: face-to-shoulder distance is roughly 0.6 body widths.
    final double bodyScale = widths.isNotEmpty
        ? widths.reduce(max)
        : (face != null && oneShoulder != null)
        ? max(face.distanceTo(oneShoulder) * 1.6, 1.0)
        : 1.0;

    return _PoseGeometry(
      anchor: anchor,
      hasShoulders: hasShoulders,
      bodyScale: bodyScale,
      lShoulder: lShoulder,
      rShoulder: rShoulder,
      lEye: lEye,
      rEye: rEye,
    );
  }
}

/// Area around an arm segment (a capsule) where colours are not read.
class _ArmZone {
  final Point<double> a;
  final Point<double> b;
  final double radius;

  const _ArmZone(this.a, this.b, this.radius);

  bool covers(Point<double> p) {
    final Point<double> ab = b - a;
    final double lengthSq = ab.x * ab.x + ab.y * ab.y;
    double t = 0;
    if (lengthSq > 0) {
      t = (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSq).clamp(0, 1);
    }
    final Point<double> closest = a + ab * t;
    return closest.distanceTo(p) <= radius;
  }
}
