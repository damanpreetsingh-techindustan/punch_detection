import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/camera_distance_gate.dart';

void main() {
  // 640 x 480 image -> diagonal 800 px, so ratio = pixels / 800.
  const double w = 640;
  const double h = 480;

  const CameraDistanceGate gate = CameraDistanceGate(
    minShoulderWidthRatio: 0.10,
    minEyeSpanRatio: 0.015,
  );

  DistanceLandmark lm(double x, double y, [double likelihood = 0.9]) =>
      DistanceLandmark(x: x, y: y, likelihood: likelihood);

  group('shoulders', () {
    test('close user (wide shoulders) is within range', () {
      final r = gate.evaluate(
        leftShoulder: lm(400, 300),
        rightShoulder: lm(240, 300), // 160 px -> 0.20
        imageWidth: w,
        imageHeight: h,
      );
      expect(r.withinRange, isTrue);
      expect(r.source, 'shoulders');
      expect(r.ratio, closeTo(0.20, 1e-9));
    });

    test('far user (narrow shoulders) is out of range', () {
      final r = gate.evaluate(
        leftShoulder: lm(340, 200),
        rightShoulder: lm(300, 200), // 40 px -> 0.05
        imageWidth: w,
        imageHeight: h,
      );
      expect(r.withinRange, isFalse);
      expect(r.description, 'shoulders 0.050 < 0.100');
    });

    test('exactly at the limit counts as within range', () {
      final r = gate.evaluate(
        leftShoulder: lm(380, 200),
        rightShoulder: lm(300, 200), // 80 px -> 0.10
        imageWidth: w,
        imageHeight: h,
      );
      expect(r.withinRange, isTrue);
    });

    test('ratio does not depend on phone orientation', () {
      final portrait = gate.evaluate(
        leftShoulder: lm(0, 0),
        rightShoulder: lm(120, 0),
        imageWidth: 480,
        imageHeight: 640,
      );
      final landscape = gate.evaluate(
        leftShoulder: lm(0, 0),
        rightShoulder: lm(120, 0),
        imageWidth: 640,
        imageHeight: 480,
      );
      expect(portrait.ratio, landscape.ratio);
    });

    test('tilted shoulders use the straight-line distance', () {
      final r = gate.evaluate(
        leftShoulder: lm(0, 0),
        rightShoulder: lm(60, 80), // 100 px
        imageWidth: w,
        imageHeight: h,
      );
      expect(r.ratio, closeTo(100 / sqrt(w * w + h * h), 1e-9));
    });
  });

  group('fallbacks', () {
    test('uses eyes when only one shoulder is visible', () {
      final r = gate.evaluate(
        leftShoulder: lm(300, 300),
        rightShoulder: lm(200, 300, 0.05), // too unlikely to use
        leftEye: lm(330, 100),
        rightEye: lm(310, 100), // 20 px -> 0.025
        imageWidth: w,
        imageHeight: h,
      );
      expect(r.source, 'eyes');
      expect(r.withinRange, isTrue);
    });

    test('far face (eyes close together) is out of range', () {
      final r = gate.evaluate(
        leftEye: lm(324, 100),
        rightEye: lm(316, 100), // 8 px -> 0.01
        imageWidth: w,
        imageHeight: h,
      );
      expect(r.withinRange, isFalse);
    });

    test('unmeasurable pose follows the unknown policy', () {
      final valid = gate.evaluate(
        leftShoulder: lm(300, 300),
        imageWidth: w,
        imageHeight: h,
      );
      expect(valid.source, 'unknown');
      expect(valid.withinRange, isTrue);

      const CameraDistanceGate strict = CameraDistanceGate(
        minShoulderWidthRatio: 0.10,
        minEyeSpanRatio: 0.015,
        unknownIsValid: false,
      );
      final invalid = strict.evaluate(
        leftShoulder: lm(300, 300),
        imageWidth: w,
        imageHeight: h,
      );
      expect(invalid.withinRange, isFalse);
    });

    test('unknown image size cannot be measured', () {
      final r = gate.evaluate(
        leftShoulder: lm(0, 0),
        rightShoulder: lm(10, 0),
        imageWidth: 0,
        imageHeight: 0,
      );
      expect(r.source, 'unknown');
    });
  });

  test('disabled gate accepts everything', () {
    const CameraDistanceGate off = CameraDistanceGate(
      enabled: false,
      minShoulderWidthRatio: 0.9,
      minEyeSpanRatio: 0.9,
    );
    final r = off.evaluate(
      leftShoulder: lm(0, 0),
      rightShoulder: lm(1, 0),
      imageWidth: w,
      imageHeight: h,
    );
    expect(r.withinRange, isTrue);
    expect(r.source, 'disabled');
  });

  test('fromConstants reads the common constants file', () {
    final CameraDistanceGate fromConstants = CameraDistanceGate.fromConstants();
    expect(
      fromConstants.minShoulderWidthRatio,
      AppConstants.cameraMinShoulderWidthRatio,
    );
    expect(fromConstants.minEyeSpanRatio, AppConstants.cameraMinEyeSpanRatio);
    expect(fromConstants.enabled, AppConstants.cameraDistanceGateEnabled);
  });
}
