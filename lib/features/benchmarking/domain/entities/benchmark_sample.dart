import 'package:equatable/equatable.dart';

class BenchmarkSample extends Equatable {
  final String sampleId;
  final double audioScore;
  final double visionScore;
  final bool expectedIsPunch;
  final int timestampUs;

  const BenchmarkSample({
    required this.sampleId,
    required this.audioScore,
    required this.visionScore,
    required this.expectedIsPunch,
    required this.timestampUs,
  });

  @override
  List<Object?> get props => [
        sampleId,
        audioScore,
        visionScore,
        expectedIsPunch,
        timestampUs,
      ];
}
