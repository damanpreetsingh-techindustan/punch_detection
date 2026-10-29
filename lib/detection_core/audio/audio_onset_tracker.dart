import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import '../config/detector_config.dart';
import '../dsp/dsp.dart';

/// An audio onset: something got suddenly louder than both the room floor and
/// the predicted decay of the previous impact.
class AudioCandidate {
  /// Refined onset time (1 ms resolution), detection clock µs.
  final int onsetUs;

  /// End of the 5 ms hop in which the onset was detected.
  final int detectedUs;

  /// Band-weighted rise over max(floor, predicted decay), dB.
  final double noveltyDb;

  const AudioCandidate({
    required this.onsetUs,
    required this.detectedUs,
    required this.noveltyDb,
  });
}

/// One analysed 5 ms hop.
class AudioHop {
  final int tUs; // time of the hop's last sample
  final Float64List bandDb;
  final double fullDb;
  final double noveltyDb;

  const AudioHop(this.tUs, this.bandDb, this.fullDb, this.noveltyDb);
}

/// Raw samples and hops of a time window, for feature extraction.
class AudioWindow {
  final Float64List samples; // full scale = 1.0
  final int firstSampleUs;
  final double usPerSample;
  final List<AudioHop> hops;
  final Float64List floorDb; // per band at extraction time
  final double fullFloorDb;

  const AudioWindow({
    required this.samples,
    required this.firstSampleUs,
    required this.usPerSample,
    required this.hops,
    required this.floorDb,
    required this.fullFloorDb,
  });
}

/// Audio front end: 16 kHz mono in, a 4-band filter bank at a 5 ms hop, a live
/// floor per band (20th percentile over the last 3 s, excluding frames right
/// after accepted impacts), a decay prediction after each onset, and a
/// SuperFlux-style novelty: the rise of the current energy over
/// max(floor, predicted decay). A second punch can therefore register inside
/// the first one's ringing tail.
class AudioOnsetTracker {
  AudioOnsetTracker({required this.config, required double initialDecayDbPerS})
    : decayDbPerS = initialDecayDbPerS {
    final List<double> e = config.bandEdgesHz;
    final double fs = config.audioSampleRate.toDouble();
    for (int b = 0; b < bandCount; b++) {
      final double lo = e[b], hi = e[b + 1];
      _filters.add(<Biquad>[
        Biquad.highPass(fs, lo),
        Biquad.highPass(fs, lo),
        if (hi < fs / 2 * 0.98) ...<Biquad>[
          Biquad.lowPass(fs, hi),
          Biquad.lowPass(fs, hi),
        ],
      ]);
      _floors.add(_newFloor());
    }
    _hopEnergy = Float64List(bandCount);
    _peakDb = Float64List(bandCount);
  }

  final DetectorConfig config;
  int get bandCount => config.bandEdgesHz.length - 1;

  /// Ring decay used for the prediction (dB/s), learned from isolated hits.
  double decayDbPerS;

  final List<List<Biquad>> _filters = <List<Biquad>>[];
  final List<RollingPercentile> _floors = <RollingPercentile>[];
  late final RollingPercentile _fullFloor = _newFloor();
  late final Float64List _hopEnergy;
  double _hopFullEnergy = 0;
  int _hopCount = 0;

  // Sample clock: time(i) = _t0Us + i * usPerSample.
  int _sampleIndex = 0;
  double? _t0Us;

  // Last second of raw samples.
  static const int _ringSize = 16384;
  final Float64List _ring = Float64List(_ringSize);

  final ListQueue<AudioHop> _hops = ListQueue<AudioHop>();
  final ListQueue<AudioHop> _floorQueue = ListQueue<AudioHop>();
  final ListQueue<double> _recentNovelty = ListQueue<double>();

  // Decay prediction from the latest onset.
  late final Float64List _peakDb;
  int? _peakTimeUs;
  double _peakFullDb = -200;
  int _peakSearchUntilUs = 0;
  int _lastCandidateUs = -1 << 40;

  // Accepted impacts: floor exclusion and decay learning.
  final List<int> _acceptedOnsets = <int>[];
  final List<_DecayFit> _decayFits = <_DecayFit>[];

  double? _floorCache(int b) => _floors[b].percentile(config.floorPercentile);

  /// The floor has enough history to judge rises (no candidates before).
  bool get _floorReady =>
      _fullFloor.count * config.hopUs >= config.minFloorHistoryMs * 1000;

