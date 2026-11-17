import 'dart:math' as math;

import 'entities/workout_record.dart';

/// Punches on one calendar day (local time).
class DayTotal {
  final DateTime day;
  final int punches;

  const DayTotal(this.day, this.punches);
}

/// Best single-session values across the whole history.
class PersonalBests {
  final int mostPunches;
  final double bestPace; // punches per minute
  final int longestStreak; // drill calls answered in a row
  final int longestSessionSeconds;

  const PersonalBests({
    this.mostPunches = 0,
    this.bestPace = 0,
    this.longestStreak = 0,
    this.longestSessionSeconds = 0,
  });
}

/// Progress numbers for the Results, History and Home screens. Records are
/// newest first, as the repository returns them.
class HistoryInsights {
  /// Sessions shorter than this don't count for "best pace": a 5-second
  /// session with 10 punches would otherwise show 120 / min.
  static const int minSecondsForPace = 30;

  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Today and the six days before it, oldest first.
  static List<DayTotal> lastSevenDays(
    List<WorkoutRecord> records,
    DateTime now,
  ) {
    final today = dayOf(now);
    final totals = <DateTime, int>{};
    for (final r in records) {
      final day = dayOf(r.date);
      totals[day] = (totals[day] ?? 0) + r.totalPunches;
    }
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final day = DateTime(today.year, today.month, today.day - i);
          return DayTotal(day, totals[day] ?? 0);
        }(),
    ];
  }

  static int punchesOn(List<WorkoutRecord> records, DateTime day) {
    final target = dayOf(day);
    return records
        .where((r) => dayOf(r.date) == target)
        .fold(0, (sum, r) => sum + r.totalPunches);
  }

  /// Days in a row with at least one session, ending today, or yesterday if
  /// the user hasn't trained yet today (the streak is still alive).
  static int dayStreak(List<WorkoutRecord> records, DateTime now) {
    final days = records.map((r) => dayOf(r.date)).toSet();
    var day = dayOf(now);
    if (!days.contains(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  static PersonalBests bests(List<WorkoutRecord> records) {
    var most = 0;
    var pace = 0.0;
    var streak = 0;
    var longest = 0;
    for (final r in records) {
      most = math.max(most, r.totalPunches);
      if (r.durationSeconds >= minSecondsForPace) {
        pace = math.max(pace, r.punchesPerMinute);
      }
      streak = math.max(streak, r.bestStreak);
      longest = math.max(longest, r.durationSeconds);
    }
    return PersonalBests(
      mostPunches: most,
      bestPace: pace,
      longestStreak: streak,
      longestSessionSeconds: longest,
    );
  }

  /// Most recent earlier session of the same mode, for "vs last time".
  static WorkoutRecord? previousOfType(
    List<WorkoutRecord> records,
    String sessionType,
  ) {
    for (final r in records) {
      if (r.sessionType == sessionType) return r;
    }
    return null;
  }

  static int totalPunches(List<WorkoutRecord> records) =>
      records.fold(0, (sum, r) => sum + r.totalPunches);
}

/// Short date labels without the intl package.
class DateLabels {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "M", "T"… for chart axes.
  static String weekdayInitial(DateTime d) => _weekdays[d.weekday - 1][0];

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// "Today", "Yesterday" or "Mon 12 Nov".
  static String relativeDay(DateTime d, DateTime now) {
    final day = HistoryInsights.dayOf(d);
    final today = HistoryInsights.dayOf(now);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${weekday(d)} ${d.day} ${_months[d.month - 1]}';
  }

  /// "18:05"
  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// "4:05" or "45 s"
  static String duration(int seconds) {
    if (seconds < 60) return '$seconds s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
