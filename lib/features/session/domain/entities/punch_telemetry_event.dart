import 'package:equatable/equatable.dart';

/// Strongly-typed structured telemetry event representing a detected acoustic/vibrational impact.
/// Contains all empirical sensor data necessary for mathematical analysis and auto-configuration.
class PunchTelemetryEvent extends Equatable {
  final int timestampMs;
  final double peakAudioDb;
  final double baselineAudioDb;
  final double audioRiseDb;
  final double targetAudioDb;
  final double vibrationPeakMag;
  final double vibrationLiveMag;
  final double vibrationThreshold;
  final int cameraConfidence;
  final String cameraArm;
  final bool isCameraConfirmed;
  final bool isCameraAvailable;
  final bool isValidPunch;
  final bool isCandidate;
  final bool isRejected;
  final String decisionCode;
  final String reasonLabel;
  final String sessionMode;
  final String mountType;
  final bool isVibrationGateEnabled;
  final bool isVisionConfirmationRequired;
  final int refractoryElapsedMs;

  const PunchTelemetryEvent({
    required this.timestampMs,
    required this.peakAudioDb,
    required this.baselineAudioDb,
    required this.audioRiseDb,
    required this.targetAudioDb,
    required this.vibrationPeakMag,
    required this.vibrationLiveMag,
    required this.vibrationThreshold,
    required this.cameraConfidence,
    required this.cameraArm,
    required this.isCameraConfirmed,
    required this.isCameraAvailable,
    required this.isValidPunch,
    this.isCandidate = false,
    this.isRejected = false,
    required this.decisionCode,
    required this.reasonLabel,
    this.sessionMode = '',
    this.mountType = '',
    this.isVibrationGateEnabled = true,
    this.isVisionConfirmationRequired = false,
    this.refractoryElapsedMs = 0,
  });

  /// Formatted single-line log string for UI display in recordedSpikesHistory
  String toLogString({required bool isPoleMount}) {
    final String tag;
    final String reason = reasonLabel.isNotEmpty ? ' ($reasonLabel)' : '';
    if (isValidPunch) {
      tag = '🟢 [VALID] $decisionCode$reason';
    } else if (isCandidate) {
      tag = '🟡 [CANDIDATE] $decisionCode$reason';
    } else {
      tag = '🔴 [REJECTED] $decisionCode$reason';
    }

    final String vibeDetail = isPoleMount
        ? 'Vibe: Disabled (Pole Mount)'
        : (vibrationPeakMag >= vibrationThreshold
              ? 'Vibe: Peak ${vibrationPeakMag.toStringAsFixed(2)} m/s² (Current: ${vibrationLiveMag.toStringAsFixed(2)} m/s², Thresh: ${vibrationThreshold.toStringAsFixed(2)} m/s²)'
              : 'Vibe: Peak ${vibrationPeakMag.toStringAsFixed(2)} m/s² (Below ${vibrationThreshold.toStringAsFixed(2)} m/s², Current: ${vibrationLiveMag.toStringAsFixed(2)} m/s²)');

    final String audioDetail =
        'Audio: ${peakAudioDb.toStringAsFixed(1)} dB '
        '(Base: ${baselineAudioDb.toStringAsFixed(1)} dB, '
        'Rise: +${audioRiseDb.toStringAsFixed(1)} dB, '
        'Target: ${targetAudioDb.round()} dB)';

    final String visionDetail = isCameraAvailable
        ? ' | Cam: $cameraConfidence% ($cameraArm, Confirmed: $isCameraConfirmed)'
        : ' | Cam: Unavailable';

    return '$tag | $audioDetail | $vibeDetail$visionDetail';
  }

  Map<String, dynamic> toMap() {
    return {
      'timestampMs': timestampMs,
      'peakAudioDb': peakAudioDb,
      'baselineAudioDb': baselineAudioDb,
      'audioRiseDb': audioRiseDb,
      'targetAudioDb': targetAudioDb,
      'vibrationPeakMag': vibrationPeakMag,
      'vibrationLiveMag': vibrationLiveMag,
      'vibrationThreshold': vibrationThreshold,
      'cameraConfidence': cameraConfidence,
      'cameraArm': cameraArm,
      'isCameraConfirmed': isCameraConfirmed,
      'isCameraAvailable': isCameraAvailable,
      'isValidPunch': isValidPunch,
      'isCandidate': isCandidate,
      'isRejected': isRejected,
      'decisionCode': decisionCode,
      'reasonLabel': reasonLabel,
      'sessionMode': sessionMode,
      'mountType': mountType,
      'isVibrationGateEnabled': isVibrationGateEnabled,
      'isVisionConfirmationRequired': isVisionConfirmationRequired,
      'refractoryElapsedMs': refractoryElapsedMs,
    };
  }

  @override
  List<Object?> get props => [
        timestampMs,
        peakAudioDb,
        baselineAudioDb,
        audioRiseDb,
        targetAudioDb,
        vibrationPeakMag,
        vibrationLiveMag,
        vibrationThreshold,
        cameraConfidence,
        cameraArm,
        isCameraConfirmed,
        isCameraAvailable,
        isValidPunch,
        isCandidate,
        isRejected,
        decisionCode,
        reasonLabel,
        sessionMode,
        mountType,
        isVibrationGateEnabled,
        isVisionConfirmationRequired,
        refractoryElapsedMs,
      ];
}
