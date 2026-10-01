import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/session/domain/entities/punch_telemetry_event.dart';
import 'package:punch_detection_demo/features/session/domain/services/auto_config_evaluator.dart';

void main() {
  group('AutoConfigEvaluator Domain Unit Tests', () {
    const evaluator = AutoConfigEvaluator();

    test('returns insufficientData when fewer than 3 events exist', () {
      final result = evaluator.evaluate(
        events: [
          const PunchTelemetryEvent(
            timestampMs: 1000,
            peakAudioDb: 78.0,
            baselineAudioDb: 50.0,
            audioRiseDb: 28.0,
            targetAudioDb: 75.0,
            vibrationPeakMag: 0.15,
            vibrationLiveMag: 0.05,
            vibrationThreshold: 0.10,
            cameraConfidence: 85,
            cameraArm: 'RIGHT',
            isCameraConfirmed: true,
            isCameraAvailable: true,
            isValidPunch: true,
            decisionCode: 'PUNCH_AUDIO_VIBE',
            reasonLabel: 'Strong Audio + Strong Vibe',
          ),
        ],
        currentTargetAudioDb: 80.0,
        currentSpikeDb: 20.0,
        currentVibrationThreshold: 0.25,
        ambientBaselineDb: 50.0,
        isPoleMount: false,
        currentVibrationGateEnabled: true,
        currentVisionRequired: true,
      );

      expect(result.hasSufficientData, isFalse);
      expect(result.recommendedTargetAudioDb, equals(80.0));
      expect(result.statusMessage, contains('Need at least 3–4 punches'));
    });

    test('calculates optimal audio target and vibration threshold from punch activity', () {
      final events = [
        const PunchTelemetryEvent(
          timestampMs: 1000,
          peakAudioDb: 82.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 32.0,
          targetAudioDb: 85.0,
          vibrationPeakMag: 0.20,
          vibrationLiveMag: 0.02,
          vibrationThreshold: 0.10,
          cameraConfidence: 90,
          cameraArm: 'RIGHT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Audio + Strong Vibe',
        ),
        const PunchTelemetryEvent(
          timestampMs: 2000,
          peakAudioDb: 80.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 30.0,
          targetAudioDb: 85.0,
          vibrationPeakMag: 0.18,
          vibrationLiveMag: 0.03,
          vibrationThreshold: 0.10,
          cameraConfidence: 88,
          cameraArm: 'LEFT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Audio + Strong Vibe',
        ),
        const PunchTelemetryEvent(
          timestampMs: 3000,
          peakAudioDb: 84.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 34.0,
          targetAudioDb: 85.0,
          vibrationPeakMag: 0.22,
          vibrationLiveMag: 0.01,
          vibrationThreshold: 0.10,
          cameraConfidence: 92,
          cameraArm: 'RIGHT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Audio + Strong Vibe',
        ),
      ];

      final result = evaluator.evaluate(
        events: events,
        currentTargetAudioDb: 85.0,
        currentSpikeDb: 25.0,
        currentVibrationThreshold: 0.25,
        ambientBaselineDb: 50.0,
        isPoleMount: false,
        currentVibrationGateEnabled: true,
        currentVisionRequired: true,
      );

      expect(result.hasSufficientData, isTrue);
      // Average audio is 82.0 dB, 25th percentile is 80.0 dB -> target = min(79.0, 79.5) = 79.0 dB
      expect(result.recommendedTargetAudioDb, equals(79.0));
      // Average vibration is 0.20 m/s² -> 40% is 0.08 m/s²
      expect(result.recommendedVibrationThreshold, equals(0.08));
      expect(result.recommendedVibrationGateEnabled, isTrue);
      expect(result.recommendedVisionRequired, isTrue);
    });

    test('disables vibration gate when pole mount is active', () {
      final events = [
        const PunchTelemetryEvent(
          timestampMs: 1000,
          peakAudioDb: 80.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 30.0,
          targetAudioDb: 75.0,
          vibrationPeakMag: 0.01,
          vibrationLiveMag: 0.00,
          vibrationThreshold: 0.10,
          cameraConfidence: 85,
          cameraArm: 'RIGHT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'AUDIO_POLE_DUAL',
          reasonLabel: 'Pole Mount Bypass',
        ),
        const PunchTelemetryEvent(
          timestampMs: 2000,
          peakAudioDb: 82.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 32.0,
          targetAudioDb: 75.0,
          vibrationPeakMag: 0.01,
          vibrationLiveMag: 0.00,
          vibrationThreshold: 0.10,
          cameraConfidence: 80,
          cameraArm: 'LEFT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'AUDIO_POLE_DUAL',
          reasonLabel: 'Pole Mount Bypass',
        ),
        const PunchTelemetryEvent(
          timestampMs: 3000,
          peakAudioDb: 81.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 31.0,
          targetAudioDb: 75.0,
          vibrationPeakMag: 0.01,
          vibrationLiveMag: 0.00,
          vibrationThreshold: 0.10,
          cameraConfidence: 82,
          cameraArm: 'RIGHT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'AUDIO_POLE_DUAL',
          reasonLabel: 'Pole Mount Bypass',
        ),
      ];

      final result = evaluator.evaluate(
        events: events,
        currentTargetAudioDb: 75.0,
        currentSpikeDb: 20.0,
        currentVibrationThreshold: 0.10,
        ambientBaselineDb: 50.0,
        isPoleMount: true,
        currentVibrationGateEnabled: true,
        currentVisionRequired: false,
      );

      expect(result.hasSufficientData, isTrue);
      expect(result.recommendedVibrationGateEnabled, isFalse);
    });


    test('relaxes vision requirement when camera confirms < 35% of punches', () {
      final events = [
        const PunchTelemetryEvent(
          timestampMs: 1000,
          peakAudioDb: 80.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 30.0,
          targetAudioDb: 75.0,
          vibrationPeakMag: 0.15,
          vibrationLiveMag: 0.02,
          vibrationThreshold: 0.10,
          cameraConfidence: 20,
          cameraArm: 'NONE',
          isCameraConfirmed: false,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Audio + Strong Vibe',
        ),
        const PunchTelemetryEvent(
          timestampMs: 2000,
          peakAudioDb: 82.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 32.0,
          targetAudioDb: 75.0,
          vibrationPeakMag: 0.18,
          vibrationLiveMag: 0.01,
          vibrationThreshold: 0.10,
          cameraConfidence: 15,
          cameraArm: 'NONE',
          isCameraConfirmed: false,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Audio + Strong Vibe',
        ),
        const PunchTelemetryEvent(
          timestampMs: 3000,
          peakAudioDb: 81.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 31.0,
          targetAudioDb: 75.0,
          vibrationPeakMag: 0.17,
          vibrationLiveMag: 0.01,
          vibrationThreshold: 0.10,
          cameraConfidence: 10,
          cameraArm: 'NONE',
          isCameraConfirmed: false,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Audio + Strong Vibe',
        ),
      ];

      final result = evaluator.evaluate(
        events: events,
        currentTargetAudioDb: 75.0,
        currentSpikeDb: 20.0,
        currentVibrationThreshold: 0.10,
        ambientBaselineDb: 50.0,
        isPoleMount: false,
        currentVibrationGateEnabled: true,
        currentVisionRequired: true,
      );

      expect(result.hasSufficientData, isTrue);
      expect(result.recommendedVisionRequired, isFalse);
    });

    test('serializes PunchTelemetryEvent to map properly', () {
      const event = PunchTelemetryEvent(
        timestampMs: 12345,
        peakAudioDb: 85.5,
        baselineAudioDb: 48.0,
        audioRiseDb: 37.5,
        targetAudioDb: 78.0,
        vibrationPeakMag: 0.25,
        vibrationLiveMag: 0.05,
        vibrationThreshold: 0.12,
        cameraConfidence: 95,
        cameraArm: 'RIGHT',
        isCameraConfirmed: true,
        isCameraAvailable: true,
        isValidPunch: true,
        decisionCode: 'PUNCH_AUDIO_VIBE',
        reasonLabel: 'Strong Audio + Strong Vibe',
        sessionMode: 'fusion',
        mountType: 'wall',
        isVibrationGateEnabled: true,
        isVisionConfirmationRequired: true,
        refractoryElapsedMs: 450,
      );

      final map = event.toMap();
      expect(map['timestampMs'], equals(12345));
      expect(map['peakAudioDb'], equals(85.5));
      expect(map['sessionMode'], equals('fusion'));
      expect(map['refractoryElapsedMs'], equals(450));
      expect(event.toLogString(isPoleMount: false), contains('🟢 [VALID]'));
    });

    test('strictly locks recommendedTargetAudioDb to ambientBaselineDb + recommendedSpikeDb', () {
      final events = [
        const PunchTelemetryEvent(
          timestampMs: 1000,
          peakAudioDb: 88.0,
          baselineAudioDb: 46.0,
          audioRiseDb: 42.0,
          targetAudioDb: 70.0,
          vibrationPeakMag: 0.20,
          vibrationLiveMag: 0.02,
          vibrationThreshold: 0.10,
          cameraConfidence: 90,
          cameraArm: 'RIGHT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Hit',
        ),
        const PunchTelemetryEvent(
          timestampMs: 2000,
          peakAudioDb: 86.0,
          baselineAudioDb: 46.0,
          audioRiseDb: 40.0,
          targetAudioDb: 70.0,
          vibrationPeakMag: 0.18,
          vibrationLiveMag: 0.01,
          vibrationThreshold: 0.10,
          cameraConfidence: 90,
          cameraArm: 'LEFT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Hit',
        ),
        const PunchTelemetryEvent(
          timestampMs: 3000,
          peakAudioDb: 87.0,
          baselineAudioDb: 46.0,
          audioRiseDb: 41.0,
          targetAudioDb: 70.0,
          vibrationPeakMag: 0.19,
          vibrationLiveMag: 0.01,
          vibrationThreshold: 0.10,
          cameraConfidence: 92,
          cameraArm: 'RIGHT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: true,
          decisionCode: 'PUNCH_AUDIO_VIBE',
          reasonLabel: 'Strong Hit',
        ),
      ];

      const double ambientBase = 46.0;
      final result = evaluator.evaluate(
        events: events,
        currentTargetAudioDb: 70.0,
        currentSpikeDb: 24.0,
        currentVibrationThreshold: 0.10,
        ambientBaselineDb: ambientBase,
        isPoleMount: false,
        currentVibrationGateEnabled: true,
        currentVisionRequired: false,
      );

      expect(result.hasSufficientData, isTrue);
      // recommendedTargetAudioDb must be exactly equal to ambientBaselineDb + recommendedSpikeDb
      expect(result.recommendedTargetAudioDb, equals(ambientBase + result.recommendedSpikeDb));
    });

    test('lowers audio target when 3+ punches are below current target but above ambient baseline', () {
      // User's punches are at ~72 dB, but target was set way too high at 88 dB
      final candidateEvents = [
        const PunchTelemetryEvent(
          timestampMs: 1000,
          peakAudioDb: 72.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 22.0,
          targetAudioDb: 88.0,
          vibrationPeakMag: 0.15,
          vibrationLiveMag: 0.02,
          vibrationThreshold: 0.10,
          cameraConfidence: 85,
          cameraArm: 'RIGHT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: false,
          isCandidate: true,
          isRejected: true,
          decisionCode: 'AUDIO_BELOW_TARGET',
          reasonLabel: 'Spike (72 dB) below target (88 dB)',
        ),
        const PunchTelemetryEvent(
          timestampMs: 2000,
          peakAudioDb: 74.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 24.0,
          targetAudioDb: 88.0,
          vibrationPeakMag: 0.18,
          vibrationLiveMag: 0.01,
          vibrationThreshold: 0.10,
          cameraConfidence: 88,
          cameraArm: 'LEFT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: false,
          isCandidate: true,
          isRejected: true,
          decisionCode: 'AUDIO_BELOW_TARGET',
          reasonLabel: 'Spike (74 dB) below target (88 dB)',
        ),
        const PunchTelemetryEvent(
          timestampMs: 3000,
          peakAudioDb: 71.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 21.0,
          targetAudioDb: 88.0,
          vibrationPeakMag: 0.14,
          vibrationLiveMag: 0.02,
          vibrationThreshold: 0.10,
          cameraConfidence: 90,
          cameraArm: 'RIGHT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: false,
          isCandidate: true,
          isRejected: true,
          decisionCode: 'AUDIO_BELOW_TARGET',
          reasonLabel: 'Spike (71 dB) below target (88 dB)',
        ),
        const PunchTelemetryEvent(
          timestampMs: 4000,
          peakAudioDb: 73.0,
          baselineAudioDb: 50.0,
          audioRiseDb: 23.0,
          targetAudioDb: 88.0,
          vibrationPeakMag: 0.16,
          vibrationLiveMag: 0.01,
          vibrationThreshold: 0.10,
          cameraConfidence: 86,
          cameraArm: 'LEFT',
          isCameraConfirmed: true,
          isCameraAvailable: true,
          isValidPunch: false,
          isCandidate: true,
          isRejected: true,
          decisionCode: 'AUDIO_BELOW_TARGET',
          reasonLabel: 'Spike (73 dB) below target (88 dB)',
        ),
      ];

      final result = evaluator.evaluate(
        events: candidateEvents,
        currentTargetAudioDb: 88.0,
        currentSpikeDb: 38.0,
        currentVibrationThreshold: 0.25,
        ambientBaselineDb: 50.0,
        isPoleMount: false,
        currentVibrationGateEnabled: true,
        currentVisionRequired: false,
      );

      expect(result.hasSufficientData, isTrue);
      // AutoConfig lowers target from 88 dB down to user's power level (~70-71 dB)
      expect(result.recommendedTargetAudioDb, lessThan(88.0));
      expect(result.recommendedTargetAudioDb, equals(70.0));
      expect(result.recommendedSpikeDb, equals(20.0)); // 50 + 20 = 70 dB
      expect(result.recommendedTargetAudioDb, equals(50.0 + result.recommendedSpikeDb));
    });
  });
}


