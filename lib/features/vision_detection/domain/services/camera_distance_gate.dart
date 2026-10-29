import 'dart:math';
import '../../../../core/utils/constants.dart';

/// A pose landmark reduced to what the distance rule needs.
class DistanceLandmark {
  final double x;
  final double y;
  final double likelihood;

  const DistanceLandmark({
    required this.x,
    required this.y,
    required this.likelihood,
  });
}

/// Outcome of the distance rule for one pose.
class CameraDistanceResult {
  /// True when the person is close enough (or the rule cannot decide / is off).
  final bool withinRange;

  /// Measured body-width ratio to the image diagonal, null when not measurable.
  final double? ratio;

  /// `shoulders`, `eyes`, `unknown` or `disabled`.
  final String source;

  /// The minimum ratio the measurement was compared with, null when not compared.
  final double? minRatio;

  const CameraDistanceResult({
    required this.withinRange,
    required this.ratio,
    required this.source,
    required this.minRatio,
  });

  /// Short text for logs, for example `shoulders 0.052 < 0.090`.
  String get description {
    if (ratio == null) return source;
    final String op = withinRange ? '>=' : '<';
    return '$source ${ratio!.toStringAsFixed(3)} $op ${minRatio!.toStringAsFixed(3)}';
  }
}

/// Rule: a person farther from the camera than the allowed distance is not a
/// valid user. Distance is a ratio of body width to the image diagonal (larger =
/// closer), which does not depend on phone orientation or camera resolution.
///
/// Pure and constant-driven: tune [minShoulderWidthRatio] / [minEyeSpanRatio]
/// in `AppConstants` (see `cameraMinShoulderWidthRatio`).
class CameraDistanceGate {
  final bool enabled;
  final double minShoulderWidthRatio;
  final double minEyeSpanRatio;
  final bool unknownIsValid;

  /// Landmarks below this likelihood are ignored for measuring.
  final double minLikelihood;

  const CameraDistanceGate({
    this.enabled = true,
    required this.minShoulderWidthRatio,
    required this.minEyeSpanRatio,
    this.unknownIsValid = true,
    this.minLikelihood = 0.20,
  });

  /// Gate configured from the common constants file.
  factory CameraDistanceGate.fromConstants() => CameraDistanceGate(
    enabled: AppConstants.cameraDistanceGateEnabled,
    minShoulderWidthRatio: AppConstants.cameraMinShoulderWidthRatio,
    minEyeSpanRatio: AppConstants.cameraMinEyeSpanRatio,
    unknownIsValid: AppConstants.cameraDistanceUnknownIsValid,
    minLikelihood: AppConstants.cameraDistanceMinLikelihood,
  );

  /// [minShoulderRatio] / [minEyeRatio] override the configured minimums
  /// (used by the live "Max Camera Distance" setting).
  CameraDistanceResult evaluate({
    DistanceLandmark? leftShoulder,
    DistanceLandmark? rightShoulder,
    DistanceLandmark? leftEye,
    DistanceLandmark? rightEye,
    required double imageWidth,
    required double imageHeight,
    double? minShoulderRatio,
    double? minEyeRatio,
    bool? unknownIsValid,
  }) {
    final double shoulderMin = minShoulderRatio ?? minShoulderWidthRatio;
    final double eyeMin = minEyeRatio ?? minEyeSpanRatio;
    if (!enabled) {
      return const CameraDistanceResult(
        withinRange: true,
        ratio: null,
        source: 'disabled',
        minRatio: null,
      );
    }

    final double diagonal = sqrt(imageWidth * imageWidth + imageHeight * imageHeight);
    if (diagonal <= 0) return _unknown(unknownIsValid);

    if (_visible(leftShoulder) && _visible(rightShoulder)) {
      final double ratio = _distance(leftShoulder!, rightShoulder!) / diagonal;
      return CameraDistanceResult(
        withinRange: ratio >= shoulderMin,
        ratio: ratio,
        source: 'shoulders',
        minRatio: shoulderMin,
      );
    }

    if (_visible(leftEye) && _visible(rightEye)) {
      final double ratio = _distance(leftEye!, rightEye!) / diagonal;
      return CameraDistanceResult(
        withinRange: ratio >= eyeMin,
        ratio: ratio,
        source: 'eyes',
        minRatio: eyeMin,
      );
    }

    return _unknown(unknownIsValid);
  }

  CameraDistanceResult _unknown([bool? override]) => CameraDistanceResult(
    withinRange: override ?? unknownIsValid,
    ratio: null,
    source: 'unknown',
    minRatio: null,
  );

  bool _visible(DistanceLandmark? landmark) =>
      landmark != null && landmark.likelihood >= minLikelihood;

  double _distance(DistanceLandmark a, DistanceLandmark b) =>
      sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2)).toDouble();
}
