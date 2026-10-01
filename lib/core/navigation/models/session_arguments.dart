import '../../enums/detection_enums.dart';

/// Strongly typed navigation arguments for Workout Sessions (Free & Prompt Modes).
class SessionArguments {
  final String sessionType;
  final String? promptMode;
  final String? mountType;
  final String? difficulty; // 'beginner', 'intermediate', 'advanced'

  MountType get resolvedMountType => MountType.fromString(mountType);
  DetectionMode get resolvedDetectionMode =>
      DetectionMode.fromString(promptMode);
  final int targetCount;
  final int durationSeconds;
  final bool audioEnabled;
  final bool ttsEnabled;
  final double maxAudioDb;

  /// Average ambient room noise level captured during precheck calibration.
  /// Used to seed the adaptive audio baseline engine at session start.
  final double avgAmbientDb;

  /// Recommended spike threshold (dB jump above adaptive baseline) to detect a punch.
  /// Calculated during calibration based on observed environmental noise characteristics.
  final double spikeThresholdDb;

  /// Direct target punch audio level (dB) calculated after calibration with safety buffer.
  final double? targetPunchDb;

  /// Static base calibrated decibel level captured during pre-check calibration.
  final double? calibratedDb;

  const SessionArguments({
    required this.sessionType,
    this.promptMode,
    this.mountType,
    this.difficulty,
    this.targetCount = 10,
    this.durationSeconds = 60,
    this.audioEnabled = true,
    this.ttsEnabled = true,
    this.maxAudioDb = 85.0,
    this.avgAmbientDb = 48.0,
    this.spikeThresholdDb = 10.0,
    this.targetPunchDb,
    this.calibratedDb,
  });

  factory SessionArguments.fromArguments(dynamic args) {
    if (args is SessionArguments) return args;
    if (args is Map<String, dynamic>) {
      return SessionArguments(
        sessionType: args['sessionType'] as String? ?? 'free',
        promptMode: args['promptMode'] as String?,
        mountType: args['mountType'] as String?,
        difficulty: args['difficulty'] as String?,
        targetCount: args['targetCount'] as int? ?? 10,
        durationSeconds: args['durationSeconds'] as int? ?? 60,
        audioEnabled: args['audioEnabled'] as bool? ?? true,
        ttsEnabled: args['ttsEnabled'] as bool? ?? true,
        maxAudioDb: args['maxAudioDb'] as double? ?? 85.0,
        avgAmbientDb: args['avgAmbientDb'] as double? ?? 48.0,
        spikeThresholdDb: args['spikeThresholdDb'] as double? ?? 10.0,
        targetPunchDb: args['targetPunchDb'] as double?,
        calibratedDb: args['calibratedDb'] as double? ??
            args['maxAudioDb'] as double?,
      );
    }
    if (args is String) return SessionArguments(sessionType: args);
    return const SessionArguments(sessionType: 'free');
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionType': sessionType,
      'promptMode': promptMode,
      'mountType': mountType,
      'difficulty': difficulty,
      'targetCount': targetCount,
      'durationSeconds': durationSeconds,
      'audioEnabled': audioEnabled,
      'ttsEnabled': ttsEnabled,
      'maxAudioDb': maxAudioDb,
      'avgAmbientDb': avgAmbientDb,
      'spikeThresholdDb': spikeThresholdDb,
      'targetPunchDb': targetPunchDb,
      'calibratedDb': calibratedDb,
    };
  }
}

