import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/audio_level/raw_pcm_source.dart';
import 'package:punch_detection_demo/core/services/raw_sensors/raw_accelerometer_service.dart';
import 'package:punch_detection_demo/core/services/session_recording/raw_sensor_recorder.dart';
import 'package:punch_detection_demo/detection_core/accel/shock_tracker.dart';
import 'package:punch_detection_demo/detection_core/config/detector_config.dart';
import 'package:punch_detection_demo/detection_core/engine/fusion_v2_engine.dart';
import 'package:punch_detection_demo/detection_core/replay/replay_runner.dart';
import 'package:punch_detection_demo/detection_core/replay/session_folder.dart';
import 'package:punch_detection_demo/detection_core/testing/synthetic_session.dart';

/// Writes [s] as a Phase 2 raw session folder, as the app would.
Future<String> writeFolder(Directory base, SyntheticSession s) async {
  final RawSensorRecorder rec = RawSensorRecorder(
    baseDirectory: () async => base,
  );
  const int startMs = SyntheticSession.startUs ~/ 1000;
  await rec.begin(sessionStartMs: startMs);
  // 20 ms buffers, each arriving 4 ms after its last sample.
  final Int16List pcm = s.input.audio;
  for (int i = 0; i < pcm.length; i += 320) {
    final int end = i + 320 > pcm.length ? pcm.length : i + 320;
    final Int16List chunk = Int16List.fromList(pcm.sublist(i, end));
    rec.addPcmChunk(
      RawPcmChunk(
        bytes: chunk.buffer.asUint8List(),
        sampleRate: 16000,
        channels: 1,
        arrivalUs: SyntheticSession.startUs + (end * 62.5).round() + 4000,
        chunkIndex: i ~/ 320 + 1,
      ),
    );
  }
  for (final AccelSampleIn a in s.input.accel) {
    rec.addAccel(
      RawAccelSample(
        tUs: a.tUs,
        sensorNs: a.tUs * 1000,
        x: a.x,
        y: a.y,
        z: a.z,
      ),
    );
  }
  final File events = File('${base.path}/events_src.jsonl');
  final StringBuffer b = StringBuffer();
  for (final ContextEvent e in s.input.events) {
    final String kind = switch (e.kind) {
      'touch' => 'touch',
      'person_valid' => 'cam',
      _ => 'ui',
    };
    b.writeln(
      jsonEncode(<String, Object?>{
        'tMs': (e.tUs - SyntheticSession.startUs) ~/ 1000,
        'epochMs': e.tUs ~/ 1000,
        'kind': kind,
        'data': kind == 'ui'
            ? <String, Object?>{'camera': 'initialized'}
            : <String, Object?>{},
      }),
    );
  }
  await events.writeAsString(b.toString());
  final String folder = (await rec.finish(
    eventsFilePath: events.path,
    meta: <String, Object?>{'sessionStartMs': startMs, 'mountType': 'wall'},
  ))!;
  await File('$folder/labels.csv').writeAsString(
    '# seconds since session start\n'
    '${s.events.where((SyntheticEvent e) => e.expectAccepted).map((SyntheticEvent e) => ((e.onsetUs - SyntheticSession.startUs) / 1e6).toString()).join('\n')}\n',
  );
  return folder;
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('hh_replay_'));
  tearDown(() async => tmp.delete(recursive: true));

  test(
    'a recorded folder replays to the same decisions as the live feed',
    () async {
      final SyntheticSession s = SyntheticSession.golden();
      final String folder = await writeFolder(tmp, s);

      final RecordedSession recorded = RecordedSession.load(folder);
      expect(recorded.mount, MountProfile.wall);
      expect(recorded.wavSampleRate, 16000);
      expect(recorded.input.audio.length, closeTo(s.input.audio.length, 2));
      // The fitted mapping recovers the true audio start within the 4 ms
      // delivery delay.
      expect(
        (recorded.input.audioStartUs - SyntheticSession.startUs).abs(),
        lessThan(5000),
      );

      List<int> acceptedOnsets(ReplayInput input) => <int>[
        for (final ImpactDecision d in runReplay(
          FusionV2Engine(mount: MountProfile.wall),
          input,
        ))
          if (d.accepted) d.onsetUs,
      ];
      final List<int> live = acceptedOnsets(s.input);
      final List<int> replayed = acceptedOnsets(recorded.input);
      expect(replayed.length, live.length);
      for (int i = 0; i < live.length; i++) {
        expect((replayed[i] - live[i]).abs(), lessThan(6000));
      }

      final List<int> labels = recorded.loadLabels('$folder/labels.csv');
      expect(labels.length, live.length);
      expect(labels.first, SyntheticSession.startUs + 1500000);
    },
  );

  test('labels: comments, header and extra columns are ignored', () {
    expect(
      RecordedSession.parseLabels(<String>[
        'time_s',
        '# a comment',
        '1.5',
        '',
        '2.25,left',
        ' 3 ',
      ], sessionStartUs: 1000),
      <int>[1501000, 2251000, 3001000],
    );
  });
}
