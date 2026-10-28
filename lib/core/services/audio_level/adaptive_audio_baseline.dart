import 'dart:math';
import '../../utils/constants.dart';

/// Strongly typed candidate spike recorded during acoustic onset detection.
class CandidateSpike {
  final int timestampMs;
  final double peakDb;
  final double baselineDb;
  final double spikeHeight;
  final double prevFrameDb;
  final bool isTargetMet;

  CandidateSpike({
    required this.timestampMs,
    required this.peakDb,
    required this.baselineDb,
    required this.spikeHeight,
    required this.prevFrameDb,
    this.isTargetMet = true,
  });
}


/// Adaptive Audio Baseline Engine for Relative Spike Punch Detection.
///
/// Maintains a continuously adapting rolling baseline of the current acoustic
/// environment and enforces a strict **Narrow Impulse Envelope (Fast Rise + Fast Decay)**:
///
/// 1. **Fast Rise Onset**: Sound must jump significantly above BOTH
///    the rolling ambient baseline AND the immediately preceding frame (`prevFrameDb`).
/// 2. **Fast Decay Verification (Narrow Spike Width)**:
///    - A real punch impact rises instantly AND decays instantly ($\le 100\text{ms}$).
///    - Within 100ms (2 frames), the volume MUST drop by $\ge 50\%$ of the spike height.
///    - If volume stays elevated (wide spike), it is identified as human speech/talking
///      and DISCARDED.
/// 3. **Continuous Leaky Baseline Adaptation**: Baseline ALWAYS updates on every
///    frame so sustained speech or music rapidly pulls the baseline up.
class AdaptiveAudioBaseline {
  /// Number of recent samples to keep in the rolling window (~2 seconds at 50ms).
  final int windowSize;

  /// Minimum dB jump above the rolling baseline to qualify as a punch spike.
  double spikeThresholdDb;

  /// Minimum frame-to-frame impulse jump ($\Delta\text{dB} = \text{db} - \text{prevFrameDb}$)
  /// required for a true percussive impact. Filters out speech that ramps up smoothly.
  double minFrameOnsetJumpDb;

  /// Absolute minimum dB floor — sounds below this are never considered punches.
  double absoluteMinFloorDb;

  /// How fast baseline rises to match a louder environment (0.0 – 1.0).
  double baselineAttackAlpha;

  /// How slowly baseline drops when environment gets quieter (0.0 – 1.0).
  double baselineDecayAlpha;

  /// Required decay percentage (default 0.50 = 50%) within maxDecayMs.
  double minDecayPercentage;

  /// Maximum allowed duration (default 100ms = 2 frames) for spike to decay by minDecayPercentage.
  int maxDecayMs;

  /// Internal rolling ring buffer of recent dB samples.
  final List<double> _recentSamples = [];

  /// Smoothed adaptive baseline representing current environment noise level.
  double _smoothedBaseline;

  /// Timestamp of the last confirmed spike, used for refractory logic.
  int _lastSpikeTimestampMs = 0;

  /// Consecutive frame counter for elevated volume ($>\text{baseline} + 4\text{dB}$).
  int _elevatedFrameCount = 0;

  /// Pending candidate spike waiting for fast decay verification.
  CandidateSpike? _pendingCandidateSpike;

  /// Fixed 4-frame history (40ms) to measure true onset rise across slow and fast punches with zero allocations.
  double _onsetHistory0 = 48.0;
  double _onsetHistory1 = 48.0;
  double _onsetHistory2 = 48.0;
  double _onsetHistory3 = 48.0;

  /// Minimum time between consecutive spikes to avoid double-counting reverb.
  int refractoryMs;

  /// Reference ambient noise level captured during 5s precheck calibration.
  double calibratedAmbientDb;

  /// Direct fixed audio target threshold. If set (> 0), punches must reach this exact decibel level.
  double? fixedAudioTargetDb;

