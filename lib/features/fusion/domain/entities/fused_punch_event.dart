import 'package:equatable/equatable.dart';

enum FusionMode { fusion, audioOnly, cameraFallback }

class FusedPunchEvent extends Equatable {
  final int timestampMicroseconds;
  final double fusedConfidenceScore; // 0.0 to 1.0
  final bool isPunchConfirmed;
  final double audioScore;
  final double visionScore;
  final FusionMode fusionMode;

  const FusedPunchEvent({
    required this.timestampMicroseconds,
    required this.fusedConfidenceScore,
    required this.isPunchConfirmed,
    required this.audioScore,
    required this.visionScore,
    required this.fusionMode,
  });

  @override
  List<Object?> get props => [
        timestampMicroseconds,
        fusedConfidenceScore,
        isPunchConfirmed,
        audioScore,
        visionScore,
        fusionMode,
      ];
}
