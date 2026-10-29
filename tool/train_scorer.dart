// Fits the fusionV2 logistic scorer from labelled sessions and writes the JSON
// asset.
//
//   dart run tool/train_scorer.dart --mount rig --out assets/detector/rig.json \
//       <session_folder> [<session_folder> ...]
//   dart run tool/train_scorer.dart --synthetic --mount wall --out /tmp/wall.json
//
// Every session folder needs a labels.csv (true punch times, seconds since
// session start). The current scorer (--scorer, default
// assets/detector/<mount>.json) runs the engine to produce candidate impacts;
// each one is labelled a punch when a label lies within ±50 ms. The full,
// audio-only and accel-only models are refitted (L2 logistic regression, class
// re-weighted, same features and standardisation). Thresholds are kept.
// See docs/detection-v2.md -> "Labelling and retraining".

import 'dart:convert';
import 'dart:io';

import 'package:punch_detection_demo/detection_core/config/detector_config.dart';
import 'package:punch_detection_demo/detection_core/engine/fusion_v2_engine.dart';
import 'package:punch_detection_demo/detection_core/features/impact_features.dart';
import 'package:punch_detection_demo/detection_core/replay/replay_runner.dart';
import 'package:punch_detection_demo/detection_core/replay/session_folder.dart';
import 'package:punch_detection_demo/detection_core/scoring/logistic_scorer.dart';
import 'package:punch_detection_demo/detection_core/scoring/trainer.dart';
import 'package:punch_detection_demo/detection_core/testing/synthetic_session.dart';

void main(List<String> args) {
  String? mountName, out, scorerPath;
  bool synthetic = false;
  final List<String> folders = <String>[];
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--mount':
        mountName = args[++i];
      case '--out':
        out = args[++i];
      case '--scorer':
        scorerPath = args[++i];
      case '--synthetic':
        synthetic = true;
      default:
        folders.add(args[i]);
    }
  }
  if (out == null || (folders.isEmpty && !synthetic)) {
    stderr.writeln(
      'usage: dart run tool/train_scorer.dart --mount rig|wall --out <file.json> '
      '<session_folder> ... | --synthetic',
    );
    exitCode = 64;
    return;
  }
  final MountProfile mount = MountProfile.fromName(mountName ?? 'wall');
  final File scorerFile = File(
    scorerPath ?? 'assets/detector/${mount.name}.json',
  );
  final ScorerSet current = scorerFile.existsSync()
      ? ScorerSet.fromJson(
          (jsonDecode(scorerFile.readAsStringSync()) as Map)
              .cast<String, Object?>(),
        )
      : ScorerSet.defaults(mount);

  final List<TrainingExample> examples = <TrainingExample>[];
  final List<(ReplayInput, List<int>, String)> sessions =
      <(ReplayInput, List<int>, String)>[];
  if (synthetic) {
    for (int seed = 1; seed <= 4; seed++) {
      final SyntheticSession s = SyntheticSession.golden(seed: seed);
      sessions.add((
        s.input,
        <int>[
          for (final SyntheticEvent e in s.events)
            if (e.expectAccepted) e.onsetUs,
        ],
        'synthetic seed $seed',
      ));
    }
  }
  for (final String folder in folders) {
    final RecordedSession s = RecordedSession.load(folder);
    final String labelPath = '$folder/labels.csv';
    if (!File(labelPath).existsSync()) {
      stderr.writeln('skipping $folder: no labels.csv');
      continue;
    }
    if (s.mount != mount) {
      stderr.writeln('note: $folder was recorded on ${s.mount.name}');
    }
    sessions.add((s.input, s.loadLabels(labelPath), folder));
  }

  for (final (ReplayInput input, List<int> labels, String name) in sessions) {
    final FusionV2Engine engine = FusionV2Engine(mount: mount, scorer: current);
    int pos = 0, neg = 0;
    for (final ImpactDecision d in runReplay(engine, input)) {
      if (d.path == 'hard') continue; // touch / settings / person gone
      final bool isPunch = labels.any(
        (int l) => (l - d.onsetUs).abs() <= 50000,
      );
      examples.add(TrainingExample(d.features, isPunch));
      isPunch ? pos++ : neg++;
    }
    stdout.writeln('$name: $pos punch candidates, $neg non-punch candidates');
  }
  if (examples.isEmpty) {
    stderr.writeln('no training examples');
    exitCode = 1;
    return;
  }

  bool has(TrainingExample e, String f) => (e.features[f] ?? 0) > 0;
  final List<TrainingExample> both = <TrainingExample>[
    for (final TrainingExample e in examples)
      if (has(e, F.audioPresent) && has(e, F.accelPresent)) e,
  ];
  final List<TrainingExample> withAudio = <TrainingExample>[
    for (final TrainingExample e in examples)
      if (has(e, F.audioPresent)) e,
  ];
  final List<TrainingExample> withAccel = <TrainingExample>[
    for (final TrainingExample e in examples)
      if (has(e, F.accelPresent)) e,
  ];
  final ScorerSet trained = current.copyWith(
    source:
        'trained ${DateTime.now().toIso8601String().substring(0, 10)} on '
        '${sessions.length} session(s), ${examples.length} candidates',
    full: both.isEmpty ? current.full : fitLogistic(current.full, both),
    audioOnly: withAudio.isEmpty
        ? current.audioOnly
        : fitLogistic(current.audioOnly, withAudio),
    accelOnly: withAccel.isEmpty
        ? current.accelOnly
        : fitLogistic(current.accelOnly, withAccel),
  );

  int correct = 0;
  for (final TrainingExample e in both) {
    final double p = trained.full.probability(e.features);
    if ((p >= trained.pDecide) == e.isPunch) correct++;
  }
  File(out).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(trained.toJson())}\n',
  );
  stdout.writeln(
    'wrote $out (training accuracy of the full model: '
    '${both.isEmpty ? '-' : (100 * correct / both.length).toStringAsFixed(1)} %)',
  );
}
