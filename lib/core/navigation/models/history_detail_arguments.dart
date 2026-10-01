/// Strongly typed navigation arguments for Workout History Detail Screen.
class HistoryDetailArguments {
  final String sessionId;
  final String sessionType;
  final int totalPunches;
  final int leftPunches;
  final int rightPunches;
  final double averageReactionMs;
  final int durationSeconds;
  final DateTime timestamp;

  const HistoryDetailArguments({
    required this.sessionId,
    required this.sessionType,
    required this.totalPunches,
    this.leftPunches = 0,
    this.rightPunches = 0,
    this.averageReactionMs = 0.0,
    required this.durationSeconds,
    required this.timestamp,
  });

  factory HistoryDetailArguments.fromArguments(dynamic args) {
    if (args is HistoryDetailArguments) return args;
    if (args is Map<String, dynamic>) {
      return HistoryDetailArguments(
        sessionId: args['sessionId'] as String? ?? '',
        sessionType: args['sessionType'] as String? ?? 'free',
        totalPunches: (args['totalPunches'] as num? ?? 0).toInt(),
        leftPunches: (args['leftPunches'] as num? ?? 0).toInt(),
        rightPunches: (args['rightPunches'] as num? ?? 0).toInt(),
        averageReactionMs: (args['averageReactionMs'] as num? ?? 0.0).toDouble(),
        durationSeconds: (args['durationSeconds'] as num? ?? 0).toInt(),
        timestamp: args['timestamp'] is DateTime
            ? args['timestamp'] as DateTime
            : DateTime.tryParse(args['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );
    }
    return HistoryDetailArguments(
      sessionId: '',
      sessionType: 'free',
      totalPunches: 0,
      durationSeconds: 0,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'sessionType': sessionType,
      'totalPunches': totalPunches,
      'leftPunches': leftPunches,
      'rightPunches': rightPunches,
      'averageReactionMs': averageReactionMs,
      'durationSeconds': durationSeconds,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
