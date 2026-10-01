import 'package:equatable/equatable.dart';

enum WorkoutIntensity { moderate, high, peak }

class FreeModeStats extends Equatable {
  final int totalPunches;
  final int punchesPerMinute;
  final int peakCadencePpm;
  final int elapsedSeconds;
  final WorkoutIntensity intensityLevel;

  const FreeModeStats({
    required this.totalPunches,
    required this.punchesPerMinute,
    required this.peakCadencePpm,
    required this.elapsedSeconds,
    required this.intensityLevel,
  });

  factory FreeModeStats.initial() {
    return const FreeModeStats(
      totalPunches: 0,
      punchesPerMinute: 0,
      peakCadencePpm: 0,
      elapsedSeconds: 0,
      intensityLevel: WorkoutIntensity.moderate,
    );
  }

  static WorkoutIntensity getIntensity(int ppm) {
    if (ppm < 40) {
      return WorkoutIntensity.moderate;
    } else if (ppm <= 80) {
      return WorkoutIntensity.high;
    } else {
      return WorkoutIntensity.peak;
    }
  }

  FreeModeStats copyWith({
    int? totalPunches,
    int? punchesPerMinute,
    int? peakCadencePpm,
    int? elapsedSeconds,
    WorkoutIntensity? intensityLevel,
  }) {
    return FreeModeStats(
      totalPunches: totalPunches ?? this.totalPunches,
      punchesPerMinute: punchesPerMinute ?? this.punchesPerMinute,
      peakCadencePpm: peakCadencePpm ?? this.peakCadencePpm,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      intensityLevel: intensityLevel ?? this.intensityLevel,
    );
  }

  @override
  List<Object?> get props => [
        totalPunches,
        punchesPerMinute,
        peakCadencePpm,
        elapsedSeconds,
        intensityLevel,
      ];
}
