import 'device_stability_models.dart';

/// Abstract Contract interface for Device Stability & Motion Tracking.
/// Adheres to Dependency Inversion (DIP) & Interface Segregation (ISP).
abstract class IDeviceStabilityService {
  /// True if device is considered sufficiently stable for reliable ML Kit pose movement tracking.
  bool get isDeviceStable;

  /// Current discrete stability state.
  DeviceStabilityState get currentState;

  /// Current telemetry metrics snapshot.
  DeviceStabilityMetrics get currentMetrics;

  /// Stream of real-time stability metric updates.
  Stream<DeviceStabilityMetrics> get metricsStream;

  /// Starts listening to hardware accelerometer & gyroscope sensors.
  void startMonitoring();

  /// Pauses/Stops hardware sensor listeners to save battery.
  void stopMonitoring();

  /// Disposes resources.
  void dispose();
}
