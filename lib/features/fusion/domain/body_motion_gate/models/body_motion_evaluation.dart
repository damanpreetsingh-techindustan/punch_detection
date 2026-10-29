import '../../services/impact_gate_evaluator.dart';
import 'body_motion_frame.dart';

/// Result of measuring the user's movement around one impact.
///
/// Carries everything the session log needs to explain the decision and to
/// tune the level: the score, the bar it was compared with, which body point
/// moved most and the score of every point.
class BodyMotionEvaluation {
  /// moved / still / unknown, or notRequired when the gate is not applied.
  /// The score is filled in either way (logged even when the gate is off).
  final BodyMotionGateState state;

  /// Movement of the most-moved point, as a fraction of the body width
  /// (null when it could not be measured).
  final double? score;

  /// Bar the score was compared with (from the difficulty level).
  final double minScore;

  /// Point that moved most (null when nothing was measured).
  final BodyMotionPoint? topPoint;

  /// Score of every point that was seen in at least two frames.
  final Map<BodyMotionPoint, double> pointScores;

  /// Camera frames inside the motion window.
  final int framesInWindow;

  /// Body width used for the score (image px), null when unknown.
  final double? bodyScale;

  /// Human-readable one-liner for logs and the decision reason.
  final String detail;

  const BodyMotionEvaluation({
    required this.state,
    required this.score,
    required this.minScore,
    required this.topPoint,
    required this.pointScores,
    required this.framesInWindow,
    required this.bodyScale,
    required this.detail,
  });

  /// True when the measured movement reaches the bar (whether or not the gate
  /// is applied); false when it was measured and too small; null when unknown.
  bool? get wouldPass => score == null ? null : score! >= minScore;

  /// Compact per-point scores for the JSON log, e.g. {face: 0.031, ...}.
  Map<String, double> get pointScoresForLog => <String, double>{
    for (final MapEntry<BodyMotionPoint, double> e in pointScores.entries)
      e.key.name: double.parse(e.value.toStringAsFixed(3)),
  };
}