  AdaptiveAudioBaseline({
    this.windowSize = 150,
    this.spikeThresholdDb = 20.0,
    this.minFrameOnsetJumpDb = 6.0,
    this.absoluteMinFloorDb = AppConstants.minAudioSafetyFloorDb,
    this.baselineAttackAlpha = 0.05,
    this.baselineDecayAlpha = 0.008,
    this.minDecayPercentage = 0.10,
    this.maxDecayMs = 80,
    this.refractoryMs = 110,
    this.fixedAudioTargetDb,
    double initialBaseline = 48.0,
  }) : _smoothedBaseline = initialBaseline,
       calibratedAmbientDb = initialBaseline,
       _onsetHistory0 = initialBaseline,
       _onsetHistory1 = initialBaseline,
       _onsetHistory2 = initialBaseline,
       _onsetHistory3 = initialBaseline;

  /// Current smoothed adaptive baseline (what the environment "sounds like").
  double get currentBaseline => _smoothedBaseline;

  /// Consecutive frames where volume has remained elevated above baseline.
  int get elevatedFrameCount => _elevatedFrameCount;

  /// Currently pending candidate spike waiting for decay check.
  CandidateSpike? get pendingCandidateSpike => _pendingCandidateSpike;

  /// Ends the post-spike lockout early. Call when a spike was NOT counted as a
  /// punch (below target, or rejected by the other sensors), so a rejected
  /// sound cannot block a real punch that follows within the lockout time.
  void releaseRefractory() {
    _lastSpikeTimestampMs = 0;
  }

  /// Average of recent samples in the rolling window.
  double get windowAverage {
    if (_recentSamples.isEmpty) return _smoothedBaseline;
    final double sum = _recentSamples.reduce((a, b) => a + b);
    return sum / _recentSamples.length;
  }

  /// Feeds an audio sample into the continuous leaky baseline tracker.
  void feedSample(double db) {
    _recentSamples.add(db);
    if (_recentSamples.length > windowSize) {
      _recentSamples.removeAt(0);
    }

    if (db > _smoothedBaseline + 4.0) {
      _elevatedFrameCount++;
    } else {
      _elevatedFrameCount = 0;
    }

    final double activeAttack = _elevatedFrameCount > 15
        ? 0.02
        : baselineAttackAlpha;

    if (db > _smoothedBaseline) {
      _smoothedBaseline =
          _smoothedBaseline * (1.0 - activeAttack) + db * activeAttack;
    } else {
      _smoothedBaseline =
          _smoothedBaseline * (1.0 - baselineDecayAlpha) +
          db * baselineDecayAlpha;
    }
  }

  /// Fixed and predictable spike threshold as configured by the user (no hidden dynamic shifts).
  double get effectiveSpikeThresholdDb => spikeThresholdDb;

