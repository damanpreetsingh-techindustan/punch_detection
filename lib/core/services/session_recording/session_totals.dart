/// Running min / average / max accumulator for one measurement series.
class RunningStats {
  int count = 0;
  double min = double.infinity;
  double max = double.negativeInfinity;
  double sum = 0.0;

  void add(double value) {
    if (value.isNaN || !value.isFinite) return;
    count++;
    sum += value;
    if (value < min) min = value;
    if (value > max) max = value;
  }

  double get avg => count == 0 ? 0.0 : sum / count;

  Map<String, Object?> toMap() => <String, Object?>{
    'n': count,
    'min': count == 0 ? null : _round(min),
    'avg': count == 0 ? null : _round(avg),
    'max': count == 0 ? null : _round(max),
  };

  String toText() {
    if (count == 0) return 'n=0';
    return 'n=$count  min=${_round(min)}  avg=${_round(avg)}  max=${_round(max)}';
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}

/// Per-session counters and measurement statistics.
///
/// Counters use dotted keys (for example `decision.REJECTED_NO_VIBRATION_WALL_MOUNT`)
/// so related totals sort next to each other in the export.
class SessionTotals {
  final Map<String, int> counters = <String, int>{};
  final Map<String, RunningStats> stats = <String, RunningStats>{};

  void increment(String key, [int by = 1]) {
    counters[key] = (counters[key] ?? 0) + by;
  }

  void addStat(String name, double value) {
    (stats[name] ??= RunningStats()).add(value);
  }

  int counter(String key) => counters[key] ?? 0;

  Map<String, Object?> toMap() => <String, Object?>{
    'counters': Map<String, int>.fromEntries(
      counters.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
    'stats': <String, Object?>{
      for (final String key in (stats.keys.toList()..sort()))
        key: stats[key]!.toMap(),
    },
  };

  /// Human readable block for the exported text log.
  String toText() {
    final StringBuffer buffer = StringBuffer();
    final List<String> counterKeys = counters.keys.toList()..sort();
    if (counterKeys.isEmpty) {
      buffer.writeln('  (no counters recorded)');
    }
    for (final String key in counterKeys) {
      buffer.writeln('  ${key.padRight(52)}: ${counters[key]}');
    }
    final List<String> statKeys = stats.keys.toList()..sort();
    if (statKeys.isNotEmpty) {
      buffer.writeln('  --- measurements (min / avg / max) ---');
    }
    for (final String key in statKeys) {
      buffer.writeln('  ${key.padRight(52)}: ${stats[key]!.toText()}');
    }
    return buffer.toString();
  }
}
