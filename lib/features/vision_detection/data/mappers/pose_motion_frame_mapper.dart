import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/constants.dart';
import '../../../fusion/domain/body_motion_gate/models/body_motion_frame.dart';

/// Converts an ML Kit [Pose] into a [BodyMotionFrame] for the body-motion gate.
///
/// Kept in the data layer so the gate itself never depends on ML Kit
/// (Dependency Inversion: the domain owns the frame type, this adapter fills it).
///
/// Only points with likelihood >= [minLikelihood] are kept: weak points jump
/// around between frames and would look like movement.
class PoseMotionFrameMapper {
  final double minLikelihood;

  /// Face-based body width: shoulder span ≈ 2.8 × eye span (same estimate the
  /// temporal punch detector uses when shoulders are missing).
  static const double eyeSpanToBodyWidth = 2.8;

  const PoseMotionFrameMapper({
    this.minLikelihood = AppConstants.bodyMotionMinLikelihood,
  });

  BodyMotionFrame map(Pose pose, {required int tMs}) {
    PoseLandmark? confident(PoseLandmarkType type) {
      final PoseLandmark? lm = pose.landmarks[type];
      return lm != null && lm.likelihood >= minLikelihood ? lm : null;
    }

    Point<double> at(PoseLandmark lm) => Point<double>(lm.x, lm.y);

    final PoseLandmark? nose = confident(PoseLandmarkType.nose);
    final PoseLandmark? lEye = confident(PoseLandmarkType.leftEye);
    final PoseLandmark? rEye = confident(PoseLandmarkType.rightEye);
    final PoseLandmark? lEar = confident(PoseLandmarkType.leftEar);
    final PoseLandmark? rEar = confident(PoseLandmarkType.rightEar);
    final PoseLandmark? lShoulder = confident(PoseLandmarkType.leftShoulder);
    final PoseLandmark? rShoulder = confident(PoseLandmarkType.rightShoulder);

    // Face: nose first, else the middle of both eyes, else one eye / ear.
    final Point<double>? face = nose != null
        ? at(nose)
        : (lEye != null && rEye != null)
        ? Point<double>((lEye.x + rEye.x) / 2, (lEye.y + rEye.y) / 2)
        : (lEye ?? rEye ?? lEar ?? rEar) == null
        ? null
        : at((lEye ?? rEye ?? lEar ?? rEar)!);

    final Map<BodyMotionPoint, Point<double>> points =
        <BodyMotionPoint, Point<double>>{
          BodyMotionPoint.face: ?face,
          if (lShoulder != null) BodyMotionPoint.leftShoulder: at(lShoulder),
          if (rShoulder != null) BodyMotionPoint.rightShoulder: at(rShoulder),
        };
    // Arms: a bonus when visible (body shots, extended punches), never needed.
    const Map<PoseLandmarkType, BodyMotionPoint> armPoints =
        <PoseLandmarkType, BodyMotionPoint>{
          PoseLandmarkType.leftElbow: BodyMotionPoint.leftElbow,
          PoseLandmarkType.rightElbow: BodyMotionPoint.rightElbow,
          PoseLandmarkType.leftWrist: BodyMotionPoint.leftWrist,
          PoseLandmarkType.rightWrist: BodyMotionPoint.rightWrist,
        };
    armPoints.forEach((PoseLandmarkType type, BodyMotionPoint point) {
      final PoseLandmark? lm = confident(type);
      if (lm != null) points[point] = at(lm);
    });

    // Body width: the larger of shoulder span and the face-based estimate.
    // Taking the larger one keeps the score honest when the body turns side-on
    // (shoulders look narrow, which would make small movements look big).
    final double? shoulderSpan = (lShoulder != null && rShoulder != null)
        ? at(lShoulder).distanceTo(at(rShoulder))
        : null;
    final double? faceWidth = (lEye != null && rEye != null)
        ? at(lEye).distanceTo(at(rEye)) * eyeSpanToBodyWidth
        : null;
    final List<double> widths = <double>[
      ?shoulderSpan,
      ?faceWidth,
    ].where((double w) => w > 1.0).toList();

    return BodyMotionFrame(
      tMs: tMs,
      points: points,
      bodyScale: widths.isEmpty ? null : widths.reduce(max),
    );
  }
}
