import '../repositories/diagnostics_repository.dart';

class UpdateThresholdsParams {
  final double? audioWeight;
  final double? visionWeight;
  final double? minConfidence;

  const UpdateThresholdsParams({
    this.audioWeight,
    this.visionWeight,
    this.minConfidence,
  });
}

class UpdateDetectionThresholds {
  final DiagnosticsRepository repository;

  UpdateDetectionThresholds(this.repository);

  void call(UpdateThresholdsParams params) {
    repository.updateThresholds(
      audioWeight: params.audioWeight,
      visionWeight: params.visionWeight,
      minConfidence: params.minConfidence,
    );
  }
}
