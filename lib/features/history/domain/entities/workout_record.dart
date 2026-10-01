import 'package:equatable/equatable.dart';

class WorkoutRecord extends Equatable {
  final String id;
  final String dateIso;
  final int durationSeconds;
  final int totalPunches;
  final double averageReactionMs;
  final int bestReactionMs;
  final String detectionMode; // 'fusion' | 'audioOnly'

  const WorkoutRecord({
    required this.id,
    required this.dateIso,
    required this.durationSeconds,
    required this.totalPunches,
    required this.averageReactionMs,
    required this.bestReactionMs,
    required this.detectionMode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateIso': dateIso,
      'durationSeconds': durationSeconds,
      'totalPunches': totalPunches,
      'averageReactionMs': averageReactionMs,
      'bestReactionMs': bestReactionMs,
      'detectionMode': detectionMode,
    };
  }

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutRecord(
      id: json['id'] as String,
      dateIso: json['dateIso'] as String,
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      totalPunches: (json['totalPunches'] as num).toInt(),
      averageReactionMs: (json['averageReactionMs'] as num).toDouble(),
      bestReactionMs: (json['bestReactionMs'] as num).toInt(),
      detectionMode: json['detectionMode'] as String? ?? 'fusion',
    );
  }

  @override
  List<Object?> get props => [
        id,
        dateIso,
        durationSeconds,
        totalPunches,
        averageReactionMs,
        bestReactionMs,
        detectionMode,
      ];
}
