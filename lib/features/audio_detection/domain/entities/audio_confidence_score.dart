import 'package:equatable/equatable.dart';

class AudioConfidenceScore extends Equatable {
  final double score; // 0.0 to 1.0
  final bool isPunchCandidate;
  final int timestampMicroseconds;
  final Map<String, bool> filterResults;
  final Map<String, dynamic> metrics;

  const AudioConfidenceScore({
    required this.score,
    required this.isPunchCandidate,
    required this.timestampMicroseconds,
    required this.filterResults,
    required this.metrics,
  });

  @override
  List<Object?> get props => [
        score,
        isPunchCandidate,
        timestampMicroseconds,
        filterResults,
        metrics,
      ];
}
