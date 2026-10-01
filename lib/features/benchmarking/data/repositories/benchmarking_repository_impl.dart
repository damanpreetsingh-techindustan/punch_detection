import '../../../audio_detection/domain/entities/audio_confidence_score.dart';
import '../../../fusion/domain/entities/fusion_config.dart';
import '../../../fusion/domain/repositories/fusion_repository.dart';
import '../../../vision_detection/domain/entities/vision_confidence_score.dart';
import '../datasources/benchmark_dataset_datasource.dart';
import '../../domain/entities/benchmark_report.dart';
import '../../domain/repositories/benchmarking_repository.dart';

class BenchmarkingRepositoryImpl implements BenchmarkingRepository {
  final BenchmarkDatasetDatasource datasource;
  final FusionRepository fusionRepository;

  BenchmarkingRepositoryImpl({
    required this.datasource,
    required this.fusionRepository,
  });

  @override
  Future<BenchmarkReport> runBenchmarkSuite() async {
    final samples = datasource.generateBenchmarkDataset();
    const fusionConfig = FusionConfig();

    int tp = 0;
    int fp = 0;
    int tn = 0;
    int fn = 0;
    int totalLatencyMicros = 0;

    for (final sample in samples) {
      final sw = Stopwatch()..start();

      final audio = AudioConfidenceScore(
        score: sample.audioScore,
        isPunchCandidate: sample.audioScore >= 0.70,
        timestampMicroseconds: sample.timestampUs,
        filterResults: const {},
        metrics: const {},
      );

      final vision = VisionConfidenceScore(
        score: sample.visionScore,
        isPunchMotionDetected: sample.visionScore >= 0.70,
        timestampMicroseconds: sample.timestampUs,
        ruleResults: const {},
        metrics: const {},
      );

      final event = fusionRepository.fuseSignals(
        audioResult: audio,
        visionResult: vision,
        config: fusionConfig,
      );

      sw.stop();
      totalLatencyMicros += sw.elapsedMicroseconds;

      final bool detected = event.isPunchConfirmed;
      final bool expected = sample.expectedIsPunch;

      if (detected && expected) {
        tp++;
      } else if (detected && !expected) {
        fp++;
      } else if (!detected && !expected) {
        tn++;
      } else if (!detected && expected) {
        fn++;
      }
    }

    final int total = samples.length;
    final double precision = (tp + fp) > 0 ? tp / (tp + fp) : 0.0;
    final double recall = (tp + fn) > 0 ? tp / (tp + fn) : 0.0;
    final double f1 = (precision + recall) > 0 ? (2 * precision * recall) / (precision + recall) : 0.0;
    final double meanLatencyMs = (totalLatencyMicros / total) / 1000.0;
    final double coincidenceRate = tp / 50.0;
    final bool isPassed = f1 >= 0.90;

    return BenchmarkReport(
      totalSamples: total,
      truePositives: tp,
      falsePositives: fp,
      trueNegatives: tn,
      falseNegatives: fn,
      precision: double.parse(precision.toStringAsFixed(3)),
      recall: double.parse(recall.toStringAsFixed(3)),
      f1Score: double.parse(f1.toStringAsFixed(3)),
      meanLatencyMs: double.parse(meanLatencyMs.toStringAsFixed(2)),
      coincidenceMatchRate: double.parse(coincidenceRate.toStringAsFixed(3)),
      isPassed: isPassed,
    );
  }
}
