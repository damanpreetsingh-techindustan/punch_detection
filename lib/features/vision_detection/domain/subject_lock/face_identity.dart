import 'dart:math';

import '../../../../core/utils/constants.dart';

/// What a face check says about the tracked person.
enum FaceVerdict {
  /// No check result (ignored, or no template yet).
  none,

  /// The face matches the reference photo.
  user,

  /// The face does not match the reference photo.
  other,
}

/// Face part of the subject lock: the user's face template, built from the
/// faces seen while the reference photo was taken.
///
/// Every check is decided on its own against [userCosine]. Faces of the same
/// person and of different people score far apart (real sessions: user
/// 0.51-0.94, others 0.05-0.43), so one check is meaningful, and voting over
/// several would keep calling a new person "user" for two more checks.
///
/// Pure: no clocks, no ML Kit / TFLite; embeddings come in as numbers.
class FaceIdentity {
  final double userCosine;
  final int templateFaces;
  final int maxTemplateFaces;

  FaceIdentity({
    this.userCosine = AppConstants.subjectFaceUserCosine,
    this.templateFaces = AppConstants.subjectFaceTemplateFaces,
    this.maxTemplateFaces = AppConstants.subjectFaceMaxTemplateFaces,
  });

  final List<List<double>> _enrolled = <List<double>>[];
  List<double>? _template;

  bool get hasTemplate => _template != null;
  int get enrolledFaces => _enrolled.length;

  /// Adds a face seen while the reference photo is taken. The template is the
  /// average of the first [templateFaces] … [maxTemplateFaces] faces.
  ///
  /// Returns false, adding nothing, when the face is not the same person as
  /// the faces so far: the tracker moved to someone else during the photo.
  /// An average of two people would accept both of them.
  bool enroll(List<double> embedding) {
    if (_enrolled.length >= maxTemplateFaces) return true;
    final List<double> face = _unit(embedding);
    if (_enrolled.isNotEmpty && _dot(_averageOfEnrolled(), face) < userCosine) {
      return false;
    }
    _enrolled.add(face);
    if (_enrolled.length >= templateFaces) _template = _averageOfEnrolled();
    return true;
  }

  /// Cosine similarity with the template (null without a template).
  double? score(List<double> embedding) {
    final List<double>? t = _template;
    return t == null ? null : _dot(t, _unit(embedding));
  }

  FaceVerdict verdictFor(double cosine) =>
      cosine >= userCosine ? FaceVerdict.user : FaceVerdict.other;

  /// Forget everything, including the template (new reference photo).
  void reset() {
    _enrolled.clear();
    _template = null;
  }

  List<double> _averageOfEnrolled() {
    final List<double> sum = List<double>.filled(_enrolled.first.length, 0);
    for (final List<double> e in _enrolled) {
      for (int i = 0; i < sum.length; i++) {
        sum[i] += e[i];
      }
    }
    return _unit(sum);
  }

  static double _dot(List<double> a, List<double> b) {
    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
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
