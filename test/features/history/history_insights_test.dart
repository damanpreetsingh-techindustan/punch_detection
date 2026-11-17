import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/history/domain/entities/workout_record.dart';
import 'package:punch_detection_demo/features/history/domain/history_insights.dart';

WorkoutRecord _rec(
  DateTime at,
  int punches, {
  int seconds = 120,
  String type = 'free',
  int streak = 0,
}) => WorkoutRecord(
  id: at.toIso8601String(),
  dateIso: at.toIso8601String(),
  durationSeconds: seconds,
  totalPunches: punches,
  averageReactionMs: 0,
  bestReactionMs: 0,
  detectionMode: 'fusion',
  sessionType: type,
  bestStreak: streak,
);

void main() {
  final now = DateTime(2026, 11, 17, 20, 0);
  DateTime daysAgo(int d, {int hour = 10}) =>
      DateTime(now.year, now.month, now.day - d, hour);

  group('lastSevenDays', () {
    test('seven days oldest first, today last, sums per day', () {
      final records = [
        _rec(daysAgo(0, hour: 18), 40),
        _rec(daysAgo(0, hour: 9), 10),
        _rec(daysAgo(2), 25),
        _rec(daysAgo(7), 999), // outside the window
      ];
      final week = HistoryInsights.lastSevenDays(records, now);
      expect(week.length, 7);
      expect(week.last.day, DateTime(2026, 11, 17));
      expect(week.first.day, DateTime(2026, 11, 11));
      expect(week.map((d) => d.punches), [0, 0, 0, 0, 25, 0, 50]);
    });
  });

  group('dayStreak', () {
    test('counts back from today', () {
      final records = [
        _rec(daysAgo(0), 1),
        _rec(daysAgo(1), 1),
        _rec(daysAgo(2), 1),
        _rec(daysAgo(4), 1),
      ];
      expect(HistoryInsights.dayStreak(records, now), 3);
    });

    test('still alive when the last session was yesterday', () {
      final records = [_rec(daysAgo(1), 1), _rec(daysAgo(2), 1)];
      expect(HistoryInsights.dayStreak(records, now), 2);
    });

    test('broken after a missed day', () {
      expect(HistoryInsights.dayStreak([_rec(daysAgo(2), 1)], now), 0);
      expect(HistoryInsights.dayStreak([], now), 0);
    });
  });

  group('bests', () {
    test('short sessions do not count for best pace', () {
      final records = [
        _rec(daysAgo(0), 20, seconds: 5), // 240 / min, too short
        _rec(daysAgo(1), 120, seconds: 60, type: 'prompt', streak: 9),
        _rec(daysAgo(2), 150, seconds: 300),
      ];
      final b = HistoryInsights.bests(records);
      expect(b.mostPunches, 150);
      expect(b.bestPace, 120);
      expect(b.longestStreak, 9);
      expect(b.longestSessionSeconds, 300);
    });

    test('empty history is all zero', () {
      final b = HistoryInsights.bests([]);
      expect(b.mostPunches, 0);
      expect(b.bestPace, 0);
    });
  });

  test('previousOfType returns the newest session of that mode', () {
    final records = [
      _rec(daysAgo(0), 10, type: 'prompt'),
      _rec(daysAgo(1), 20),
      _rec(daysAgo(2), 30),
    ];
    expect(HistoryInsights.previousOfType(records, 'free')?.totalPunches, 20);
    expect(HistoryInsights.previousOfType(records, 'prompt')?.totalPunches, 10);
    expect(HistoryInsights.previousOfType([], 'free'), isNull);
  });

  test('date labels', () {
    expect(DateLabels.relativeDay(daysAgo(0), now), 'Today');
    expect(DateLabels.relativeDay(daysAgo(1), now), 'Yesterday');
    expect(DateLabels.relativeDay(DateTime(2026, 11, 12), now), 'Thu 12 Nov');
    expect(DateLabels.duration(45), '45 s');
    expect(DateLabels.duration(245), '4:05');
    expect(DateLabels.time(DateTime(2026, 1, 1, 7, 3)), '07:03');
  });
}
