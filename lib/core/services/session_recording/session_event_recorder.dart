import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'raw_session_event.dart';
import 'session_totals.dart';

/// Records every sensor sample and detection decision of one session to a JSONL
/// file so a field test can be replayed offline, and keeps per-session totals.
///
/// Instrumentation only: nothing here feeds back into detection, and no public
/// method throws, so a recording failure can never affect punch counting.
class SessionEventRecorder {
  SessionEventRecorder({
    Future<Directory> Function()? directoryProvider,
    this.flushIntervalMs = 1000,
    this.maxBufferedChars = 2000000,
    this.maxKeptFiles = 20,
  }) : _directoryProvider = directoryProvider ?? defaultLogDirectory;

  final Future<Directory> Function() _directoryProvider;

  /// Raw files kept in the log folder; older ones are deleted when a new
  /// session starts (0 = keep all).
  final int maxKeptFiles;

  static const String _filePrefix = 'hyper_hitter_raw_events_';

  /// `<app documents>/session_logs`: unlike the temporary folder, the OS does
  /// not clear it, so a session can still be exported days later.
  static Future<Directory> defaultLogDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/session_logs').create(recursive: true);
  }

  /// Minimum time between flushes of the file sink (checked on each record, no timer).
  final int flushIntervalMs;

  /// Events written before the file is open are buffered up to this size.
  final int maxBufferedChars;

  final SessionTotals totals = SessionTotals();

  int _startEpochMs = 0;
  bool _begun = false;
  bool _finished = false;
  IOSink? _sink;
  String? _filePath;
  final StringBuffer _pending = StringBuffer();
  int _lastFlushEpochMs = 0;

  /// Number of events accepted (written or buffered).
  int eventCount = 0;

  /// Number of events dropped because the file could not be opened.
  int droppedCount = 0;

  bool get isBegun => _begun;
  bool get isFinished => _finished;
  int get startEpochMs => _startEpochMs;

  /// Path of the JSONL file, or null while it is not open (or could not be opened).
  String? get filePath => _filePath;

  /// Milliseconds since session start for a wall-clock timestamp.
  int elapsedForEpoch(int epochMs) => _begun ? epochMs - _startEpochMs : 0;

  /// Milliseconds since session start right now.
  int get nowElapsedMs =>
      elapsedForEpoch(DateTime.now().millisecondsSinceEpoch);

  /// Formats elapsed milliseconds as `+mm:ss.mmm` for log lines.
  static String formatElapsed(int ms) {
    final bool negative = ms < 0;
    final int abs = ms.abs();
    final String mm = (abs ~/ 60000).toString().padLeft(2, '0');
    final String ss = ((abs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final String mmm = (abs % 1000).toString().padLeft(3, '0');
    return '${negative ? '-' : '+'}$mm:$ss.$mmm';
  }

  /// Starts the session timeline and opens the output file in the background.
  void begin({
    required int startEpochMs,
    Map<String, Object?> config = const <String, Object?>{},
  }) {
    if (_begun) return;
    _begun = true;
    _startEpochMs = startEpochMs;
    _lastFlushEpochMs = startEpochMs;
    record('session_start', <String, Object?>{
      ...config,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
    }, atEpochMs: startEpochMs);
    _opening = _openSink();
  }

  /// Completes when the output file is open (or opening failed). `finish` waits
  /// on it so a very short session still gets its buffered events written.
  Future<void>? _opening;

  Future<void> _openSink() async {
    try {
      final Directory dir = await _directoryProvider();
      final String path = '${dir.path}/$_filePrefix$_startEpochMs.jsonl';
      final IOSink sink = File(path).openWrite();
      if (_pending.isNotEmpty) {
        sink.write(_pending.toString());
        _pending.clear();
      }
      _sink = sink;
      _filePath = path;
      await _deleteOldFiles(dir, keep: path);
    } catch (_) {
      _sink = null;
      _filePath = null;
    }
  }

  /// Keeps the newest [maxKeptFiles] raw files (names sort by start time).
  Future<void> _deleteOldFiles(Directory dir, {required String keep}) async {
    if (maxKeptFiles <= 0) return;
    try {
      final List<File> files = dir
          .listSync()
          .whereType<File>()
          .where((File f) {
            final String name = f.uri.pathSegments.last;
            return name.startsWith(_filePrefix) && name.endsWith('.jsonl');
          })
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
      final int excess = files.length - maxKeptFiles;
      for (int i = 0; i < excess; i++) {
        if (files[i].path != keep) await files[i].delete();
      }
    } catch (_) {}
  }

  /// Records one event. [atEpochMs] lets callers stamp an event with the time the
  /// underlying sample happened instead of the time it was processed.
  void record(
    String kind,
    Map<String, Object?> data, {
    int? atEpochMs,
  }) {
    if (!_begun || _finished) return;
    try {
      final int epoch = atEpochMs ?? DateTime.now().millisecondsSinceEpoch;
      final String line = RawSessionEvent(
        tMs: epoch - _startEpochMs,
        epochMs: epoch,
        kind: kind,
        data: data,
      ).toJsonLine();
      eventCount++;
      _write(line, epoch);
    } catch (_) {
      droppedCount++;
    }
  }

  void _write(String line, int epoch) {
    final IOSink? sink = _sink;
    if (sink != null) {
      sink.writeln(line);
      if (epoch - _lastFlushEpochMs >= flushIntervalMs) {
        _lastFlushEpochMs = epoch;
        sink.flush().catchError((Object _) {});
      }
      return;
    }
    if (_pending.length > maxBufferedChars) {
      // File never opened (for example no storage plugin): stop growing memory.
      _pending.clear();
      droppedCount++;
      return;
    }
    _pending.writeln(line);
  }

  /// Increments a named counter in the session totals.
  void count(String key, [int by = 1]) {
    try {
      totals.increment(key, by);
    } catch (_) {}
  }

  /// Adds a measurement to a named min / avg / max series in the session totals.
  void stat(String name, double value) {
    try {
      totals.addStat(name, value);
    } catch (_) {}
  }

  /// Writes the closing `session_end` record with all totals and closes the file.
  Future<void> finish({
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    if (!_begun || _finished) return;
    record('session_end', <String, Object?>{
      ...extra,
      'events': eventCount,
      'dropped': droppedCount,
      'totals': totals.toMap(),
    });
    _finished = true;
    await _opening;
    final IOSink? sink = _sink;
    _sink = null;
    if (sink == null) return;
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
  }

  Future<void> dispose() => finish();
}
