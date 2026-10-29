/// Represents a detected physical impact knock derived from sudden sample-to-sample
/// acceleration changes (jerk), independent of low-frequency pendulum bag swings.
class VibrationKnock {
  /// Unique incremental ID for tracking and logging.
  final int id;

  /// Sensor timestamp (epoch ms) when the knock occurred.
  final int timestampMs;

  /// Instantaneous 3D vector or scalar delta from the previous sample (m/s²).
  final double deltaMag;

  /// Peak raw acceleration magnitude recorded at the moment of the knock (m/s²).
  final double rawMag;

  /// Whether this knock has been permanently consumed by a confirmed punch.
  bool isUsed;

  /// Temporary ear-mark for an active pending impact window (audio timestamp).
  int? claimedByAudioTsMs;

  /// Punch sequence number that permanently consumed this knock.
  int? confirmedPunchNo;

  VibrationKnock({
    required this.id,
    required this.timestampMs,
    required this.deltaMag,
    required this.rawMag,
    this.isUsed = false,
    this.claimedByAudioTsMs,
    this.confirmedPunchNo,
  });

  @override
  String toString() =>
      'VibrationKnock(#$id @ ${timestampMs}ms, Δ=${deltaMag.toStringAsFixed(2)}, raw=${rawMag.toStringAsFixed(2)}, used=$isUsed, claimedBy=$claimedByAudioTsMs)';
}
