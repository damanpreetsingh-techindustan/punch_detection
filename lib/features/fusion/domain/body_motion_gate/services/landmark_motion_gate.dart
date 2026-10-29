import 'dart:math';

import '../../../../../core/utils/constants.dart';
import '../../services/impact_gate_evaluator.dart';
import '../i_body_motion_gate.dart';
import '../models/body_motion_evaluation.dart';
import '../models/body_motion_frame.dart';

/// Body-motion gate based on face / shoulder / arm landmark positions.
///
/// HOW THE SCORE IS MEASURED (for one impact):
///  1. Take the camera frames from [beforeMs] before to [afterMs] after the
///     audio spike. A punch moves the body mostly during the wind-up, so the
///     window starts well before the sound.
///  2. For every body point seen in at least two of those frames, find its
///     usual position (median x / median y) and how far each frame is from it.
///  3. The point's movement is the SECOND-largest of those distances (when the
///     point was seen 4+ times): a real movement shows on several frames, a
///     single ML Kit glitch on one frame does not count.
///  4. Divide by the body width so the score is the same near or far from the
///     camera. The impact's score is the score of the most-moved point.
///
/// Standing still: ≈ 0.01-0.03. Punch (even with only face + shoulders
/// visible: the shoulders rotate / drop, the head shifts): ≈ 0.08-0.30.
///
/// Pure: no clocks, no ML Kit types; time comes from the frames.
class LandmarkMotionGate implements IBodyMotionGate {
  /// Window start before the audio spike (ms).
  final int beforeMs;

  /// Window end after the audio spike (ms).
  final int afterMs;

  /// Fewer frames than this in the window → unknown.
  final int minFrames;

  /// Frames older than this (relative to the newest) are dropped.
  final int historyMs;

  final List<BodyMotionFrame> _frames = <BodyMotionFrame>[];

  LandmarkMotionGate({
    this.beforeMs = AppConstants.bodyMotionBeforeMs,
    this.afterMs = AppConstants.bodyMotionAfterMs,
    this.minFrames = AppConstants.bodyMotionMinFrames,
    this.historyMs = AppConstants.bodyMotionHistoryMs,
  });

  @override
  String get name => 'LandmarkMotionGate';

  @override
  int get frameCount => _frames.length;

  @override
  void addFrame(BodyMotionFrame frame) {
    _frames.add(frame);
    final int cutoff = frame.tMs - historyMs;
    while (_frames.isNotEmpty && _frames.first.tMs < cutoff) {
      _frames.removeAt(0);
    }
  }

  @override
  BodyMotionEvaluation evaluate({
    required int audioTsMs,
    required double minScore,
    required bool isRequired,
  }) {
    final int fromMs = audioTsMs - beforeMs;
    final int toMs = audioTsMs + afterMs;
    final List<BodyMotionFrame> window = _frames
        .where((BodyMotionFrame f) => f.tMs >= fromMs && f.tMs <= toMs)
        .toList();

    BodyMotionEvaluation unknown(String why) => BodyMotionEvaluation(
      state: isRequired
          ? BodyMotionGateState.unknown
          : BodyMotionGateState.notRequired,
      score: null,
      minScore: minScore,
      topPoint: null,
      pointScores: const <BodyMotionPoint, double>{},
      framesInWindow: window.length,
      bodyScale: null,
      detail: 'Motion unknown: $why',
    );

    if (window.length < minFrames) {
      return unknown('${window.length}/$minFrames camera frames in window');
    }

    final List<double> scales = window
        .map((BodyMotionFrame f) => f.bodyScale)
        .whereType<double>()
        .where((double s) => s > 0)
        .toList();
    if (scales.isEmpty) return unknown('body width not measurable');
    final double scale = _median(scales);

    final Map<BodyMotionPoint, double> pointScores =
        <BodyMotionPoint, double>{};
    for (final BodyMotionPoint point in BodyMotionPoint.values) {
      final List<Point<double>> positions = window
          .map((BodyMotionFrame f) => f.points[point])
          .whereType<Point<double>>()
          .toList();
      if (positions.length < 2) continue;
      pointScores[point] = _pointMovement(positions) / scale;
    }
    if (pointScores.isEmpty) return unknown('no body point seen twice');

    final MapEntry<BodyMotionPoint, double> top = pointScores.entries.reduce(
      (MapEntry<BodyMotionPoint, double> a, MapEntry<BodyMotionPoint, double> b) =>
          b.value > a.value ? b : a,
    );
    final double score = top.value;
    final bool moved = score >= minScore;
    final BodyMotionGateState state = !isRequired
        ? BodyMotionGateState.notRequired
        : (moved ? BodyMotionGateState.moved : BodyMotionGateState.still);

    return BodyMotionEvaluation(
      state: state,
      score: score,
      minScore: minScore,
      topPoint: top.key,
      pointScores: pointScores,
      framesInWindow: window.length,
      bodyScale: scale,
      detail:
          'Motion ${score.toStringAsFixed(3)} ${moved ? '>=' : '<'} '
          '${minScore.toStringAsFixed(3)} (top: ${top.key.name}, '
          '${window.length} frames, body ${scale.round()} px)',
    );
  }

  /// How far the point went from its usual (median) position, ignoring a
  /// single-frame outlier when there are enough frames (see class doc, step 3).
  static double _pointMovement(List<Point<double>> positions) {
    final Point<double> centre = Point<double>(
      _median(positions.map((Point<double> p) => p.x).toList()),
      _median(positions.map((Point<double> p) => p.y).toList()),
    );
    final List<double> distances =
        positions.map((Point<double> p) => p.distanceTo(centre)).toList()
          ..sort((double a, double b) => b.compareTo(a));
    return distances.length >= 4 ? distances[1] : distances.first;
  }

  static double _median(List<double> values) {
    final List<double> sorted = List<double>.of(values)..sort();
    final int mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  @override
  void reset() => _frames.clear();
}
