import '../config/detector_config.dart';
import '../engine/fusion_v2_engine.dart';
import '../features/impact_features.dart';

/// What a quick calibration learned.
class QuickCalibrationResult {
  final bool ok;
  final String message;
  final int punches;
  final int lowPunches;

  /// Accel onset minus audio onset (median), ms.
  final double? lagMs;
  final double decayDbPerS;
  final double ringTauMs;

  /// Seeds of the user's running medians.
  final double? audioStrengthDb;
  final double? accelStrength;

  /// Heuristic guess from the shock strength and ring (logged, not applied).
  final MountProfile suggestedMount;

  const QuickCalibrationResult({
    required this.ok,
    required this.message,
    required this.punches,
    required this.lowPunches,
    required this.lagMs,
    required this.decayDbPerS,
    required this.ringTauMs,
    required this.audioStrengthDb,
    required this.accelStrength,
    required this.suggestedMount,
  });

  Map<String, Object?> toMap() => <String, Object?>{
    'ok': ok,
    'message': message,
    'punches': punches,
    'lowPunches': lowPunches,
    'lagMs': lagMs,
    'decayDbPerS': decayDbPerS,
    'ringTauMs': ringTauMs,
    'audioStrengthDb': audioStrengthDb,
    'accelStrength': accelStrength,
    'suggestedMount': suggestedMount.name,
  };
}

/// Optional 10 s calibration for fusionV2: "throw 5 punches, 2 of them low".
///
/// While active it collects every impact that looks like a real hit (accepted,
/// or rejected but with both an audio and a shock candidate and p >= 0.2, so
/// the soft low hooks the default weights might reject are included). At the
/// end it learns the audio-accelerometer lag, the ring decay and ring time
/// constant (the engine learns those online from the isolated calibration
/// hits) and seeds the user's strength medians. A session works without it.
class QuickCalibrator {
  QuickCalibrator({
    required this.engine,
    this.durationMs = 10000,
    this.expectedPunches = 5,
    this.minPunches = 3,
  });

  final FusionV2Engine engine;
  final int durationMs;
  final int expectedPunches;
  final int minPunches;

  int? _startUs;
  final List<ImpactDecision> _punches = <ImpactDecision>[];

  bool get isActive => _startUs != null;
  int get punchesSeen => _punches.length;

  void start(int nowUs) {
    _startUs = nowUs;
    _punches.clear();
  }

  /// Feeds every decision made while active.
  void addDecision(ImpactDecision d) {
    if (!isActive || d.path == 'hard') return;
    final bool plausible =
        d.accepted ||
        (d.hasAudioCandidate && d.hasShockCandidate && d.pRaw >= 0.2);
    if (plausible) _punches.add(d);
  }

  /// Finishes when [nowUs] is past the calibration window; null before.
  QuickCalibrationResult? finishIfDue(int nowUs) {
    final int? start = _startUs;
    if (start == null || nowUs - start < durationMs * 1000) return null;
    return finish();
  }

  QuickCalibrationResult finish() {
    _startUs = null;
    double? median(Iterable<double> values) {
      final List<double> v = values.toList()..sort();
      if (v.isEmpty) return null;
      return v.length.isOdd
          ? v[v.length ~/ 2]
          : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
    }

    final List<double> rises = <double>[
      for (final ImpactDecision d in _punches)
        if (d.hasAudioCandidate) d.features[F.audioRiseMax] ?? 0,
    ];
    final List<double> jerks = <double>[
      for (final ImpactDecision d in _punches)
        if (d.hasShockCandidate) d.features[F.accelPeakJerk] ?? 0,
    ];
    final List<double> lags = <double>[
      for (final ImpactDecision d in _punches)
        if (d.features[F.crossLag] != null) d.features[F.crossLag]!,
    ];
    final double? riseMedian = median(rises);
    final int low = riseMedian == null
        ? 0
        : rises.where((double r) => r < riseMedian - 6).length;
    final double? jerkMedian = median(jerks);
    final double ring = engine.shock.ringTauMs;
    final MountProfile suggested = (jerkMedian ?? 0) >= 250 || ring >= 220
        ? MountProfile.rig
        : MountProfile.wall;

    final bool ok = _punches.length >= minPunches;
    final QuickCalibrationResult result = QuickCalibrationResult(
      ok: ok,
      message: ok
          ? 'Calibrated from ${_punches.length} punches ($low low)'
          : 'Only ${_punches.length} punches detected; keeping the defaults',
      punches: _punches.length,
      lowPunches: low,
      lagMs: median(lags),
      decayDbPerS: engine.audio.decayDbPerS,
      ringTauMs: ring,
      audioStrengthDb: riseMedian,
      accelStrength: jerkMedian,
      suggestedMount: suggested,
    );
    if (ok) {
      engine.applySeeds(
        lagMs: result.lagMs,
        audioStrengthDb: riseMedian,
        accelStrength: jerkMedian,
      );
    }
    return result;
  }
}
