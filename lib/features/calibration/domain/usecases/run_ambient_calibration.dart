import '../../../../core/usecases/usecase.dart';
import '../entities/calibration_result.dart';
import '../repositories/calibration_repository.dart';

class RunAmbientCalibrationParams {
  final List<double>? testSamples;
  final bool isCameraEnabled;

  const RunAmbientCalibrationParams({
    this.testSamples,
    this.isCameraEnabled = true,
  });
}

class RunAmbientCalibration implements UseCase<CalibrationResult, RunAmbientCalibrationParams> {
  final CalibrationRepository repository;

  RunAmbientCalibration(this.repository);

  @override
  Future<CalibrationResult> call(RunAmbientCalibrationParams params) async {
    return repository.runCalibration(
      testSamples: params.testSamples,
      isCameraEnabled: params.isCameraEnabled,
    );
  }
}
