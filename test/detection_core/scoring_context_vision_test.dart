import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/config/detector_config.dart';
import 'package:punch_detection_demo/detection_core/context/soft_context.dart';
import 'package:punch_detection_demo/detection_core/engine/fusion_v2_engine.dart';
import 'package:punch_detection_demo/detection_core/replay/metrics.dart';
import 'package:punch_detection_demo/detection_core/scoring/logistic_scorer.dart';
import 'package:punch_detection_demo/detection_core/scoring/trainer.dart';
import 'package:punch_detection_demo/detection_core/vision/arm_motion_tracker.dart';

void main() {
  group('scorer', () {
    test(
      'the shipped JSON assets are valid (and equal the defaults while hand-set)',
      () {
        for (final MountProfile m in MountProfile.values) {
          final Map<String, Object?> asset =
              (jsonDecode(
                        File(
                          'assets/detector/${m.name}.json',
                        ).readAsStringSync(),
                      )
                      as Map)
                  .cast<String, Object?>();
          final ScorerSet parsed = ScorerSet.fromJson(asset);
          final ScorerSet defaults = ScorerSet.defaults(m);
          expect(parsed.mount, m.name);
          expect(parsed.pLow, lessThan(parsed.pDecide));
          expect(parsed.pDecide, lessThan(parsed.pHigh));
          expect(
            parsed.full.terms.keys.toSet(),
            defaults.full.terms.keys.toSet(),
            reason: '${m.name}: trained weights keep the feature list',
          );
          if (parsed.source.startsWith('hand-set')) {
            expect(asset, defaults.toJson(), reason: m.name);
          }
        }
      },
    );

    test('JSON round trip keeps the probabilities', () {
      final ScorerSet s = ScorerSet.defaults(MountProfile.rig);
      final ScorerSet back = ScorerSet.fromJson(
        (jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>(),
      );
      const Map<String, double> f = <String, double>{
        'audio_rise_max_db': 18,
        'audio_attack_ms': 3,
        'accel_env_ratio_log2': 2,
      };
      expect(back.full.probability(f), s.full.probability(f));
      expect(back.pHigh, s.pHigh);
    });

    test('field findings: a real hit scores high, gym noise and claps low', () {
      final LogisticModel full = ScorerSet.defaults(MountProfile.wall).full;
      final double hit = full.probability(const <String, double>{
        'audio_rise_max_db': 22,
        'audio_attack_ms': 3,
        'audio_centroid_khz': 0.6,
        'audio_low_ratio': 0.6,
        'accel_env_ratio_log2': 2.5,
        'accel_strength_rel_log2': 0,
        'cross_lag_dev_ms': 3,
        'cross_strength_log_ratio': 0,
      });
      final double gym = full.probability(const <String, double>{
        'audio_rise_max_db': 5,
        'audio_attack_ms': 18,
        'audio_centroid_khz': 1.8,
        'audio_low_ratio': 0.2,
        'accel_env_ratio_log2': -1.5,
        'accel_strength_rel_log2': -4,
        'cross_lag_dev_ms': 40,
        'cross_strength_log_ratio': -3,
      });
      final double clap = full.probability(const <String, double>{
        'audio_rise_max_db': 28,
        'audio_attack_ms': 1,
        'audio_centroid_khz': 4,
        'audio_low_ratio': 0.02,
        'accel_env_ratio_log2': -1.2,
        'accel_strength_rel_log2': -4,
        'cross_lag_dev_ms': 40,
        'cross_strength_log_ratio': -4,
      });
      expect(hit, greaterThan(0.95));
      expect(gym, lessThan(0.05));
      expect(clap, lessThan(0.3));
    });

    test('the trainer separates labelled examples', () {
      final Random rng = Random(9);
      final List<TrainingExample> ex = <TrainingExample>[
        for (int i = 0; i < 200; i++)
          TrainingExample(<String, double>{
            'audio_rise_max_db': (i.isEven ? 20 : 6) + rng.nextDouble() * 4,
            'audio_attack_ms': (i.isEven ? 3 : 16) + rng.nextDouble() * 3,
          }, i.isEven),
      ];
      const LogisticModel template = LogisticModel(
        bias: 0,
        terms: <String, ScorerTerm>{
          'audio_rise_max_db': ScorerTerm(center: 12, scale: 5, weight: 0),
          'audio_attack_ms': ScorerTerm(center: 10, scale: 4, weight: 0),
        },
      );
      final LogisticModel fitted = fitLogistic(template, ex);
      expect(fitted.terms['audio_rise_max_db']!.weight, greaterThan(0));
      expect(fitted.terms['audio_attack_ms']!.weight, lessThan(0));
      final int correct = ex
          .where(
            (TrainingExample e) =>
                (fitted.probability(e.features) >= 0.5) == e.isPunch,
          )
          .length;
      expect(correct, ex.length);
    });
  });

  group('soft context', () {
    const DetectorConfig config = DetectorConfig();
    const int t = 1000000000000;

    test('touch and open settings are hard rejections', () {
      final SoftContext c = SoftContext(config)..addTouch(t);
      expect(
        c.evaluate(onsetUs: t + 300000, decideUs: t + 330000).hardReject,
        'TOUCH',
      );
      final SoftContext s = SoftContext(config)..setSettingsOpen(true, t);
      expect(s.evaluate(onsetUs: t, decideUs: t).hardReject, 'SETTINGS_OPEN');
      s.setSettingsOpen(false, t + 1000);
      expect(
        s.evaluate(onsetUs: t + 500000, decideUs: t + 500000).hardReject,
        'SETTINGS_OPEN',
        reason: '1 s cooldown after closing',
      );
      expect(
        s.evaluate(onsetUs: t + 1200000, decideUs: t + 1200000).hardReject,
        isNull,
      );
    });

    test('presence: soft down-weight, hard reject only after 5 s', () {
      final SoftContext c = SoftContext(config)
        ..setCameraAvailable(true, t)
        ..notePersonValid(t + 1000000);
      expect(
        c.evaluate(onsetUs: t + 2000000, decideUs: t + 2000000).oddsFactor,
        1.0,
      );
      final ContextResult missing = c.evaluate(
        onsetUs: t + 3000000,
        decideUs: t + 3000000,
      );
      expect(missing.hardReject, isNull);
      expect(missing.oddsFactor, config.presenceMissingFactor);
      expect(
        c.evaluate(onsetUs: t + 6200000, decideUs: t + 6200000).hardReject,
        'PERSON_GONE',
      );
      final SoftContext noCamera = SoftContext(config);
      expect(noCamera.evaluate(onsetUs: t, decideUs: t).oddsFactor, 1.0);
    });

    test('arm activity scales the odds within [0.5, 1.5], never decides', () {
      final SoftContext c = SoftContext(config)
        ..setCameraAvailable(true, t)
        ..notePersonValid(t);
      c.setArmActivity(0, 'unknown', t + 100000);
      expect(
        c.evaluate(onsetUs: t + 150000, decideUs: t + 180000).oddsFactor,
        0.5,
      );
      c.setArmActivity(1, 'left', t + 200000);
      expect(
        c.evaluate(onsetUs: t + 250000, decideUs: t + 280000).oddsFactor,
        1.5,
      );
      expect(
        c
            .evaluate(onsetUs: t + 1250000, decideUs: t + 1280000)
            .factors
            .containsKey('arm'),
        isFalse,
        reason: 'stale activity is ignored (factor 1.0)',
      );
    });

    test('more than 10 impacts per second are down-weighted', () {
      final SoftContext c = SoftContext(config);
      for (int i = 0; i < 10; i++) {
        c.noteAccepted(t + i * 90000);
      }
      expect(
        c.evaluate(onsetUs: t + 950000, decideUs: t + 950000).oddsFactor,
        config.rateFactor,
      );
    });
  });

  group('ArmMotionTracker (optical flow prior)', () {
    Uint8List disc(double cx, double cy, double r, double scale) {
      const int w = 160, h = 120;
      final Uint8List img = Uint8List(w * h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final double dx = x - cx, dy = y - cy;
          img[y * w + x] = dx * dx + dy * dy <= r * r
              ? (128 + 70 * sin(0.45 * dx / scale) * sin(0.45 * dy / scale))
                    .round()
              : 40;
        }
      }
      return img;
    }

    ArmMotionResult run(Uint8List Function(int i) frame, {int rotation = 0}) {
      final ArmMotionTracker t = ArmMotionTracker();
      late ArmMotionResult r;
      for (int i = 0; i < 6; i++) {
        r = t.processFrame(
          LumaFrame(
            data: frame(i),
            width: 160,
            height: 120,
            rowStride: 160,
            tUs: i * 66667,
            rotationDegrees: rotation,
          ),
        );
      }
      return r;
    }

    test(
      'a growing disc (glove punching toward the camera) has positive divergence',
      () {
        final ArmMotionResult r = run(
          (int i) => disc(
            80,
            80,
            25 * pow(1.04, i).toDouble(),
            pow(1.04, i).toDouble(),
          ),
        );
        // 4 % per frame at 15 fps = ~0.59 per second.
        expect(r.divergencePerS, closeTo(0.59, 0.12));
        expect(r.armActivity, greaterThan(0.3));
      },
    );

    test(
      'a translating disc (sway, someone walking past) has ~zero divergence',
      () {
        final ArmMotionResult r = run((int i) => disc(70.0 + 2 * i, 80, 25, 1));
        expect(r.divergencePerS.abs(), lessThan(0.08));
        expect(r.meanFlowPxPerS, closeTo(30, 6)); // 2 px/frame at 15 fps
      },
    );

    test('a static scene has no flow and no activity', () {
      final ArmMotionResult r = run((int i) => disc(80, 80, 25, 1));
      expect(r.meanFlowPxPerS, lessThan(1));
      expect(r.armActivity, lessThan(0.01));
    });

    test('rotation to upright keeps the looming sign', () {
      final ArmMotionResult r = run(
        (int i) =>
            disc(80, 60, 25 * pow(1.04, i).toDouble(), pow(1.04, i).toDouble()),
        rotation: 90,
      );
      expect(r.divergencePerS, greaterThan(0.3));
    });

    test('falls back to frame difference when LK is too slow', () {
      final ArmMotionTracker t = ArmMotionTracker(
        config: const ArmMotionConfig(maxLkMs: 0.0001),
      );
      for (int i = 0; i < 20; i++) {
        t.processFrame(
          LumaFrame(
            data: disc(70.0 + 2 * i, 80, 25, 1),
            width: 160,
            height: 120,
            rowStride: 160,
            tUs: i * 66667,
          ),
        );
      }
      expect(t.usesFrameDifference, isTrue);
    });

    test('pose: a fast wrist raises activity and names the hand', () {
      final ArmMotionTracker t = ArmMotionTracker();
      for (int i = 0; i < 5; i++) {
        t.addPose(
          ArmPose(
            tUs: i * 60000,
            leftShoulder: const <double>[60, 60, 0.9],
            rightShoulder: const <double>[100, 60, 0.9],
            leftWrist: <double>[60, 90 - i * 10.0, 0.9],
          ),
        );
      }
      final ArmMotionResult r = t.processFrame(
        LumaFrame(
          data: disc(80, 80, 25, 1),
          width: 160,
          height: 120,
          rowStride: 160,
          tUs: 240000,
        ),
      );
      expect(r.poseScore, greaterThan(0.5));
      expect(r.hand, 'left');
    });
  });

  group('replay metrics', () {
    ImpactDecision accepted(int onsetUs) => ImpactDecision(
      id: 0,
      onsetUs: onsetUs,
      decidedUs: onsetUs + 35000,
      accepted: true,
      p: 1,
      pRaw: 1,
      path: 'fast',
      reason: '',
      mode: ScorerMode.full,
      hasAudioCandidate: true,
      hasShockCandidate: true,
      hand: 'unknown',
      features: const <String, double>{},
      contextFactors: const <String, double>{},
    );

    test('±50 ms matching, false positives in idle time, latency', () {
      const int s = 0;
      final ReplayMetrics m = computeMetrics(
        decisions: <ImpactDecision>[
          accepted(1000000 + 30000), // TP (30 ms late)
          accepted(2000000 - 60000), // too far -> FP (not idle: within 1 s)
          accepted(30000000), // idle FP
        ],
        labelsUs: const <int>[1000000, 2000000, 3000000],
        startUs: s,
        endUs: 60000000,
      );
      expect(m.truePositives, 1);
      expect(m.falsePositives, 2);
      expect(m.falseNegatives, 2);
      expect(m.idleFalsePositives, 1);
      expect(m.idleMinutes, closeTo((60 - 4) / 60, 1e-6));
      expect(m.latencyPercentile(50), 35);
    });
  });

  test('the detector core never imports Flutter', () {
    final List<String> offenders = <String>[
      for (final FileSystemEntity f in Directory(
        'lib/detection_core',
      ).listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(
              r'''import\s+['"]package:(flutter|get)/''',
            ).hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
