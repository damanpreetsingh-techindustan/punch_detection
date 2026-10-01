import 'package:get/get.dart';
import '../../../fusion/data/repositories/fusion_repository_impl.dart';
import '../../../fusion/domain/repositories/fusion_repository.dart';
import '../../data/datasources/benchmark_dataset_datasource.dart';
import '../../data/repositories/benchmarking_repository_impl.dart';
import '../../domain/repositories/benchmarking_repository.dart';
import '../../domain/usecases/run_accuracy_benchmark.dart';
import '../controllers/benchmarking_controller.dart';

class BenchmarkingBinding extends Bindings {
  @override
  void dependencies() {
    final fusionRepo = FusionRepositoryImpl();
    Get.lazyPut<FusionRepository>(() => fusionRepo);

    final datasource = BenchmarkDatasetDatasource();
    final repository = BenchmarkingRepositoryImpl(
      datasource: datasource,
      fusionRepository: fusionRepo,
    );
    Get.lazyPut<BenchmarkingRepository>(() => repository);

    final runUseCase = RunAccuracyBenchmark(repository);
    Get.lazyPut<RunAccuracyBenchmark>(() => runUseCase);

    Get.lazyPut<BenchmarkingController>(
      () => BenchmarkingController(runAccuracyBenchmarkUseCase: runUseCase),
    );
  }
}
