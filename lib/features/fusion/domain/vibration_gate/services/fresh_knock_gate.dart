import '../../../../../core/utils/constants.dart';
import '../../services/impact_gate_evaluator.dart';
import '../i_vibration_gate.dart';
import '../models/vibration_gate_evaluation.dart';
import '../models/vibration_knock.dart';
import 'vibration_knock_tracker.dart';

/// Concrete vibration gating strategy implementing the fresh-knock rule.
///
/// Ensures each confirmed punch has its own unused, impulsive mechanical knock.
/// Eliminates voice false-positives on swinging bags and enables rapid-combo punch
/// detection where a soft punch follows a hard punch.
class FreshKnockGate implements IVibrationGate {
  final VibrationKnockTracker tracker;

  int _lastRawSampleMs = 0;

  FreshKnockGate({VibrationKnockTracker? tracker})
      : tracker = tracker ?? VibrationKnockTracker();

  @override
  String get name => 'FreshKnockGate';

  @override
  VibrationGateType get type => VibrationGateType.knock;

  @override
  void addRawSample({
    required int sensorMs,
    required double rawMag,
    double? rawX,
    double? rawY,
    double? rawZ,
  }) {
    _lastRawSampleMs = sensorMs;
    tracker.addSample(
      sensorMs: sensorMs,
      rawMag: rawMag,
      x: rawX,
      y: rawY,
      z: rawZ,
    );
  }

  @override
  void addEnvelopeSample({
    required int arrivalMs,
    required double magnitude,
  }) {
    // Only when NO raw accelerometer reading has ever arrived (test suites or
    // simulations): synthesize knocks from envelope samples. In the app the raw
    // stream always runs, and mixing the two streams would mix sensor time
    // with arrival time and create fake knocks.
    if (_lastRawSampleMs == 0) {
      tracker.addSample(sensorMs: arrivalMs, rawMag: magnitude);
    }
  }

  @override
  VibrationGateEvaluation evaluate({
    required int audioTsMs,
    required int fromMs,
    required int toMs,
    required double threshold,
    required bool windowClosed,
    required bool isVibrationDisabled,
  }) {
    if (isVibrationDisabled) {
      return const VibrationGateEvaluation(
        state: VibrationGateState.notRequired,
        detail: 'Vibration not required (Pole mount or gate off)',
      );
    }

    final VibrationKnock? knock = tracker.findUnusedKnock(
      fromMs: fromMs,
      toMs: toMs,
      audioTsMs: audioTsMs,
      minRawMag: threshold > 0 ? threshold : null,
    );

    if (knock != null) {
      knock.claimedByAudioTsMs = audioTsMs;
      return VibrationGateEvaluation(
        state: VibrationGateState.present,
        matchedKnock: knock,
        peakMagnitude: knock.rawMag,
        detail:
            'Knock verified: Δ${knock.deltaMag.toStringAsFixed(2)} m/s² @ ${knock.timestampMs}ms (Raw: ${knock.rawMag.toStringAsFixed(2)} m/s²)',
      );
    }

    return VibrationGateEvaluation(
      state: VibrationGateState.missing,
      detail: windowClosed
          ? 'No unused mechanical knock in window [$fromMs..$toMs]'
          : 'Waiting for mechanical knock in window...',
    );
  }

  @override
  void onPunchConfirmed({required int audioTsMs, required int punchNo}) {
    tracker.markKnockUsed(audioTsMs: audioTsMs, punchNo: punchNo);
  }

  @override
  void onImpactRejected({required int audioTsMs}) {
    tracker.releaseClaim(audioTsMs);
  }

  @override
  void reset() {
    _lastRawSampleMs = 0;
    tracker.reset();
  }
}
