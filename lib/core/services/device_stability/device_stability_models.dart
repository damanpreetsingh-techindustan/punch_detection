enum DeviceStabilityState {
  /// Device is sitting on a stable surface or tripod with virtually zero motion.
  stable,

  /// Device is on a surface experiencing minor ambient vibrations (e.g. table tap, footsteps).
  /// Punch tracking remains fully enabled.
  minorVibration,

  /// Device is held in hand or undergoing significant physical shaking.
  /// Vision punch triggers are BLOCKED to avoid false pose triggers.
  unstableHandheld,

  /// Device sensors disabled or initializing.
  unknown,
}

class DeviceStabilityMetrics {
  final double linearAccelMag;
  final double angularVelMag;
  final double smoothedLinearAccel;
  final double smoothedAngularVel;
  final DeviceStabilityState state;
  final int timestampMs;
  final String statusMessage;

  const DeviceStabilityMetrics({
    required this.linearAccelMag,
    required this.angularVelMag,
    required this.smoothedLinearAccel,
    required this.smoothedAngularVel,
    required this.state,
    required this.timestampMs,
    required this.statusMessage,
  });

  factory DeviceStabilityMetrics.initial() {
    return DeviceStabilityMetrics(
      linearAccelMag: 0.0,
      angularVelMag: 0.0,
      smoothedLinearAccel: 0.0,
      smoothedAngularVel: 0.0,
      state: DeviceStabilityState.stable,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      statusMessage: 'Device Ready & Stable',
    );
  }

  bool get isStable =>
      state == DeviceStabilityState.stable ||
      state == DeviceStabilityState.minorVibration;
}
