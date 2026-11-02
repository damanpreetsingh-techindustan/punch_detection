import 'dart:math';

import '../../../../core/utils/constants.dart';

/// The user's own look-match scores this session, turned into accept /
/// reject levels relative to them:
///   accept = median − [acceptSpreads] × spread
///   reject = median − [rejectSpreads] × spread
/// with spread = 1.4826 × MAD (the robust standard deviation).
///
/// So the levels follow this user, these clothes and this light instead of
/// fixed numbers: a plain shirt in even light gives a tight distribution and
/// tight levels, a patterned one in harsh light a wide one.
///
/// Until [minSamples] boxing frames are seen, the levels come from the
/// reference-photo frames with a wider spread floor
/// ([bootstrapMinSpread]): standing still says little about how much the
/// look varies while punching.
class UserMatchStats {
  final int capacity;
  final int minSamples;
  final double minSpread;
  final double bootstrapMinSpread;
  final double acceptSpreads;
  final double rejectSpreads;

  UserMatchStats({
    this.capacity = AppConstants.subjectMatchStatsCapacity,
    this.minSamples = AppConstants.subjectMatchStatsMinSamples,
    this.minSpread = AppConstants.subjectMatchMinSpread,
    this.bootstrapMinSpread = AppConstants.subjectMatchBootstrapMinSpread,
    this.acceptSpreads = AppConstants.subjectMatchAcceptSpreads,
    this.rejectSpreads = AppConstants.subjectMatchRejectSpreads,
  });

  final List<double> _samples = <double>[];
  List<double> _bootstrap = const <double>[];
  double _accept = 0;
  double _reject = 0;

  double get accept => _accept;
  double get reject => _reject;
  int get sampleCount => _samples.length;

  /// Starts over from the reference-photo frames' own scores.
  void bootstrap(List<double> scores) {
    _samples.clear();
    _bootstrap = List<double>.of(scores);
    _update();
  }

  /// A frame counted as the user (no jump just before it).
  void add(double score) {
    _samples.add(score);
    if (_samples.length > capacity) _samples.removeAt(0);
    _update();
  }

  void _update() {
    final bool measured = _samples.length >= minSamples;
    final List<double> source = measured ? _samples : _bootstrap;
    if (source.isEmpty) {
      _accept = 0;
      _reject = 0;
      return;
    }
    final List<double> sorted = List<double>.of(source)..sort();
    final double median = _median(sorted);
    final List<double> deviations =
        sorted.map((double s) => (s - median).abs()).toList()..sort();
    final double spread = max(
      1.4826 * _median(deviations),
      measured ? minSpread : bootstrapMinSpread,
    );
    _accept = median - acceptSpreads * spread;
    _reject = median - rejectSpreads * spread;
  }

  static double _median(List<double> sorted) {
    final int n = sorted.length;
    return n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }
}
