import 'package:equatable/equatable.dart';

class FusionConfig extends Equatable {
  final double audioWeight;                  // Primary signal weight (default 0.70)
  final double visionWeight;                 // Confirmation signal weight (default 0.30)
  final int coincidenceWindowMs;            // Max timestamp offset for fusion (default 150ms)
  final double minFusedConfidenceThreshold; // Threshold to confirm punch (default 0.65)

  const FusionConfig({
    this.audioWeight = 0.70,
    this.visionWeight = 0.30,
    this.coincidenceWindowMs = 150,
    this.minFusedConfidenceThreshold = 0.65,
  });

  @override
  List<Object?> get props => [
        audioWeight,
        visionWeight,
        coincidenceWindowMs,
        minFusedConfidenceThreshold,
      ];
}
