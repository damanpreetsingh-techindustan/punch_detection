import 'dart:collection';

import '../config/detector_config.dart';
import 'presence_window.dart';
import 'touch_lockout.dart';

/// Result of the soft context for one impact.
class ContextResult {
  /// Non-null when the impact must be rejected regardless of its score:
  /// `TOUCH`, `SETTINGS_OPEN` or `PERSON_GONE`.
  final String? hardReject;

  /// Multiplier applied to the score's odds (1.0 = neutral).
  final double oddsFactor;

  /// Individual factors, for the decision log.
  final Map<String, double> factors;

  const ContextResult({
    required this.hardReject,
    required this.oddsFactor,
    required this.factors,
  });
}

/// Priors that scale the odds of an impact, plus the few hard rejections.
///
/// - presence: no valid person in the last 1.5 s -> strong down-weight; no
///   person for more than 5 s (the user walked away) -> hard reject. The camera
///   is never a per-frame gate.
/// - arm activity (optical flow + pose, computed off the hot path) -> bounded
///   factor in [0.5, 1.5]; 1.0 when unknown.
/// - touch lockout / open settings sheet -> hard reject.
/// - rate sanity: more than 10 impacts per second -> down-weight.
///
/// Pure: times are detection-clock microseconds.
class SoftContext {
  SoftContext(this.config)
    : touch = TouchLockout(
        beforeMs: config.touchLockoutBeforeMs,
        afterMs: config.touchLockoutAfterMs,
      ),
      presence = PresenceWindow(windowMs: config.presenceWindowMs);

  final DetectorConfig config;
  final TouchLockout touch;
  final PresenceWindow presence;

  bool _cameraAvailable = false;
  int? _cameraAvailableSinceMs;
  bool _settingsOpen = false;
  int _settingsCooldownUntilMs = 0;
  final ListQueue<(int, double, String)> _arm =
      ListQueue<(int, double, String)>();
  final ListQueue<int> _acceptedMs = ListQueue<int>();

  bool get cameraAvailable => _cameraAvailable;

  void addTouch(int tUs) => touch.addTouch(tUs ~/ 1000);

  void setCameraAvailable(bool available, int tUs) {
    if (available && !_cameraAvailable) _cameraAvailableSinceMs = tUs ~/ 1000;
    if (!available) _cameraAvailableSinceMs = null;
    _cameraAvailable = available;
  }

  void notePersonValid(int tUs) => presence.noteValid(tUs ~/ 1000);

  void setSettingsOpen(bool open, int tUs) {
    if (_settingsOpen && !open) {
      _settingsCooldownUntilMs = tUs ~/ 1000 + config.settingsCooldownMs;
    }
    _settingsOpen = open;
  }

  /// Latest arm-activity score in [0, 1] with the hand ('left', 'right',
  /// 'unknown'); the tracker already takes the max over the last 300 ms.
  void setArmActivity(double score, String hand, int tUs) {
    _arm.addLast((tUs ~/ 1000, score.clamp(0.0, 1.0), hand));
    while (_arm.length > 64) {
      _arm.removeFirst();
    }
  }

  /// Most recent arm activity at or before [tUs] that is fresh enough.
  (double, String)? armActivityAt(int tUs) {
    final int t = tUs ~/ 1000;
    for (final (int, double, String) a in _arm.toList().reversed) {
      if (a.$1 <= t) {
        return t - a.$1 <= config.armActivityMaxAgeMs ? (a.$2, a.$3) : null;
      }
    }
    return null;
  }

  void noteAccepted(int onsetUs) {
    _acceptedMs.addLast(onsetUs ~/ 1000);
    while (_acceptedMs.isNotEmpty &&
        _acceptedMs.first < onsetUs ~/ 1000 - 2000) {
      _acceptedMs.removeFirst();
    }
  }

  ContextResult evaluate({required int onsetUs, required int decideUs}) {
    final int onsetMs = onsetUs ~/ 1000;
    final Map<String, double> factors = <String, double>{};
    if (touch.isLocked(onsetMs)) {
      return const ContextResult(
        hardReject: 'TOUCH',
        oddsFactor: 0,
        factors: <String, double>{},
      );
    }
    if (_settingsOpen || onsetMs < _settingsCooldownUntilMs) {
      return const ContextResult(
        hardReject: 'SETTINGS_OPEN',
        oddsFactor: 0,
        factors: <String, double>{},
      );
    }

    double odds = 1.0;
    // Presence.
    if (_cameraAvailable) {
      if (!presence.isPresentAt(onsetMs)) {
        final int? since = presence.msSinceValid(onsetMs);
        final int availableFor = onsetMs - (_cameraAvailableSinceMs ?? onsetMs);
        final bool gone =
            (since != null && since > config.personGoneHardRejectMs) ||
            (since == null && availableFor > config.personGoneHardRejectMs);
        if (gone) {
          return ContextResult(
            hardReject: 'PERSON_GONE',
            oddsFactor: 0,
            factors: <String, double>{'presence': 0},
          );
        }
        factors['presence'] = config.presenceMissingFactor;
        odds *= config.presenceMissingFactor;
      } else {
        factors['presence'] = 1;
      }
    }
    // Arm activity (bounded, neutral when unknown).
    final (double, String)? arm = _cameraAvailable
        ? armActivityAt(decideUs)
        : null;
    if (arm != null) {
      final double f =
          config.armActivityMinFactor +
          (config.armActivityMaxFactor - config.armActivityMinFactor) * arm.$1;
      factors['arm'] = f;
      odds *= f;
    }
    // Rate sanity.
    final int recent = _acceptedMs
        .where((int t) => t >= onsetMs - 1000 && t < onsetMs)
        .length;
    if (recent >= config.maxImpactsPerSecond) {
      factors['rate'] = config.rateFactor;
      odds *= config.rateFactor;
    }
    return ContextResult(hardReject: null, oddsFactor: odds, factors: factors);
  }
}
