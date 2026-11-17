/// Strongly typed navigation arguments for Session Pre-Check Screen.
class SessionPreCheckArguments {
  final String sessionType;
  final String? promptMode;
  final int? durationSeconds;

  /// Prompt drill pace: 'beginner', 'intermediate' or 'advanced'.
  final String? difficulty;

  const SessionPreCheckArguments({
    this.sessionType = 'free',
    this.promptMode,
    this.durationSeconds,
    this.difficulty,
  });

  factory SessionPreCheckArguments.fromArguments(dynamic args) {
    if (args is SessionPreCheckArguments) return args;
    if (args is String) return SessionPreCheckArguments(sessionType: args);
    if (args is Map<String, dynamic>) {
      return SessionPreCheckArguments(
        sessionType: args['sessionType'] as String? ?? 'free',
        promptMode: args['promptMode'] as String?,
        durationSeconds: args['durationSeconds'] as int?,
        difficulty: args['difficulty'] as String?,
      );
    }
    return const SessionPreCheckArguments();
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionType': sessionType,
      'promptMode': promptMode,
      'durationSeconds': durationSeconds,
      'difficulty': difficulty,
    };
  }
}
