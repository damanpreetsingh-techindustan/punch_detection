import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/fast_combo_fusion_synchronizer.dart';

void main() {
  group('FastComboFusionSynchronizer Unit Tests', () {
    late FastComboFusionSynchronizer synchronizer;

    setUp(() {
      synchronizer = FastComboFusionSynchronizer(
        audioWindowMs: 350,
        sameArmRefractoryMs: 210,
        comboArmRefractoryMs: 140,
        minShoulderDriveScore: 35.0,
      );
    });

    test('1. Matched Audio + Vision produces confirmed fused punch event', () {
      final result = synchronizer.pushAudioImpact(
        nowMs: 1000,
        decibelLevel: 90.0,
        onsetSpikeDb: 25.0,
        activeDrivingArm: 'right',
        currentVisionScore: 45.0,
      );

      expect(result.isMatched, isTrue);
      expect(result.drivingArm, equals('right'));
      expect(result.matchReason, contains('PUNCH FUSED'));
    });

    test('2. Alternating arm combo passes fast 140ms refractory window', () {
      // First punch on Right arm at t = 1000ms
      synchronizer.pushAudioImpact(
        nowMs: 1000,
        decibelLevel: 90.0,
        onsetSpikeDb: 25.0,
        activeDrivingArm: 'right',
        currentVisionScore: 45.0,
      );

      // Fast second punch on Left arm at t = 1160ms (160ms later, which is > 140ms combo window)
      final comboResult = synchronizer.pushAudioImpact(
        nowMs: 1160,
        decibelLevel: 88.0,
        onsetSpikeDb: 20.0,
        activeDrivingArm: 'left',
        currentVisionScore: 50.0,
      );

      expect(comboResult.isMatched, isTrue);
      expect(comboResult.drivingArm, equals('left'));
      expect(comboResult.matchReason, contains('FAST COMBO FUSED'));
    });

    test('3. Same arm rapid punch within 210ms same-arm refractory window is rejected', () {
      // First punch on Right arm at t = 1000ms
      synchronizer.pushAudioImpact(
        nowMs: 1000,
        decibelLevel: 90.0,
        onsetSpikeDb: 25.0,
        activeDrivingArm: 'right',
        currentVisionScore: 45.0,
      );

      // Rapid second punch on SAME Right arm at t = 1120ms (120ms < 210ms same-arm window)
      final sameArmResult = synchronizer.pushAudioImpact(
        nowMs: 1120,
        decibelLevel: 88.0,
        onsetSpikeDb: 20.0,
        activeDrivingArm: 'right',
        currentVisionScore: 50.0,
      );

      expect(sameArmResult.isMatched, isFalse);
    });
  });
}
