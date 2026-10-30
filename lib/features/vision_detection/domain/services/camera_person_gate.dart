import '../../../../core/utils/constants.dart';
import 'camera_distance_gate.dart';

/// Outcome of the real-person rule for one pose.
class CameraPersonResult {
  final bool isPerson;

  /// `ok`, `no_face`, `no_shoulder`, `no_face_no_shoulder`,
  /// `face_below_shoulder`, or `old_rule` when the gate is switched off.
  final String reason;

  /// Highest confidence among the face points (0 when none).
  final double bestFaceConfidence;

  /// Highest confidence of the two shoulders (0 when none).
  final double bestShoulderConfidence;

  const CameraPersonResult({
    required this.isPerson,
    required this.reason,
    required this.bestFaceConfidence,
    required this.bestShoulderConfidence,
  });

  /// Short text for logs, for example `no_shoulder (face 0.81, shoulder 0.32)`.
  String get description =>
      '$reason (face ${bestFaceConfidence.toStringAsFixed(2)}, '
      'shoulder ${bestShoulderConfidence.toStringAsFixed(2)})';
}

/// Rule: a pose is a real person only when at least one face point AND at least
/// one shoulder are detected with enough confidence, and (optionally) the face
/// is above the shoulder. Face + one shoulder is enough.
///
/// Objects (a bottle, a bag, a chair) can produce a weak pose with a few
/// low-confidence points; they rarely reach the confidence on both.
///
/// Pure and constant-driven: tune in `AppConstants` (`cameraMinFaceConfidence`,
/// `cameraMinShoulderConfidence`).
class CameraPersonGate {
  final bool enabled;
  final double minFaceConfidence;
  final double minShoulderConfidence;
  final bool requireFaceAboveShoulder;

  /// Confidence used by the old rule when the gate is switched off.
  static const double legacyMinConfidence = 0.20;

  const CameraPersonGate({
    this.enabled = true,
    required this.minFaceConfidence,
    required this.minShoulderConfidence,
    this.requireFaceAboveShoulder = true,
  });

  /// Gate configured from the common constants file.
  factory CameraPersonGate.fromConstants() => const CameraPersonGate(
    enabled: AppConstants.cameraPersonGateEnabled,
    minFaceConfidence: AppConstants.cameraMinFaceConfidence,
    minShoulderConfidence: AppConstants.cameraMinShoulderConfidence,
    requireFaceAboveShoulder: AppConstants.cameraRequireFaceAboveShoulder,
  );

  /// [facePoints]: nose, eyes, inner eyes, ears, mouth corners (null = missing).
  /// Image y grows downward, so "above" means a smaller y.
  CameraPersonResult evaluate({
    required List<DistanceLandmark?> facePoints,
    DistanceLandmark? leftShoulder,
    DistanceLandmark? rightShoulder,
  }) {
    final DistanceLandmark? bestFace = _best(facePoints);
    final DistanceLandmark? bestShoulder = _best(<DistanceLandmark?>[
      leftShoulder,
      rightShoulder,
    ]);
    final double faceConf = bestFace?.likelihood ?? 0.0;
    final double shoulderConf = bestShoulder?.likelihood ?? 0.0;

    if (!enabled) {
      final bool legacy =
          faceConf >= legacyMinConfidence ||
          shoulderConf >= legacyMinConfidence;
      return CameraPersonResult(
        isPerson: legacy,
        reason: legacy ? 'old_rule' : 'no_face_no_shoulder',
        bestFaceConfidence: faceConf,
        bestShoulderConfidence: shoulderConf,
      );
    }

    final bool hasFace = faceConf >= minFaceConfidence;
    final bool hasShoulder = shoulderConf >= minShoulderConfidence;
    if (!hasFace || !hasShoulder) {
      return CameraPersonResult(
        isPerson: false,
        reason: !hasFace && !hasShoulder
            ? 'no_face_no_shoulder'
            : (!hasFace ? 'no_face' : 'no_shoulder'),
        bestFaceConfidence: faceConf,
        bestShoulderConfidence: shoulderConf,
      );
    }

    if (requireFaceAboveShoulder && bestFace!.y >= bestShoulder!.y) {
      return CameraPersonResult(
        isPerson: false,
        reason: 'face_below_shoulder',
        bestFaceConfidence: faceConf,
        bestShoulderConfidence: shoulderConf,
      );
    }

    return CameraPersonResult(
      isPerson: true,
      reason: 'ok',
      bestFaceConfidence: faceConf,
      bestShoulderConfidence: shoulderConf,
    );
  }

  static DistanceLandmark? _best(List<DistanceLandmark?> points) {
    DistanceLandmark? best;
    for (final DistanceLandmark? point in points) {
      if (point == null) continue;
      if (best == null || point.likelihood > best.likelihood) best = point;
    }
    return best;
  }
}
