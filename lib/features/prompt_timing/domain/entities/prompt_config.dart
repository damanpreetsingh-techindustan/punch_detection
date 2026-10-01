import 'package:equatable/equatable.dart';

enum DifficultyTier { beginner, intermediate, advanced }

class PromptConfig extends Equatable {
  final DifficultyTier difficulty;
  final double speechRate;
  final double pitch;
  final int minIntervalMs;
  final int maxIntervalMs;

  const PromptConfig({
    this.difficulty = DifficultyTier.intermediate,
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.minIntervalMs = 2000,
    this.maxIntervalMs = 4000,
  });

  @override
  List<Object?> get props => [
        difficulty,
        speechRate,
        pitch,
        minIntervalMs,
        maxIntervalMs,
      ];
}
