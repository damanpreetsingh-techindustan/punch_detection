import 'dart:math' as math;
import 'dart:typed_data';

import '../accel/shock_tracker.dart';
import '../audio/audio_onset_tracker.dart';
import '../config/detector_config.dart';
import '../context/soft_context.dart';
import '../dsp/dsp.dart';
import '../features/impact_features.dart';
import '../scoring/logistic_scorer.dart';

/// One decision of the fusionV2 engine, with everything needed to audit it.
class ImpactDecision {
  final int id;
  final int onsetUs;
  final int decidedUs; // data time at which the decision could be made
  final bool accepted;
  final double p; // after soft context
  final double pRaw; // scorer output
  /// fast | low | direct | waited | hard
  final String path;
  final String reason;
  final ScorerMode mode;
  final bool hasAudioCandidate;
  final bool hasShockCandidate;
  final String hand;
  final Map<String, double> features;
  final Map<String, double> contextFactors;

  const ImpactDecision({
    required this.id,
    required this.onsetUs,
    required this.decidedUs,
    required this.accepted,
    required this.p,
    required this.pRaw,
    required this.path,
    required this.reason,
    required this.mode,
    required this.hasAudioCandidate,
    required this.hasShockCandidate,
    required this.hand,
    required this.features,
    required this.contextFactors,
  });

  int get latencyUs => decidedUs - onsetUs;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'onsetUs': onsetUs,
    'decidedUs': decidedUs,
    'latencyMs': latencyUs / 1000,
    'accepted': accepted,
    'p': p,
    'pRaw': pRaw,
    'path': path,
    'reason': reason,
    'mode': mode.name,
    'audioCandidate': hasAudioCandidate,
    'shockCandidate': hasShockCandidate,
    'hand': hand,
    'features': features,
    'context': contextFactors,
  };
}

class _Impact {
  _Impact(this.id, this.onsetUs);
  final int id;
  int onsetUs; // audio onset, or shock onset - lag
  AudioCandidate? audio;
  ShockCandidate? shock;
  int? waitUntilUs;
}

/// Adaptive impact-fusion detector (pure Dart).
///
/// capture -> candidates (audio onset OR accelerometer shock) -> features
/// (<= 40 ms after onset, normalised by the live room and this user) -> score
/// (logistic, per mount) -> soft context (odds multipliers) -> decide.
///
/// Feed it with [addAudio] / [addAccel] in time order; context with
/// [addTouch], [setSettingsOpen], [setCameraAvailable], [notePersonValid],
/// [setArmActivity]. Each feeding call returns the decisions it completed.
class FusionV2Engine {
  FusionV2Engine({
    this.config = const DetectorConfig(),
    required this.mount,
    ScorerSet? scorer,
  }) : scorer = scorer ?? ScorerSet.defaults(mount),
       audio = AudioOnsetTracker(
         config: config,
         initialDecayDbPerS: MountDefaults.of(mount).decayDbPerS,
       ),
       shock = ShockTracker(
         config: config,
         initialRingTauMs: MountDefaults.of(mount).ringTauMs,
       ),
       context = SoftContext(config),
       _audioStrength = RunningMedian(
         capacity: config.strengthHistory,
         seed: MountDefaults.of(mount).seedAudioStrengthDb,
       ),
       _accelStrength = RunningMedian(
         capacity: config.strengthHistory,
         seed: MountDefaults.of(mount).seedAccelStrength,
       );

  final DetectorConfig config;
  final MountProfile mount;
  final ScorerSet scorer;
  final AudioOnsetTracker audio;
  final ShockTracker shock;
  final SoftContext context;
  final RunningMedian _audioStrength;
  final RunningMedian _accelStrength;

  /// Learned audio -> accelerometer lag (accel onset minus audio onset), ms.
  double learnedLagMs = 0;

  final List<_Impact> _pending = <_Impact>[];
  final List<(int, bool)> _recent = <(int, bool)>[]; // (onsetUs, accepted)
  int _nextId = 1;
  int _nowUs = 0;
  int? _lastImpactOnsetUs;
  ImpactDecision? lastDecision;

  int get nowUs => _nowUs;
  int get pendingCount => _pending.length;
  double get medianAudioStrengthDb => _audioStrength.median;
  double get medianAccelStrength => _accelStrength.median;

  bool _audioAvailable() =>
      audio.hasStarted &&
      _nowUs - audio.coveredUntilUs <= config.accelStaleMs * 1000;

  bool _accelAvailable() => shock.isAvailable(_nowUs);

  // ─── Feeding ───────────────────────────────────────────────────────────────

  List<ImpactDecision> addAudio(Int16List samples, int firstSampleUs) {
    for (final AudioCandidate c in audio.process(samples, firstSampleUs)) {
      _attach(c.onsetUs, audioCandidate: c);
    }
    _nowUs = math.max(_nowUs, audio.coveredUntilUs);
    return _evaluate();
  }

