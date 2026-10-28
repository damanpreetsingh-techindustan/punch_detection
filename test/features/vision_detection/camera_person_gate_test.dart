import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/camera_distance_gate.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/camera_person_gate.dart';

void main() {
  const CameraPersonGate gate = CameraPersonGate(
    minFaceConfidence: 0.5,
    minShoulderConfidence: 0.5,
  );

  DistanceLandmark p(double y, double likelihood) =>
      DistanceLandmark(x: 100, y: y, likelihood: likelihood);

  test('face + one shoulder, both confident, face above -> person', () {
    final r = gate.evaluate(
      facePoints: [p(100, 0.9)],
      leftShoulder: p(250, 0.8),
    );
    expect(r.isPerson, isTrue);
    expect(r.reason, 'ok');
  });

  test('face + both shoulders -> person', () {
    final r = gate.evaluate(
      facePoints: [p(100, 0.9), p(105, 0.7)],
      leftShoulder: p(250, 0.8),
      rightShoulder: p(255, 0.9),
    );
    expect(r.isPerson, isTrue);
  });

  test('bottle-like pose: a few weak points -> not a person', () {
    final r = gate.evaluate(
      facePoints: [p(100, 0.25), p(110, 0.31), null],
      leftShoulder: p(250, 0.28),
      rightShoulder: p(250, 0.22),
    );
    expect(r.isPerson, isFalse);
    expect(r.reason, 'no_face_no_shoulder');
    expect(r.bestFaceConfidence, 0.31);
    expect(r.bestShoulderConfidence, 0.28);
  });

  test('confident face but weak shoulders -> no_shoulder', () {
    final r = gate.evaluate(
      facePoints: [p(100, 0.95)],
      leftShoulder: p(250, 0.3),
    );
    expect(r.isPerson, isFalse);
    expect(r.reason, 'no_shoulder');
  });

  test('confident shoulder but no face -> no_face', () {
    final r = gate.evaluate(facePoints: [null], rightShoulder: p(250, 0.9));
    expect(r.isPerson, isFalse);
    expect(r.reason, 'no_face');
  });

  test('exactly at the minimum confidence counts', () {
    final r = gate.evaluate(
      facePoints: [p(100, 0.5)],
      leftShoulder: p(250, 0.5),
    );
    expect(r.isPerson, isTrue);
  });

  test('face below the shoulder -> not a person', () {
    final r = gate.evaluate(
      facePoints: [p(300, 0.9)],
      leftShoulder: p(250, 0.9),
    );
    expect(r.isPerson, isFalse);
    expect(r.reason, 'face_below_shoulder');
  });

  test('face-above check can be switched off', () {
    const CameraPersonGate noOrder = CameraPersonGate(
      minFaceConfidence: 0.5,
      minShoulderConfidence: 0.5,
      requireFaceAboveShoulder: false,
    );
    final r = noOrder.evaluate(
      facePoints: [p(300, 0.9)],
      leftShoulder: p(250, 0.9),
    );
    expect(r.isPerson, isTrue);
  });

  test('the most confident points are the ones compared', () {
    // Weak face point below the shoulder is ignored; the confident one is above.
    final r = gate.evaluate(
      facePoints: [p(400, 0.3), p(100, 0.9)],
      leftShoulder: p(250, 0.9),
    );
    expect(r.isPerson, isTrue);
  });

  test('disabled gate falls back to the old rule (any point >= 0.20)', () {
    const CameraPersonGate off = CameraPersonGate(
      enabled: false,
      minFaceConfidence: 0.5,
      minShoulderConfidence: 0.5,
    );
    expect(
      off.evaluate(facePoints: [p(100, 0.25)]).isPerson,
      isTrue,
    );
    expect(
      off.evaluate(facePoints: [p(100, 0.1)]).isPerson,
      isFalse,
    );
  });

  test('description shows reason and confidences', () {
    final r = gate.evaluate(
      facePoints: [p(100, 0.81)],
      leftShoulder: p(250, 0.32),
    );
    expect(r.description, 'no_shoulder (face 0.81, shoulder 0.32)');
  });

  test('fromConstants reads the common constants file', () {
    final g = CameraPersonGate.fromConstants();
    expect(g.minFaceConfidence, AppConstants.cameraMinFaceConfidence);
    expect(g.minShoulderConfidence, AppConstants.cameraMinShoulderConfidence);
    expect(g.enabled, AppConstants.cameraPersonGateEnabled);
    expect(
      g.requireFaceAboveShoulder,
      AppConstants.cameraRequireFaceAboveShoulder,
    );
  });
}
