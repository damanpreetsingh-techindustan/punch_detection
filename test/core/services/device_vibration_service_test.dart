import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/device_vibration/i_device_vibration_service.dart';

class MockDeviceVibrationService implements IDeviceVibrationService {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();
  double _currentVibration = 0.0;
  double _peakVibration = 0.0;
  int _peakTimestampMs = 0;
  int _lastVibeTimestampMs = 0;

  @override
  Stream<double> get vibrationMagnitudeStream => _controller.stream;

  @override
  double get currentVibrationMagnitude => _currentVibration;

  @override
  double get recentPeakVibrationMagnitude {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _peakTimestampMs <= 600) {
      return _peakVibration;
    }
    return _currentVibration;
  }

  @override
  int get lastVibrationTimestampMs => _lastVibeTimestampMs;

  @override
  bool hasRecentVibration(int nowMs, {int maxAgeMs = 600}) {
    if (_lastVibeTimestampMs <= 0) return false;
    return (nowMs - _lastVibeTimestampMs) <= maxAgeMs;
  }

  void simulateImpact(double rawMag, int timestampMs) {
    _currentVibration = rawMag;
    if (timestampMs - _peakTimestampMs > 600 || rawMag > _peakVibration) {
      _peakVibration = rawMag;
      _peakTimestampMs = timestampMs;
    }
    if (rawMag >= 0.05) {
      _lastVibeTimestampMs = timestampMs;
    }
  }

  /// Simulates raw hardware accelerometer event applying stationary deadband and envelope decay
  void simulateSensorEvent(double rawMag, int timestampMs) {
    const double stationaryNoiseFloor = 0.10;
    final double effectiveMag = rawMag < stationaryNoiseFloor ? 0.0 : rawMag;

    if (effectiveMag > _currentVibration) {
      _currentVibration = effectiveMag;
    } else {
      _currentVibration = (_currentVibration * 0.70) + (effectiveMag * 0.30);
      if (_currentVibration < 0.01) {
        _currentVibration = 0.0;
      }
    }

    if (timestampMs - _peakTimestampMs > 600) {
      _peakVibration = effectiveMag;
      _peakTimestampMs = timestampMs;
    } else if (effectiveMag > _peakVibration) {
      _peakVibration = effectiveMag;
      _peakTimestampMs = timestampMs;
    }

    if (effectiveMag >= 0.18) {
      _lastVibeTimestampMs = timestampMs;
    }
  }

  @override
  void startMonitoring({double minVibrationThreshold = 0.18}) {}

  @override
  void stopMonitoring() {}

  @override
  void resetMagnitude() {
    _currentVibration = 0.0;
    _peakVibration = 0.0;
    _peakTimestampMs = 0;
    _lastVibeTimestampMs = 0;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  group('IDeviceVibrationService Peak Magnitude & Noise Gate Tests', () {
    test('1. simulateImpact tracks peak shockwave in window', () {
      final service = MockDeviceVibrationService();
      final int now = DateTime.now().millisecondsSinceEpoch;

      service.simulateImpact(0.25, now);
      expect(service.recentPeakVibrationMagnitude, equals(0.25));
      expect(service.hasRecentVibration(now), isTrue);

      // Instantaneous decays, but windowed peak persists
      service.simulateImpact(0.02, now + 50);
      expect(service.currentVibrationMagnitude, equals(0.02));
      expect(service.recentPeakVibrationMagnitude, equals(0.25));

      // Reset magnitude clears both
      service.resetMagnitude();
      expect(service.recentPeakVibrationMagnitude, equals(0.0));
      expect(service.hasRecentVibration(now + 60), isFalse);
    });

    test('2. Stationary MEMS noise & acoustic clap pressure (<0.10 m/s²) outputs clean 0.00 m/s²', () {
      final service = MockDeviceVibrationService();
      final int now = DateTime.now().millisecondsSinceEpoch;

      // Simulate typical resting noise (0.02 to 0.045 m/s²)
      service.simulateSensorEvent(0.035, now);
      expect(service.currentVibrationMagnitude, equals(0.0));
      expect(service.recentPeakVibrationMagnitude, equals(0.0));
      expect(service.hasRecentVibration(now), isFalse);

      // Simulate loud hand clap / shout acoustic air pressure wave (0.06 to 0.085 m/s²)
      service.simulateSensorEvent(0.082, now + 10);
      expect(service.currentVibrationMagnitude, equals(0.0));
      expect(service.recentPeakVibrationMagnitude, equals(0.0));
      expect(service.hasRecentVibration(now + 10), isFalse);
    });

    test('3. Real physical impact shockwave (>=0.18 m/s²) registers peak', () {
      final service = MockDeviceVibrationService();
      final int now = DateTime.now().millisecondsSinceEpoch;

      // Real punch strike shockwave at 0.35 m/s²
      service.simulateSensorEvent(0.35, now);
      expect(service.currentVibrationMagnitude, equals(0.35));
      expect(service.recentPeakVibrationMagnitude, equals(0.35));
      expect(service.hasRecentVibration(now), isTrue);

      // Ensuing sample decays with 70% retention
      service.simulateSensorEvent(0.0, now + 20);
      expect(service.currentVibrationMagnitude, closeTo(0.245, 0.001));
      // Windowed peak remains 0.35 for fusion coincidence sync
      expect(service.recentPeakVibrationMagnitude, equals(0.35));
    });
  });
}
