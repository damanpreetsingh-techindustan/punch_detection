import 'dart:math' as math;

import '../engine/fusion_v2_engine.dart';

/// Accuracy of a replay against hand labels.
class ReplayMetrics {
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;
  final double idleMinutes;
  final int idleFalsePositives;
  final List<double> latenciesMs; // matched accepts
  final int labels;
  final int accepted;

  const ReplayMetrics({
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.idleMinutes,
    required this.idleFalsePositives,
    required this.latenciesMs,
    required this.labels,
    required this.accepted,
  });

  double get precision => truePositives + falsePositives == 0
      ? 0
      : truePositives / (truePositives + falsePositives);
  double get recall => truePositives + falseNegatives == 0
      ? 0
      : truePositives / (truePositives + falseNegatives);
  double get f1 => precision + recall == 0
      ? 0
      : 2 * precision * recall / (precision + recall);
  double get falsePerIdleMinute =>
      idleMinutes <= 0 ? 0 : idleFalsePositives / idleMinutes;

  double latencyPercentile(double p) {
    if (latenciesMs.isEmpty) return double.nan;
    final List<double> s = List<double>.of(latenciesMs)..sort();
    final int i = ((p / 100) * (s.length - 1)).round();
    return s[i];
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'labels': labels,
    'accepted': accepted,
    'tp': truePositives,
    'fp': falsePositives,
    'fn': falseNegatives,
    'precision': precision,
    'recall': recall,
    'f1': f1,
    'idleMinutes': idleMinutes,
    'idleFp': idleFalsePositives,
    'falsePerIdleMinute': falsePerIdleMinute,
    'latencyMedianMs': latencyPercentile(50),
    'latencyP95Ms': latencyPercentile(95),
    'latencyMaxMs': latenciesMs.isEmpty ? null : latenciesMs.reduce(math.max),
  };

  String toText() {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)} %';
    String ms(double v) => v.isNaN ? '-' : '${v.toStringAsFixed(1)} ms';
    return <String>[
      'labels $labels  accepted $accepted',
      'TP $truePositives  FP $falsePositives  FN $falseNegatives',
      'precision ${pct(precision)}  recall ${pct(recall)}  F1 ${pct(f1)}',
      'false counts per idle minute ${falsePerIdleMinute.toStringAsFixed(2)} '
          '($idleFalsePositives in ${idleMinutes.toStringAsFixed(2)} min)',
      'latency median ${ms(latencyPercentile(50))}  p95 ${ms(latencyPercentile(95))}',
    ].join('\n');
  }
}

/// Matches accepted decisions to labels (each label once, within
/// ±[toleranceMs], nearest first). Idle time is the session minus
/// ±[idleMarginMs] around every label.
ReplayMetrics computeMetrics({
  required List<ImpactDecision> decisions,
  required List<int> labelsUs,
  required int startUs,
  required int endUs,
  int toleranceMs = 50,
  int idleMarginMs = 1000,
}) {
  final List<ImpactDecision> accepted =
      <ImpactDecision>[
        for (final ImpactDecision d in decisions)
          if (d.accepted) d,
      ]..sort(
        (ImpactDecision a, ImpactDecision b) => a.onsetUs.compareTo(b.onsetUs),
      );
  final List<int> labels = List<int>.of(labelsUs)..sort();
  final int tol = toleranceMs * 1000;

  // All candidate pairs within tolerance, closest first.
  final List<(int, int, int)> pairs = <(int, int, int)>[];
  int start = 0;
  for (int i = 0; i < accepted.length; i++) {
    while (start < labels.length && labels[start] < accepted[i].onsetUs - tol) {
      start++;
    }
    for (
      int j = start;
      j < labels.length && labels[j] <= accepted[i].onsetUs + tol;
      j++
    ) {
      pairs.add(((accepted[i].onsetUs - labels[j]).abs(), i, j));
    }
  }
  pairs.sort(((int, int, int) a, (int, int, int) b) => a.$1.compareTo(b.$1));
  final Set<int> usedD = <int>{}, usedL = <int>{};
  final List<double> latencies = <double>[];
  for (final (int, int, int) p in pairs) {
    if (usedD.contains(p.$2) || usedL.contains(p.$3)) continue;
    usedD.add(p.$2);
    usedL.add(p.$3);
    latencies.add(accepted[p.$2].latencyUs / 1000);
  }

  bool isIdle(int t) {
    for (final int l in labels) {
      if ((t - l).abs() <= idleMarginMs * 1000) return false;
    }
    return true;
  }

  // Idle duration: session length minus the union of label margins.
  final List<(int, int)> busy = <(int, int)>[
    for (final int l in labels)
      (
        math.max(startUs, l - idleMarginMs * 1000),
        math.min(endUs, l + idleMarginMs * 1000),
      ),
  ];
  int busyUs = 0;
  int cursor = startUs;
  for (final (int, int) b in busy) {
    final int s = math.max(b.$1, cursor);
    if (b.$2 > s) {
      busyUs += b.$2 - s;
      cursor = b.$2;
    }
  }
  final double idleMinutes = math.max(0, endUs - startUs - busyUs) / 60e6;
  int idleFp = 0;
  for (int i = 0; i < accepted.length; i++) {
    if (!usedD.contains(i) && isIdle(accepted[i].onsetUs)) idleFp++;
  }

  return ReplayMetrics(
    truePositives: usedL.length,
    falsePositives: accepted.length - usedD.length,
    falseNegatives: labels.length - usedL.length,
    idleMinutes: idleMinutes,
    idleFalsePositives: idleFp,
    latenciesMs: latencies,
    labels: labels.length,
    accepted: accepted.length,
  );
}