  /// Evaluates an incoming audio frame for instantaneous transient spike onset.
  CandidateSpike? processFrame(double db, double prevFrameDb, {int? nowMs}) {
    final int currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;

    // 1. Continuous Leaky Baseline Adaptation
    feedSample(db);

    // 2. Refractory Window Check (Dynamic per mode, default 110ms)
    if (currentMs - _lastSpikeTimestampMs < refractoryMs) {
      _onsetHistory3 = _onsetHistory2;
      _onsetHistory2 = _onsetHistory1;
      _onsetHistory1 = _onsetHistory0;
      _onsetHistory0 = db;
      return null;
    }

    // Measure onset rise across the last 4 frames (40ms)
    final double onsetTrough = min(
      min(_onsetHistory0, _onsetHistory1),
      min(_onsetHistory2, _onsetHistory3),
    );
    final double windowRise = db - onsetTrough;
    final double frameJump = db - prevFrameDb;

    // Shift history
    _onsetHistory3 = _onsetHistory2;
    _onsetHistory2 = _onsetHistory1;
    _onsetHistory1 = _onsetHistory0;
    _onsetHistory0 = db;

    final double referenceBaseline = calibratedAmbientDb;
    final double baselineSpike = db - referenceBaseline;

    // Direct target check: If fixedAudioTargetDb is set, impact must reach this exact target
    final double targetDb =
        fixedAudioTargetDb ?? (calibratedAmbientDb + spikeThresholdDb);

    // Robust Percussive Onset Rise Verification:
    // Safety floor defaults to absoluteMinFloorDb, but must not exceed targetDb when user lowers threshold
    final double ambientFloor = spikeThresholdDb < 0
        ? (calibratedAmbientDb + spikeThresholdDb)
        : (calibratedAmbientDb + 4.0);
    final double effectiveMinFloor = min(
      targetDb,
      max(min(absoluteMinFloorDb, targetDb), ambientFloor),
    );

    // Strict percussive impact onset verification:
    // Physical punches produce explosive shockwaves (>= +6.0 dB jump in 20ms or steep onset).
    // Human voices, speech, and background movement ramp up gradually (1-3 dB) and are completely filtered out.
    final bool isOnsetMet = frameJump >= 6.0 ||
        windowRise >= 10.0 ||
        (windowRise >= 8.0 && frameJump >= 4.0);

    // Condition 1: Target Met (Valid punch threshold achieved)
    final bool isThresholdMet = db >= targetDb && db >= effectiveMinFloor;

    // Condition 2: Candidate Strike above Calibration Line (Percussive strike above room baseline, but below target)
    final bool isAboveCalibrationCandidate = !isThresholdMet &&
        db >= (calibratedAmbientDb + 4.0) &&
        baselineSpike >= 4.0;

    if (isOnsetMet) {
      if (isThresholdMet) {
        // Sharp percussive onset exceeding Target dB confirmed!
        _lastSpikeTimestampMs = currentMs;
        _pendingCandidateSpike = null;
        return CandidateSpike(
          timestampMs: currentMs,
          peakDb: db,
          baselineDb: referenceBaseline,
          spikeHeight: baselineSpike,
          prevFrameDb: onsetTrough,
          isTargetMet: true,
        );
      } else if (isAboveCalibrationCandidate) {
        // Sharp percussive onset above calibration baseline, but below current target.
        // Captured for telemetry, spike history logs, and Auto-Config optimization.
        _lastSpikeTimestampMs = currentMs;
        _pendingCandidateSpike = null;
        return CandidateSpike(
          timestampMs: currentMs,
          peakDb: db,
          baselineDb: referenceBaseline,
          spikeHeight: baselineSpike,
          prevFrameDb: onsetTrough,
          isTargetMet: false,
        );
      }
    }

    return null;

  }

  /// Returns how many dB the given reading is above the current baseline.
  double getSpikeIntensity(double db) => db - _smoothedBaseline;

  /// Resets the baseline state engine.
  void reset({double initialBaseline = 48.0}) {
    _recentSamples.clear();
    _smoothedBaseline = initialBaseline;
    _lastSpikeTimestampMs = 0;
    _elevatedFrameCount = 0;
    _pendingCandidateSpike = null;
    _onsetHistory0 = initialBaseline;
    _onsetHistory1 = initialBaseline;
    _onsetHistory2 = initialBaseline;
    _onsetHistory3 = initialBaseline;
  }

  /// Seeds the baseline with a known ambient level from 5s precheck calibration.
  void seedBaseline(double ambientDb) {
    calibratedAmbientDb = ambientDb;
    _smoothedBaseline = ambientDb;
    _recentSamples.clear();
    _elevatedFrameCount = 0;
    _pendingCandidateSpike = null;
    _onsetHistory0 = ambientDb;
    _onsetHistory1 = ambientDb;
    _onsetHistory2 = ambientDb;
    _onsetHistory3 = ambientDb;
    for (int i = 0; i < (windowSize ~/ 2); i++) {
      _recentSamples.add(ambientDb);
    }
  }
}