  List<ImpactDecision> addAccel(AccelSampleIn s) {
    for (final ShockCandidate c in shock.add(s)) {
      _attach(c.onsetUs - (learnedLagMs * 1000).round(), shockCandidate: c);
    }
    _nowUs = math.max(_nowUs, s.tUs);
    return _evaluate();
  }

  void addTouch(int tUs) => context.addTouch(tUs);
  void setSettingsOpen(bool open, int tUs) =>
      context.setSettingsOpen(open, tUs);
  void setCameraAvailable(bool available, int tUs) =>
      context.setCameraAvailable(available, tUs);
  void notePersonValid(int tUs) => context.notePersonValid(tUs);
  void setArmActivity(double score, String hand, int tUs) =>
      context.setArmActivity(score, hand, tUs);

  /// Advances time without new data (e.g. a sensor stopped); decides what
  /// became decidable.
  List<ImpactDecision> advance(int nowUs) {
    _nowUs = math.max(_nowUs, nowUs);
    return _evaluate();
  }

  /// Decides every pending impact with the data available (end of session).
  List<ImpactDecision> flush() => _evaluate(force: true);

  // ─── Merging ───────────────────────────────────────────────────────────────

  /// Candidates closer than `impactMergeMs` to a pending impact merge into it
  /// (the stronger candidate of each sensor is kept, so a noise precursor
  /// cannot hide the real hit's onset). A candidate near an impact that was
  /// already ACCEPTED is the same hit and is dropped; near a REJECTED one it
  /// is new evidence and starts a new impact.
  void _attach(
    int refOnsetUs, {
    AudioCandidate? audioCandidate,
    ShockCandidate? shockCandidate,
  }) {
    final int mergeUs = config.impactMergeMs * 1000;
    for (final (int, bool) r in _recent) {
      if (r.$2 && (r.$1 - refOnsetUs).abs() < mergeUs) return;
    }
    for (final _Impact i in _pending) {
      if ((i.onsetUs - refOnsetUs).abs() < mergeUs) {
        final AudioCandidate? oldAudio = i.audio;
        if (audioCandidate != null &&
            (oldAudio == null ||
                audioCandidate.noveltyDb > oldAudio.noveltyDb)) {
          i.audio = audioCandidate;
          i.onsetUs = audioCandidate.onsetUs; // audio onset is the reference
        }
        final ShockCandidate? oldShock = i.shock;
        if (shockCandidate != null &&
            (oldShock == null || shockCandidate.ratio > oldShock.ratio)) {
          i.shock = shockCandidate;
          if (i.audio == null) i.onsetUs = refOnsetUs;
        }
        return;
      }
    }
    final _Impact impact = _Impact(_nextId++, refOnsetUs)
      ..audio = audioCandidate
      ..shock = shockCandidate;
    _pending.add(impact);
    audio.notifyImpact(refOnsetUs);
    shock.notifyImpact(refOnsetUs);
  }

  // ─── Deciding ──────────────────────────────────────────────────────────────

  int _audioRef(_Impact i) =>
      i.audio?.onsetUs ?? (i.shock!.onsetUs - (learnedLagMs * 1000).round());

  int _accelRef(_Impact i) =>
      i.shock?.onsetUs ?? (i.onsetUs + (learnedLagMs * 1000).round());

  bool _isReady(_Impact i, bool audioOk, bool accelOk) {
    final int fw = config.featureWindowMs * 1000;
    final bool audioReady =
        !audioOk || audio.coveredUntilUs >= _audioRef(i) + fw;
    final int? accelCovered = shock.coveredUntilUs;
    final bool accelReady =
        !accelOk || (accelCovered != null && accelCovered >= _accelRef(i) + fw);
    return audioReady && accelReady;
  }

  List<ImpactDecision> _evaluate({bool force = false}) {
    final List<ImpactDecision> out = <ImpactDecision>[];
    if (_pending.isEmpty) return out;
    final bool audioOk = _audioAvailable();
    final bool accelOk = _accelAvailable();
    _pending.sort((_Impact a, _Impact b) => a.onsetUs.compareTo(b.onsetUs));
    for (final _Impact i in List<_Impact>.of(_pending)) {
      if (!force && !_isReady(i, audioOk, accelOk)) continue;
      final ImpactDecision? d = _tryDecide(i, audioOk, accelOk, force);
      if (d != null) {
        _pending.remove(i);
        _recent.add((i.onsetUs, d.accepted));
        _recent.removeWhere((r) => r.$1 < i.onsetUs - 1000000);
        out.add(d);
        lastDecision = d;
      }
    }
    return out;
  }

