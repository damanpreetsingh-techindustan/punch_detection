import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/session_recording/raw_session_event.dart';
import 'package:punch_detection_demo/core/services/session_recording/session_event_recorder.dart';
import 'package:punch_detection_demo/core/services/session_recording/session_totals.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_recorder_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SessionEventRecorder.formatElapsed', () {
    test('formats minutes, seconds and milliseconds', () {
      expect(SessionEventRecorder.formatElapsed(0), '+00:00.000');
      expect(SessionEventRecorder.formatElapsed(1234), '+00:01.234');
      expect(SessionEventRecorder.formatElapsed(61005), '+01:01.005');
      expect(SessionEventRecorder.formatElapsed(3600000), '+60:00.000');
    });

    test('keeps the sign for negative values', () {
      expect(SessionEventRecorder.formatElapsed(-250), '-00:00.250');
    });
  });

  group('SessionEventRecorder file output', () {
    test('writes session_start, ordered events and session_end as JSONL', () async {
      final SessionEventRecorder recorder = SessionEventRecorder(
        directoryProvider: () async => tempDir,
      );
      recorder.begin(
        startEpochMs: 1000000,
        config: <String, Object?>{'targetDb': 75.0},
      );
      recorder.record('audio', <String, Object?>{'db': 80.5}, atEpochMs: 1000100);
      recorder.record('vibe', <String, Object?>{'mag': 0.5}, atEpochMs: 1000150);
      recorder.count('punch.registered');
      recorder.stat('level.audio_db_at_punch', 99.0);
      await recorder.finish(extra: <String, Object?>{'punches': 1});

      expect(recorder.filePath, isNotNull);
      final List<String> lines = await File(recorder.filePath!).readAsLines();
      final List<Map<String, dynamic>> events = lines
          .map((String l) => jsonDecode(l) as Map<String, dynamic>)
          .toList();

      expect(events.first['k'], 'session_start');
      expect(events.first['targetDb'], 75.0);
      expect(events.first['t'], 0);
      expect(events[1]['k'], 'audio');
      expect(events[1]['t'], 100);
      expect(events[2]['k'], 'vibe');
      expect(events[2]['t'], 150);
      expect(events.last['k'], 'session_end');
      expect(events.last['punches'], 1);
      final Map<String, dynamic> totals =
          events.last['totals'] as Map<String, dynamic>;
      expect(
        (totals['counters'] as Map<String, dynamic>)['punch.registered'],
        1,
      );

      final List<int> times = events.map((e) => e['t'] as int).toList();
      expect(times, orderedEquals(List<int>.from(times)..sort()));
    });

    test('NaN and Infinity become null so every line stays valid JSON', () async {
      final SessionEventRecorder recorder = SessionEventRecorder(
        directoryProvider: () async => tempDir,
      );
      recorder.begin(startEpochMs: 5000);
      recorder.record('audio', <String, Object?>{
        'db': double.nan,
        'inf': double.infinity,
        'ok': 1.23456,
        'nested': <String, Object?>{'x': double.nan},
      }, atEpochMs: 5010);
      await recorder.finish();

      final List<String> lines = await File(recorder.filePath!).readAsLines();
      final Map<String, dynamic> audio =
          jsonDecode(lines[1]) as Map<String, dynamic>;
      expect(audio['db'], isNull);
      expect(audio['inf'], isNull);
      expect(audio['ok'], 1.235);
      expect((audio['nested'] as Map<String, dynamic>)['x'], isNull);
    });

    test('events before begin and after finish are ignored', () async {
      final SessionEventRecorder recorder = SessionEventRecorder(
        directoryProvider: () async => tempDir,
      );
      recorder.record('early', <String, Object?>{});
      expect(recorder.eventCount, 0);
      recorder.begin(startEpochMs: 1);
      final int afterBegin = recorder.eventCount;
      await recorder.finish();
      final int afterFinish = recorder.eventCount;
      recorder.record('late', <String, Object?>{});
      expect(recorder.eventCount, afterFinish);
      expect(afterBegin, 1);
    });

    test('a storage failure never throws and leaves no file path', () async {
      final SessionEventRecorder recorder = SessionEventRecorder(
        directoryProvider: () async => throw Exception('no storage plugin'),
        maxBufferedChars: 200,
      );
      expect(() => recorder.begin(startEpochMs: 1), returnsNormally);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      for (int i = 0; i < 100; i++) {
        recorder.record('audio', <String, Object?>{'db': i.toDouble()});
      }
      expect(recorder.filePath, isNull);
      expect(recorder.droppedCount, greaterThan(0));
      await expectLater(recorder.finish(), completes);
    });
  });

  group('SessionTotals', () {
    test('counts and aggregates min / avg / max', () {
      final SessionTotals totals = SessionTotals();
      totals.increment('a');
      totals.increment('a');
      totals.increment('b', 5);
      totals.addStat('lag', 10);
      totals.addStat('lag', -20);
      totals.addStat('lag', 40);
      totals.addStat('lag', double.nan);

      expect(totals.counter('a'), 2);
      expect(totals.counter('b'), 5);
      expect(totals.counter('missing'), 0);
      final RunningStats lag = totals.stats['lag']!;
      expect(lag.count, 3);
      expect(lag.min, -20);
      expect(lag.max, 40);
      expect(lag.avg, closeTo(10.0, 1e-9));
    });

    test('text export lists counters and measurements', () {
      final SessionTotals totals = SessionTotals();
      totals.increment('decision.AUDIO.AUDIO_BELOW_TARGET', 3);
      totals.addStat('interval.inter_punch_ms', 250);
      final String text = totals.toText();
      expect(text, contains('decision.AUDIO.AUDIO_BELOW_TARGET'));
      expect(text, contains('interval.inter_punch_ms'));
      expect(text, contains('min=250'));
    });
  });

  group('RawSessionEvent', () {
    test('toJsonLine includes t, e, k and data', () {
      const RawSessionEvent event = RawSessionEvent(
        tMs: 12,
        epochMs: 1012,
        kind: 'audio',
        data: <String, Object?>{'db': 70.0},
      );
      final Map<String, dynamic> json =
          jsonDecode(event.toJsonLine()) as Map<String, dynamic>;
      expect(json, <String, dynamic>{'t': 12, 'e': 1012, 'k': 'audio', 'db': 70.0});
    });
  });
}
