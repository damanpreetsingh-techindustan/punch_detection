import 'package:get/get.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/benchmark_report.dart';
import '../../domain/usecases/run_accuracy_benchmark.dart';

class BenchmarkingController extends GetxController {
  final RunAccuracyBenchmark runAccuracyBenchmarkUseCase;

  final Rx<BenchmarkReport> report = BenchmarkReport.initial().obs;
  final RxBool isRunning = false.obs;

  BenchmarkingController({required this.runAccuracyBenchmarkUseCase});

  @override
  void onInit() {
    super.onInit();
    executeBenchmark();
  }

  Future<void> executeBenchmark() async {
    isRunning.value = true;
    try {
      final result = await runAccuracyBenchmarkUseCase(NoParams());
      report.value = result;
    } finally {
      isRunning.value = false;
    }
  }
}
