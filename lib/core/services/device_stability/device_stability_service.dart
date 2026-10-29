import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../../utils/constants.dart';
import 'device_stability_models.dart';
import 'i_device_stability_service.dart';
import '../../utils/monotonic_clock.dart';

/// Concrete implementation of [IDeviceStabilityService] using `sensors_plus`.
/// Fuses UserAccelerometer, Gyroscope, and Raw Accelerometer Tilt Deltas
/// with Fast-Attack and a 1500ms Hysteresis Hold Timer to prevent rapid flip-flopping.
class DeviceStabilityService implements IDeviceStabilityService {
  final StreamController<DeviceStabilityMetrics> _metricsStreamController =
      StreamController<DeviceStabilityMetrics>.broadcast();

  StreamSubscription<UserAccelerometerEvent>? _userAccelSubscription;
  StreamSubscription<AccelerometerEvent>? _rawAccelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  DeviceStabilityMetrics _currentMetrics = DeviceStabilityMetrics.initial();

  double _latestLinearAccelMag = 0.0;
  double _latestGyroMag = 0.0;
  double _latestTiltDeltaMag = 0.0;

  double _smoothedLinearAccel = 0.0;
  double _smoothedGyro = 0.0;

  // Previous raw accelerometer readings for gravity tilt delta calculation
  double _prevRawX = 0.0;
  double _prevRawY = 0.0;
  double _prevRawZ = 0.0;
  bool _hasPrevRawAccel = false;

  bool _isMonitoring = false;
  int _lastMotionSpikeTimestampMs = 0;

  /// Hysteresis hold period: Once motion is detected, device remains unstable/vibrating
  /// for at least 1500ms after the last motion spike.
  static const int holdPeriodMs = 1500;

  // Sensitivity Threshold Configurations (Calibrated for strict handheld rejection)
  double maxStableAccel = 0.25; // m/s^2 (Mounted threshold)
  double maxStableGyro = 0.15; // rad/s (Mounted threshold)
  double maxUnstableAccel = 0.55; // m/s^2 (Handheld unstable threshold)
  double maxUnstableGyro = 0.30; // rad/s (Handheld unstable threshold)
  double maxUnstableTiltDelta = 0.40; // m/s^2 (Handheld tilt shift threshold)

  // DC-block High-Pass Filter components (removes static gravity bias & resting sensor offset)
  double _dcX = 0.0;
  double _dcY = 0.0;
  double _dcZ = 0.0;
  bool _isDcInitialized = false;

  // UI Throttle to prevent Choreographer frame skipping (~20 FPS or on state change)
  int _lastMetricsEmitTimestampMs = 0;
  DeviceStabilityState _lastEmittedState = DeviceStabilityState.unknown;

  @override
  bool get isDeviceStable {
    if (!AppConstants.enableDeviceStabilityCheck) return true;
    return _currentMetrics.isStable;
  }

  @override
  DeviceStabilityState get currentState {
    if (!AppConstants.enableDeviceStabilityCheck) {
      return DeviceStabilityState.stable;
    }
    return _currentMetrics.state;
  }

  @override
  DeviceStabilityMetrics get currentMetrics => _currentMetrics;

  @override
  Stream<DeviceStabilityMetrics> get metricsStream =>
      _metricsStreamController.stream;

