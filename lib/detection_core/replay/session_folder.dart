import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../accel/shock_tracker.dart';
import '../config/detector_config.dart';
import 'replay_runner.dart';

/// A Phase 2 raw session folder (see docs/raw-logging.md) loaded for replay.
class RecordedSession {
  final String folder;
  final Map<String, Object?> meta;
  final ReplayInput input;
  final MountProfile mount;

  /// Session start on the detection clock (µs); labels are seconds from here.
  final int sessionStartUs;
  final int wavSampleRate;

  const RecordedSession({
    required this.folder,
    required this.meta,
    required this.input,
    required this.mount,
    required this.sessionStartUs,
    required this.wavSampleRate,
  });

  /// Reads audio.wav, accel.csv, events.jsonl and session_meta.json.
  static RecordedSession load(String folder) {
    final Map<String, Object?> meta = _readJson('$folder/session_meta.json');
    final int startMs = (meta['sessionStartMs'] as num? ?? 0).toInt();
    final Map<String, Object?> audioMeta =
        (meta['audio'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final Map<String, Object?> mapping =
        (audioMeta['mappingWav'] as Map<String, Object?>?) ??
        const <String, Object?>{};

    final (Int16List samples, int rate) = _readWav('$folder/audio.wav');
    final double usPerSample =
        (mapping['usPerSample'] as num?)?.toDouble() ?? 1e6 / rate;
    final int audioStartUs =
        (mapping['interceptUs'] as num?)?.round() ??
        (audioMeta['firstSampleUs'] as num?)?.round() ??
        startMs * 1000;

    return RecordedSession(
      folder: folder,
      meta: meta,
      mount: MountProfile.fromName(meta['mountType'] as String?),
      sessionStartUs: startMs * 1000,
      wavSampleRate: rate,
      input: ReplayInput(
        audio: samples,
        audioStartUs: audioStartUs,
        audioUsPerSample: usPerSample,
        accel: _readAccel('$folder/accel.csv'),
        events: _readEvents('$folder/events.jsonl'),
      ),
    );
  }

  /// labels.csv: one true punch time per line, seconds since session start.
  /// Blank lines, `#` comments and a non-numeric header are ignored.
  List<int> loadLabels(String path) =>
      parseLabels(File(path).readAsLinesSync(), sessionStartUs: sessionStartUs);

  static List<int> parseLabels(
    List<String> lines, {
    required int sessionStartUs,
  }) {
    final List<int> out = <int>[];
    for (final String raw in lines) {
      final String line = raw.split('#').first.split(',').first.trim();
      final double? s = double.tryParse(line);
      if (s != null) out.add(sessionStartUs + (s * 1e6).round());
    }
    out.sort();
    return out;
  }
}

Map<String, Object?> _readJson(String path) {
  final File f = File(path);
  if (!f.existsSync()) return <String, Object?>{};
  return (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
}

/// Reads a 16-bit mono PCM WAV (finds the `data` chunk; tolerates a header
/// whose sizes were never patched).
(Int16List, int) _readWav(String path) {
  final File f = File(path);
  if (!f.existsSync()) return (Int16List(0), 16000);
  final Uint8List bytes = f.readAsBytesSync();
  final ByteData d = ByteData.sublistView(bytes);
  int rate = 16000;
  int pos = 12;
  while (pos + 8 <= bytes.length) {
    final String id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
    final int size = d.getUint32(pos + 4, Endian.little);
    if (id == 'fmt ') {
      rate = d.getUint32(pos + 12, Endian.little);
    } else if (id == 'data') {
      final int start = pos + 8;
      final int end = size == 0 || start + size > bytes.length
          ? bytes.length
          : start + size;
      final int n = (end - start) ~/ 2;
      final Int16List out = Int16List(n);
      for (int i = 0; i < n; i++) {
        out[i] = d.getInt16(start + 2 * i, Endian.little);
      }
      return (out, rate);
    }
    pos += 8 + size + (size.isOdd ? 1 : 0);
  }
  return (Int16List(0), rate);
}

List<AccelSampleIn> _readAccel(String path) {
  final File f = File(path);
  if (!f.existsSync()) return const <AccelSampleIn>[];
  final List<AccelSampleIn> out = <AccelSampleIn>[];
  for (final String line in f.readAsLinesSync().skip(1)) {
    final List<String> p = line.split(',');
    if (p.length < 5) continue;
    final int? t = int.tryParse(p[0]);
    final double? x = double.tryParse(p[2]);
    final double? y = double.tryParse(p[3]);
    final double? z = double.tryParse(p[4]);
    if (t == null || x == null || y == null || z == null) continue;
    out.add(AccelSampleIn(t, x, y, z));
  }
  out.sort((AccelSampleIn a, AccelSampleIn b) => a.tUs.compareTo(b.tUs));
  return out;
}

/// Context events the engine uses, from the session event file.
List<ContextEvent> _readEvents(String path) {
  final File f = File(path);
  if (!f.existsSync()) return const <ContextEvent>[];
  final List<ContextEvent> out = <ContextEvent>[];
  for (final String line in f.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      continue;
    }
    if (decoded is! Map) continue;
    final int tUs = ((decoded['epochMs'] as num?) ?? 0).toInt() * 1000;
    final Map<Object?, Object?> data =
        (decoded['data'] as Map?) ?? const <Object?, Object?>{};
    switch (decoded['kind']) {
      case 'touch':
        out.add(ContextEvent(tUs, 'touch'));
      case 'settings':
        out.add(
          ContextEvent(
            tUs,
            data['open'] == true ? 'settings_open' : 'settings_close',
          ),
        );
      case 'ui':
        if (data['camera'] == 'initialized') {
          out.add(ContextEvent(tUs, 'camera_on'));
        } else if (data['camera'] == 'unavailable') {
          out.add(ContextEvent(tUs, 'camera_off'));
        }
      case 'cam':
        // Logged only for frames that passed the person + distance rules.
        out.add(ContextEvent(tUs, 'person_valid'));
      case 'arm_motion':
        out.add(
          ContextEvent(
            tUs,
            'arm_activity',
            value: (data['activity'] as num? ?? 0).toDouble(),
            hand: data['hand'] as String? ?? 'unknown',
          ),
        );
    }
  }
  return out;
}
