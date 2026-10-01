import 'package:equatable/equatable.dart';

class CalibrationResult extends Equatable {
  final double noiseFloorRmsBaseline;
  final double adaptiveMultiplierThreshold;
  final bool isCameraFramingValid;
  final bool isCalibrationSuccess;
  final int calibrationTimestampUs;

  const CalibrationResult({
    required this.noiseFloorRmsBaseline,
    required this.adaptiveMultiplierThreshold,
    required this.isCameraFramingValid,
    required this.isCalibrationSuccess,
    required this.calibrationTimestampUs,
  });

  @override
  List<Object?> get props => [
        noiseFloorRmsBaseline,
        adaptiveMultiplierThreshold,
        isCameraFramingValid,
        isCalibrationSuccess,
        calibrationTimestampUs,
      ];
}
