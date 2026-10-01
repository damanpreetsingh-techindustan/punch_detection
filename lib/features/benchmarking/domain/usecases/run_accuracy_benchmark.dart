import '../../../../core/usecases/usecase.dart';
import '../entities/benchmark_report.dart';
import '../repositories/benchmarking_repository.dart';

class RunAccuracyBenchmark implements UseCase<BenchmarkReport, NoParams> {
  final BenchmarkingRepository repository;

  RunAccuracyBenchmark(this.repository);

  @override
  Future<BenchmarkReport> call(NoParams params) async {
    return repository.runBenchmarkSuite();
  }
}
