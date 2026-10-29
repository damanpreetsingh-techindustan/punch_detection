import 'dart:math' as math;
import 'dart:typed_data';

import '../accel/shock_tracker.dart';
import '../replay/replay_runner.dart';

/// One scripted event of a synthetic session and the decision expected for it.
class SyntheticEvent {
  final String kind;
  final int onsetUs;
  final bool expectAccepted;

  /// Expected hard-reject reason (e.g. TOUCH), if any.
  final String? expectReason;

  const SyntheticEvent(
    this.kind,
    this.onsetUs, {
    required this.expectAccepted,
    this.expectReason,
  });
}

/// Synthetic microphone + accelerometer signals that reproduce the field
/// findings, for golden tests and harness demos.
class SyntheticSession {
  SyntheticSession._(this.input, this.events);

  final ReplayInput input;
  final List<SyntheticEvent> events;

  static const int sampleRate = 16000;
  static const int startUs = 1000000000000;

  /// The golden session (12 s):
  ///   1.50 s clean hit           -> accept
  ///   2.50 s clean hit           -> accept
  ///   2.75 s hit inside the 2.5 s hit's ringing tail (250 ms later) -> accept
  ///   4.00 s soft low hit (-10 dB, slow attack) with a strong shock -> accept
  ///   5.50 s loud clap, no shock -> reject
  ///   7.00 s and 7.70 s gym noise swells (+8 dB, 20 ms attack), no shock -> no accept
  ///   9.00 s phone tap with a screen touch -> reject (TOUCH)
  ///  10.50 s clean hit           -> accept
  ///
  /// The room is a busy gym: broadband noise plus a bass-heavy rumble (music,
  /// crowd) at about -37 dBFS, so real hits rise roughly 15-30 dB over the
  /// live floor as measured in the field.
  static SyntheticSession golden({
    int seed = 1,
    double ringDecayDbPerS = 60,
    double hitAmplitude = 0.25,
  }) {
    const double durationS = 12;
    final int n = (durationS * sampleRate).round();
    final Float64List audio = Float64List(n);
    final math.Random rng = math.Random(seed);
    double gauss() {
      final double u1 = math.max(1e-12, rng.nextDouble());
      final double u2 = rng.nextDouble();
      return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }

    // Room floor: white noise plus a low-passed rumble (~130 Hz corner).
    const double floorRms = 0.012;
    double rumble = 0;
    for (int i = 0; i < n; i++) {
      rumble += 0.05 * (gauss() - rumble);
      audio[i] = floorRms * gauss() + 0.03 * rumble;
    }

    // Accelerometer at 200 Hz: gravity on z, sensor noise.
    const int accelRate = 200;
    final int accelN = (durationS * accelRate).round();
    final List<List<double>> acc = <List<double>>[
      for (int i = 0; i < accelN; i++)
        <double>[0.02 * gauss(), 0.02 * gauss(), 9.81 + 0.02 * gauss()],
    ];

    void bagHit(
      double tS, {
      double? amplitude,
      double attackMs = 1.5,
      double lowShare = 0.8,
      double shockG = 2.0,
      double lagMs = 3,
    }) {
      final int i0 = (tS * sampleRate).round();
      final double a = amplitude ?? hitAmplitude;
      final double decayPerS = ringDecayDbPerS / 8.686; // amplitude e-folding
      for (int k = 0; k < (1.2 * sampleRate).round() && i0 + k < n; k++) {
        final double t = k / sampleRate;
        final double attack = math.min(1.0, t * 1000 / attackMs);
        final double body =
            math.sin(2 * math.pi * 110 * t) * 0.7 +
            math.sin(2 * math.pi * 230 * t) * 0.3;
        final double ring = math.exp(-decayPerS * t);
        // Short broadband slap at the contact (decays in ~10 ms).
        final double slap = gauss() * math.exp(-t / 0.004);
        audio[i0 + k] +=
            a * attack * (lowShare * body * ring + (1 - lowShare) * slap);
      }
      final int a0 = ((tS + lagMs / 1000) * accelRate).round();
      for (int k = 0; k < (1.0 * accelRate).round() && a0 + k < accelN; k++) {
        final double t = k / accelRate;
        final double ring =
            math.exp(-t / 0.15) * math.sin(2 * math.pi * 25 * t + 1.0);
        acc[a0 + k][2] += shockG * ring;
        acc[a0 + k][0] += 0.3 * shockG * ring;
      }
    }

    void clap(double tS, {double amplitude = 0.5}) {
      final int i0 = (tS * sampleRate).round();
      // Bright broadband burst: differenced noise (high-pass), 0.3 ms attack.
      double prev = 0;
      for (int k = 0; k < (0.08 * sampleRate).round() && i0 + k < n; k++) {
        final double t = k / sampleRate;
        final double w = gauss();
        final double hp = w - prev;
        prev = w;
        final double env = math.min(1.0, t * 1000 / 0.3) * math.exp(-t / 0.012);
        audio[i0 + k] += amplitude * 0.6 * hp * env;
      }
    }

    void gymSwell(double tS) {
      final int i0 = (tS * sampleRate).round();
      // Crowd / music swell: about +8 dB of band-limited noise over the floor,
      // 20 ms attack, 250 ms long (lp has a std of ~0.42).
      double lp = 0;
      for (int k = 0; k < (0.25 * sampleRate).round() && i0 + k < n; k++) {
        final double t = k / sampleRate;
        lp += 0.3 * (gauss() - lp);
        final double env =
            math.min(1.0, t * 1000 / 20) * (t > 0.2 ? (0.25 - t) / 0.05 : 1);
        audio[i0 + k] += floorRms * 2.3 / 0.42 * lp * env;
      }
    }

    void phoneTap(double tS) {
      final int i0 = (tS * sampleRate).round();
      for (int k = 0; k < (0.01 * sampleRate).round() && i0 + k < n; k++) {
        final double t = k / sampleRate;
        audio[i0 + k] += 0.3 * gauss() * math.exp(-t / 0.0015);
      }
      final int a0 = (tS * accelRate).round();
      for (int k = 0; k < 20 && a0 + k < accelN; k++) {
        final double t = k / accelRate;
        acc[a0 + k][2] +=
            1.5 * math.exp(-t / 0.02) * math.sin(2 * math.pi * 40 * t + 1.0);
      }
    }

    final List<SyntheticEvent> events = <SyntheticEvent>[];
    int us(double s) => startUs + (s * 1e6).round();

    bagHit(1.5);
    events.add(SyntheticEvent('clean_hit', us(1.5), expectAccepted: true));
    bagHit(2.5);
    events.add(SyntheticEvent('clean_hit', us(2.5), expectAccepted: true));
    bagHit(2.75);
    events.add(
      SyntheticEvent('hit_in_ring_tail', us(2.75), expectAccepted: true),
    );
    bagHit(
      4.0,
      amplitude: hitAmplitude * 0.316, // -10 dB
      attackMs: 8,
      lowShare: 0.92,
      shockG: 3.0,
    );
    events.add(
      SyntheticEvent(
        'soft_low_hit_strong_shock',
        us(4.0),
        expectAccepted: true,
      ),
    );
    clap(5.5);
    events.add(SyntheticEvent('clap_no_shock', us(5.5), expectAccepted: false));
    gymSwell(7.0);
    gymSwell(7.7);
    events.add(SyntheticEvent('gym_noise', us(7.0), expectAccepted: false));
    events.add(SyntheticEvent('gym_noise', us(7.7), expectAccepted: false));
    phoneTap(9.0);
    events.add(
      SyntheticEvent(
        'phone_tap',
        us(9.0),
        expectAccepted: false,
        expectReason: 'TOUCH',
      ),
    );
    bagHit(10.5);
    events.add(SyntheticEvent('clean_hit', us(10.5), expectAccepted: true));

    final Int16List pcm = Int16List(n);
    for (int i = 0; i < n; i++) {
      pcm[i] = (audio[i] * 32767).round().clamp(-32768, 32767);
    }
    final List<AccelSampleIn> accel = <AccelSampleIn>[
      for (int i = 0; i < accelN; i++)
        AccelSampleIn(
          startUs + (i * 1e6 / accelRate).round(),
          acc[i][0],
          acc[i][1],
          acc[i][2],
        ),
    ];
    final List<ContextEvent> context = <ContextEvent>[
      const ContextEvent(startUs, 'camera_on'),
      // The user stays in frame: a valid person every ~66 ms (15 fps).
      for (int t = 0; t < durationS * 1000; t += 66)
        ContextEvent(startUs + t * 1000, 'person_valid'),
      // The touch event reaches the app ~20 ms after the tap's sound.
      ContextEvent(us(9.02), 'touch'),
    ];
    return SyntheticSession._(
      ReplayInput(
        audio: pcm,
        audioStartUs: startUs,
        audioUsPerSample: 1e6 / sampleRate,
        accel: accel,
        events: context,
      ),
      events,
    );
  }
}
