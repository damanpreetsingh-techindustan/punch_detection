import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/fusion/domain/entities/sensor_signal_state.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/tri_sensor_matrix_evaluator.dart';

void main() {
  group('TriSensorMatrixEvaluator Wall vs Pole Mount Decision Matrix Tests', () {
    const int timestamp = 12345678;

    group('Wall Mount Tests (Physical Vibration is Mandatory)', () {
      final evaluator = TriSensorMatrixEvaluator(
        strongAudioSpikeDb: 8.0,
        weakAudioSpikeDb: 4.0,
        strongVibrationMag: 0.08,
        weakVibrationMag: 0.02,
        requireVisionConfirmation: false,
        isPoleMount: false,
      );

      test('Wall Mount: Strong Audio + Confirmed Camera + NO Vibration is REJECTED', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 12.0,
          vibrationMag: 0.00,
          isCameraAvailable: true,
          isCameraConfirmed: true,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isFalse);
        expect(result.outcome, equals(PunchOutcome.notPunch));
        expect(result.combinationCode, equals('REJECTED_NO_VIBRATION_WALL_MOUNT'));
        expect(result.reasonLabel, contains('Physical Vibration Required on Wall Mount'));
      });

      test('Wall Mount: Strong Audio + Confirmed Camera + WEAK Vibration (<0.08) is REJECTED', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 10.0,
          vibrationMag: 0.04, // Weak vibration (between 0.02 and 0.08)
          isCameraAvailable: true,
          isCameraConfirmed: true,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isFalse);
        expect(result.outcome, equals(PunchOutcome.notPunch));
        expect(result.combinationCode, equals('REJECTED_WEAK_VIBRATION_WALL_MOUNT'));
        expect(result.reasonLabel, contains('Vibration Below Threshold on Wall Mount'));
      });

      test('Wall Mount: Strong Audio + Strong Vibration (>=0.08) + Confirmed Camera is VALID PUNCH', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 14.0,
          vibrationMag: 0.15,
          isCameraAvailable: true,
          isCameraConfirmed: true,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isTrue);
        expect(result.outcome, equals(PunchOutcome.validPunch));
        expect(result.combinationCode, equals('VALID_HIGH_CONFIDENCE_TRIPLE'));
      });

      test('Wall Mount: Strong Audio + Strong Vibration + Camera Unavailable is VALID PUNCH (Dual Impact)', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 10.0,
          vibrationMag: 0.12,
          isCameraAvailable: false,
          isCameraConfirmed: false,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isTrue);
        expect(result.outcome, equals(PunchOutcome.validPunch));
        expect(result.combinationCode, equals('VALID_AUDIO_VIBE_DUAL'));
      });

      test('Wall Mount: Strict Vision Confirmation enabled rejects when Camera is not confirmed', () {
        final strictEvaluator = TriSensorMatrixEvaluator(
          strongAudioSpikeDb: 8.0,
          weakAudioSpikeDb: 4.0,
          strongVibrationMag: 0.08,
          weakVibrationMag: 0.02,
          requireVisionConfirmation: true,
          isPoleMount: false,
        );

        final result = strictEvaluator.evaluate(
          audioSpikeDb: 15.0,
          vibrationMag: 0.20,
          isCameraAvailable: true,
          isCameraConfirmed: false,
          isCameraRejected: true,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isFalse);
        expect(result.combinationCode, equals('REJECTED_VISION_CONFIRMATION_REQUIRED'));
      });
    });

    group('Pole Mount Tests (Either Audio+Camera OR Audio+Vibration Confirms Punch)', () {
      final evaluator = TriSensorMatrixEvaluator(
        strongAudioSpikeDb: 8.0,
        weakAudioSpikeDb: 4.0,
        strongVibrationMag: 0.08,
        weakVibrationMag: 0.02,
        requireVisionConfirmation: false,
        isPoleMount: true,
      );

      test('Pole Mount: Strong Audio + Confirmed Camera (NO Vibration) is VALID PUNCH', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 12.0,
          vibrationMag: 0.00,
          isCameraAvailable: true,
          isCameraConfirmed: true,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isTrue);
        expect(result.outcome, equals(PunchOutcome.validPunch));
        expect(result.combinationCode, equals('VALID_AUDIO_CAMERA_POLE'));
      });

      test('Pole Mount: Strong Audio + Strong Vibration (Camera Unavailable) is VALID PUNCH', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 10.0,
          vibrationMag: 0.15,
          isCameraAvailable: false,
          isCameraConfirmed: false,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isTrue);
        expect(result.outcome, equals(PunchOutcome.validPunch));
        expect(result.combinationCode, equals('VALID_AUDIO_VIBE_POLE'));
      });

      test('Pole Mount: Strong Audio + Strong Vibration + Confirmed Camera is VALID PUNCH (High Confidence)', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 12.0,
          vibrationMag: 0.18,
          isCameraAvailable: true,
          isCameraConfirmed: true,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isTrue);
        expect(result.outcome, equals(PunchOutcome.validPunch));
        expect(result.combinationCode, equals('VALID_HIGH_CONFIDENCE_TRIPLE_POLE'));
      });
    });

    group('Wall Mount with Vibration Disabled Tests (Bypassed to Audio + Camera & Audio-only Fallback)', () {
      final evaluator = TriSensorMatrixEvaluator(
        strongAudioSpikeDb: 8.0,
        weakAudioSpikeDb: 4.0,
        strongVibrationMag: 0.08,
        weakVibrationMag: 0.02,
        requireVisionConfirmation: false,
        isPoleMount: false,
        isVibrationDisabled: true, // Physical vibration is disabled even though user selected Wall Mount!
      );

      test('Wall Mount with Vibe Disabled: Strong Audio + Confirmed Camera (NO Vibration) is VALID PUNCH', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 12.0,
          vibrationMag: 0.00,
          isCameraAvailable: true,
          isCameraConfirmed: true,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isTrue);
        expect(result.outcome, equals(PunchOutcome.validPunch));
        expect(result.combinationCode, equals('VALID_AUDIO_CAMERA_POLE'));
      });

      test('Wall Mount with Vibe Disabled: Strong Audio + Camera Unavailable (NO Vibration) is VALID PUNCH (Audio Fallback)', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 10.0,
          vibrationMag: 0.00,
          isCameraAvailable: false,
          isCameraConfirmed: false,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isTrue);
        expect(result.outcome, equals(PunchOutcome.validPunch));
        expect(result.combinationCode, equals('VALID_AUDIO_CAMERA_POLE'));
        expect(result.reasonLabel, contains('Audio Spike — Camera Disabled/Unavailable'));
      });

      test('Wall Mount with Vibe Disabled: Weak Audio + Confirmed Camera (NO Vibration) is VALID PUNCH', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 5.0,
          vibrationMag: 0.00,
          isCameraAvailable: true,
          isCameraConfirmed: true,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isTrue);
        expect(result.outcome, equals(PunchOutcome.validPunch));
        expect(result.combinationCode, equals('VALID_WEAK_AUDIO_CAMERA_POLE'));
      });

      test('Wall Mount with Vibe Disabled: Weak Audio + Camera Unavailable is REJECTED', () {
        final result = evaluator.evaluate(
          audioSpikeDb: 5.0,
          vibrationMag: 0.00,
          isCameraAvailable: false,
          isCameraConfirmed: false,
          isCameraRejected: false,
          timestampMs: timestamp,
        );

        expect(result.isValidPunch, isFalse);
        expect(result.outcome, equals(PunchOutcome.notPunch));
      });
    });
  });
}
