/// Mount types of the fusionV2 detector. `rig` = phone on the vertical rig pole
/// (the app's `MountType.pole`), `wall` = phone on a wall bracket.
enum MountProfile {
  rig,
  wall;

  static MountProfile fromName(String? name) {
    switch ((name ?? '').toLowerCase()) {
      case 'rig':
      case 'pole':
        return MountProfile.rig;
      default:
        return MountProfile.wall;
    }
  }
}

/// Every tunable of the fusionV2 detector in one place. Nothing in the core is
/// hard-coded; all thresholds come from here (and the scorer JSON assets).
/// See docs/detection-v2.md for what each value does.
class DetectorConfig {
  // ─── Audio front end ───────────────────────────────────────────────────────
  final int audioSampleRate;

  /// Microseconds per audio sample (1e6 / rate; replay may pass a measured one).
  final double audioUsPerSample;
  final int hopSamples; // 80 = 5 ms at 16 kHz
  final List<double> bandEdgesHz; // 4 bands: 60-300, 300-1500, 1.5-4k, 4-8k
  final List<double> bandWeights;
  final double floorPercentile; // 20th percentile of band energy
  final int floorWindowMs; // over the last 3 s
  final int
  floorExclusionAfterImpactMs; // skip frames 300 ms after an accepted impact
  /// Frames join the floor this late (after their decisions are known).
  final int floorIngestDelayMs;

  /// No audio candidates until the floor has this much history.
  final int minFloorHistoryMs;
  final double audioNoveltyMarginDb; // candidate when novelty exceeds this

  /// Novelty is max(weighted mean rise, strongest single-band rise - this),
  /// so a hit that rises in one band only (a low hook) still triggers while
  /// broadband gym noise (+5 dB everywhere) does not.
  final double singleBandExtraDb;
  final int audioRetriggerMs;
  final int
  peakSearchMs; // after an onset, the reference follows the rising peak
  final double decayLearnRate;
  final double minDecayDbPerS;
  final double maxDecayDbPerS;

  // ─── Accelerometer front end ───────────────────────────────────────────────
  final double accelHighPassHz;
  final double shockK; // jerk > envelope * k + floor
  final double shockFloorPercentile;
  final double shockFloorScale;
  final double shockMinJerk; // m/s³, absolute lower bound of the floor
  final int shockFloorWindowMs;
  final int shockRetriggerMs;
  final double ringTauLearnRate;
  final double minRingTauMs;
  final double maxRingTauMs;
  final int accelStaleMs; // no sample for this long = accelerometer unavailable

  // ─── Merger / features ─────────────────────────────────────────────────────
  final int
  mergeWindowMs; // audio and accel candidates within this (+ lag) merge
  final int impactMergeMs; // impacts closer than this merge
  final double lagLearnRate;
  final double maxAbsLagMs;
  final int
  featureWindowMs; // features use at most this much after onset (<= 40)
  final int spectralWindowMs;

  // ─── User normalisation ────────────────────────────────────────────────────
  final int strengthHistory;

  // ─── Decider ───────────────────────────────────────────────────────────────
  final int waitForOtherSensorMs;

  // ─── Soft context ──────────────────────────────────────────────────────────
  final int presenceWindowMs;
  final double presenceMissingFactor;
  final int personGoneHardRejectMs;
  final double armActivityMinFactor;
  final double armActivityMaxFactor;
  final int armActivityMaxAgeMs;
  final int maxImpactsPerSecond;
  final double rateFactor;
  final int touchLockoutBeforeMs;
  final int touchLockoutAfterMs;
  final int settingsCooldownMs;

  const DetectorConfig({
    this.audioSampleRate = 16000,
    this.audioUsPerSample = 62.5,
    this.hopSamples = 80,
    this.bandEdgesHz = const <double>[60, 300, 1500, 4000, 8000],
    this.bandWeights = const <double>[1.0, 1.0, 0.8, 0.6],
    this.floorPercentile = 20,
    this.floorWindowMs = 3000,
    this.floorExclusionAfterImpactMs = 300,
    this.floorIngestDelayMs = 150,
    this.minFloorHistoryMs = 200,
    this.audioNoveltyMarginDb = 6.0,
    this.singleBandExtraDb = 6.0,
    this.audioRetriggerMs = 30,
    this.peakSearchMs = 30,
    this.decayLearnRate = 0.2,
    this.minDecayDbPerS = 20,
    this.maxDecayDbPerS = 400,
    this.accelHighPassHz = 2.0,
    this.shockK = 1.5,
    this.shockFloorPercentile = 50,
    this.shockFloorScale = 3.0,
    this.shockMinJerk = 20.0,
    this.shockFloorWindowMs = 3000,
    this.shockRetriggerMs = 30,
    this.ringTauLearnRate = 0.2,
    this.minRingTauMs = 30,
    this.maxRingTauMs = 600,
    this.accelStaleMs = 500,
    this.mergeWindowMs = 40,
    this.impactMergeMs = 80,
    this.lagLearnRate = 0.1,
    this.maxAbsLagMs = 60,
    this.featureWindowMs = 30,
    this.spectralWindowMs = 20,
    this.strengthHistory = 30,
    this.waitForOtherSensorMs = 80,
    this.presenceWindowMs = 1500,
    this.presenceMissingFactor = 0.15,
    this.personGoneHardRejectMs = 5000,
    this.armActivityMinFactor = 0.5,
    this.armActivityMaxFactor = 1.5,
    this.armActivityMaxAgeMs = 500,
    this.maxImpactsPerSecond = 10,
    this.rateFactor = 0.3,
    this.touchLockoutBeforeMs = 100,
    this.touchLockoutAfterMs = 400,
    this.settingsCooldownMs = 1000,
  }) : assert(featureWindowMs <= 40, 'features may use at most 40 ms');

