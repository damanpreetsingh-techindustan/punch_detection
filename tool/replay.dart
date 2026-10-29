// Replay harness for the fusionV2 detector core.
//
//   dart run tool/replay.dart <session_folder> [options]
//   dart run tool/replay.dart --synthetic [options]
//
// Options:
//   --labels <file>     labels.csv (seconds since session start, one per line);
//                       defaults to <session_folder>/labels.csv when present
//   --mount rig|wall    override the mount type from session_meta.json
//   --scorer <file>     scorer JSON (default assets/detector/<mount>.json)
//   --out <file>        write every decision (with features) as CSV
//   --sweep <file>      grid-search the main margins and write a metrics CSV
//   --no-arm            ignore arm-activity events (measure the prior's value)
//   --no-presence       ignore camera/presence events
//   --quiet             do not print every decision
//
// See docs/detection-v2.md.

import 'dart:convert';
import 'dart:io';

import 'package:punch_detection_demo/detection_core/config/detector_config.dart';
import 'package:punch_detection_demo/detection_core/engine/fusion_v2_engine.dart';
import 'package:punch_detection_demo/detection_core/replay/metrics.dart';
import 'package:punch_detection_demo/detection_core/replay/replay_runner.dart';
import 'package:punch_detection_demo/detection_core/replay/session_folder.dart';
import 'package:punch_detection_demo/detection_core/scoring/logistic_scorer.dart';
import 'package:punch_detection_demo/detection_core/testing/synthetic_session.dart';

void main(List<String> args) {
  final Map<String, String?> opts = _parse(args);
  final List<String> positional = <String>[
    for (final MapEntry<String, String?> e in opts.entries)
      if (e.key.startsWith('_')) e.value!,
  ];

  late final ReplayInput input;
  late final MountProfile mount;
  late final int sessionStartUs;
  List<int>? labels;
  String name;
  if (opts.containsKey('synthetic')) {
    final SyntheticSession s = SyntheticSession.golden();
    input = s.input;
    mount = MountProfile.fromName(opts['mount'] ?? 'wall');
    sessionStartUs = SyntheticSession.startUs;
    labels = <int>[
      for (final SyntheticEvent e in s.events)
        if (e.expectAccepted) e.onsetUs,
    ];
    name = 'synthetic golden session';
  } else {
    if (positional.isEmpty) {
      stderr.writeln(
        'usage: dart run tool/replay.dart <session_folder> [options]',
      );
      exitCode = 64;
      return;
    }
    final RecordedSession s = RecordedSession.load(positional.first);
    input = s.input;
    mount = opts['mount'] != null
        ? MountProfile.fromName(opts['mount'])
        : s.mount;
    sessionStartUs = s.sessionStartUs;
    final String labelPath = opts['labels'] ?? '${positional.first}/labels.csv';
    if (File(labelPath).existsSync()) labels = s.loadLabels(labelPath);
    name = positional.first;
  }

  final ReplayInput filtered = _filterEvents(
    input,
    dropArm: opts.containsKey('no-arm'),
    dropPresence: opts.containsKey('no-presence'),
  );
  final ScorerSet scorer = loadScorer(mount, opts['scorer']);
  stdout.writeln('session : $name');
  stdout.writeln(
    'mount   : ${mount.name}   scorer: ${scorer.source} (v${scorer.version})',
  );
  stdout.writeln(
    'audio   : ${(filtered.audio.length * filtered.audioUsPerSample / 1e6).toStringAsFixed(1)} s, '
    'accel: ${filtered.accel.length} samples, events: ${filtered.events.length}',
  );

  final FusionV2Engine engine = FusionV2Engine(mount: mount, scorer: scorer);
  final Stopwatch watch = Stopwatch()..start();
  final List<ImpactDecision> decisions = runReplay(engine, filtered);
  watch.stop();
  final int accepted = decisions.where((ImpactDecision d) => d.accepted).length;
  stdout.writeln(
    'decisions: ${decisions.length} (accepted $accepted) in ${watch.elapsedMilliseconds} ms',
  );
  if (!opts.containsKey('quiet')) {
    for (final ImpactDecision d in decisions) {
      stdout.writeln(_describe(d, sessionStartUs));
    }
  }
  stdout.writeln('engine  : ${jsonEncode(engine.debugState())}');

  if (labels != null) {
    final ReplayMetrics m = computeMetrics(
      decisions: decisions,
      labelsUs: labels,
      startUs: filtered.audioStartUs,
      endUs: filtered.endUs,
    );
    stdout.writeln('--- metrics (±50 ms) ---');
    stdout.writeln(m.toText());
  } else {
    stdout.writeln('(no labels.csv: metrics skipped)');
  }

  final String? out = opts['out'];
  if (out != null) {
    _writeDecisionsCsv(out, decisions, sessionStartUs);
    stdout.writeln('decisions written to $out');
  }

  final String? sweep = opts['sweep'];
  if (sweep != null) {
    if (labels == null) {
      stderr.writeln('--sweep needs labels');
      exitCode = 64;
      return;
    }
    _sweep(sweep, filtered, mount, scorer, labels);
  }
}

