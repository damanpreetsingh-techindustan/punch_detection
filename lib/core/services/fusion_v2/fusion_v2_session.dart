import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../detection_core/config/detector_config.dart';
import '../../../detection_core/runtime/arm_motion_worker.dart';
import '../../../detection_core/runtime/fusion_worker.dart';
import '../../../detection_core/scoring/logistic_scorer.dart';
import '../raw_sensors/raw_accelerometer_service.dart';
import 'native_pcm_capture.dart';

/// Runs the fusionV2 detector for one session:
///
/// - the low-latency native microphone ([NativePcmCapture]) and the full-rate
///   raw accelerometer ([RawAccelerometerService]) feed a background isolate
///   that owns the detector core ([fusionWorkerMain]);
/// - camera frames go to a second isolate running the optical-flow prior
///   ([armMotionWorkerMain]), whose arm activity is forwarded to the detector;
/// - the UI isolate only relays buffers (no detection work) and receives the
///   decisions ("punch at time t") plus a periodic debug state.
class FusionV2Session {
  FusionV2Session({
    required this.mount,
    NativePcmCapture? pcm,
    required this.accel,
    this.useAccelerometer = true,
    this.useArmMotion = true,
  }) : pcm = pcm ?? NativePcmCapture();

  final MountProfile mount;
  final NativePcmCapture pcm;
  final RawAccelerometerService accel;
  final bool useAccelerometer;
  final bool useArmMotion;

  SendPort? _toWorker;
  SendPort? _toArm;
  ReceivePort? _fromWorker;
  ReceivePort? _fromArm;
  Isolate? _worker;
  Isolate? _armIsolate;
  StreamSubscription<PcmBatch>? _pcmSub;
  StreamSubscription<RawAccelSample>? _accelSub;
  final List<double> _accelBatch = <double>[];
  bool _armBusy = false;
  bool _started = false;

  final StreamController<Map<String, Object?>> _decisions =
      StreamController<Map<String, Object?>>.broadcast();
  final StreamController<Map<String, Object?>> _debug =
      StreamController<Map<String, Object?>>.broadcast();
  final StreamController<Map<String, Object?>> _calibration =
      StreamController<Map<String, Object?>>.broadcast();
  final StreamController<Map<String, Object?>> _arm =
      StreamController<Map<String, Object?>>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();

  /// `{type: decision, calibrating, decision: ImpactDecision.toMap()}`.
  Stream<Map<String, Object?>> get decisions => _decisions.stream;
  Stream<Map<String, Object?>> get debug => _debug.stream;
  Stream<Map<String, Object?>> get calibration => _calibration.stream;

  /// ArmMotionResult maps (also forwarded to the detector).
  Stream<Map<String, Object?>> get armResults => _arm.stream;
  Stream<String> get errors => _errors.stream;
  bool get isStarted => _started;

  /// Spawns the isolates and starts the sensors. [scorer] is the mount's
  /// weights (loaded from the asset by the caller); null = built-in defaults.
  Future<bool> start({
    ScorerSet? scorer,
    String audioSource = 'mic',
    bool measurementMode = false,
  }) async {
    if (_started) return true;
    _toWorker = await _spawn(fusionWorkerMain, _onWorkerMessage, isArm: false);
    final Completer<void> ready = Completer<void>();
    late final StreamSubscription<Map<String, Object?>> readySub;
    readySub = _readyEvents.stream.listen((_) {
      if (!ready.isCompleted) ready.complete();
      readySub.cancel();
    });
    _toWorker!.send(<String, Object?>{
      'op': 'init',
      'mount': mount.name,
      'scorer': scorer?.toJson(),
    });
    await ready.future.timeout(const Duration(seconds: 5));
    if (useArmMotion) {
      _toArm = await _spawn(armMotionWorkerMain, _onArmMessage, isArm: true);
    }

    _pcmSub = pcm.batches.listen((PcmBatch b) {
      _toWorker?.send(<String, Object?>{
        'op': 'pcm',
        'samples': b.samples,
        'rate': b.sampleRate,
        'firstUs': b.firstSampleUs,
      });
    });
    final bool micOk = await pcm.start(
      source: audioSource,
      measurement: measurementMode,
    );
    if (useAccelerometer) {
      _accelSub = accel.samples.listen((RawAccelSample s) {
        _accelBatch.addAll(<double>[s.tUs.toDouble(), s.x, s.y, s.z]);
        if (_accelBatch.length >= 4 * 2) _flushAccel();
      });
      await accel.start();
    }
    _started = true;
    return micOk;
  }

