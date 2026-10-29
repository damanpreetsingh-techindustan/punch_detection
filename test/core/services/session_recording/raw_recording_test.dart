import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/audio_level/raw_pcm_source.dart';
import 'package:punch_detection_demo/core/services/raw_sensors/raw_accelerometer_service.dart';
import 'package:punch_detection_demo/core/services/session_recording/raw_sensor_recorder.dart';
import 'package:punch_detection_demo/core/services/session_recording/wav_writer.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hh_raw_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('WavWriter', () {
    test('header describes 16-bit mono PCM', () {
      final ByteData h = ByteData.sublistView(
        WavWriter.buildHeader(sampleRate: 16000, channels: 1, dataBytes: 3200),
      );
      expect(String.fromCharCodes(Uint8List.sublistView(h, 0, 4)), 'RIFF');
      expect(h.getUint32(4, Endian.little), 36 + 3200);
      expect(String.fromCharCodes(Uint8List.sublistView(h, 8, 12)), 'WAVE');
      expect(h.getUint16(20, Endian.little), 1);
      expect(h.getUint16(22, Endian.little), 1);
      expect(h.getUint32(24, Endian.little), 16000);
      expect(h.getUint32(28, Endian.little), 32000);
      expect(h.getUint16(34, Endian.little), 16);
      expect(h.getUint32(40, Endian.little), 3200);
    });

    test('sizes are patched on close and samples are little-endian', () async {
      final String path = '${tmp.path}/a.wav';
      final WavWriter wav = WavWriter(path: path, sampleRate: 16000);
      await wav.open();
      wav.write(Int16List.fromList(<int>[1, -2, 32767]));
      wav.write(Int16List.fromList(<int>[-32768]));
      await wav.close();
      final Uint8List bytes = await File(path).readAsBytes();
      final ByteData d = ByteData.sublistView(bytes);
      expect(bytes.length, 44 + 8);
      expect(d.getUint32(40, Endian.little), 8);
      expect(d.getInt16(44, Endian.little), 1);
      expect(d.getInt16(46, Endian.little), -2);
      expect(d.getInt16(48, Endian.little), 32767);
      expect(d.getInt16(50, Endian.little), -32768);
      expect(wav.samplesWritten, 4);
    });
  });

  group('RawAccelerometerService', () {
    test(
      'maps sensor timestamps (not arrival) onto the detection clock',
      () async {
        // detection clock = native clock + offset; the batch below is sent at
        // native 10.020 s and received 0.5 ms later.
        const int offsetUs = 1700000000000000;
        const int sentNativeUs = 10020000;
        final RawAccelerometerService service = RawAccelerometerService(
          nowUs: () => sentNativeUs + offsetUs + 500,
        );
        final List<RawAccelSample> got = <RawAccelSample>[];
        service.samples.listen(got.add);
        service.handleEvent(<String, Object?>{'type': 'info', 'sensor': 'x'});
        service.handleEvent(<String, Object?>{
          'type': 'batch',
          'now': sentNativeUs * 1000,
          't': <int>[10000000000, 10005000000, 10010000000], // native ns
          'x': <double>[0.1, 0.2, 0.3],
          'y': <double>[0, 0, 0],
          'z': <double>[9.8, 9.8, 9.8],
        });
        await Future<void>.delayed(Duration.zero);
        expect(got.length, 3);
        // Event time, not arrival: 20 ms before the batch was sent (plus the
        // 0.5 ms channel delay that a single observation cannot remove).
        expect(got[0].tUs, 10000000 + offsetUs + 500);
        expect(got[2].tUs - got[0].tUs, 10000);
        expect(got[1].x, 0.2);
        expect(service.achievedRateHz, closeTo(200, 1e-9));
        expect(service.diagnostics['info'], <String, Object?>{
          'type': 'info',
          'sensor': 'x',
        });
      },
    );
  });

  group('RawSensorRecorder end to end', () {
    test(
      'writes WAV (resampled to 16 kHz), sync points, accel and meta',
      () async {
        final RawSensorRecorder recorder = RawSensorRecorder(
          baseDirectory: () async => tmp,
        );
        expect(await recorder.begin(sessionStartMs: 1234), isTrue);
        expect(recorder.folderPath, '${tmp.path}/raw_sessions/session_1234');

        // 2.5 s of 44.1 kHz audio in 20 ms buffers (882 samples), 3 ms late each.
        const int rate = 44100;
        const int t0Us = 5000000000;
        int captured = 0;
        for (int k = 1; k <= 125; k++) {
          final Int16List samples = Int16List.fromList(<int>[
            for (int i = 0; i < 882; i++)
              (8000 * sin(2 * pi * 440 * (captured + i) / rate)).round(),
          ]);
          captured += 882;
          recorder.addPcmChunk(
            RawPcmChunk(
              bytes: samples.buffer.asUint8List(),
              sampleRate: rate,
              channels: 1,
              arrivalUs: t0Us + (captured * 1e6 / rate).round() + 3000,
              chunkIndex: k,
            ),
          );
        }
        // 2.5 s of 200 Hz accelerometer.
        for (int i = 0; i < 500; i++) {
          recorder.addAccel(
            RawAccelSample(
              tUs: t0Us + i * 5000,
              sensorNs: 9000000000 + i * 5000000,
              x: 0.01 * i,
              y: 0,
              z: 9.81,
            ),
          );
        }
        final File events = File('${tmp.path}/events_src.jsonl')
          ..writeAsStringSync('{"kind":"touch"}\n');
        final String? folder = await recorder.finish(
          eventsFilePath: events.path,
          meta: <String, Object?>{
            'mountType': 'wall',
            'accel': <String, Object?>{
              'service': <String, Object?>{'n': 1},
            },
          },
        );

        final Uint8List wav = await File('$folder/audio.wav').readAsBytes();
        final int wavSamples =
            ByteData.sublistView(wav).getUint32(40, Endian.little) ~/ 2;
        expect(wavSamples, closeTo(2.5 * 16000, 40));
        expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);

        final List<String> sync = await File(
          '$folder/audio_sync.csv',
        ).readAsLines();
        expect(sync.first, 'wav_sample_index,t_us,capture_sample_index');
        expect(sync.length - 1, inInclusiveRange(2, 4));

        final List<String> accel = await File(
          '$folder/accel.csv',
        ).readAsLines();
        expect(accel.first, 't_us,sensor_ns,x,y,z');
        expect(accel.length, 501);
        expect(accel[2], '${t0Us + 5000},9005000000,0.01000,0.00000,9.81000');

        expect(
          await File('$folder/events.jsonl').readAsString(),
          '{"kind":"touch"}\n',
        );

        final Map<String, Object?> meta =
            jsonDecode(await File('$folder/session_meta.json').readAsString())
                as Map<String, Object?>;
        final Map<String, Object?> audio =
            meta['audio']! as Map<String, Object?>;
        expect(audio['captureSampleRate'], 44100);
        expect(audio['wavSampleRate'], 16000);
        expect(audio['captureSamples'], 125 * 882);
        expect(audio['durationS'] as double, closeTo(2.5, 1e-9));
        expect(audio['medianChunkIntervalMs'] as double, closeTo(20.0, 0.01));
        expect(audio['measuredRateHz'] as double, closeTo(44100, 5));
        final Map<String, Object?> wavMap =
            audio['mappingWav']! as Map<String, Object?>;
        expect(wavMap['usPerSample'] as double, closeTo(62.5, 0.01));
        final Map<String, Object?> accelMeta =
            meta['accel']! as Map<String, Object?>;
        expect(accelMeta['samplesWritten'], 500);
        expect(accelMeta['rateFromMedianHz'] as double, closeTo(200, 1e-9));
        expect(accelMeta['service'], <String, Object?>{'n': 1});
        expect(meta['mountType'], 'wall');
        expect(meta['recorderErrors'], isEmpty);
      },
    );

    test('nothing is written before begin or after finish', () async {
      final RawSensorRecorder recorder = RawSensorRecorder(
        baseDirectory: () async => tmp,
      );
      recorder.addAccel(
        const RawAccelSample(tUs: 1, sensorNs: 1, x: 0, y: 0, z: 0),
      );
      expect(recorder.accelSamples, 0);
      await recorder.begin(sessionStartMs: 1);
      await recorder.finish();
      recorder.addAccel(
        const RawAccelSample(tUs: 1, sensorNs: 1, x: 0, y: 0, z: 0),
      );
      expect(recorder.accelSamples, 0);
    });
  });
}