  @override
  void startMonitoring() {
    if (!AppConstants.enableDeviceStabilityCheck) {
      _updateMetrics(
        state: DeviceStabilityState.stable,
        statusMessage: 'Stability check disabled globally',
      );
      return;
    }

    if (_isMonitoring) return;
    _isMonitoring = true;

    try {
      // 1. Linear Accelerometer Stream (Filtered with Adaptive DC-Block)
      _userAccelSubscription = userAccelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (UserAccelerometerEvent event) {
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

          final double acX = event.x - _dcX;
          final double acY = event.y - _dcY;
          final double acZ = event.z - _dcZ;
          final double dynamicMag = sqrt(acX * acX + acY * acY + acZ * acZ);

          // Deadband: micro-vibrations & sensor thermal noise < 0.08 m/s² are clamped to 0.0
          const double deadband = 0.08;
          final double effectiveLinearMag =
              dynamicMag < deadband ? 0.0 : dynamicMag;
          _latestLinearAccelMag = effectiveLinearMag;

          // Fast Attack (instant peak) + Slow Decay
          if (effectiveLinearMag > _smoothedLinearAccel) {
            _smoothedLinearAccel = effectiveLinearMag;
          } else {
            _smoothedLinearAccel =
                (_smoothedLinearAccel * 0.85) + (effectiveLinearMag * 0.15);
            if (_smoothedLinearAccel < 0.01) {
              _smoothedLinearAccel = 0.0;
            }
          }
          _evaluateState();
        },
        onError: (_) {
          _updateMetrics(
            state: DeviceStabilityState.stable,
            statusMessage: 'Accelerometer unavailable — assuming stable',
          );
        },
      );

      // 2. Raw Accelerometer Stream (Monitors tilt & orientation shifts in hand)
      _rawAccelSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen((
        AccelerometerEvent event,
      ) {
        if (_hasPrevRawAccel) {
          final double dx = event.x - _prevRawX;
          final double dy = event.y - _prevRawY;
          final double dz = event.z - _prevRawZ;
          final double rawTilt = sqrt(dx * dx + dy * dy + dz * dz);
          _latestTiltDeltaMag = rawTilt < 0.08 ? 0.0 : rawTilt;
        } else {
          _hasPrevRawAccel = true;
        }
        _prevRawX = event.x;
        _prevRawY = event.y;
        _prevRawZ = event.z;
        _evaluateState();
      }, onError: (_) {});

      // 3. Gyroscope Stream (Angular velocity / rotational movement in hand)
      _gyroSubscription = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen((GyroscopeEvent event) {
        final double rawMag = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        // Gyro deadband for ambient thermal drift (< 0.03 rad/s)
        final double effectiveGyro = rawMag < 0.03 ? 0.0 : rawMag;
        _latestGyroMag = effectiveGyro;

        // Fast Attack (instant peak) + Slow Decay
        if (effectiveGyro > _smoothedGyro) {
          _smoothedGyro = effectiveGyro;
        } else {
          _smoothedGyro = (_smoothedGyro * 0.85) + (effectiveGyro * 0.15);
          if (_smoothedGyro < 0.01) {
            _smoothedGyro = 0.0;
          }
        }
        _evaluateState();
      }, onError: (_) {});
    } catch (_) {
      _updateMetrics(
        state: DeviceStabilityState.stable,
        statusMessage: 'Device sensors unavailable — defaulting to stable',
      );
    }
  }

  void _evaluateState() {
    final int nowMs = MonotonicClock.epochMs();

    // Check if current instant readings exceed handheld motion thresholds
    final bool isHandheldMotionSpike =
        _latestLinearAccelMag >= maxUnstableAccel ||
        _latestGyroMag >= maxUnstableGyro ||
        _latestTiltDeltaMag >= maxUnstableTiltDelta ||
        _smoothedLinearAccel >= maxUnstableAccel ||
        _smoothedGyro >= maxUnstableGyro;

    final bool isMinorMotionSpike =
        _latestLinearAccelMag >= maxStableAccel ||
        _latestGyroMag >= maxStableGyro ||
        _smoothedLinearAccel >= maxStableAccel ||
        _smoothedGyro >= maxStableGyro;

    if (isHandheldMotionSpike || isMinorMotionSpike) {
      _lastMotionSpikeTimestampMs = nowMs;
    }

    final bool isWithinHoldPeriod =
        (nowMs - _lastMotionSpikeTimestampMs) < holdPeriodMs;

    DeviceStabilityState state = DeviceStabilityState.stable;
    String statusMessage = '🟢 Device Mounted & Stable';

    if (isHandheldMotionSpike ||
        (isWithinHoldPeriod &&
            (_smoothedLinearAccel >= maxUnstableAccel * 0.7 ||
                _smoothedGyro >= maxUnstableGyro * 0.7))) {
      state = DeviceStabilityState.unstableHandheld;
      statusMessage = '🔴 Device Shaking / Handheld Motion Detected';
    } else if (isWithinHoldPeriod || isMinorMotionSpike) {
      state = DeviceStabilityState.minorVibration;
      statusMessage = '🟡 Device Settling / Minor Table Vibration';
    }

    _updateMetrics(state: state, statusMessage: statusMessage);
  }

  void _updateMetrics({
    required DeviceStabilityState state,
    required String statusMessage,
  }) {
    final int nowMs = MonotonicClock.epochMs();
    _currentMetrics = DeviceStabilityMetrics(
      linearAccelMag: _latestLinearAccelMag,
      angularVelMag: _latestGyroMag,
      smoothedLinearAccel: _smoothedLinearAccel,
      smoothedAngularVel: _smoothedGyro,
      state: state,
      timestampMs: nowMs,
      statusMessage: statusMessage,
    );

    // Throttle UI stream emissions to ~20 FPS (every 50ms) OR on state changes to eliminate frame drops
    final bool isStateChanged = state != _lastEmittedState;
    final bool isThrottled = (nowMs - _lastMetricsEmitTimestampMs) >= 50;

    if ((isStateChanged || isThrottled) && !_metricsStreamController.isClosed) {
      _lastMetricsEmitTimestampMs = nowMs;
      _lastEmittedState = state;
      _metricsStreamController.add(_currentMetrics);
    }
  }

  @override
  void stopMonitoring() {
    _isMonitoring = false;
    _userAccelSubscription?.cancel();
    _userAccelSubscription = null;
    _rawAccelSubscription?.cancel();
    _rawAccelSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _isDcInitialized = false;
    _hasPrevRawAccel = false;
    _latestLinearAccelMag = 0.0;
    _latestGyroMag = 0.0;
    _smoothedLinearAccel = 0.0;
    _smoothedGyro = 0.0;
  }

  @override
  void dispose() {
    stopMonitoring();
    _metricsStreamController.close();
  }
}
