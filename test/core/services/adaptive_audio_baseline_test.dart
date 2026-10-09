     import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/audio_level/adaptive_audio_baseline.dart';

void main() {
  group('AdaptiveAudioBaseline Unit Tests', () {
    late AdaptiveAudioBaseline baselineEngine;

    setUp(() {
      baselineEngine = AdaptiveAudioBaseline(
        initialBaseline: 50.0,
        spikeThresholdDb: 15.0, // Target = 50 + 15 = 65 dB
        refractoryMs: 110,
      );
      baselineEngine.seedBaseline(50.0);
    });

    test('replaces stationary background noise with null', () {
      final spike = baselineEngine.processFrame(51.0, 50.0, nowMs: 1000);
      expect(spike, isNull);
    });

    test('rejects slow-ramping human speech without explosive onset', () {
      // Speech ramping up 2 dB at a time
      baselineEngine.processFrame(52.0, 50.0, nowMs: 1000);
      baselineEngine.processFrame(54.0, 52.0, nowMs: 1020);
      baselineEngine.processFrame(56.0, 54.0, nowMs: 1040);
      final spike = baselineEngine.processFrame(58.0, 56.0, nowMs: 1060);
      expect(spike, isNull);
    });

    test('detects explosive percussive strike meeting target with isTargetMet == true', () {
      // Background steady at 50 dB
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1000);
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1020);
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1040);

      // Sudden explosive punch: jump from 50 dB to 78 dB (well above 65 dB target)
      final spike = baselineEngine.processFrame(78.0, 50.0, nowMs: 1060);
      expect(spike, isNotNull);
      expect(spike!.isTargetMet, isTrue);
      expect(spike.peakDb, equals(78.0));
      expect(spike.spikeHeight, equals(28.0));
    });

    test('detects sub-target percussive strike above calibration line with isTargetMet == false', () {
      // Background steady at 50 dB
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1000);
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1020);
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1040);

      // Sudden punch at 60 dB:
      // Jump = +10 dB onset, rises +10 dB above 50 dB calibration line, but below 65 dB target
      final spike = baselineEngine.processFrame(60.0, 50.0, nowMs: 1060);
      expect(spike, isNotNull);
      expect(spike!.isTargetMet, isFalse);
      expect(spike.peakDb, equals(60.0));
      expect(spike.spikeHeight, equals(10.0));
    });

    test('enforces fixedAudioTargetDb so 95 dB spike is rejected as sub-target when target is 98 dB', () {
      baselineEngine.fixedAudioTargetDb = 98.0;

      // Steady ambient
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1000);
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1020);

      // Strike at 95 dB: explosive onset (+45 dB jump), above calibration, but below 98 dB target
      final subTargetSpike = baselineEngine.processFrame(95.0, 50.0, nowMs: 1060);
      expect(subTargetSpike, isNotNull);
      expect(subTargetSpike!.isTargetMet, isFalse);
      expect(subTargetSpike.peakDb, equals(95.0));

      // Strike at 99 dB (after refractory): explosive onset meeting 98 dB target
      final targetMetSpike = baselineEngine.processFrame(99.0, 50.0, nowMs: 1250);
      expect(targetMetSpike, isNotNull);
      expect(targetMetSpike!.isTargetMet, isTrue);
      expect(targetMetSpike.peakDb, equals(99.0));
    });

    test('enforces refractory window so identical hit is not double-counted within 110ms', () {
      // Hit 1
      final spike1 = baselineEngine.processFrame(72.0, 50.0, nowMs: 1000);
      expect(spike1, isNotNull);

      // Hit 2 inside refractory window (40ms later)
      final spike2 = baselineEngine.processFrame(75.0, 72.0, nowMs: 1040);
      expect(spike2, isNull);

      // Hit 3 after refractory window (150ms later)
      final spike3 = baselineEngine.processFrame(73.0, 50.0, nowMs: 1200);
      expect(spike3, isNotNull);
    });
    test('supports negative spikeThresholdDb down to -15 dB and confirms punches reaching lower target', () {
      baselineEngine.seedBaseline(70.0);
      baselineEngine.spikeThresholdDb = -10.0; // Target is 70 + (-10) = 60 dB

      // Steady ambient
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1000);
      baselineEngine.processFrame(50.0, 50.0, nowMs: 1020);

      // Punch at 63 dB: explosive onset exceeding the 60 dB target
      final confirmedSpike = baselineEngine.processFrame(63.0, 50.0, nowMs: 1060);
      expect(confirmedSpike, isNotNull);
      expect(confirmedSpike!.isTargetMet, isTrue);
      expect(confirmedSpike.peakDb, equals(63.0));
    });
  });
}
