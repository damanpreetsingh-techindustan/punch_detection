import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/impact_gate_evaluator.dart';

void main() {
  const ImpactGateEvaluator evaluator = ImpactGateEvaluator();

  ImpactGateResult run(
    VibrationGateState v,
    CameraGateState c, {
    bool closed = false,
  }) => evaluator.evaluate(vibration: v, camera: c, windowClosed: closed);

  group('valid only when every gate in use confirms', () {
    test('audio + vibration + camera', () {
      final r = run(VibrationGateState.present, CameraGateState.valid);
      expect(r.isValid, isTrue);
      expect(r.code, 'IMPACT_VALID_AUDIO_VIBE_CAM');
    });

    test('camera disabled -> audio + vibration decides', () {
      final r = run(VibrationGateState.present, CameraGateState.notRequired);
      expect(r.isValid, isTrue);
      expect(r.code, 'IMPACT_VALID_AUDIO_VIBE');
    });

    test('vibration disabled (pole) -> audio + camera decides', () {
      final r = run(VibrationGateState.notRequired, CameraGateState.valid);
      expect(r.isValid, isTrue);
      expect(r.code, 'IMPACT_VALID_AUDIO_CAM');
    });

    test('both disabled -> audio only', () {
      final r = run(VibrationGateState.notRequired, CameraGateState.notRequired);
      expect(r.code, 'IMPACT_VALID_AUDIO_ONLY');
    });
  });

  group('waits while the window is open', () {
    test('missing vibration is pending, not rejected', () {
      final r = run(VibrationGateState.missing, CameraGateState.valid);
      expect(r.isPending, isTrue);
      expect(r.reasonLabel, contains('vibration'));
    });

    test('camera not valid yet is pending', () {
      final r = run(VibrationGateState.present, CameraGateState.noPerson);
      expect(r.isPending, isTrue);
      expect(r.reasonLabel, contains('camera'));
    });
  });

  group('rejected once the window closes', () {
    test('no vibration', () {
      final r = run(
        VibrationGateState.missing,
        CameraGateState.valid,
        closed: true,
      );
      expect(r.isRejected, isTrue);
      expect(r.code, 'IMPACT_REJECTED_NO_VIBRATION');
    });

    test('user too far', () {
      final r = run(
        VibrationGateState.present,
        CameraGateState.tooFar,
        closed: true,
      );
      expect(r.code, 'IMPACT_REJECTED_CAMERA_TOO_FAR');
    });

    test('no user visible', () {
      final r = run(
        VibrationGateState.present,
        CameraGateState.noPerson,
        closed: true,
      );
      expect(r.code, 'IMPACT_REJECTED_CAMERA_NO_PERSON');
    });

    test('camera not ready', () {
      final r = run(
        VibrationGateState.present,
        CameraGateState.notReady,
        closed: true,
      );
      expect(r.code, 'IMPACT_REJECTED_CAMERA_NOT_READY');
    });

    test('vibration and camera both missing', () {
      final r = run(
        VibrationGateState.missing,
        CameraGateState.noPerson,
        closed: true,
      );
      expect(r.code, 'IMPACT_REJECTED_NO_VIBRATION_NO_CAMERA');
    });
  });

  test('a passing impact is valid even after the window closed', () {
    final r = run(
      VibrationGateState.present,
      CameraGateState.valid,
      closed: true,
    );
    expect(r.isValid, isTrue);
  });
}