  ImpactDecision? _tryDecide(
    _Impact i,
    bool audioOk,
    bool accelOk,
    bool force,
  ) {
    final ScorerMode mode = audioOk && accelOk
        ? ScorerMode.full
        : (audioOk ? ScorerMode.audioOnly : ScorerMode.accelOnly);
    final Map<String, double> features = _features(i, audioOk, accelOk);
    final double pRaw = scorer.model(mode).probability(features);
    final ContextResult ctx = context.evaluate(
      onsetUs: i.onsetUs,
      decideUs: _nowUs,
    );
    final String hand = context.armActivityAt(_nowUs)?.$2 ?? 'unknown';

    ImpactDecision decide(bool accepted, double p, String path, String reason) {
      final ImpactDecision d = ImpactDecision(
        id: i.id,
        onsetUs: i.onsetUs,
        decidedUs: _nowUs,
        accepted: accepted,
        p: p,
        pRaw: pRaw,
        path: path,
        reason: reason,
        mode: mode,
        hasAudioCandidate: i.audio != null,
        hasShockCandidate: i.shock != null,
        hand: hand,
        features: features,
        contextFactors: ctx.factors,
      );
      if (accepted) _onAccepted(i, features);
      return d;
    }

    if (ctx.hardReject != null) {
      return decide(false, 0, 'hard', ctx.hardReject!);
    }
    final double odds = pRaw / math.max(1e-9, 1 - pRaw) * ctx.oddsFactor;
    final double p = odds / (1 + odds);
    if (p >= scorer.pHigh) return decide(true, p, 'fast', 'score >= pHigh');
    if (p < scorer.pLow) return decide(false, p, 'low', 'score < pLow');

    // Borderline: wait (once) for the other sensor's evidence if it is
    // running and has not produced a candidate for this impact.
    final bool missingOther =
        (i.audio == null && audioOk) || (i.shock == null && accelOk);
    if (!force && missingOther) {
      final int readyUs = math.max(
        _audioRef(i) + config.featureWindowMs * 1000,
        _accelRef(i) + config.featureWindowMs * 1000,
      );
      i.waitUntilUs ??= readyUs + config.waitForOtherSensorMs * 1000;
      if (_nowUs < i.waitUntilUs!) return null;
      return decide(
        p >= scorer.pDecide,
        p,
        'waited',
        'borderline after waiting for the other sensor',
      );
    }
    return decide(p >= scorer.pDecide, p, 'direct', 'borderline');
  }

  Map<String, double> _features(_Impact i, bool audioOk, bool accelOk) {
    final int fw = config.featureWindowMs * 1000;
    final Map<String, double> f = <String, double>{};
    final Map<String, double> a = audioOk
        ? audioFeatures(
            audio.window(_audioRef(i) - 2000, _audioRef(i) + fw),
            onsetUs: _audioRef(i),
            noveltyDb: i.audio?.noveltyDb ?? 0,
            config: config,
          )
        : <String, double>{F.audioPresent: 0};
    final Map<String, double> s = accelOk
        ? accelFeatures(shock.window(_accelRef(i) - 10000, _accelRef(i) + fw))
        : <String, double>{F.accelPresent: 0};
    f.addAll(a);
    f.addAll(s);
    final double? lagMs = i.audio != null && i.shock != null
        ? (i.shock!.onsetUs - i.audio!.onsetUs) / 1000
        : null;
    f.addAll(
      crossFeatures(
        audio: a,
        accel: s,
        lagMs: lagMs,
        learnedLagMs: learnedLagMs,
        medianAudioStrengthDb: _audioStrength.median,
        medianAccelStrength: _accelStrength.median,
        mergeWindowMs: config.mergeWindowMs.toDouble(),
      ),
    );
    return f;
  }

  void _onAccepted(_Impact i, Map<String, double> features) {
    final int? last = _lastImpactOnsetUs;
    final bool isolated = last == null || i.onsetUs - last > 500000;
    _lastImpactOnsetUs = i.onsetUs;
    context.noteAccepted(i.onsetUs);
    audio.notifyAccepted(_audioRef(i), isolated: isolated);
    shock.notifyAccepted(_accelRef(i), isolated: isolated);
    if (i.audio != null) _audioStrength.add(features[F.audioRiseMax] ?? 0);
    if (i.shock != null) _accelStrength.add(features[F.accelPeakJerk] ?? 0);
    if (i.audio != null && i.shock != null) {
      final double lag = (i.shock!.onsetUs - i.audio!.onsetUs) / 1000;
      learnedLagMs += config.lagLearnRate * (lag - learnedLagMs);
      learnedLagMs = learnedLagMs.clamp(
        -config.maxAbsLagMs,
        config.maxAbsLagMs,
      );
    }
  }

  /// Live values for the debug panel.
  Map<String, Object?> debugState() => <String, Object?>{
    'audioFloorsDb': audio.floorsDb.toList(),
    'audioFullFloorDb': audio.fullFloorDb,
    'decayDbPerS': audio.decayDbPerS,
    'jerkFloor': shock.floorJerk,
    'ringTauMs': shock.ringTauMs,
    'learnedLagMs': learnedLagMs,
    'medianAudioStrengthDb': _audioStrength.median,
    'medianAccelStrength': _accelStrength.median,
    'lastP': lastDecision?.p,
    'lastLatencyMs': lastDecision == null
        ? null
        : lastDecision!.latencyUs / 1000,
    'pending': _pending.length,
  };
}
