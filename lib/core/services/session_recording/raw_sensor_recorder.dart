import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../../detection_core/audio/resampler.dart';
import '../../../detection_core/timing/sample_clock.dart';
import '../audio_level/raw_pcm_source.dart';
import '../raw_sensors/raw_accelerometer_service.dart';
import 'wav_writer.dart';

/// Writes the raw sensor data of one session into its own folder so it can be
/// replayed offline (see docs/raw-logging.md):
///
///   audio.wav          16 kHz mono 16-bit PCM (resampled when captured at 44.1 kHz)
///   audio_sync.csv     sync points: WAV sample index <-> detection-clock time
///   accel.csv          raw 3-axis accelerometer, sensor-event timestamps
///   events.jsonl       the session event file (touches, UI, camera, decisions)
///   session_meta.json  device, settings and the rates actually achieved
///
/// Instrumentation only: nothing here feeds detection, and no method throws.
class RawSensorRecorder {
  RawSensorRecorder({
    Future<Directory> Function()? baseDirectory,
    this.wavSampleRate = 16000,
    this.syncPeriodUs = 1000000,
  }) : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  /// Sample rate of audio.wav.
  final int wavSampleRate;

  /// One sync point is written per this period.
  final int syncPeriodUs;

  String? _folderPath;
  bool _active = false;
  WavWriter? _wav;
  IOSink? _accelSink;
  StreamingResampler? _resampler;
  SyncPointCollector? _sync;
  int? _captureRate;
  int _inputSamples = 0;
  int _chunks = 0;
  int? _firstSampleUs;
  int? _danglingByte;
  final List<int> _chunkIntervalsUs = <int>[];
  int? _lastChunkArrivalUs;

  int _accelSamples = 0;
  int? _lastAccelSensorNs;
  final List<int> _accelIntervalsUs = <int>[];
  final List<String> _errors = <String>[];

  static const int _maxIntervalsKept = 100000;

  bool get isActive => _active;
  String? get folderPath => _folderPath;
  int get accelSamples => _accelSamples;
  int get audioInputSamples => _inputSamples;

  /// Creates `<documents>/raw_sessions/session_<startMs>/` and opens the files.
  Future<bool> begin({required int sessionStartMs}) async {
    if (_active) return true;
    try {
      final Directory base = await _baseDirectory();
      final Directory folder = Directory(
        '${base.path}/raw_sessions/session_$sessionStartMs',
      );
      await folder.create(recursive: true);
      _folderPath = folder.path;
      final WavWriter wav = WavWriter(
        path: '${folder.path}/audio.wav',
        sampleRate: wavSampleRate,
      );
      await wav.open();
      _wav = wav;
      final IOSink accel = File('${folder.path}/accel.csv').openWrite();
      accel.writeln('t_us,sensor_ns,x,y,z');
      _accelSink = accel;
      _active = true;
      return true;
    } catch (e) {
      _errors.add('begin: $e');
      return false;
    }
  }

  /// Appends one raw microphone buffer.
  void addPcmChunk(RawPcmChunk chunk) {
    if (!_active) return;
    try {
      final int rate = chunk.sampleRate;
      _captureRate ??= rate;
      _resampler ??= StreamingResampler(inRate: rate, outRate: wavSampleRate);
      _sync ??= SyncPointCollector(nominalRate: rate, periodUs: syncPeriodUs);
      final Int16List samples = _firstChannel(chunk);
      if (samples.isEmpty) return;
      _chunks++;
      final int? lastArrival = _lastChunkArrivalUs;
      if (lastArrival != null && _chunkIntervalsUs.length < _maxIntervalsKept) {
        _chunkIntervalsUs.add(chunk.arrivalUs - lastArrival);
      }
      _lastChunkArrivalUs = chunk.arrivalUs;
      _firstSampleUs ??=
          chunk.arrivalUs - (samples.length * 1e6 / rate).round();
      _inputSamples += samples.length;
      _sync!.addArrival(
        endSampleIndex: _inputSamples,
        arrivalUs: chunk.arrivalUs,
      );
      _wav!.write(_resampler!.process(samples));
    } catch (e) {
      if (_errors.length < 20) _errors.add('pcm: $e');
    }
  }

  /// Appends one raw accelerometer reading.
  void addAccel(RawAccelSample sample) {
    if (!_active) return;
    _accelSamples++;
    final int? last = _lastAccelSensorNs;
    if (last != null && _accelIntervalsUs.length < _maxIntervalsKept) {
      _accelIntervalsUs.add((sample.sensorNs - last) ~/ 1000);
    }
    _lastAccelSensorNs = sample.sensorNs;
    _accelSink?.writeln(
      '${sample.tUs},${sample.sensorNs},${sample.x.toStringAsFixed(5)},'
      '${sample.y.toStringAsFixed(5)},${sample.z.toStringAsFixed(5)}',
    );
  }

