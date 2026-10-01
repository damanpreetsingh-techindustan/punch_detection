import '../entities/benchmark_report.dart';

abstract class BenchmarkingRepository {
  /// Executes the 100-sample accuracy benchmark suite
  Future<BenchmarkReport> runBenchmarkSuite();
}
