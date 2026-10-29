import 'dart:collection';
import 'dart:math' as math;

import '../config/detector_config.dart';
import '../dsp/dsp.dart';

/// One raw accelerometer sample on the detection clock (m/s², gravity included).
class AccelSampleIn {
  final int tUs;
  final double x, y, z;

  const AccelSampleIn(this.tUs, this.x, this.y, this.z);
}

/// A sudden change of acceleration (shock) that stands out of the ringing of
/// earlier impacts.
class ShockCandidate {
  final int onsetUs;
  final double jerk; // m/s³ at detection
  final double ratio; // jerk / (envelope + floor)

  const ShockCandidate({
    required this.onsetUs,
    required this.jerk,
    required this.ratio,
  });
}

/// One processed accelerometer sample.
class AccelPoint {
  final int tUs;
  final double hx, hy, hz; // high-passed acceleration
  final double jx, jy, jz; // jerk per axis
  final double jerk; // jerk magnitude
  final double ratio; // jerk / (decayed envelope + floor)

  const AccelPoint({
    required this.tUs,
    required this.hx,
    required this.hy,
    required this.hz,
    required this.jx,
    required this.jy,
    required this.jz,
    required this.jerk,
    required this.ratio,
  });

  double get accelMagnitude => math.sqrt(hx * hx + hy * hy + hz * hz);
}

/// Accelerometer front end: high-pass at ~2 Hz (removes gravity and slow sway),
/// jerk magnitude, an envelope that decays at the mount's ring rate (learned
/// from isolated hits, starting at tau = 150 ms) and a rolling-percentile floor.
/// A shock is a candidate when jerk > envelope * k + floor.
class ShockTracker {
  ShockTracker({required this.config, required double initialRingTauMs})
    : ringTauMs = initialRingTauMs;

  final DetectorConfig config;

  /// Ring time constant of the mount (ms), learned from isolated hits.
  double ringTauMs;

  AccelSampleIn? _prev;
  double _hx = 0, _hy = 0, _hz = 0;
  double _envelope = 0;
  int _lastCandidateUs = -1 << 40;
  int? _lastSampleUs;
  int _samples = 0;

  final ListQueue<AccelPoint> _points = ListQueue<AccelPoint>();
  final ListQueue<AccelPoint> _floorQueue = ListQueue<AccelPoint>();
  late final RollingPercentile _floor = RollingPercentile(
    minValue: -3,
    maxValue: 6,
    binWidth: 0.02,
    windowUs: config.shockFloorWindowMs * 1000,
  );
  final List<int> _acceptedOnsets = <int>[];
  final List<_RingFit> _ringFits = <_RingFit>[];

  int get sampleCount => _samples;

  /// Time of the latest sample (null before the first).
  int? get coveredUntilUs => _lastSampleUs;

  bool isAvailable(int atUs) {
    final int? last = _lastSampleUs;
    return last != null && atUs - last <= config.accelStaleMs * 1000;
  }

  /// Jerk floor (m/s³): rolling percentile × scale, never below the minimum.
  double get floorJerk {
    final double? logP = _floor.percentile(config.shockFloorPercentile);
    final double fromHistory = logP == null
        ? 0
        : math.pow(10, logP).toDouble() * config.shockFloorScale;
    return math.max(config.shockMinJerk, fromHistory);
  }

  List<ShockCandidate> add(AccelSampleIn s) {
    final AccelSampleIn? prev = _prev;
    _prev = s;
    _lastSampleUs = s.tUs;
    _samples++;
    if (prev == null) return const <ShockCandidate>[];
    final double dt = (s.tUs - prev.tUs) / 1e6;
    if (dt <= 0) return const <ShockCandidate>[];
    if (dt > 0.1) {
      // Gap in the stream: restart the filters instead of seeing a fake shock.
      _hx = _hy = _hz = 0;
      _envelope = 0;
      return const <ShockCandidate>[];
    }
    final double rc = 1 / (2 * math.pi * config.accelHighPassHz);
    final double a = rc / (rc + dt);
    final double hx = a * (_hx + s.x - prev.x);
    final double hy = a * (_hy + s.y - prev.y);
    final double hz = a * (_hz + s.z - prev.z);
    final double jx = (hx - _hx) / dt,
        jy = (hy - _hy) / dt,
        jz = (hz - _hz) / dt;
    _hx = hx;
    _hy = hy;
    _hz = hz;
    final double jerk = math.sqrt(jx * jx + jy * jy + jz * jz);
    final double decayed =
        _envelope * math.exp(-dt * 1000 / math.max(1, ringTauMs));
    final double floor = floorJerk;
    final double ratio = jerk / (decayed + floor);
    final AccelPoint point = AccelPoint(
      tUs: s.tUs,
      hx: hx,
      hy: hy,
      hz: hz,
      jx: jx,
      jy: jy,
      jz: jz,
      jerk: jerk,
      ratio: ratio,
    );
    _points.addLast(point);
    while (_points.isNotEmpty && _points.first.tUs < s.tUs - 1000000) {
      _points.removeFirst();
    }
    _floorQueue.addLast(point);
    _ingestFloor(s.tUs);
    _envelope = math.max(jerk, decayed);
    _updateRingFits(point);

    final bool spaced =
        s.tUs - _lastCandidateUs >= config.shockRetriggerMs * 1000;
    if (_samples > 4 && spaced && jerk > config.shockK * decayed + floor) {
      _lastCandidateUs = s.tUs;
      return <ShockCandidate>[
        ShockCandidate(onsetUs: s.tUs, jerk: jerk, ratio: ratio),
      ];
    }
    return const <ShockCandidate>[];
  }