  final StreamController<Map<String, Object?>> _readyEvents =
      StreamController<Map<String, Object?>>.broadcast();

  Future<SendPort> _spawn(
    void Function(SendPort) entry,
    void Function(Object?) onMessage, {
    required bool isArm,
  }) async {
    final ReceivePort port = ReceivePort();
    final Completer<SendPort> sendPort = Completer<SendPort>();
    port.listen((Object? message) {
      if (message is SendPort && !sendPort.isCompleted) {
        sendPort.complete(message);
        return;
      }
      onMessage(message);
    });
    final Isolate isolate = await Isolate.spawn(entry, port.sendPort);
    if (isArm) {
      _fromArm = port;
      _armIsolate = isolate;
    } else {
      _fromWorker = port;
      _worker = isolate;
    }
    return sendPort.future;
  }

  void _onWorkerMessage(Object? message) {
    if (message is! Map) return;
    final Map<String, Object?> m = message.cast<String, Object?>();
    switch (m['type']) {
      case 'ready':
        _readyEvents.add(m);
      case 'decision':
        _decisions.add(m);
      case 'debug':
        _debug.add(m);
      case 'calibration':
        _calibration.add(m);
      case 'error':
        _errors.add('${m['message']}');
    }
  }

  void _onArmMessage(Object? message) {
    _armBusy = false;
    if (message is! Map || message['type'] != 'arm') return;
    final Map<String, Object?> result = (message['result']! as Map)
        .cast<String, Object?>();
    _arm.add(result);
    _toWorker?.send(<String, Object?>{
      'op': 'arm',
      'score': result['activity'],
      'hand': result['hand'],
      't': result['tUs'],
    });
  }

  void _flushAccel() {
    if (_accelBatch.isEmpty) return;
    _toWorker?.send(<String, Object?>{
      'op': 'accel',
      'data': Float64List.fromList(_accelBatch),
    });
    _accelBatch.clear();
  }

  void _send(Map<String, Object?> m) => _toWorker?.send(m);

  void touch(int tUs) => _send(<String, Object?>{'op': 'touch', 't': tUs});
  void settings(bool open, int tUs) =>
      _send(<String, Object?>{'op': 'settings', 'open': open, 't': tUs});
  void camera(bool on, int tUs) =>
      _send(<String, Object?>{'op': 'camera', 'on': on, 't': tUs});
  void person(int tUs) => _send(<String, Object?>{'op': 'person', 't': tUs});

  /// Optional 10 s quick calibration ("throw 5 punches, 2 of them low").
  void startQuickCalibration(int tUs) =>
      _send(<String, Object?>{'op': 'calibrate', 't': tUs});

  /// Sends a luma (or BGRA) frame to the optical-flow isolate. Returns false
  /// (frame dropped) while the previous frame is still being processed.
  bool sendFrame({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rowStride,
    required int rotationDegrees,
    required int tUs,
    required bool bgra,
  }) {
    final SendPort? arm = _toArm;
    if (arm == null || _armBusy) return false;
    _armBusy = true;
    arm.send(<String, Object?>{
      'op': 'frame',
      'bytes': TransferableTypedData.fromList(<TypedData>[bytes]),
      'width': width,
      'height': height,
      'rowStride': rowStride,
      'rotation': rotationDegrees,
      't': tUs,
      'format': bgra ? 'bgra' : 'luma',
    });
    return true;
  }

  /// Arm landmarks ([x, y, confidence]) for the pose part of the prior.
  void sendPose({
    required int tUs,
    List<double>? leftWrist,
    List<double>? rightWrist,
    List<double>? leftShoulder,
    List<double>? rightShoulder,
  }) {
    _toArm?.send(<String, Object?>{
      'op': 'pose',
      't': tUs,
      'lw': leftWrist,
      'rw': rightWrist,
      'ls': leftShoulder,
      'rs': rightShoulder,
    });
  }

  /// Flushes pending impacts and stops everything.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _pcmSub?.cancel();
    await _accelSub?.cancel();
    _flushAccel();
    await pcm.stop();
    _toWorker?.send(<String, Object?>{'op': 'stop'});
    _toArm?.send(<String, Object?>{'op': 'stop'});
    // Let the worker answer the final flush before shutting it down.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _worker?.kill(priority: Isolate.beforeNextEvent);
    _armIsolate?.kill(priority: Isolate.beforeNextEvent);
    _fromWorker?.close();
    _fromArm?.close();
    _toWorker = null;
    _toArm = null;
  }
}