  int get hopUs => (hopSamples * audioUsPerSample).round();

  DetectorConfig copyWith({
    double? audioUsPerSample,
    double? audioNoveltyMarginDb,
    double? shockK,
    double? shockFloorScale,
    int? featureWindowMs,
    int? waitForOtherSensorMs,
    double? presenceMissingFactor,
  }) {
    return DetectorConfig(
      audioSampleRate: audioSampleRate,
      audioUsPerSample: audioUsPerSample ?? this.audioUsPerSample,
      hopSamples: hopSamples,
      bandEdgesHz: bandEdgesHz,
      bandWeights: bandWeights,
      floorPercentile: floorPercentile,
      floorWindowMs: floorWindowMs,
      floorExclusionAfterImpactMs: floorExclusionAfterImpactMs,
      floorIngestDelayMs: floorIngestDelayMs,
      minFloorHistoryMs: minFloorHistoryMs,
      audioNoveltyMarginDb: audioNoveltyMarginDb ?? this.audioNoveltyMarginDb,
      singleBandExtraDb: singleBandExtraDb,
      audioRetriggerMs: audioRetriggerMs,
      peakSearchMs: peakSearchMs,
      decayLearnRate: decayLearnRate,
      minDecayDbPerS: minDecayDbPerS,
      maxDecayDbPerS: maxDecayDbPerS,
      accelHighPassHz: accelHighPassHz,
      shockK: shockK ?? this.shockK,
      shockFloorPercentile: shockFloorPercentile,
      shockFloorScale: shockFloorScale ?? this.shockFloorScale,
      shockMinJerk: shockMinJerk,
      shockFloorWindowMs: shockFloorWindowMs,
      shockRetriggerMs: shockRetriggerMs,
      ringTauLearnRate: ringTauLearnRate,
      minRingTauMs: minRingTauMs,
      maxRingTauMs: maxRingTauMs,
      accelStaleMs: accelStaleMs,
      mergeWindowMs: mergeWindowMs,
      impactMergeMs: impactMergeMs,
      lagLearnRate: lagLearnRate,
      maxAbsLagMs: maxAbsLagMs,
      featureWindowMs: featureWindowMs ?? this.featureWindowMs,
      spectralWindowMs: spectralWindowMs,
      strengthHistory: strengthHistory,
      waitForOtherSensorMs: waitForOtherSensorMs ?? this.waitForOtherSensorMs,
      presenceWindowMs: presenceWindowMs,
      presenceMissingFactor:
          presenceMissingFactor ?? this.presenceMissingFactor,
      personGoneHardRejectMs: personGoneHardRejectMs,
      armActivityMinFactor: armActivityMinFactor,
      armActivityMaxFactor: armActivityMaxFactor,
      armActivityMaxAgeMs: armActivityMaxAgeMs,
      maxImpactsPerSecond: maxImpactsPerSecond,
      rateFactor: rateFactor,
      touchLockoutBeforeMs: touchLockoutBeforeMs,
      touchLockoutAfterMs: touchLockoutAfterMs,
      settingsCooldownMs: settingsCooldownMs,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'audioSampleRate': audioSampleRate,
    'audioUsPerSample': audioUsPerSample,
    'hopSamples': hopSamples,
    'bandEdgesHz': bandEdgesHz,
    'bandWeights': bandWeights,
    'floorPercentile': floorPercentile,
    'floorWindowMs': floorWindowMs,
    'floorExclusionAfterImpactMs': floorExclusionAfterImpactMs,
    'floorIngestDelayMs': floorIngestDelayMs,
    'minFloorHistoryMs': minFloorHistoryMs,
    'audioNoveltyMarginDb': audioNoveltyMarginDb,
    'singleBandExtraDb': singleBandExtraDb,
    'audioRetriggerMs': audioRetriggerMs,
    'peakSearchMs': peakSearchMs,
    'decayLearnRate': decayLearnRate,
    'accelHighPassHz': accelHighPassHz,
    'shockK': shockK,
    'shockFloorPercentile': shockFloorPercentile,
    'shockFloorScale': shockFloorScale,
    'shockMinJerk': shockMinJerk,
    'mergeWindowMs': mergeWindowMs,
    'impactMergeMs': impactMergeMs,
    'featureWindowMs': featureWindowMs,
    'waitForOtherSensorMs': waitForOtherSensorMs,
    'presenceWindowMs': presenceWindowMs,
    'presenceMissingFactor': presenceMissingFactor,
    'personGoneHardRejectMs': personGoneHardRejectMs,
    'maxImpactsPerSecond': maxImpactsPerSecond,
    'touchLockoutBeforeMs': touchLockoutBeforeMs,
    'touchLockoutAfterMs': touchLockoutAfterMs,
  };
}

/// Starting values per mount, refined online from isolated hits.
class MountDefaults {
  final double decayDbPerS; // audio ring decay
  final double ringTauMs; // accelerometer ring time constant
  final double seedAudioStrengthDb; // seed of the user's median audio rise
  final double seedAccelStrength; // seed of the user's median peak jerk (m/s³)

  const MountDefaults({
    required this.decayDbPerS,
    required this.ringTauMs,
    required this.seedAudioStrengthDb,
    required this.seedAccelStrength,
  });

  static MountDefaults of(MountProfile mount) => switch (mount) {
    MountProfile.wall => const MountDefaults(
      decayDbPerS: 60,
      ringTauMs: 150,
      seedAudioStrengthDb: 20,
      seedAccelStrength: 150,
    ),
    MountProfile.rig => const MountDefaults(
      decayDbPerS: 120,
      ringTauMs: 150,
      seedAudioStrengthDb: 20,
      seedAccelStrength: 300,
    ),
  };
}
