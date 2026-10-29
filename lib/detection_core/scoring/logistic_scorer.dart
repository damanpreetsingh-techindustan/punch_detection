import 'dart:math' as math;

import '../config/detector_config.dart';
import '../features/impact_features.dart';

/// One term of the logistic model: weight * clip((x - center) / scale, ±4).
class ScorerTerm {
  final double center;
  final double scale;
  final double weight;

  const ScorerTerm({
    required this.center,
    required this.scale,
    required this.weight,
  });

  double z(double x) => ((x - center) / scale).clamp(-4.0, 4.0);

  Map<String, Object?> toJson() => <String, Object?>{
    'center': center,
    'scale': scale,
    'weight': weight,
  };

  static ScorerTerm fromJson(Map<String, Object?> json) => ScorerTerm(
    center: (json['center']! as num).toDouble(),
    scale: (json['scale']! as num).toDouble(),
    weight: (json['weight']! as num).toDouble(),
  );
}

/// Logistic regression over named features.
class LogisticModel {
  final double bias;
  final Map<String, ScorerTerm> terms;

  const LogisticModel({required this.bias, required this.terms});

  double logit(Map<String, double> features) {
    double s = bias;
    terms.forEach((String name, ScorerTerm t) {
      s += t.weight * t.z(features[name] ?? t.center);
    });
    return s;
  }

  double probability(Map<String, double> features) => sigmoid(logit(features));

  Map<String, Object?> toJson() => <String, Object?>{
    'bias': bias,
    'terms': <String, Object?>{
      for (final MapEntry<String, ScorerTerm> e in terms.entries)
        e.key: e.value.toJson(),
    },
  };

  static LogisticModel fromJson(Map<String, Object?> json) => LogisticModel(
    bias: (json['bias']! as num).toDouble(),
    terms: <String, ScorerTerm>{
      for (final MapEntry<String, Object?> e
          in (json['terms']! as Map<String, Object?>).entries)
        e.key: ScorerTerm.fromJson(e.value! as Map<String, Object?>),
    },
  );
}

double sigmoid(double x) => 1 / (1 + math.exp(-x));

/// Which model scored an impact.
enum ScorerMode { full, audioOnly, accelOnly }

/// The scorer of one mount type: a full model plus missing-sensor models, and
/// the decision thresholds. Loaded from `assets/detector/{rig,wall}.json`.
class ScorerSet {
  final String mount;
  final int version;
  final String source;
  final LogisticModel full;
  final LogisticModel audioOnly;
  final LogisticModel accelOnly;
  final double pHigh; // accept immediately
  final double pLow; // reject immediately
  final double pDecide; // threshold after waiting for the other sensor

  const ScorerSet({
    required this.mount,
    required this.version,
    required this.source,
    required this.full,
    required this.audioOnly,
    required this.accelOnly,
    required this.pHigh,
    required this.pLow,
    required this.pDecide,
  });

  ScorerSet copyWith({
    String? source,
    LogisticModel? full,
    LogisticModel? audioOnly,
    LogisticModel? accelOnly,
    double? pHigh,
    double? pLow,
    double? pDecide,
  }) => ScorerSet(
    mount: mount,
    version: version,
    source: source ?? this.source,
    full: full ?? this.full,
    audioOnly: audioOnly ?? this.audioOnly,
    accelOnly: accelOnly ?? this.accelOnly,
    pHigh: pHigh ?? this.pHigh,
    pLow: pLow ?? this.pLow,
    pDecide: pDecide ?? this.pDecide,
  );

  LogisticModel model(ScorerMode mode) => switch (mode) {
    ScorerMode.full => full,
    ScorerMode.audioOnly => audioOnly,
    ScorerMode.accelOnly => accelOnly,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'mount': mount,
    'version': version,
    'source': source,
    'pHigh': pHigh,
    'pLow': pLow,
    'pDecide': pDecide,
    'full': full.toJson(),
    'audioOnly': audioOnly.toJson(),
    'accelOnly': accelOnly.toJson(),
  };