  RollingPercentile _newFloor() => RollingPercentile(
    minValue: -140,
    maxValue: 10,
    binWidth: 0.5,
    windowUs: config.floorWindowMs * 1000,
  );

  /// Time up to which audio has been analysed.
  int get coveredUntilUs => _timeOf(_sampleIndex - 1);

  bool get hasStarted => _t0Us != null;

  int _timeOf(int index) =>
      ((_t0Us ?? 0) + index * config.audioUsPerSample).round();

  /// Current floor per band and full band (dB re full scale).
  Float64List get floorsDb => Float64List.fromList(<double>[
    for (int b = 0; b < bandCount; b++) _floorOrMin(b),
  ]);

  double get fullFloorDb =>
      _fullFloor.percentile(config.floorPercentile) ?? _minFull;

  double _minFull = 0;
  final List<double> _minBand = <double>[0, 0, 0, 0, 0, 0, 0, 0];

  double _floorOrMin(int b) => _floorCache(b) ?? _minBand[b];

  /// Analyses [samples] (16-bit mono) whose first sample is at [firstSampleUs].
  /// Returns the onsets found in them.
  List<AudioCandidate> process(Int16List samples, int firstSampleUs) {
    final double candidateT0 =
        firstSampleUs - _sampleIndex * config.audioUsPerSample;
    final double? t0 = _t0Us;
    // Lower envelope: arrival-based times are late, never early. Relax slowly
    // (50 ppm) so a capture clock that runs slow is followed.
    _t0Us = t0 == null
        ? candidateT0
        : math.min(
            candidateT0,
            t0 + samples.length * config.audioUsPerSample * 50e-6,
          );
    final List<AudioCandidate> found = <AudioCandidate>[];
    for (final int s in samples) {
      final double x = s / 32768.0;
      _ring[_sampleIndex % _ringSize] = x;
      _sampleIndex++;
      for (int b = 0; b < bandCount; b++) {
        double y = x;
        for (final Biquad f in _filters[b]) {
          y = f.process(y);
        }
        _hopEnergy[b] += y * y;
      }
      _hopFullEnergy += x * x;
      _hopCount++;
      if (_hopCount == config.hopSamples) {
        final AudioCandidate? c = _finishHop();
        if (c != null) found.add(c);
      }
    }
    return found;
  }

  AudioCandidate? _finishHop() {
    final int tUs = coveredUntilUs;
    final Float64List bandDb = Float64List(bandCount);
    for (int b = 0; b < bandCount; b++) {
      bandDb[b] = dbFromPower(_hopEnergy[b] / _hopCount);
      _hopEnergy[b] = 0;
    }
    final double fullDb = dbFromPower(_hopFullEnergy / _hopCount);
    _hopFullEnergy = 0;
    _hopCount = 0;

    // Floor fallback before enough history: the quietest level seen so far.
    if (_hops.isEmpty) {
      for (int b = 0; b < bandCount; b++) {
        _minBand[b] = bandDb[b];
      }
      _minFull = fullDb;
    } else {
      for (int b = 0; b < bandCount; b++) {
        _minBand[b] = math.min(_minBand[b], bandDb[b]);
      }
      _minFull = math.min(_minFull, fullDb);
    }

    _ingestFloors(tUs);

    // Reference: max(floor, predicted decay of the last impact).
    final bool inPeakSearch = tUs <= _peakSearchUntilUs;
    if (inPeakSearch) {
      for (int b = 0; b < bandCount; b++) {
        _peakDb[b] = math.max(_peakDb[b], bandDb[b]);
      }
      if (fullDb > _peakFullDb) {
        _peakFullDb = fullDb;
        _peakTimeUs = tUs;
      }
    }
    double weighted = 0, weights = 0, strongestBand = 0;
    for (int b = 0; b < bandCount; b++) {
      double ref = _floorOrMin(b);
      final int? peakT = _peakTimeUs;
      if (peakT != null) {
        final double predicted = inPeakSearch
            ? _peakDb[b]
            : _peakDb[b] - decayDbPerS * (tUs - peakT) / 1e6;
        ref = math.max(ref, predicted);
      }
      final double w = config.bandWeights[b];
      final double rise = math.max(0.0, bandDb[b] - ref);
      weighted += w * rise;
      weights += w;
      strongestBand = math.max(strongestBand, rise);
    }
    // Broadband rise, or a strong rise in a single band (a low hook).
    final double novelty = math.max(
      weights > 0 ? weighted / weights : 0,
      strongestBand - config.singleBandExtraDb,
    );
    final AudioHop hop = AudioHop(tUs, bandDb, fullDb, novelty);
    _hops.addLast(hop);
    _floorQueue.addLast(hop);
    while (_hops.isNotEmpty && _hops.first.tUs < tUs - 1000000) {
      _hops.removeFirst();
    }
    _updateDecayFits(hop);

    final double recentMin = _recentNovelty.isEmpty
        ? 0
        : _recentNovelty.reduce(math.min);
    _recentNovelty.addLast(novelty);
    while (_recentNovelty.length > 4) {
      _recentNovelty.removeFirst();
    }

    final double margin = config.audioNoveltyMarginDb;
    final bool rising = novelty - recentMin >= margin / 2;
    final bool spaced =
        tUs - _lastCandidateUs >= config.audioRetriggerMs * 1000;
    if (novelty < margin || !rising || !spaced || !_floorReady) return null;

    _lastCandidateUs = tUs;
    final int onsetUs = _refineOnset(tUs);
    for (int b = 0; b < bandCount; b++) {
      _peakDb[b] = bandDb[b];
    }
    _peakFullDb = fullDb;
    _peakTimeUs = tUs;
    _peakSearchUntilUs = onsetUs + config.peakSearchMs * 1000;
    return AudioCandidate(
      onsetUs: onsetUs,
      detectedUs: tUs,
      noveltyDb: novelty,
    );
  }

