import '../../utils/constants.dart';

/// Strongly typed navigation model for Workout Results Screen.
class SessionResultModel {
  final int totalPunches;
  final int leftPunches;
  final int rightPunches;
  final double averageReactionTimeMs;
  final double averageLatencyMs;
  final double accuracyPercentage;
  final int durationSeconds;
  final String sessionType; // 'free' or 'prompt'
  final String detectionMode; // 'fusion', 'audio', or 'camera'
  final double peakAudioDb;
  final double averageConfidence;
  final List<String> recordedSpikesHistory;
  final DateTime completedAt;

  // Session Settings & Calibration Telemetry
  final int audioSampleIntervalMs;
  final double directAudioTargetDb;
  final double audioSpikeThresholdDb;
  final double ambientBaselineDb;
  final double vibrationThreshold;
  final bool isVisionConfirmationRequired;
  final bool isVibrationGateEnabled;

  // Session instrumentation (empty when the session did not record it)
  /// Every confirmed punch log line of the session, oldest first, never trimmed.
  final List<String> confirmedPunchLog;

  /// Pre-formatted per-session totals block for the exported text log.
  final String sessionTotalsText;

  /// Path of the raw event file (JSONL) written during the session, if any.
  final String? rawEventFilePath;

  /// Short CSV table: one row per punch decision and per camera change.
  final String summaryCsv;

  /// Folder with the raw sensor recording (WAV, accelerometer, events, meta)
  /// when "Record raw data" was on; null otherwise.
  final String? rawSessionFolderPath;

  SessionResultModel({
    required this.totalPunches,
    this.leftPunches = 0,
    this.rightPunches = 0,
    this.averageReactionTimeMs = 0.0,
    this.averageLatencyMs = 38.0,
    this.accuracyPercentage = 95.0,
    this.durationSeconds = 0,
    this.sessionType = 'free',
    this.detectionMode = 'fusion',
    this.peakAudioDb = 0.0,
    this.averageConfidence = 85.0,
    this.recordedSpikesHistory = const [],
    int? audioSampleIntervalMs,
    this.directAudioTargetDb = 70.0,
    this.audioSpikeThresholdDb = 20.0,
    this.ambientBaselineDb = 45.0,
    this.vibrationThreshold = 0.25,
    this.isVisionConfirmationRequired = true,
    this.isVibrationGateEnabled = true,
    this.confirmedPunchLog = const [],
    this.sessionTotalsText = '',
    this.rawEventFilePath,
    this.summaryCsv = '',
    this.rawSessionFolderPath,
    DateTime? completedAt,
  }) : audioSampleIntervalMs =
           audioSampleIntervalMs ?? AppConstants.globalAudioSampleIntervalMs,
       completedAt = completedAt ?? DateTime.now();

  factory SessionResultModel.fromArguments(dynamic args) {
    if (args is SessionResultModel) return args;
    if (args is Map<String, dynamic>) {
      final num punchesRaw = args['punches'] ?? args['totalPunches'] ?? 0;
      final num leftRaw = args['leftPunches'] ?? 0;
      final num rightRaw = args['rightPunches'] ?? 0;
      final num reactionRaw =
          args['reaction'] ?? args['averageReactionTimeMs'] ?? 0.0;
      final num latencyRaw =
          args['latency'] ?? args['averageLatencyMs'] ?? 38.0;
      final num accuracyRaw = args['accuracyPercentage'] ?? 95.0;
      final num durationRaw = args['durationSeconds'] ?? 0;
      final num peakDbRaw = args['peakAudioDb'] ?? 0.0;
      final num avgConfRaw = args['averageConfidence'] ?? 85.0;
      final rawSpikes = args['recordedSpikesHistory'] as List?;
      final List<String> spikesList = rawSpikes != null
          ? rawSpikes.map((e) => e.toString()).toList()
          : const [];

      return SessionResultModel(
        totalPunches: punchesRaw.toInt(),
        leftPunches: leftRaw.toInt(),
        rightPunches: rightRaw.toInt(),
        averageReactionTimeMs: reactionRaw.toDouble(),
        averageLatencyMs: latencyRaw.toDouble(),
        accuracyPercentage: accuracyRaw.toDouble(),
        durationSeconds: durationRaw.toInt(),
        sessionType: args['sessionType'] as String? ?? 'free',
        detectionMode: args['detectionMode'] as String? ?? 'fusion',
        peakAudioDb: peakDbRaw.toDouble(),
        averageConfidence: avgConfRaw.toDouble(),
        recordedSpikesHistory: spikesList,
        audioSampleIntervalMs:
            (args['audioSampleIntervalMs'] as num?)?.toInt() ??
            AppConstants.globalAudioSampleIntervalMs,
        directAudioTargetDb:
            (args['directAudioTargetDb'] as num?)?.toDouble() ?? 70.0,
        audioSpikeThresholdDb:
            (args['audioSpikeThresholdDb'] as num?)?.toDouble() ?? 20.0,
        ambientBaselineDb:
            (args['ambientBaselineDb'] as num?)?.toDouble() ?? 45.0,
        vibrationThreshold:
            (args['vibrationThreshold'] as num?)?.toDouble() ?? 0.25,
        isVisionConfirmationRequired:
            args['isVisionConfirmationRequired'] as bool? ?? true,
        isVibrationGateEnabled: args['isVibrationGateEnabled'] as bool? ?? true,
        completedAt: args['completedAt'] != null
            ? DateTime.tryParse(args['completedAt'].toString()) ??
                  DateTime.now()
            : DateTime.now(),
      );
    }
    return SessionResultModel(totalPunches: 0);
  }

  Map<String, dynamic> toMap() {
    return {
      'punches': totalPunches,
      'totalPunches': totalPunches,
      'leftPunches': leftPunches,
      'rightPunches': rightPunches,
      'reaction': averageReactionTimeMs,
      'averageReactionTimeMs': averageReactionTimeMs,
      'averageLatencyMs': averageLatencyMs,
      'accuracyPercentage': accuracyPercentage,
      'durationSeconds': durationSeconds,
      'sessionType': sessionType,
      'detectionMode': detectionMode,
      'peakAudioDb': peakAudioDb,
      'averageConfidence': averageConfidence,
      'audioSampleIntervalMs': audioSampleIntervalMs,
      'directAudioTargetDb': directAudioTargetDb,
      'audioSpikeThresholdDb': audioSpikeThresholdDb,
      'ambientBaselineDb': ambientBaselineDb,
      'vibrationThreshold': vibrationThreshold,
      'isVisionConfirmationRequired': isVisionConfirmationRequired,
      'isVibrationGateEnabled': isVibrationGateEnabled,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  /// Formatted duration string e.g. "02:15"
  String get formattedDuration {
    final int minutes = durationSeconds ~/ 60;
    final int seconds = durationSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// User-friendly label for detection mode
  String get formattedSessionModeLabel {
    if (detectionMode == 'audio') return 'AUDIO ONLY';
    if (detectionMode == 'camera') return 'CAMERA ONLY';
    return 'FUSION (AUDIO + CAMERA)';
  }

  /// User-friendly label for workout mode
  String get formattedSessionTypeLabel {
    return sessionType == 'prompt' ? 'PROMPT WORKOUT' : 'FREE WORKOUT';
  }

  /// Performance Grade calculation
  String get grade {
    if (accuracyPercentage >= 95.0 && totalPunches >= 15) return 'S';
    if (accuracyPercentage >= 90.0 || totalPunches >= 10) return 'A+';
    if (accuracyPercentage >= 85.0 || totalPunches >= 5) return 'A';
    return 'B+';
  }
}