/// Scorer from [path], else `assets/detector/{mount}.json`, else the defaults.
ScorerSet loadScorer(MountProfile mount, String? path) {
  final File file = File(path ?? 'assets/detector/${mount.name}.json');
  if (file.existsSync()) {
    return ScorerSet.fromJson(
      (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>(),
    );
  }
  if (path != null) stderr.writeln('scorer $path not found, using defaults');
  return ScorerSet.defaults(mount);
}

ReplayInput _filterEvents(
  ReplayInput input, {
  required bool dropArm,
  required bool dropPresence,
}) {
  if (!dropArm && !dropPresence) return input;
  return ReplayInput(
    audio: input.audio,
    audioStartUs: input.audioStartUs,
    audioUsPerSample: input.audioUsPerSample,
    accel: input.accel,
    events: <ContextEvent>[
      for (final ContextEvent e in input.events)
        if (!(dropArm && e.kind == 'arm_activity') &&
            !(dropPresence &&
                (e.kind == 'person_valid' ||
                    e.kind == 'camera_on' ||
                    e.kind == 'camera_off')))
          e,
    ],
  );
}

String _describe(ImpactDecision d, int startUs) {
  final double t = (d.onsetUs - startUs) / 1e6;
  final Map<String, double> f = d.features;
  String g(String k, [int digits = 1]) =>
      (f[k] ?? double.nan).toStringAsFixed(digits);
  return '${d.accepted ? 'ACCEPT' : 'reject'} t=${t.toStringAsFixed(3)}s '
      'p=${d.p.toStringAsFixed(3)} (raw ${d.pRaw.toStringAsFixed(3)}) '
      '${d.path}${d.path == 'hard' ? ':${d.reason}' : ''} '
      'lat=${(d.latencyUs / 1000).toStringAsFixed(0)}ms '
      '${d.hasAudioCandidate ? 'A' : '-'}${d.hasShockCandidate ? 'S' : '-'} '
      'rise=${g('audio_rise_max_db')}dB att=${g('audio_attack_ms', 0)}ms '
      'cen=${g('audio_centroid_khz', 2)}k env=${g('accel_env_ratio_log2', 2)} '
      'jerk=${g('accel_peak_jerk', 0)} ctx=${d.contextFactors}';
}

void _writeDecisionsCsv(String path, List<ImpactDecision> ds, int startUs) {
  final List<String> featureNames = <String>{
    for (final ImpactDecision d in ds) ...d.features.keys,
  }.toList()..sort();
  final StringBuffer b = StringBuffer(
    't_s,accepted,p,p_raw,path,reason,latency_ms,audio_cand,shock_cand,mode,hand,'
    '${featureNames.join(',')}\n',
  );
  for (final ImpactDecision d in ds) {
    b.writeln(
      <Object>[
        ((d.onsetUs - startUs) / 1e6).toStringAsFixed(4),
        d.accepted,
        d.p.toStringAsFixed(4),
        d.pRaw.toStringAsFixed(4),
        d.path,
        d.reason.replaceAll(',', ';'),
        (d.latencyUs / 1000).toStringAsFixed(1),
        d.hasAudioCandidate,
        d.hasShockCandidate,
        d.mode.name,
        d.hand,
        for (final String n in featureNames)
          (d.features[n] ?? double.nan).toStringAsFixed(4),
      ].join(','),
    );
  }
  File(path).writeAsStringSync(b.toString());
}

void _sweep(
  String path,
  ReplayInput input,
  MountProfile mount,
  ScorerSet scorer,
  List<int> labels,
) {
  const List<double> margins = <double>[4, 5, 6, 7, 8];
  const List<double> shockKs = <double>[1.2, 1.5, 2.0];
  const List<double> floorScales = <double>[2, 3, 4];
  const List<double> pHighs = <double>[0.75, 0.85, 0.95];
  final StringBuffer b = StringBuffer(
    'audio_margin_db,shock_k,shock_floor_scale,p_high,precision,recall,f1,'
    'fp,fn,false_per_idle_min,latency_median_ms,latency_p95_ms\n',
  );
  int runs = 0;
  double bestF1 = -1;
  String best = '';
  for (final double margin in margins) {
    for (final double k in shockKs) {
      for (final double fs in floorScales) {
        for (final double ph in pHighs) {
          final DetectorConfig config = const DetectorConfig().copyWith(
            audioNoveltyMarginDb: margin,
            shockK: k,
            shockFloorScale: fs,
          );
          final FusionV2Engine engine = FusionV2Engine(
            config: config,
            mount: mount,
            scorer: scorer.copyWith(pHigh: ph),
          );
          final ReplayMetrics m = computeMetrics(
            decisions: runReplay(engine, input),
            labelsUs: labels,
            startUs: input.audioStartUs,
            endUs: input.endUs,
          );
          runs++;
          b.writeln(
            <Object>[
              margin,
              k,
              fs,
              ph,
              m.precision.toStringAsFixed(4),
              m.recall.toStringAsFixed(4),
              m.f1.toStringAsFixed(4),
              m.falsePositives,
              m.falseNegatives,
              m.falsePerIdleMinute.toStringAsFixed(3),
              m.latencyPercentile(50).toStringAsFixed(1),
              m.latencyPercentile(95).toStringAsFixed(1),
            ].join(','),
          );
          if (m.f1 > bestF1) {
            bestF1 = m.f1;
            best = 'margin $margin dB, shockK $k, floorScale $fs, pHigh $ph';
          }
        }
      }
    }
  }
  File(path).writeAsStringSync(b.toString());
  stdout.writeln(
    'sweep: $runs runs written to $path; best F1 ${(bestF1 * 100).toStringAsFixed(1)} % at $best',
  );
}

/// --key value / --flag / positional (stored as _0, _1, ...).
Map<String, String?> _parse(List<String> args) {
  const Set<String> flags = <String>{
    'synthetic',
    'no-arm',
    'no-presence',
    'quiet',
  };
  final Map<String, String?> out = <String, String?>{};
  int positional = 0;
  for (int i = 0; i < args.length; i++) {
    final String a = args[i];
    if (a.startsWith('--')) {
      final String key = a.substring(2);
      if (flags.contains(key) || i + 1 >= args.length) {
        out[key] = null;
      } else {
        out[key] = args[++i];
      }
    } else {
      out['_${positional++}'] = a;
    }
  }
  return out;
}
