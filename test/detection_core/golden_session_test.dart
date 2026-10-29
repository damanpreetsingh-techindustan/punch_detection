import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/config/detector_config.dart';
import 'package:punch_detection_demo/detection_core/engine/fusion_v2_engine.dart';
import 'package:punch_detection_demo/detection_core/replay/replay_runner.dart';
import 'package:punch_detection_demo/detection_core/testing/synthetic_session.dart';

/// The decision made for a scripted event: the decision whose onset is
/// closest (within 60 ms), or null when no candidate was formed.
ImpactDecision? decisionFor(SyntheticEvent e, List<ImpactDecision> ds) {
  ImpactDecision? best;
  for (final ImpactDecision d in ds) {
    final int dist = (d.onsetUs - e.onsetUs).abs();
    if (dist <= 60000 &&
        (best == null || dist < (best.onsetUs - e.onsetUs).abs())) {
      best = d;
    }
  }
  return best;
}

void main() {
  for (final int seed in <int>[1, 2, 3]) {
    group('golden synthetic session (seed $seed)', () {
      late SyntheticSession session;
      late FusionV2Engine engine;
      late List<ImpactDecision> decisions;

      setUpAll(() {
        session = SyntheticSession.golden(seed: seed);
        engine = FusionV2Engine(mount: MountProfile.wall);
        decisions = runReplay(engine, session.input);
      });

      test('every expected decision is right', () {
        for (final SyntheticEvent e in session.events) {
          final ImpactDecision? d = decisionFor(e, decisions);
          final double t = (e.onsetUs - SyntheticSession.startUs) / 1e6;
          if (e.expectAccepted) {
            expect(d, isNotNull, reason: '${e.kind} at $t s formed no impact');
            expect(d!.accepted, isTrue, reason: '${e.kind} at $t s: p=${d.p}');
          } else {
            expect(
              d?.accepted ?? false,
              isFalse,
              reason: '${e.kind} at $t s was counted',
            );
          }
          if (e.expectReason != null) {
            expect(d?.reason, e.expectReason, reason: '${e.kind} at $t s');
          }
        }
      });

      test('nothing else is counted', () {
        final int accepted = decisions
            .where((ImpactDecision d) => d.accepted)
            .length;
        final int expected = session.events
            .where((SyntheticEvent e) => e.expectAccepted)
            .length;
        expect(accepted, expected);
      });

      test('fast-path latency inside the core is under 45 ms after onset', () {
        final List<ImpactDecision> fast = <ImpactDecision>[
          for (final ImpactDecision d in decisions)
            if (d.accepted && d.path == 'fast') d,
        ];
        expect(fast, isNotEmpty);
        for (final ImpactDecision d in fast) {
          expect(
            d.latencyUs,
            lessThan(45000),
            reason: 'latency ${d.latencyUs} µs',
          );
        }
      });

      test('a hit in the previous ring is dated to its own onset', () {
        final SyntheticEvent tail = session.events.firstWhere(
          (SyntheticEvent e) => e.kind == 'hit_in_ring_tail',
        );
        final ImpactDecision d = decisionFor(tail, decisions)!;
        expect((d.onsetUs - tail.onsetUs).abs(), lessThan(3000));
      });

      test('mount parameters are learned from the isolated hits', () {
        expect(engine.audio.decayDbPerS, closeTo(60, 10));
        expect(engine.shock.ringTauMs, closeTo(150, 20));
        expect(engine.learnedLagMs, inInclusiveRange(0.5, 5));
      });
    });
  }

  test('the rig profile gets the same golden decisions', () {
    final SyntheticSession s = SyntheticSession.golden(ringDecayDbPerS: 120);
    final List<ImpactDecision> ds = runReplay(
      FusionV2Engine(mount: MountProfile.rig),
      s.input,
    );
    for (final SyntheticEvent e in s.events) {
      expect(
        decisionFor(e, ds)?.accepted ?? false,
        e.expectAccepted,
        reason: e.kind,
      );
    }
  });

  test('without the accelerometer the audio-only scorer is used', () {
    final SyntheticSession s = SyntheticSession.golden();
    final ReplayInput noAccel = ReplayInput(
      audio: s.input.audio,
      audioStartUs: s.input.audioStartUs,
      audioUsPerSample: s.input.audioUsPerSample,
      accel: const [],
      events: s.input.events,
    );
    final List<ImpactDecision> ds = runReplay(
      FusionV2Engine(mount: MountProfile.wall),
      noAccel,
    );
    final ImpactDecision clean = decisionFor(s.events.first, ds)!;
    expect(clean.mode.name, 'audioOnly');
    expect(clean.accepted, isTrue);
  });
}
