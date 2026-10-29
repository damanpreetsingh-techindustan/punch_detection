import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'i_device_vibration_service.dart';
import '../../utils/monotonic_clock.dart';

/// Concrete implementation of [IDeviceVibrationService] using `sensors_plus`.
/// Monitors high-frequency linear acceleration shockwave spikes caused by physical impacts on the bag/mount.
class DeviceVibrationService implements IDeviceVibrationService {
  static DeviceVibrationService? _activeGlobalService;

  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  final StreamController<double> _vibrationStreamController =
      StreamController<double>.broadcast();

  double _currentVibrationMagnitude = 0.0;
  double _recentPeakMagnitude = 0.0;
  int _recentPeakTimestampMs = 0;
  int _lastVibrationTimestampMs = 0;
  double _minVibrationThreshold = 0.18; // m/s^2 linear accel threshold
  bool _isMonitoring = false;

  // DC-block High-Pass Filter components (removes static gravity bias & resting sensor offset)
  double _dcX = 0.0;
  double _dcY = 0.0;
  double _dcZ = 0.0;
  bool _isDcInitialized = false;

  // UI Throttle to prevent Choreographer frame skipping (capped at ~30 FPS or significant jumps)
  int _lastUiEmitTimestampMs = 0;
  double _lastEmittedMagnitude = 0.0;

  @override
  Stream<double> get vibrationMagnitudeStream =>
      _vibrationStreamController.stream;

  @override
  double get currentVibrationMagnitude => _currentVibrationMagnitude;

  @override
  double get recentPeakVibrationMagnitude {
    final int nowMs = MonotonicClock.epochMs();
    if (nowMs - _recentPeakTimestampMs <= 600) {
      return max(_recentPeakMagnitude, _currentVibrationMagnitude);
    }
    return _currentVibrationMagnitude;
  }

  @override
  int get lastVibrationTimestampMs => _lastVibrationTimestampMs;

  @override
  int get recentPeakTimestampMs => _recentPeakTimestampMs;

  @override
  bool hasRecentVibration(int nowMs, {int maxAgeMs = 600}) {
    if (_lastVibrationTimestampMs <= 0) return false;
    return (nowMs - _lastVibrationTimestampMs) <= maxAgeMs;
  }

  @override
  void startMonitoring({double minVibrationThreshold = 0.18}) {
    _minVibrationThreshold = minVibrationThreshold;
    if (_isMonitoring) return;

    try {
      if (_activeGlobalService != null && _activeGlobalService != this) {
        _activeGlobalService!.stopMonitoring();
      }
      _activeGlobalService = this;

      // Sample at 50Hz (gameInterval, 20ms) to reliably catch 20-30ms punch shockwaves
      // without overloading the Android main thread / Choreographer.
      _accelSubscription =
          userAccelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen((UserAccelerometerEvent event) {
            final int nowMs = MonotonicClock.epochMs();

            // 1. Adaptive DC-Block High-Pass Filter:
            // Automatically measures and subtracts static gravity residuals and mounting tilt offsets.
            // When device is stationary, AC deviation is 0.00 m/s², eliminating all baseline fluctuations.
            if (!_isDcInitialized) {
              _dcX = event.x;
              _dcY = event.y;
              _dcZ = event.z;
              _isDcInitialized = true;
            } else {
              const double alpha = 0.95;
              _dcX = (_dcX * alpha) + (event.x * (1.0 - alpha));
              _dcY = (_dcY * alpha) + (event.y * (1.0 - alpha));
              _dcZ = (_dcZ * alpha) + (event.z * (1.0 - alpha));
            }

            // Compute dynamic AC acceleration (true mechanical vibration)
            final double acX = event.x - _dcX;
            final double acY = event.y - _dcY;
            final double acZ = event.z - _dcZ;
            final double dynamicMag = sqrt(acX * acX + acY * acY + acZ * acZ);

            // 2. Deadband Filter (cancels micro-jitter / acoustic noise / sensor noise floor < 0.10 m/s²)
            const double deadband = 0.10;
            final double effectiveMag = dynamicMag < deadband
                ? 0.0
                : dynamicMag;

            // 3. Fast Attack + Envelope Decay for impact shockwave detection
            if (effectiveMag > _currentVibrationMagnitude) {
              _currentVibrationMagnitude = effectiveMag;
            } else {
              _currentVibrationMagnitude =
                  (_currentVibrationMagnitude * 0.70) + (effectiveMag * 0.30);
              if (_currentVibrationMagnitude < 0.01) {
                _currentVibrationMagnitude = 0.0;
              }
            }

            // 4. Sliding 600ms Peak Window for Multi-Sensor Coincidence Matching
            if (nowMs - _recentPeakTimestampMs > 600) {
              _recentPeakMagnitude = effectiveMag;
              _recentPeakTimestampMs = nowMs;
            } else if (effectiveMag > _recentPeakMagnitude) {
              _recentPeakMagnitude = effectiveMag;
              _recentPeakTimestampMs = nowMs;
            }

            // 5. Throttled UI Streaming (~30 FPS or on notable impact changes >= 0.02)
            // Prevents Choreographer frame drops while providing instantaneous punch response.
            final bool shouldEmit =
                (nowMs - _lastUiEmitTimestampMs >= 33) ||
                (_currentVibrationMagnitude - _lastEmittedMagnitude).abs() >=
                    0.02;

            if (shouldEmit && !_vibrationStreamController.isClosed) {
              _lastUiEmitTimestampMs = nowMs;
              _lastEmittedMagnitude = _currentVibrationMagnitude;
              _vibrationStreamController.add(_currentVibrationMagnitude);
            }

            // 6. Register physical vibration impulse timestamp if dynamic spike exceeds threshold
            if (effectiveMag >= _minVibrationThreshold) {
              _lastVibrationTimestampMs = nowMs;
            }
          }, onError: (_) {});

      _isMonitoring = true;
    } catch (_) {}
  }

  @override
  void stopMonitoring() {
    _isMonitoring = false;
    if (_activeGlobalService == this) {
      _activeGlobalService = null;
    }

    try {
      _accelSubscription?.cancel();
    } catch (_) {}
    _accelSubscription = null;
  }

  @override
  void consumeRecentPeak() {
    _currentVibrationMagnitude = 0.0;
    _recentPeakMagnitude = 0.0;
    _recentPeakTimestampMs = 0;
    _lastVibrationTimestampMs = 0;
  }

  @override
  void resetMagnitude() {
    _currentVibrationMagnitude = 0.0;
    _recentPeakMagnitude = 0.0;
    _recentPeakTimestampMs = 0;
    _lastVibrationTimestampMs = 0;
    _lastEmittedMagnitude = 0.0;
    if (!_vibrationStreamController.isClosed) {
      _vibrationStreamController.add(0.0);
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    _vibrationStreamController.close();
  }
}
