import 'dart:async';

/// One accelerometer reading, before throttling, for the session log.
class VibrationRawSample {
  /// Time the sensor measured it (epoch ms, from the sensor event).
  final int sensorMs;

  /// Time the reading reached Dart (epoch ms).
  final int arrivalMs;

  /// Magnitude after gravity / drift removal, before the deadband (m/s²).
  final double rawMag;

  /// Magnitude after the deadband (m/s²).
  final double effectiveMag;

  /// Smoothed envelope that detection uses (m/s²).
  final double envelope;

  /// Dynamic AC acceleration components along device axes (m/s²).
  final double x;
  final double y;
  final double z;

  const VibrationRawSample({
    required this.sensorMs,
    required this.arrivalMs,
    required this.rawMag,
    required this.effectiveMag,
    required this.envelope,
    this.x = 0.0,
    this.y = 0.0,
    this.z = 0.0,
  });
}

/// Abstract Contract interface for Device Impact Vibration Detection.
/// Adheres to Dependency Inversion (DIP) & Interface Segregation (ISP).
abstract class IDeviceVibrationService {
  /// Stream of real-time linear acceleration magnitude spikes (in m/s^2).
  Stream<double> get vibrationMagnitudeStream;

  /// Every accelerometer reading (not throttled), for logging only.
  Stream<VibrationRawSample> get rawSampleStream;

  /// Current smoothed vibration acceleration magnitude (in m/s^2).
  double get currentVibrationMagnitude;

  /// Windowed peak vibration acceleration magnitude recorded over the recent coincidence window (in m/s^2).
  /// Captures true physical impact shockwave before exponential decay occurs.
  double get recentPeakVibrationMagnitude;

  /// Timestamp of the last detected physical vibration impact (in milliseconds).
  int get lastVibrationTimestampMs;

  /// Returns true if a physical device vibration impulse occurred within the past [maxAgeMs].
  bool hasRecentVibration(int nowMs, {int maxAgeMs = 350});

  /// Starts listening to hardware accelerometer sensors.
  void startMonitoring({double minVibrationThreshold = 0.35});

  /// Stops monitoring hardware sensors to save battery.
  void stopMonitoring();

  /// Timestamp of the peak vibration recorded in the recent window.
  int get recentPeakTimestampMs;

  /// Consumes the recent peak magnitude after punch confirmation so lingering decay/oscillations cannot be recycled.
  void consumeRecentPeak();

  /// Resets peak accumulated magnitude to zero right after punch confirmation.
  void resetMagnitude();

  /// Disposes resources.
  void dispose();
}
