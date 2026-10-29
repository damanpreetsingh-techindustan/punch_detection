import 'dart:math' as math;
import 'dart:typed_data';

import '../accel/shock_tracker.dart';
import '../audio/audio_onset_tracker.dart';
import '../config/detector_config.dart';
import '../dsp/dsp.dart';

/// Stable feature names (used as keys in the scorer JSON and in logs).
abstract final class F {
  static const String audioPresent = 'audio_present';
  static const String audioRiseMax = 'audio_rise_max_db';
  static const String audioRiseBand0 = 'audio_rise_b0_db';
  static const String audioRiseBand1 = 'audio_rise_b1_db';
  static const String audioRiseBand2 = 'audio_rise_b2_db';
  static const String audioRiseBand3 = 'audio_rise_b3_db';
  static const String audioNovelty = 'audio_novelty_db';
  static const String audioAttack = 'audio_attack_ms';
  static const String audioPeak = 'audio_peak_dbfs';
  static const String audioClippedMs = 'audio_clipped_ms';
  static const String audioCentroid = 'audio_centroid_khz';
  static const String audioLowRatio = 'audio_low_ratio';
  static const String audioCrest = 'audio_crest_db';
  static const String audioStrengthRel = 'audio_strength_rel_log2';
  static const String accelPresent = 'accel_present';
  static const String accelEnvRatio = 'accel_env_ratio_log2';
  static const String accelPeakJerk = 'accel_peak_jerk';
  static const String accelPeakAcc = 'accel_peak_acc';
  static const String accelAxis = 'accel_axis';
  static const String accelEnergy = 'accel_energy_log10';
  static const String accelStrengthRel = 'accel_strength_rel_log2';
  static const String crossLagDev = 'cross_lag_dev_ms';

  /// Signed accel onset minus audio onset (ms); only when both candidates
  /// exist. Logged and used by the quick calibration, not by the scorer.
  static const String crossLag = 'cross_lag_ms';
  static const String crossStrengthRatio = 'cross_strength_log_ratio';
}

/// Feature vector of one impact, computed from at most
/// `config.featureWindowMs` (<= 40 ms) after the onset.
class ImpactFeatures {
  final Map<String, double> values;
  final bool hasAudioData;
  final bool hasAccelData;

  const ImpactFeatures(
    this.values, {
    required this.hasAudioData,
    required this.hasAccelData,
  });

  double operator [](String name) => values[name] ?? 0;

  Map<String, double> toMap() => Map<String, double>.of(values);
}

/// Audio part of the features (room-normalised: rises are over the live floor).
Map<String, double> audioFeatures(
  AudioWindow w, {
  required int onsetUs,
  required double noveltyDb,
  required DetectorConfig config,
}) {
  final Map<String, double> f = <String, double>{F.audioPresent: 1};
  // Per-band rise over the floor: loudest hop in the window.
  final int bands = w.floorDb.length;
  final List<double> rises = List<double>.filled(bands, 0);
  double maxNovelty = noveltyDb;
  for (final AudioHop h in w.hops) {
    for (int b = 0; b < bands; b++) {
      rises[b] = math.max(rises[b], h.bandDb[b] - w.floorDb[b]);
    }
    maxNovelty = math.max(maxNovelty, h.noveltyDb);
  }
  const List<String> bandNames = <String>[
    F.audioRiseBand0,
    F.audioRiseBand1,
    F.audioRiseBand2,
    F.audioRiseBand3,
  ];
  for (int b = 0; b < math.min(bands, 4); b++) {
    f[bandNames[b]] = rises[b];
  }
  f[F.audioRiseMax] = rises.reduce(math.max);
  f[F.audioNovelty] = maxNovelty;

  final Float64List x = w.samples;
  final double us = w.usPerSample;
  final int onsetIdx = ((onsetUs - w.firstSampleUs) / us).round().clamp(
    0,
    x.length,
  );

  // 1 ms peak envelope -> attack time (onset to 70 % of the window peak).
  const int sub = 16;
  final List<double> env = <double>[];
  for (int i = onsetIdx; i < x.length; i += sub) {
    double p = 0;
    for (int k = i; k < math.min(i + sub, x.length); k++) {
      p = math.max(p, x[k].abs());
    }
    env.add(p);
  }
  final double peak = env.isEmpty ? 0 : env.reduce(math.max);
  double attackMs = config.featureWindowMs.toDouble();
  for (int j = 0; j < env.length; j++) {
    if (env[j] >= 0.7 * peak) {
      attackMs = j * sub * us / 1000;
      break;
    }
  }
  f[F.audioAttack] = attackMs;

  // Clipping-aware peak: each clipped millisecond hides about 3 dB of peak.
  int clipped = 0;
  double sumSq = 0;
  for (int i = onsetIdx; i < x.length; i++) {
    if (x[i].abs() >= 32000 / 32768) clipped++;
    sumSq += x[i] * x[i];
  }
  final double clippedMs = clipped * us / 1000;
  f[F.audioClippedMs] = clippedMs;
  f[F.audioPeak] = dbFromAmplitude(peak) + math.min(12.0, 3.0 * clippedMs);
  final int n = x.length - onsetIdx;
  final double rms = n > 0 ? math.sqrt(sumSq / n) : 0;
  f[F.audioCrest] = rms > 0 ? dbFromAmplitude(peak) - dbFromAmplitude(rms) : 0;

  // Spectrum of the first 20 ms: centroid and low-band ratio.
  final int specN = math.min(
    x.length - onsetIdx,
    (config.spectralWindowMs * 1000 / us).round(),
  );
  if (specN >= 64) {
    final Float64List power = powerSpectrum(
      Float64List.sublistView(x, onsetIdx, onsetIdx + specN),
      512,
    );
    final double binHz = config.audioSampleRate / 512;
    double total = 0, weighted = 0, low = 0;
    for (int k = 0; k < power.length; k++) {
      final double hz = k * binHz;
      if (hz < config.bandEdgesHz.first) continue;
      total += power[k];
      weighted += power[k] * hz;
      if (hz < config.bandEdgesHz[1]) low += power[k];
    }
    f[F.audioCentroid] = total > 0 ? weighted / total / 1000 : 0;
    f[F.audioLowRatio] = total > 0 ? low / total : 0;
  } else {
    f[F.audioCentroid] = 0;
    f[F.audioLowRatio] = 0;
  }
  return f;
}

