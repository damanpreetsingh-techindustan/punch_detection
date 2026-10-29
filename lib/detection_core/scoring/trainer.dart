import 'dart:math' as math;

import 'logistic_scorer.dart';

/// One labelled training example: an impact's features and whether a true
/// punch was within the matching tolerance.
class TrainingExample {
  final Map<String, double> features;
  final bool isPunch;

  const TrainingExample(this.features, this.isPunch);
}

/// Fits the weights and bias of [template] (keeping its feature list and the
/// center/scale standardisation) by L2-regularised logistic regression with
/// full-batch gradient descent. Classes are re-weighted so a session with many
/// more punches than noise events (or the reverse) is not dominated by one.
LogisticModel fitLogistic(
  LogisticModel template,
  List<TrainingExample> examples, {
  double l2 = 0.01,
  double learningRate = 0.5,
  int iterations = 3000,
}) {
  if (examples.isEmpty) return template;
  final List<String> names = template.terms.keys.toList();
  final int k = names.length;
  final List<List<double>> x = <List<double>>[
    for (final TrainingExample e in examples)
      <double>[
        for (final String n in names)
          template.terms[n]!.z(e.features[n] ?? template.terms[n]!.center),
      ],
  ];
  final List<double> y = <double>[
    for (final TrainingExample e in examples) e.isPunch ? 1.0 : 0.0,
  ];
  final int positives = y.where((double v) => v == 1).length;
  final int negatives = y.length - positives;
  final double wPos = positives == 0 ? 0 : y.length / (2.0 * positives);
  final double wNeg = negatives == 0 ? 0 : y.length / (2.0 * negatives);

  final List<double> w = <double>[
    for (final String n in names) template.terms[n]!.weight,
  ];
  double b = template.bias;
  for (int it = 0; it < iterations; it++) {
    final List<double> gw = List<double>.filled(k, 0);
    double gb = 0;
    for (int i = 0; i < x.length; i++) {
      double s = b;
      for (int j = 0; j < k; j++) {
        s += w[j] * x[i][j];
      }
      final double p = 1 / (1 + math.exp(-s));
      final double cw = y[i] == 1 ? wPos : wNeg;
      final double err = cw * (p - y[i]);
      for (int j = 0; j < k; j++) {
        gw[j] += err * x[i][j];
      }
      gb += err;
    }
    for (int j = 0; j < k; j++) {
      w[j] -= learningRate * (gw[j] / x.length + l2 * w[j]);
    }
    b -= learningRate * gb / x.length;
  }
  return LogisticModel(
    bias: b,
    terms: <String, ScorerTerm>{
      for (int j = 0; j < k; j++)
        names[j]: ScorerTerm(
          center: template.terms[names[j]]!.center,
          scale: template.terms[names[j]]!.scale,
          weight: w[j],
        ),
    },
  );
}
