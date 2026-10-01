import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/benchmarking/data/datasources/benchmark_dataset_datasource.dart';
import 'package:punch_detection_demo/features/benchmarking/data/repositories/benchmarking_repository_impl.dart';
import 'package:punch_detection_demo/features/benchmarking/domain/entities/benchmark_sample.dart';
import 'package:punch_detection_demo/features/fusion/data/repositories/fusion_repository_impl.dart';

void main() {
  late BenchmarkDatasetDatasource datasource;
  late FusionRepositoryImpl fusionRepository;
  late BenchmarkingRepositoryImpl repository;

  setUp(() {
    datasource = BenchmarkDatasetDatasource();
    fusionRepository = FusionRepositoryImpl();
    repository = BenchmarkingRepositoryImpl(
      datasource: datasource,
      fusionRepository: fusionRepository,
    );
  });

  group('Phase 11: Integration & Accuracy Benchmarking Unit Tests', () {
    test('1. BenchmarkDatasetDatasource generates 100 test samples', () {
      final List<BenchmarkSample> samples = datasource.generateBenchmarkDataset();
      expect(samples.length, equals(100));

      final punchSamples = samples.where((s) => s.expectedIsPunch).toList();
      expect(punchSamples.length, equals(50));
    });

    test('2. BenchmarkingRepositoryImpl calculates F1 score and passes benchmark target', () async {
      final report = await repository.runBenchmarkSuite();

      expect(report.totalSamples, equals(100));
      expect(report.truePositives, equals(50));
      expect(report.precision, equals(1.0));
      expect(report.recall, equals(1.0));
      expect(report.f1Score, equals(1.0));
      expect(report.isPassed, isTrue);
      expect(report.meanLatencyMs, lessThan(30.0));
    });
  });
}