  /// First 1 ms sub-block (in the last 15 ms) whose peak reaches a quarter of
  /// the loudest sub-block and clearly exceeds the background, where the
  /// background is max(floor, predicted decay of the previous impact), so a
  /// hit inside a ringing tail is not dated to the tail.
  int _refineOnset(int detectedUs) {
    const int sub = 16; // 1 ms
    final int end = _sampleIndex;
    final int start = math.max(0, end - 15 * sub);
    double backgroundDb = fullFloorDb;
    final int? peakT = _peakTimeUs;
    if (peakT != null && detectedUs > _peakSearchUntilUs) {
      backgroundDb = math.max(
        backgroundDb,
        _peakFullDb - decayDbPerS * (detectedUs - peakT) / 1e6,
      );
    }
    // Hop levels are mean-square; sample peaks of noise sit ~10 dB higher.
    final double noisePeak = math.pow(10, (backgroundDb + 10) / 20).toDouble();
    double loudest = 0;
    final List<double> peaks = <double>[];
    for (int i = start; i < end; i += sub) {
      double p = 0;
      for (int k = i; k < math.min(i + sub, end); k++) {
        p = math.max(p, _ring[k % _ringSize].abs());
      }
      peaks.add(p);
      loudest = math.max(loudest, p);
    }
    final double threshold = math.max(loudest * 0.25, noisePeak);
    for (int j = 0; j < peaks.length; j++) {
      if (peaks[j] >= threshold) return _timeOf(start + j * sub);
    }
    return detectedUs;
  }

  void _ingestFloors(int nowUs) {
    final int ingestBefore = nowUs - config.floorIngestDelayMs * 1000;
    while (_floorQueue.isNotEmpty && _floorQueue.first.tUs <= ingestBefore) {
      final AudioHop hop = _floorQueue.removeFirst();
      if (_isExcluded(hop.tUs)) continue;
      for (int b = 0; b < bandCount; b++) {
        _floors[b].add(hop.bandDb[b], hop.tUs);
      }
      _fullFloor.add(hop.fullDb, hop.tUs);
    }
    for (final RollingPercentile f in _floors) {
      f.prune(nowUs);
    }
    _fullFloor.prune(nowUs);
  }

  bool _isExcluded(int tUs) {
    for (final int onset in _acceptedOnsets) {
      if (tUs >= onset &&
          tUs <= onset + config.floorExclusionAfterImpactMs * 1000) {
        return true;
      }
    }
    return false;
  }

  /// Tells the tracker an impact at [onsetUs] was accepted: its frames are
  /// kept out of the floor, and an isolated one teaches the decay rate.
  void notifyAccepted(int onsetUs, {required bool isolated}) {
    _acceptedOnsets.add(onsetUs);
    _acceptedOnsets.removeWhere((int t) => t < onsetUs - 2000000);
    if (isolated) _decayFits.add(_DecayFit(onsetUs));
    _anchorDecay(onsetUs);
  }

