import 'package:equatable/equatable.dart';

class VisionConfidenceScore extends Equatable {
  final double score; // 0.0 to 1.0
  final bool isPunchMotionDetected;
  final int timestampMicroseconds;
  final Map<String, bool> ruleResults;
  final Map<String, dynamic> metrics;

  const VisionConfidenceScore({
    required this.score,
    required this.isPunchMotionDetected,
    required this.timestampMicroseconds,
    required this.ruleResults,
    required this.metrics,
  });

  @override
  List<Object?> get props => [
    score,
    isPunchMotionDetected,
    timestampMicroseconds,
    ruleResults,
    metrics,
  ];
}
