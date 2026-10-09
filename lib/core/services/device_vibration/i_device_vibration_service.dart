import 'dart:async';

/// Abstract Contract interface for Device Impact Vibration Detection.
/// Adheres to Dependency Inversion (DIP) & Interface Segregation (ISP).
abstract class IDeviceVibrationService {
  /// Stream of real-time linear acceleration magnitude spikes (in m/s^2).
  Stream<double> get vibrationMagnitudeStream;

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