  static ScorerSet fromJson(Map<String, Object?> json) => ScorerSet(
    mount: json['mount']! as String,
    version: (json['version'] as num? ?? 1).toInt(),
    source: json['source'] as String? ?? '',
    full: LogisticModel.fromJson(json['full']! as Map<String, Object?>),
    audioOnly: LogisticModel.fromJson(
      json['audioOnly']! as Map<String, Object?>,
    ),
    accelOnly: LogisticModel.fromJson(
      json['accelOnly']! as Map<String, Object?>,
    ),
    pHigh: (json['pHigh']! as num).toDouble(),
    pLow: (json['pLow']! as num).toDouble(),
    pDecide: (json['pDecide']! as num).toDouble(),
  );

  /// Hand-set initial weights encoding the field findings (identical to the
  /// shipped assets/detector/*.json; used when the asset cannot be loaded):
  /// - real hits rise 15-30 dB over the live floor with an attack < 5 ms;
  ///   gym noise rises ~5 dB with a 15+ ms attack;
  /// - claps are loud and sharp but bright (high centroid, little low band)
  ///   and shake the phone far less than the bag does;
  /// - soft low hooks are ~10 dB quieter with a slower attack, so the
  ///   accelerometer carries them;
  /// - the rig shows a stronger shock than the wall, so accel weighs more.
  static ScorerSet defaults(MountProfile mount) {
    final bool rig = mount == MountProfile.rig;
    const ScorerTerm attack = ScorerTerm(center: 10, scale: 4, weight: -1.0);
    const ScorerTerm centroid = ScorerTerm(
      center: 1.8,
      scale: 0.8,
      weight: -0.7,
    );
    const ScorerTerm lowRatio = ScorerTerm(
      center: 0.25,
      scale: 0.15,
      weight: 0.5,
    );
    const ScorerTerm crest = ScorerTerm(center: 9, scale: 3, weight: 0.2);
    const ScorerTerm lagDev = ScorerTerm(center: 25, scale: 12, weight: -0.5);
    const ScorerTerm strengthRatio = ScorerTerm(
      center: -2.5,
      scale: 1.5,
      weight: 0.4,
    );
    return ScorerSet(
      mount: mount.name,
      version: 1,
      source: 'hand-set initial weights (field findings, 2026-10)',
      pHigh: 0.85,
      pLow: 0.30,
      pDecide: 0.5,
      full: LogisticModel(
        bias: rig ? 0.3 : 0.5,
        terms: <String, ScorerTerm>{
          F.audioRiseMax: ScorerTerm(
            center: 12,
            scale: 5,
            weight: rig ? 0.8 : 1.0,
          ),
          F.audioAttack: attack,
          F.audioCentroid: centroid,
          F.audioLowRatio: lowRatio,
          F.audioCrest: crest,
          F.accelEnvRatio: ScorerTerm(
            center: 0.8,
            scale: 0.8,
            weight: rig ? 1.8 : 1.4,
          ),
          F.accelStrengthRel: ScorerTerm(
            center: -2,
            scale: 1.2,
            weight: rig ? 0.8 : 0.6,
          ),
          F.crossLagDev: lagDev,
          F.crossStrengthRatio: strengthRatio,
        },
      ),
      audioOnly: const LogisticModel(
        bias: 0,
        terms: <String, ScorerTerm>{
          F.audioRiseMax: ScorerTerm(center: 12, scale: 5, weight: 1.4),
          F.audioAttack: ScorerTerm(center: 10, scale: 4, weight: -1.3),
          F.audioCentroid: ScorerTerm(center: 1.8, scale: 0.8, weight: -0.9),
          F.audioLowRatio: ScorerTerm(center: 0.25, scale: 0.15, weight: 0.7),
          F.audioCrest: ScorerTerm(center: 9, scale: 3, weight: 0.3),
        },
      ),
      accelOnly: LogisticModel(
        bias: -0.5,
        terms: <String, ScorerTerm>{
          F.accelEnvRatio: ScorerTerm(
            center: 0.8,
            scale: 0.8,
            weight: rig ? 2.2 : 2.0,
          ),
          F.accelStrengthRel: const ScorerTerm(
            center: -2,
            scale: 1.2,
            weight: 1.0,
          ),
        },
      ),
    );
  }
}
