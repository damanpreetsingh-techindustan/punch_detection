import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math';
import 'skeleton/skeleton_style.dart';

/// Internal Low-Pass Filter & EMA Smoother to eliminate camera landmark jitter.
class _LandmarkSmoother {
  static final Map<PoseLandmarkType, Offset> _smoothed = {};

  static Offset? smooth(
    PoseLandmarkType type,
    Offset? raw, {
    double alpha = 0.30,
    double deadZone = 3.5,
  }) {
    if (raw == null) {
      _smoothed.remove(type);
      return null;
    }

    final prev = _smoothed[type];
    if (prev == null) {
      _smoothed[type] = raw;
      return raw;
    }

    final dx = (raw.dx - prev.dx).abs();
    final dy = (raw.dy - prev.dy).abs();

    if (dx < deadZone && dy < deadZone) {
      return prev;
    }

    final newX = prev.dx * (1.0 - alpha) + raw.dx * alpha;
    final newY = prev.dy * (1.0 - alpha) + raw.dy * alpha;

    final result = Offset(newX, newY);
    _smoothed[type] = result;
    return result;
  }

  static void reset() {
    _smoothed.clear();
  }
}

class PoseSkeletonPainter extends CustomPainter {
  final Pose? pose;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  /// Colours of the overlay (active = valid user, inactive = grey).
  final SkeletonStyle style;

