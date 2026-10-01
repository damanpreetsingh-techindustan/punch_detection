import 'package:equatable/equatable.dart';

class CalibrationProgress extends Equatable {
  final int secondsRemaining; // 10..0
  final double currentRms;
  final double progressRatio; // 0.0..1.0
  final bool isCompleted;

  const CalibrationProgress({
    required this.secondsRemaining,
    required this.currentRms,
    required this.progressRatio,
    required this.isCompleted,
  });

  @override
  List<Object?> get props => [
        secondsRemaining,
        currentRms,
        progressRatio,
        isCompleted,
      ];
}
