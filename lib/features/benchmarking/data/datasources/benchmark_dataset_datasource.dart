import '../../domain/entities/benchmark_sample.dart';

class BenchmarkDatasetDatasource {
  List<BenchmarkSample> generateBenchmarkDataset() {
    final List<BenchmarkSample> samples = [];

    // 1. 50 True Heavy-Bag Impact Samples (Audio + Vision)
    for (int i = 0; i < 50; i++) {
      samples.add(
        BenchmarkSample(
          sampleId: 'impact_$i',
          audioScore: 0.85 + (i % 10) * 0.01,
          visionScore: 0.80 + (i % 10) * 0.01,
          expectedIsPunch: true,
          timestampUs: 1000000 + (i * 500000),
        ),
      );
    }

    // 2. 25 Background Ambient Speech Noise Samples (Filtered Out)
    for (int i = 0; i < 25; i++) {
      samples.add(
        BenchmarkSample(
          sampleId: 'noise_$i',
          audioScore: 0.25 + (i % 5) * 0.02,
          visionScore: 0.10,
          expectedIsPunch: false,
          timestampUs: 30000000 + (i * 500000),
        ),
      );
    }

    // 3. 25 Non-Punch Arm Movements (Guard Adjustments)
    for (int i = 0; i < 25; i++) {
      samples.add(
        BenchmarkSample(
          sampleId: 'arm_movement_$i',
          audioScore: 0.15,
          visionScore: 0.65 + (i % 5) * 0.02,
          expectedIsPunch: false,
          timestampUs: 45000000 + (i * 500000),
        ),
      );
    }

    return samples;
  }
}
