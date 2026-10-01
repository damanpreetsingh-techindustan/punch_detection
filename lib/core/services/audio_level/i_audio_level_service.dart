import 'dart:async';

/// Abstract Contract interface for Real-Time Microphone Audio Level (Decibel) Sensing.
///
/// Adheres to:
/// - Dependency Inversion Principle (DIP): High-level business logic & UI controllers
///   depend on this abstraction rather than concrete audio packages.
/// - Interface Segregation Principle (ISP): Exposes only essential decibel telemetry
///   and lifecycle control methods.
/// - Open/Closed Principle (OCP): Enables plugging in alternative audio drivers
///   (e.g., Record, NoiseMeter, Mock/Simulated) without changing consumer code.
abstract class IAudioLevelService {
  /// Stream of real-time decibel (dB) level readings.
  Stream<double> get decibelStream;

  /// Current instantaneous decibel reading.
  double get currentDecibels;

  /// True if active microphone sampling is currently in progress.
  bool get isMonitoring;

  /// True if Bluetooth earbuds, AirPods, or headset devices are connected.
  bool get isEarbudsConnected;

  /// Queries native hardware audio devices to check if earbuds/headset are connected.
  Future<bool> checkEarbudsConnected();

  /// Starts listening to microphone hardware and streaming decibel updates.
  /// [sampleIntervalMs] defines the sampling rate interval (default: 50ms).
  /// Returns `true` if monitoring started successfully, `false` if permission was denied or failed.
  Future<bool> startMonitoring({int sampleIntervalMs = 50});

  /// Pauses/stops microphone listening to conserve battery and release hardware resources.
  Future<void> stopMonitoring();

  /// Updates the native audio sampling interval dynamically on the fly (e.g. 10ms, 20ms, 50ms).
  Future<void> updateSampleInterval(int newIntervalMs);

  /// Releases all stream controllers, subscriptions, and native resources.
  void dispose();
}
