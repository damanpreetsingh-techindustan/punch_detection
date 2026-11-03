import 'dart:math';

import '../../../../core/utils/constants.dart';

/// What the recent face checks say about the tracked person.
enum FaceVerdict {
  /// Not enough recent face checks (face hidden, turned or too small).
  none,

  /// The face matches the reference photo.
  user,

  /// Checks seen, but neither clearly the user nor clearly someone else.
  unsure,

  /// The face clearly is not the person in the reference photo.
  other,
}

/// Face part of the subject lock: the user's face template, built from the
/// faces seen while the reference photo was taken, and a verdict from the
/// last few face checks.
///
/// One face check can be wrong (blur, a glove at the edge of the face), so
/// the verdict uses the median of the last [votes] checks within [maxAgeMs].
/// The user / other levels sit around the face model's published operating
/// point (SFace: cosine 0.363 on LFW), with an "unsure" band in between.
///
/// Pure: no clocks, no ML Kit / TFLite; embeddings come in as numbers.
class FaceIdentity {
  final double userCosine;
  final double otherCosine;
  final int votes;
  final int templateFaces;
  final int maxTemplateFaces;
  final int maxAgeMs;

  FaceIdentity({
    this.userCosine = AppConstants.subjectFaceUserCosine,
    this.otherCosine = AppConstants.subjectFaceOtherCosine,
    this.votes = AppConstants.subjectFaceVotes,
    this.templateFaces = AppConstants.subjectFaceTemplateFaces,
    this.maxTemplateFaces = AppConstants.subjectFaceMaxTemplateFaces,
    this.maxAgeMs = AppConstants.subjectFaceMaxAgeMs,
  });

  final List<List<double>> _enrolled = <List<double>>[];
  List<double>? _template;
  final List<double> _scores = <double>[];
  final List<int> _scoreTimes = <int>[];

  bool get hasTemplate => _template != null;
  int get enrolledFaces => _enrolled.length;

  /// True when a face check was scored since the last [clearScores].
  bool get seenSinceClear => _scores.isNotEmpty;

  /// Face checks scored since the last [clearScores] (kept up to 4 × votes).
  int get recentScoreCount => _scores.length;

  /// Adds a face seen while the reference photo is taken. The template is the
  /// average of the first [templateFaces] … [maxTemplateFaces] faces.
  void enroll(List<double> embedding) {
    if (_enrolled.length >= maxTemplateFaces) return;
    _enrolled.add(_unit(embedding));
    if (_enrolled.length >= templateFaces) {
      final List<double> sum = List<double>.filled(embedding.length, 0);
      for (final List<double> e in _enrolled) {
        for (int i = 0; i < sum.length; i++) {
          sum[i] += e[i];
        }
      }
      _template = _unit(sum);
    }
  }

  /// Cosine similarity with the template (null without a template).
  double? score(List<double> embedding) {
    final List<double>? t = _template;
    if (t == null) return null;
    final List<double> e = _unit(embedding);
    double dot = 0;
    for (int i = 0; i < t.length; i++) {
      dot += t[i] * e[i];
    }
    return dot;
  }

  void addScore(double score, int tMs) {
    _scores.add(score);
    _scoreTimes.add(tMs);
    if (_scores.length > votes * 4) {
      _scores.removeAt(0);
      _scoreTimes.removeAt(0);
    }
  }

  /// Median of the last [votes] scores not older than [maxAgeMs].
  FaceVerdict verdict(int nowMs) {
    final List<double> recent = <double>[];
    for (int i = _scores.length - 1; i >= 0 && recent.length < votes; i--) {
      if (nowMs - _scoreTimes[i] <= maxAgeMs) recent.add(_scores[i]);
    }
    if (recent.length < votes) return FaceVerdict.none;
    recent.sort();
    final double median = recent[recent.length ~/ 2];
    if (median >= userCosine) return FaceVerdict.user;
    if (median < otherCosine) return FaceVerdict.other;
    return FaceVerdict.unsure;
  }

  /// Forget the recent checks (the tracked person may have changed).
  void clearScores() {
    _scores.clear();
    _scoreTimes.clear();
  }

  /// Forget everything, including the template (new reference photo).
  void reset() {
    _enrolled.clear();
    _template = null;
    clearScores();
  }

  static List<double> _unit(List<double> v) {
    double n = 0;
    for (final double x in v) {
      n += x * x;
    }
    n = sqrt(n);
    return n == 0 ? List<double>.of(v) : v.map((double x) => x / n).toList();
  }
}
