import 'package:equatable/equatable.dart';

class WorkoutRecord extends Equatable {
  final String id;
  final String dateIso;
  final int durationSeconds;
  final int totalPunches;
  final double averageReactionMs;
  final int bestReactionMs;
  final String detectionMode; // 'fusion' | 'audioOnly'

  /// 'free' (Free Fight) or 'prompt' (Reaction Drill).
  final String sessionType;

  /// Drill pace: 'beginner' | 'intermediate' | 'advanced' (drills only).
  final String? difficulty;

  /// Drill only: most calls answered in a row, calls answered, calls made.
  final int bestStreak;
  final int callsAnswered;
  final int callsMade;

  const WorkoutRecord({
    required this.id,
    required this.dateIso,
    required this.durationSeconds,
    required this.totalPunches,
    required this.averageReactionMs,
    required this.bestReactionMs,
    required this.detectionMode,
    this.sessionType = 'free',
    this.difficulty,
    this.bestStreak = 0,
    this.callsAnswered = 0,
    this.callsMade = 0,
  });

  DateTime get date => DateTime.tryParse(dateIso)?.toLocal() ?? DateTime(1970);

  bool get isDrill => sessionType == 'prompt';

  /// Punches per minute over the whole session.
  double get punchesPerMinute =>
      durationSeconds <= 0 ? 0 : totalPunches * 60 / durationSeconds;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateIso': dateIso,
      'durationSeconds': durationSeconds,
      'totalPunches': totalPunches,
      'averageReactionMs': averageReactionMs,
      'bestReactionMs': bestReactionMs,
      'detectionMode': detectionMode,
      'sessionType': sessionType,
      'difficulty': difficulty,
      'bestStreak': bestStreak,
      'callsAnswered': callsAnswered,
      'callsMade': callsMade,
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
      sessionType: json['sessionType'] as String? ?? 'free',
      difficulty: json['difficulty'] as String?,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
      callsAnswered: (json['callsAnswered'] as num?)?.toInt() ?? 0,
      callsMade: (json['callsMade'] as num?)?.toInt() ?? 0,
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
    sessionType,
    difficulty,
    bestStreak,
    callsAnswered,
    callsMade,
  ];
}
