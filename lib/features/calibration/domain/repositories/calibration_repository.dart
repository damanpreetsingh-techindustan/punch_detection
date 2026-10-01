import '../entities/calibration_progress.dart';
import '../entities/calibration_result.dart';

abstract class CalibrationRepository {
  /// Streams 5-second calibration progress (seconds remaining, RMS level)
  Stream<CalibrationProgress> startCalibrationStream();

  /// Completes calibration and returns final CalibrationResult
  Future<CalibrationResult> runCalibration({
    List<double>? testSamples,
    bool isCameraEnabled = true,
  });
}
