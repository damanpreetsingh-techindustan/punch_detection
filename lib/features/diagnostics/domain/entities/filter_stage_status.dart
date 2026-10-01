import 'package:equatable/equatable.dart';

class FilterStageStatus extends Equatable {
  final String stageName;
  final bool passed;
  final double currentValue;
  final double thresholdValue;

  const FilterStageStatus({
    required this.stageName,
    required this.passed,
    required this.currentValue,
    required this.thresholdValue,
  });

  @override
  List<Object?> get props => [stageName, passed, currentValue, thresholdValue];
}