  void _ingestFloor(int nowUs) {
    final int before = nowUs - config.floorIngestDelayMs * 1000;
    while (_floorQueue.isNotEmpty && _floorQueue.first.tUs <= before) {
      final AccelPoint p = _floorQueue.removeFirst();
      if (_isExcluded(p.tUs) || p.jerk <= 0) continue;
      _floor.add(math.log(p.jerk) / math.ln10, p.tUs);
    }
    _floor.prune(nowUs);
  }

  bool _isExcluded(int tUs) {
    for (final int onset in _acceptedOnsets) {
      if (tUs >= onset - 20000 &&
          tUs <= onset + config.floorExclusionAfterImpactMs * 1000) {
        return true;
      }
    }
    return false;
  }

  void notifyAccepted(int onsetUs, {required bool isolated}) {
    _acceptedOnsets.add(onsetUs);
    _acceptedOnsets.removeWhere((int t) => t < onsetUs - 2000000);
    if (isolated) _ringFits.add(_RingFit(onsetUs));
  }

  void notifyImpact(int onsetUs) {
    _ringFits.removeWhere(
      (_RingFit f) => onsetUs > f.onsetUs && onsetUs - f.onsetUs < 500000,
    );
  }

  void _updateRingFits(AccelPoint p) {
    for (final _RingFit fit in List<_RingFit>.of(_ringFits)) {
      if (p.tUs < fit.onsetUs - 20000) continue;
      fit.points.add((p.tUs, p.jerk));
      if (p.tUs - fit.onsetUs >= 500000) {
        _ringFits.remove(fit);
        final double? tau = fit.tauMs(floorJerk);
        if (tau != null) {
          final double clamped = tau.clamp(
            config.minRingTauMs,
            config.maxRingTauMs,
          );
          ringTauMs += config.ringTauLearnRate * (clamped - ringTauMs);
        }
      }
    }
  }

  /// Processed samples in [fromUs, toUs].
  List<AccelPoint> window(int fromUs, int toUs) => <AccelPoint>[
    for (final AccelPoint p in _points)
      if (p.tUs >= fromUs && p.tUs <= toUs) p,
  ];
}

class _RingFit {
  _RingFit(this.onsetUs);
  final int onsetUs;
  final List<(int, double)> points = <(int, double)>[];

  /// Time constant of the jerk envelope's decay after the peak, from the
  /// least-squares slope of ln(running-max jerk) until it reaches the floor.
  double? tauMs(double floor) {
    if (points.isEmpty) return null;
    int peakIdx = 0;
    for (int i = 1; i < points.length && points[i].$1 - onsetUs <= 60000; i++) {
      if (points[i].$2 > points[peakIdx].$2) peakIdx = i;
    }
    // Envelope: the max of the remaining tail, so oscillation zero-crossings
    // do not look like a fast decay.
    final List<(int, double)> env = <(int, double)>[];
    for (int i = peakIdx; i < points.length; i++) {
      double m = 0;
      for (int k = i; k < math.min(points.length, i + 6); k++) {
        m = math.max(m, points[k].$2);
      }
      if (m <= floor * 1.5) break;
      env.add((points[i].$1, math.log(m)));
    }
    if (env.length < 6) return null;
    double mt = 0, ml = 0;
    for (final (int, double) p in env) {
      mt += p.$1;
      ml += p.$2;
    }
    mt /= env.length;
    ml /= env.length;
    double cov = 0, vt = 0;
    for (final (int, double) p in env) {
      cov += (p.$1 - mt) * (p.$2 - ml);
      vt += (p.$1 - mt) * (p.$1 - mt);
    }
    if (vt <= 0 || cov >= 0) return null;
    return -1 / (cov / vt) / 1000; // slope is per µs -> tau in ms
  }
}
