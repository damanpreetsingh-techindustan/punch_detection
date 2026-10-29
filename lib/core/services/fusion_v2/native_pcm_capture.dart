import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../../detection_core/timing/clock_offset_estimator.dart';
import '../../utils/monotonic_clock.dart';

/// One buffer from the low-latency native capture, on the detection clock.
class PcmBatch {
  final Int16List samples;
  final int sampleRate;

  /// Time of samples[0] (detection clock µs), from the audio HAL timestamp
  /// when the platform gives one, else from the arrival time.
  final int firstSampleUs;
  final int arrivalUs;

  /// Which time source [firstSampleUs] came from: hal | buffer | arrival.
  final String timeSource;

  const PcmBatch({
    required this.samples,
    required this.sampleRate,
    required this.firstSampleUs,
    required this.arrivalUs,
    required this.timeSource,
  });
}

/// Low-latency microphone for fusionV2 (`PcmCapture.kt`, `AppDelegate.swift`):
/// Android AudioRecord read in 10 ms pieces, iOS AVAudioEngine sink node with
/// a 5 ms IO buffer. Native times are mapped onto the detection clock with a
/// min-latency clock-offset estimator.
class NativePcmCapture {
  NativePcmCapture({
    this.eventSource,
    int Function()? nowUs,
    ClockOffsetEstimator? offset,
  }) : _nowUs = nowUs ?? MonotonicClock.epochUs,
       _offset = offset ?? ClockOffsetEstimator();

  static const EventChannel _channel = EventChannel('hyper_hitter/pcm_capture');

  /// Native event stream; tests inject a fake one.
  final Stream<Object?>? eventSource;
  final int Function() _nowUs;
  final ClockOffsetEstimator _offset;
  final StreamController<PcmBatch> _batches =
      StreamController<PcmBatch>.broadcast();
  StreamSubscription<Object?>? _subscription;
  Map<String, Object?> _info = const <String, Object?>{};
  String? _error;
  int _batchCount = 0;
  int _samples = 0;
  int? _firstArrivalUs;
  int? _lastArrivalUs;

  Stream<PcmBatch> get batches => _batches.stream;
  bool get isRunning => _subscription != null;

  Map<String, Object?> get diagnostics => <String, Object?>{
    'info': _info,
    'error': _error,
    'batches': _batchCount,
    'samples': _samples,
    'clockOffsetUs': _offset.offsetUs,
    'medianExtraLatencyUs': _offset.medianExtraLatencyUs,
    'measuredRateHz':
        _firstArrivalUs == null ||
            _lastArrivalUs == null ||
            _lastArrivalUs! <= _firstArrivalUs!
        ? null
        : _samples * 1e6 / (_lastArrivalUs! - _firstArrivalUs!),
  };

  /// [source]: mic | voiceRecognition | unprocessed (Android);
  /// [measurement]: iOS measurement mode.
  Future<bool> start({
    String source = 'mic',
    bool measurement = false,
    int sampleRate = 16000,
  }) async {
    if (_subscription != null) return true;
    try {
      final Stream<Object?> stream =
          eventSource ??
          _channel.receiveBroadcastStream(<String, Object?>{
            'sampleRate': sampleRate,
            'framesPerRead': sampleRate ~/ 100,
            'source': source,
            'measurement': measurement,
          });
      _subscription = stream.listen(
        handleEvent,
        onError: (Object e) => _error = e.toString(),
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
    if (type != 'pcm') return;
    final int arrivalUs = _nowUs();
    final Object? data = event['data'];
    final Uint8List bytes = data is Uint8List ? data : Uint8List(0);
    final int rate = (event['sampleRate'] as num? ?? 16000).toInt();
    final int count = bytes.length ~/ 2;
    if (count == 0) return;
    final int nowNs = (event['now'] as num).toInt();
    _offset.addObservation(nativeUs: nowNs ~/ 1000, receivedUs: arrivalUs);

    final int tsNs = (event['tsNs'] as num? ?? -1).toInt();
    final int tsFrame = (event['tsFrame'] as num? ?? -1).toInt();
    final int frame = (event['frame'] as num? ?? -1).toInt();
    int firstNativeNs;
    String source;
    if (tsNs >= 0 && tsFrame >= 0 && frame >= 0) {
      firstNativeNs = tsNs + ((frame - tsFrame) * 1e9 / rate).round();
      source = 'hal';
    } else if (tsNs >= 0) {
      firstNativeNs = tsNs; // iOS: host time of the buffer's first frame
      source = 'buffer';
    } else {
      firstNativeNs = nowNs - (count * 1e9 / rate).round();
      source = 'arrival';
    }
    final int firstUs =
        _offset.toDetectionUs(firstNativeNs ~/ 1000) ??
        arrivalUs - (count * 1e6 / rate).round();

    final Int16List samples = Int16List(count);
    final ByteData view = ByteData.sublistView(bytes);
    for (int i = 0; i < count; i++) {
      samples[i] = view.getInt16(2 * i, Endian.little);
    }
    _batchCount++;
    _samples += count;
    _firstArrivalUs ??= arrivalUs;
    _lastArrivalUs = arrivalUs;
    if (!_batches.isClosed) {
      _batches.add(
        PcmBatch(
          samples: samples,
          sampleRate: rate,
          firstSampleUs: firstUs,
          arrivalUs: arrivalUs,
          timeSource: source,
        ),
      );
    }
  }

  Future<void> dispose() async {
    await stop();
    await _batches.close();
  }
}
