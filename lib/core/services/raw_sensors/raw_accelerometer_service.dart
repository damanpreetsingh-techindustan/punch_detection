import 'dart:async';
import 'package:flutter/services.dart';
import '../../../detection_core/timing/clock_offset_estimator.dart';
import '../../utils/monotonic_clock.dart';

/// One raw accelerometer reading (gravity included), m/s².
class RawAccelSample {
  /// Time on the detection clock (`MonotonicClock.epochUs`), from the sensor
  /// event timestamp (not the arrival time).
  final int tUs;

  /// Native sensor event timestamp (Android elapsedRealtimeNanos, iOS uptime).
  final int sensorNs;

  final double x;
  final double y;
  final double z;

  const RawAccelSample({
    required this.tUs,
    required this.sensorNs,
    required this.x,
    required this.y,
    required this.z,
  });
}

/// Full-rate raw accelerometer through the app's own native channel
/// (`RawSensorChannels.kt` / `AppDelegate.swift`): Android TYPE_ACCELEROMETER at
/// SENSOR_DELAY_FASTEST, iOS CoreMotion at 100 Hz. `sensors_plus` at
/// gameInterval (50 Hz, arrival-time stamps) is not good enough for impacts.
class RawAccelerometerService {
  RawAccelerometerService({
    this.eventSource,
    int Function()? nowUs,
    ClockOffsetEstimator? offsetEstimator,
  }) : _nowUs = nowUs ?? MonotonicClock.epochUs,
       _offset = offsetEstimator ?? ClockOffsetEstimator();

  static const EventChannel _channel = EventChannel('hyper_hitter/raw_accel');

  /// Native event stream; tests inject a fake one (defaults to the channel).
  final Stream<Object?>? eventSource;
  final int Function() _nowUs;
  final ClockOffsetEstimator _offset;
  final StreamController<RawAccelSample> _samples =
      StreamController<RawAccelSample>.broadcast();
  StreamSubscription<Object?>? _subscription;

  Map<String, Object?> _info = const <String, Object?>{};
  String? _error;
  int _count = 0;
  int? _firstSensorNs;
  int? _lastSensorNs;
  int _batches = 0;

  Stream<RawAccelSample> get samples => _samples.stream;
  bool get isRunning => _subscription != null;
  int get sampleCount => _count;
  ClockOffsetEstimator get clockOffset => _offset;

  /// Rate measured from the sensor timestamps.
  double? get achievedRateHz {
    final int? first = _firstSensorNs;
    final int? last = _lastSensorNs;
    if (first == null || last == null || last <= first || _count < 2) {
      return null;
    }
    return (_count - 1) * 1e9 / (last - first);
  }

  Map<String, Object?> get diagnostics => <String, Object?>{
    'info': _info,
    'error': _error,
    'samples': _count,
    'batches': _batches,
    'achievedRateHz': achievedRateHz,
    'clockOffsetUs': _offset.offsetUs,
    'medianExtraLatencyUs': _offset.medianExtraLatencyUs,
  };

  Future<bool> start() async {
    if (_subscription != null) return true;
    try {
      final Stream<Object?> source =
          eventSource ?? _channel.receiveBroadcastStream();
      _subscription = source.listen(
        handleEvent,
        onError: (Object error) => _error = error.toString(),
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Parses one native event (public for tests).
  void handleEvent(Object? event) {
    if (event is! Map) return;
    final Object? type = event['type'];
    if (type == 'info') {
      _info = event.map(
        (Object? k, Object? v) => MapEntry<String, Object?>(k.toString(), v),
      );
      return;
    }
    if (type != 'batch') return;
    final int receivedUs = _nowUs();
    final List<Object?> t = _list(event['t']);
    final List<Object?> x = _list(event['x']);
    final List<Object?> y = _list(event['y']);
    final List<Object?> z = _list(event['z']);
    final Object? now = event['now'];
    if (now is int) {
      _offset.addObservation(nativeUs: now ~/ 1000, receivedUs: receivedUs);
    }
    _batches++;
    final int n = t.length;
    for (
      int i = 0;
      i < n && i < x.length && i < y.length && i < z.length;
      i++
    ) {
      final int sensorNs = (t[i]! as num).toInt();
      final int tUs =
          _offset.toDetectionUs(sensorNs ~/ 1000) ?? receivedUs; // no sync yet
      _count++;
      _firstSensorNs ??= sensorNs;
      _lastSensorNs = sensorNs;
      if (!_samples.isClosed) {
        _samples.add(
          RawAccelSample(
            tUs: tUs,
            sensorNs: sensorNs,
            x: (x[i]! as num).toDouble(),
            y: (y[i]! as num).toDouble(),
            z: (z[i]! as num).toDouble(),
          ),
        );
      }
    }
  }

  /// Native arrays arrive as Int64List / Float64List (Android) or plain lists
  /// (iOS); all are Lists.
  static List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

  Future<void> dispose() async {
    await stop();
    await _samples.close();
  }
}