  PoseSkeletonPainter({
    required this.pose,
    this.absoluteImageSize = Size.zero,
    this.rotation = InputImageRotation.rotation90deg,
    this.isFrontCamera = true,
    this.style = SkeletonStyle.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null ||
        absoluteImageSize.width <= 0 ||
        absoluteImageSize.height <= 0) {
      _LandmarkSmoother.reset();
      return;
    }

    // Body skeleton lines (cyan when active, grey when inactive)
    final skeletonLinePaint = Paint()
      ..color = style.lineColor
      ..strokeWidth = style.lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Round joint endpoints (red when active, grey when inactive)
    final jointPaint = Paint()
      ..color = style.jointFillColor
      ..style = PaintingStyle.fill;

    // Outer stroke border for endpoints
    final jointBorderPaint = Paint()
      ..color = style.jointBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Normalizing ML Kit landmark space to portrait/landscape canvas bounds.
    final bool isPortraitCanvas = size.height >= size.width;
    final double imgW = isPortraitCanvas
        ? min(absoluteImageSize.width, absoluteImageSize.height)
        : max(absoluteImageSize.width, absoluteImageSize.height);
    final double imgH = isPortraitCanvas
        ? max(absoluteImageSize.width, absoluteImageSize.height)
        : min(absoluteImageSize.width, absoluteImageSize.height);

    Offset? getLandmarkOffset(
      PoseLandmarkType type, {
      double minLikelihood = 0.35,
    }) {
      final lm = pose!.landmarks[type];
      // Do NOT draw dots by ML Kit estimation if likelihood is low!
      if (lm == null || lm.likelihood < minLikelihood) {
        return _LandmarkSmoother.smooth(type, null);
      }

      double x = (lm.x / imgW) * size.width;
      double y = (lm.y / imgH) * size.height;

      // Android front camera feed requires horizontal flipping to match mirrored CameraPreview.
      // On iOS, ML Kit landmark coordinates already correspond directly to mirrored preview coordinates.
      if (isFrontCamera && defaultTargetPlatform == TargetPlatform.android) {
        x = size.width - x;
      }

      // Shift shoulder landmarks slightly upwards to align perfectly with top side of shoulders
      if (type == PoseLandmarkType.leftShoulder ||
          type == PoseLandmarkType.rightShoulder) {
        final lLM = pose!.landmarks[PoseLandmarkType.leftShoulder];
        final rLM = pose!.landmarks[PoseLandmarkType.rightShoulder];
        if (lLM != null && rLM != null) {
          final double rawWidth = sqrt(
            pow((lLM.x - rLM.x) / imgW * size.width, 2) +
                pow((lLM.y - rLM.y) / imgH * size.height, 2),
          );
          y -= (rawWidth * 0.10);
        }
      }

      final rawOffset = Offset(x, y);
      return _LandmarkSmoother.smooth(
        type,
        rawOffset,
        alpha: 0.30,
        deadZone: 3.5,
      );
    }

    final leftShoulder = getLandmarkOffset(
      PoseLandmarkType.leftShoulder,
      minLikelihood: 0.35,
    );
    final rightShoulder = getLandmarkOffset(
      PoseLandmarkType.rightShoulder,
      minLikelihood: 0.35,
    );

    // Guard: Only render skeleton overlay when shoulders are visually present
    final lShoulderLM = pose!.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulderLM = pose!.landmarks[PoseLandmarkType.rightShoulder];
    if (lShoulderLM == null ||
        rShoulderLM == null ||
        lShoulderLM.likelihood < 0.35 ||
        rShoulderLM.likelihood < 0.35) {
      return;
    }

    // Helper to draw a round joint with its outline
    void drawJoint(Offset point, double radius) {
      canvas.drawCircle(point, radius, jointPaint);
      canvas.drawCircle(point, radius, jointBorderPaint);
    }

    // 1. 🔵 Draw Body Shoulder Line (Shoulder -> Shoulder)
    if (leftShoulder != null && rightShoulder != null) {
      canvas.drawLine(leftShoulder, rightShoulder, skeletonLinePaint);
    }

    // 2. 🔵 Draw Arm Skeleton Lines with Advanced Kinematic Elbow Inferrer
    final detectedLeftElbow = getLandmarkOffset(
      PoseLandmarkType.leftElbow,
      minLikelihood: 0.35,
    );
    final detectedRightElbow = getLandmarkOffset(
      PoseLandmarkType.rightElbow,
      minLikelihood: 0.35,
    );
    final leftWrist = getLandmarkOffset(
      PoseLandmarkType.leftWrist,
      minLikelihood: 0.35,
    );
    final rightWrist = getLandmarkOffset(
      PoseLandmarkType.rightWrist,
      minLikelihood: 0.35,
    );

    // Kinematic Anatomical Elbow Inferrer:
    // If shoulder is visible, but elbow is missing/occluded:
    //  Case A: Wrist is visible -> Elbow projected at midpoint between Shoulder & Wrist.
    //  Case B: Wrist is NOT visible -> Project Elbow anatomically downward along torso vector!
    Offset? inferElbow({
      required Offset? shoulder,
      required Offset? otherShoulder,
      required Offset? detectedElbow,
      required Offset? wrist,
      required bool isLeft,
    }) {
      if (detectedElbow != null) return detectedElbow;
      if (shoulder == null || otherShoulder == null) return null;

      // Case A: Wrist is visible -> Midpoint with anatomical outward bend
      if (wrist != null) {
        final midX = (shoulder.dx + wrist.dx) / 2.0;
        final midY = (shoulder.dy + wrist.dy) / 2.0;
        final outwardOffset = isLeft ? 10.0 : -10.0;
        return Offset(midX + outwardOffset, midY);
      }

      // Case B: Wrist is NOT visible -> Project anatomically downward from shoulder
      final double shoulderDist = sqrt(
        pow(shoulder.dx - otherShoulder.dx, 2) +
            pow(shoulder.dy - otherShoulder.dy, 2),
      );

      if (shoulderDist < 1.0) return null;

      // Upper arm length is ~60% of shoulder-to-shoulder width
      final double armLen = shoulderDist * 0.60;

      // Calculate angle from shoulder to other shoulder
      final double shoulderAngle = atan2(
        otherShoulder.dy - shoulder.dy,
        otherShoulder.dx - shoulder.dx,
      );

      // Downward angle perpendicular to shoulder line
      final double downAngle = isLeft
          ? (shoulderAngle - pi / 2)
          : (shoulderAngle + pi / 2);

      double projDx = cos(downAngle) * armLen;
      double projDy = sin(downAngle) * armLen;

      // HARD SAFETY GUARD: In screen space +Y is downward toward torso.
      // Forces elbow projection to ALWAYS point downward (projDy > 0), never topside!
      if (projDy < 0) {
        projDy = -projDy;
      }

      return Offset(shoulder.dx + projDx, shoulder.dy + projDy);
    }

    final leftElbow = inferElbow(
      shoulder: leftShoulder,
      otherShoulder: rightShoulder,
      detectedElbow: detectedLeftElbow,
      wrist: leftWrist,
      isLeft: true,
    );

    final rightElbow = inferElbow(
      shoulder: rightShoulder,
      otherShoulder: leftShoulder,
      detectedElbow: detectedRightElbow,
      wrist: rightWrist,
      isLeft: false,
    );

    // Left Arm (Shoulder -> Elbow -> Wrist)
    if (leftShoulder != null && leftElbow != null) {
      canvas.drawLine(leftShoulder, leftElbow, skeletonLinePaint);
    }
    if (leftElbow != null && leftWrist != null) {
      canvas.drawLine(leftElbow, leftWrist, skeletonLinePaint);
    }

    // Right Arm (Shoulder -> Elbow -> Wrist)
    if (rightShoulder != null && rightElbow != null) {
      canvas.drawLine(rightShoulder, rightElbow, skeletonLinePaint);
    }
    if (rightElbow != null && rightWrist != null) {
      canvas.drawLine(rightElbow, rightWrist, skeletonLinePaint);
    }

    // 3. Draw round endpoints for body joints (Shoulders, Elbows, Wrists)
    if (leftShoulder != null) drawJoint(leftShoulder, 8.5);
    if (rightShoulder != null) drawJoint(rightShoulder, 8.5);
    if (leftElbow != null) drawJoint(leftElbow, 7.5);
    if (rightElbow != null) drawJoint(rightElbow, 7.5);
    if (leftWrist != null) drawJoint(leftWrist, 8.0);
    if (rightWrist != null) drawJoint(rightWrist, 8.0);

    // 4. 👤 FACIAL SKELETON: Hidden from visual UI overlay per user preference.
    // (Note: Facial landmark validation logic in PoseValidityGate & TemporalPunchDetector remains 100% active).
  }

  @override
  bool shouldRepaint(covariant PoseSkeletonPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.isFrontCamera != isFrontCamera ||
        oldDelegate.style != style;
  }
}