  /// Closes the files, copies the event file and writes session_meta.json.
  /// [meta] is merged into the meta file (device, settings, sensor diagnostics).
  Future<String?> finish({
    Map<String, Object?> meta = const <String, Object?>{},
    String? eventsFilePath,
  }) async {
    if (!_active) return _folderPath;
    _active = false;
    final String folder = _folderPath!;
    try {
      await _wav?.close();
      await _accelSink?.flush();
      await _accelSink?.close();
    } catch (e) {
      _errors.add('close: $e');
    }

    final SyncPointCollector? sync = _sync;
    sync?.flush();
    final List<SyncPoint> points = sync?.points ?? const <SyncPoint>[];
    final int captureRate = _captureRate ?? wavSampleRate;
    final SampleClockMapping mapping = SampleClockMapping.fit(
      points,
      nominalRate: captureRate,
    );
    try {
      final StringBuffer csv = StringBuffer(
        'wav_sample_index,t_us,capture_sample_index\n',
      );
      for (final SyncPoint p in points) {
        final int wavIndex = (p.sampleIndex * wavSampleRate / captureRate)
            .round();
        csv.writeln('$wavIndex,${p.tUs},${p.sampleIndex}');
      }
      await File('$folder/audio_sync.csv').writeAsString(csv.toString());
      if (eventsFilePath != null && await File(eventsFilePath).exists()) {
        await File(eventsFilePath).copy('$folder/events.jsonl');
      }
    } catch (e) {
      _errors.add('sync/events: $e');
    }

    final Map<String, Object?> metaOut = <String, Object?>{
      'formatVersion': 1,
      ...meta,
      'audio': <String, Object?>{
        ...?(meta['audio'] as Map<String, Object?>?),
        'captureSampleRate': captureRate,
        'wavSampleRate': wavSampleRate,
        'captureSamples': _inputSamples,
        'wavSamples': _wav?.samplesWritten ?? 0,
        'durationS': _inputSamples / captureRate,
        'chunks': _chunks,
        'medianChunkIntervalMs': _medianUs(_chunkIntervalsUs) / 1000.0,
        'firstSampleUs': _firstSampleUs,
        'syncPoints': points.length,
        'mappingCaptureTimeline': mapping.toMap(),
        // Same mapping on the WAV timeline: t_us = interceptUs + i * usPerSample.
        'mappingWav': <String, Object?>{
          'interceptUs': mapping.interceptUs,
          'usPerSample': mapping.usPerSample * captureRate / wavSampleRate,
        },
        'measuredRateHz': points.length >= 2 ? mapping.effectiveRateHz : null,
      },
      'accel': <String, Object?>{
        ...?(meta['accel'] as Map<String, Object?>?),
        'samplesWritten': _accelSamples,
        'medianIntervalMs': _medianUs(_accelIntervalsUs) / 1000.0,
        'rateFromMedianHz': _accelIntervalsUs.isEmpty
            ? null
            : 1e6 / _medianUs(_accelIntervalsUs),
      },
      'files': <String>[
        'audio.wav',
        'audio_sync.csv',
        'accel.csv',
        'events.jsonl',
        'session_meta.json',
      ],
      'recorderErrors': _errors,
    };
    try {
      await File('$folder/session_meta.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(_jsonSafe(metaOut)),
      );
    } catch (e) {
      _errors.add('meta: $e');
    }
    return folder;
  }

  Int16List _firstChannel(RawPcmChunk chunk) {
    Uint8List bytes = chunk.bytes;
    final int? dangling = _danglingByte;
    if (dangling != null) {
      bytes = Uint8List(bytes.length + 1)
        ..[0] = dangling
        ..setRange(1, bytes.length + 1, chunk.bytes);
      _danglingByte = null;
    }
    final int frameBytes = 2 * chunk.channels;
    final int frames = bytes.length ~/ frameBytes;
    final int used = frames * frameBytes;
    if (used < bytes.length && chunk.channels == 1) {
      _danglingByte = bytes[used];
    }
    final ByteData data = ByteData.sublistView(bytes);
    final Int16List out = Int16List(frames);
    for (int i = 0; i < frames; i++) {
      out[i] = data.getInt16(i * frameBytes, Endian.little);
    }
    return out;
  }

  static double _medianUs(List<int> values) {
    if (values.isEmpty) return 0;
    final List<int> sorted = List<int>.of(values)..sort();
    return sorted[sorted.length ~/ 2].toDouble();
  }

  /// Replaces NaN / infinity (not valid JSON) with null.
  static Object? _jsonSafe(Object? value) {
    if (value is double && !value.isFinite) return null;
    if (value is Map) {
      return value.map(
        (Object? k, Object? v) =>
            MapEntry<String, Object?>(k.toString(), _jsonSafe(v)),
      );
    }
    if (value is List) return value.map(_jsonSafe).toList();
    return value;
  }
}
