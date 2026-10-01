/// Enums representing signal states across the three hardware sensors.
enum AudioSignalState {
  /// Strong onset decibel spike (>= +8 dB above ambient baseline)
  strong,

  /// Weak decibel spike (+4 dB to +8 dB above ambient baseline)
  weak,

  /// No decibel spike detected (< +4 dB above baseline)
  none,
}

enum VibrationSignalState {
  /// Strong physical impact sensed on accelerometer (magnitude >= 0.35)
  strong,

  /// Weak physical impact sensed on accelerometer (magnitude 0.15 to 0.35)
  weak,

  /// No physical impact sensed (< 0.15)
  none,
}

enum CameraSignalState {
  /// Vision tracking active and arm extension pose confirmed
  confirmed,

  /// Camera stream turned off, disabled, or unavailable
  unavailable,

  /// Camera active but pose rejected (e.g. invalid posture/misalignment)
  rejected,
}

enum PunchOutcome {
  /// Valid punch — increments primary punch count
  validPunch,

  /// Low confidence candidate — logged for auditing
  candidate,

  /// Rejected impact — not a punch
  notPunch,
}