  /// Makes the decay prediction follow an accepted impact even when it had no
  /// audio candidate (found by the accelerometer): otherwise its own ringing
  /// would later look like a rise over the previous impact's prediction.
  void _anchorDecay(int onsetUs) {
    final int until = onsetUs + config.peakSearchMs * 1000;
    AudioHop? loudest;
    for (final AudioHop h in _hops) {
      if (h.tUs < onsetUs - config.hopUs || h.tUs > until) continue;
      if (loudest == null || h.fullDb > loudest.fullDb) loudest = h;
    }
    if (loudest == null) return;
    final int? peakT = _peakTimeUs;
    final double predicted = peakT == null
        ? -200
        : _peakFullDb - decayDbPerS * (loudest.tUs - peakT) / 1e6;
    if (loudest.fullDb <= predicted) return;
    for (int b = 0; b < bandCount; b++) {
      _peakDb[b] = loudest.bandDb[b];
    }
    _peakFullDb = loudest.fullDb;
    _peakTimeUs = loudest.tUs;
  }

  /// A later impact makes an earlier hit non-isolated.
  void notifyImpact(int onsetUs) {
    _decayFits.removeWhere(
      (_DecayFit f) => onsetUs > f.onsetUs && onsetUs - f.onsetUs < 500000,
    );
  }

  void _updateDecayFits(AudioHop hop) {
    for (final _DecayFit fit in List<_DecayFit>.of(_decayFits)) {
      if (hop.tUs < fit.onsetUs) continue;
      fit.points.add((hop.tUs, hop.fullDb));
      if (hop.tUs - fit.onsetUs >= 500000) {
        _decayFits.remove(fit);
        final double? rate = fit.decayDbPerS(fullFloorDb);
        if (rate != null) {
          final double clamped = rate.clamp(
            config.minDecayDbPerS,
            config.maxDecayDbPerS,
          );
          decayDbPerS += config.decayLearnRate * (clamped - decayDbPerS);
        }
      }
    }
  }

  /// Raw samples and hops in [fromUs, toUs] (clipped to what is buffered).
  AudioWindow window(int fromUs, int toUs) {
    final double us = config.audioUsPerSample;
    final double t0 = _t0Us ?? 0;
    int first = ((fromUs - t0) / us).ceil();
    int last = ((toUs - t0) / us).floor();
    first = math.max(first, math.max(0, _sampleIndex - _ringSize + 1));
    last = math.min(last, _sampleIndex - 1);
    final int n = math.max(0, last - first + 1);
    final Float64List samples = Float64List(n);
    for (int i = 0; i < n; i++) {
      samples[i] = _ring[(first + i) % _ringSize];
    }
    return AudioWindow(
      samples: samples,
      firstSampleUs: _timeOf(first),
      usPerSample: us,
      hops: <AudioHop>[
        for (final AudioHop h in _hops)
          if (h.tUs >= fromUs && h.tUs <= toUs) h,
      ],
      floorDb: floorsDb,
      fullFloorDb: fullFloorDb,
    );
  }
}

class _DecayFit {
  _DecayFit(this.onsetUs);
  final int onsetUs;
  final List<(int, double)> points = <(int, double)>[];

  /// Slope (dB/s, positive = decaying) from the peak until the level reaches
  /// the floor + 3 dB, or null when the decay is too short to fit.
  double? decayDbPerS(double floorDb) {
    if (points.isEmpty) return null;
    int peakIdx = 0;
    for (int i = 1; i < points.length && points[i].$1 - onsetUs <= 60000; i++) {
      if (points[i].$2 > points[peakIdx].$2) peakIdx = i;
    }
    final List<(int, double)> tail = <(int, double)>[];
    for (int i = peakIdx; i < points.length; i++) {
      if (points[i].$2 <= floorDb + 3) break;
      tail.add(points[i]);
    }
    if (tail.length < 6) return null;
    double mt = 0, ml = 0;
    for (final (int, double) p in tail) {
      mt += p.$1;
      ml += p.$2;
    }
    mt /= tail.length;
    ml /= tail.length;
    double cov = 0, vt = 0;
    for (final (int, double) p in tail) {
      cov += (p.$1 - mt) * (p.$2 - ml);
      vt += (p.$1 - mt) * (p.$1 - mt);
    }
    if (vt <= 0) return null;
    final double slopePerUs = cov / vt;
    return -slopePerUs * 1e6;
  }
}
