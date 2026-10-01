import 'package:equatable/equatable.dart';

class BenchmarkReport extends Equatable {
  final int totalSamples;
  final int truePositives;
  final int falsePositives;
  final int trueNegatives;
  final int falseNegatives;
  final double precision;
  final double recall;
  final double f1Score;
  final double meanLatencyMs;
  final double coincidenceMatchRate;
  final bool isPassed;

  const BenchmarkReport({
    required this.totalSamples,
    required this.truePositives,
    required this.falsePositives,
    required this.trueNegatives,
    required this.falseNegatives,
    required this.precision,
    required this.recall,
    required this.f1Score,
    required this.meanLatencyMs,
    required this.coincidenceMatchRate,
    required this.isPassed,
  });

  factory BenchmarkReport.initial() {
    return const BenchmarkReport(
      totalSamples: 0,
      truePositives: 0,
      falsePositives: 0,
      trueNegatives: 0,
      falseNegatives: 0,
      precision: 0.0,
      recall: 0.0,
      f1Score: 0.0,
      meanLatencyMs: 0.0,
      coincidenceMatchRate: 0.0,
      isPassed: false,
    );
  }

  @override
  List<Object?> get props => [
        totalSamples,
        truePositives,
        falsePositives,
        trueNegatives,
        falseNegatives,
        precision,
        recall,
        f1Score,
        meanLatencyMs,
        coincidenceMatchRate,
        isPassed,
      ];
}