/// Accelerometer part of the features over the points of the window.
Map<String, double> accelFeatures(List<AccelPoint> points) {
  if (points.isEmpty) {
    return <String, double>{
      F.accelPresent: 0,
      F.accelEnvRatio: log2(0.25),
      F.accelPeakJerk: 0,
      F.accelPeakAcc: 0,
      F.accelAxis: -1,
      F.accelEnergy: -6,
    };
  }
  double ratio = 0, jerk = 0, acc = 0, energy = 0;
  double ex = 0, ey = 0, ez = 0;
  for (int i = 0; i < points.length; i++) {
    final AccelPoint p = points[i];
    ratio = math.max(ratio, p.ratio);
    jerk = math.max(jerk, p.jerk);
    acc = math.max(acc, p.accelMagnitude);
    final double dt = i == 0 ? 0 : (p.tUs - points[i - 1].tUs) / 1e6;
    energy += p.accelMagnitude * p.accelMagnitude * dt;
    ex += p.jx * p.jx;
    ey += p.jy * p.jy;
    ez += p.jz * p.jz;
  }
  final double axis = ex >= ey && ex >= ez ? 0 : (ey >= ez ? 1 : 2);
  return <String, double>{
    F.accelPresent: 1,
    F.accelEnvRatio: log2(math.max(ratio, 1e-3)),
    F.accelPeakJerk: jerk,
    F.accelPeakAcc: acc,
    F.accelAxis: axis,
    F.accelEnergy: math.log(energy + 1e-6) / math.ln10,
  };
}

/// User-normalised strengths and cross-sensor features.
Map<String, double> crossFeatures({
  required Map<String, double> audio,
  required Map<String, double> accel,
  required double? lagMs,
  required double learnedLagMs,
  required double medianAudioStrengthDb,
  required double medianAccelStrength,
  required double mergeWindowMs,
}) {
  final double audioRise = audio[F.audioRiseMax] ?? 0;
  final double audioRel =
      math.max(audioRise, 0.5) / math.max(medianAudioStrengthDb, 1);
  final double accelRel =
      math.max(accel[F.accelPeakJerk] ?? 0, 1) /
      math.max(medianAccelStrength, 1);
  return <String, double>{
    F.audioStrengthRel: log2(audioRel),
    F.accelStrengthRel: log2(accelRel),
    F.crossLagDev: lagMs == null
        ? mergeWindowMs
        : (lagMs - learnedLagMs).abs().clamp(0, 200).toDouble(),
    F.crossStrengthRatio: log2(accelRel / audioRel),
    F.crossLag: ?lagMs,
  };
}
