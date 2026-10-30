import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/services/session_recording/session_summary_table.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/impact_gate_evaluator.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';

class _MockAudioLevelService implements IAudioLevelService {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  @override
  Stream<double> get decibelStream => _controller.stream;

  @override
  Stream<AudioLevelSample> get sampleStream => _controller.stream.map(
    (double db) => AudioLevelSample(
      db: db,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  @override
  Map<String, Object?> get diagnostics => const <String, Object?>{};

  @override
  double get currentDecibels => 45.0;

  @override
  bool get isMonitoring => true;

  @override
  bool get isEarbudsConnected => false;

  @override
  Future<bool> checkEarbudsConnected() async => false;

  @override
  Future<bool> startMonitoring({int sampleIntervalMs = 50}) async => true;

  @override
  Future<void> stopMonitoring() async {}

  @override
  Future<void> updateSampleInterval(int newIntervalMs) async {}

  @override
  void dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FreeSessionController controller;
  const int t0 = 1000000000000;

  /// One audio frame at session time [t] (ms).
  void frame(double db, int t) {
    controller.liveDecibelLevel.value = db;
    controller.checkPunchDetectionForTesting(frameTimestampMs: t0 + t);
  }

  /// Quiet frames every 10 ms in [from, to).
  void quiet(int from, int to) {
    for (int t = from; t < to; t += 10) {
      frame(50.0, t);
    }
  }

  void vibe(double mag, int t) =>
      controller.ingestVibrationSampleForTesting(mag, atEpochMs: t0 + t);

  void camera(CameraGateState state, int t) =>
      controller.setCameraObservationForTesting(state, atMs: t0 + t);

  List<String> codes() =>
      controller.telemetryEvents.map((e) => e.decisionCode).toList();

  setUp(() {
    AppConstants.changeSettingToDefault();
    AppConstants.warmUpDurationInMiliSeconds = 0;
    controller = FreeSessionController(
      audioLevelService: _MockAudioLevelService(),
    );
    // These tests cover the vibration / camera gates; the body-motion gate
    // (ON by default) has its own tests in body_motion_gate_test.dart.
    controller.isBodyMotionGateEnabled.value = false;
    controller.sessionMode.value = DetectionMode.fusion;
    controller.mountType.value = MountType.wall;
    controller.isVibrationGateEnabled.value = true;
    controller.minVibrationThreshold.value = 0.18;
    controller.isVisionConfirmationRequired.value = true;
    controller.isCameraInitialized.value = true;
    controller.isCameraUnavailable.value = false;
    controller.staticCalibratedAudioDb.value = 70.0;
    controller.customTargetAudioDb.value = 75.0;
    controller.minAudioPunchSpikeDb.value = 5.0;
  });

  tearDown(() => controller.onClose());

  group('audio + vibration + camera', () {
    test('counts when all three confirm (vibration slightly before audio)', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 40);
      vibe(0.6, 40); // 20 ms before the audio spike
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
      expect(codes().first, 'IMPACT_VALID_AUDIO_VIBE_CAM');
    });

    test('late vibration (80 ms after audio) still counts', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      frame(95.0, 60);
      expect(controller.punchCount.value, 0, reason: 'waiting for vibration');
      quiet(70, 140);
      vibe(0.6, 140);
      expect(controller.punchCount.value, 1);
    });

    test('no vibration in the window -> rejected when the window closes', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_NO_VIBRATION'));
    });

    test('vibration outside the window does not count', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      vibe(0.9, -200); // 260 ms before the spike: too early
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
    });

    test('a rejected impact does not lock out the next real punch', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      frame(95.0, 60); // A: no vibration
      quiet(70, 220); // window closes at 210 -> rejected, lock released
      expect(controller.punchCount.value, 0);

      // B is 155 ms after A: inside the old 160 ms lock, but A was not counted.
      camera(CameraGateState.valid, 200);
      frame(95.0, 215);
      vibe(0.6, 230);
      expect(controller.punchCount.value, 1);
    });

    test('two punches 200 ms apart both count', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      frame(95.0, 60);
      vibe(0.6, 80);
      quiet(70, 260);
      camera(CameraGateState.valid, 250);
      frame(95.0, 260);
      vibe(0.6, 280);
      expect(controller.punchCount.value, 2);
    });

    test('a second spike inside the lockout after a counted punch is ignored', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      vibe(0.6, 60);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
      quiet(70, 130);
      vibe(0.6, 130);
      frame(95.0, 130); // 70 ms later
      quiet(140, 300);
      expect(controller.punchCount.value, 1);
    });
  });

  group('CAM status on screen', () {
    test('shows the live camera gate in fusion mode (valid user = Confirm)', () {
      expect(controller.isCameraGateShownOnScreen, isTrue);
      camera(CameraGateState.valid, 10);
      expect(controller.liveCameraGateState.value, CameraGateState.valid);
      camera(CameraGateState.tooFar, 20);
      expect(controller.liveCameraGateState.value, CameraGateState.tooFar);
      camera(CameraGateState.noPerson, 30);
      expect(controller.liveCameraGateState.value, CameraGateState.noPerson);
    });

    test('camera-only mode keeps the arm-motion status', () {
      controller.sessionMode.value = DetectionMode.camera;
      expect(controller.isCameraGateShownOnScreen, isFalse);
    });

    test('vision confirmation off: camera gate not shown', () {
      controller.isVisionConfirmationRequired.value = false;
      expect(controller.isCameraGateShownOnScreen, isFalse);
    });
  });

  group('camera hard gate', () {
    test('user too far -> rejected even with audio and vibration', () {
      quiet(0, 60);
      camera(CameraGateState.tooFar, 50);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_CAMERA_TOO_FAR'));
    });

    test('no user visible -> rejected', () {
      quiet(0, 60);
      camera(CameraGateState.noPerson, 50);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_CAMERA_NO_PERSON'));
    });

    test('an old camera observation no longer counts', () {
      camera(CameraGateState.valid, -2000); // seen 2 s ago, then nothing
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
    });

    test('camera still starting up -> rejected as not ready', () {
      controller.isCameraInitialized.value = false;
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 220);
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_CAMERA_NOT_READY'));
    });

    test('user steps into frame during the window -> counts', () {
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      expect(controller.punchCount.value, 0);
      camera(CameraGateState.valid, 100);
      frame(50.0, 100);
      expect(controller.punchCount.value, 1);
    });
  });

  group('when a sensor is disabled', () {
    test('camera disabled (vision confirmation off) -> audio + vibration', () {
      controller.isVisionConfirmationRequired.value = false;
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
      expect(codes().first, 'IMPACT_VALID_AUDIO_VIBE');
    });

    test('camera failed to start -> audio + vibration', () {
      controller.isCameraUnavailable.value = true;
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
    });

    test('pole mount (no vibration) -> audio + camera', () {
      controller.mountType.value = MountType.pole;
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
      expect(codes().first, 'IMPACT_VALID_AUDIO_CAM');
    });

    test('audio + vibration mode never uses the camera', () {
      controller.sessionMode.value = DetectionMode.audioVibration;
      quiet(0, 60);
      vibe(0.6, 60);
      frame(95.0, 60);
      expect(controller.punchCount.value, 1);
    });
  });

  group('debug log details', () {
    /// Summary CSV rows of one kind, as column -> cell maps.
    List<Map<String, String>> rows(String kind) {
      final List<String> lines = controller.summaryTable.toCsv().trim().split(
        '\n',
      );
      return lines
          .skip(1)
          .map((String line) => line.split(','))
          .where((List<String> cells) => cells[1] == kind)
          .map(
            (List<String> cells) => <String, String>{
              for (int i = 0; i < SessionSummaryTable.columns.length; i++)
                SessionSummaryTable.columns[i]: cells[i],
            },
          )
          .toList();
    }

    test('a hit hidden by the lockout is logged as suppressed', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      vibe(0.6, 60);
      frame(95.0, 60);
      quiet(70, 130);
      frame(95.0, 130); // 70 ms later: inside the 160 ms lockout
      quiet(140, 300);
      expect(controller.punchCount.value, 1);
      expect(
        controller.recorder.totals.counter('audio.spikes_suppressed'),
        greaterThanOrEqualTo(1),
      );
      final List<Map<String, String>> suppressed = rows('SUPPRESSED');
      expect(suppressed, hasLength(1));
      expect(suppressed.single['code'], 'SPIKE_SUPPRESSED_LOCKOUT');
      expect(
        controller.summaryTable.toCsv(),
        contains('70 ms after previous spike, above target'),
      );
    });

    test('impact row carries rise values and vibration offset', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 40);
      vibe(0.6, 40); // 20 ms before the audio spike
      frame(95.0, 60);
      final Map<String, String> row = rows('IMPACT').single;
      expect(row['vibe_offset_ms'], '-20');
      expect(row['vibe_rose'], 'yes');
      expect(double.parse(row['window_rise']!), greaterThanOrEqualTo(10.0));
    });

    test('vibration that is only the previous punch tail is flagged', () {
      quiet(0, 60);
      camera(CameraGateState.valid, 50);
      vibe(0.6, 60);
      frame(95.0, 60);
      vibe(0.3, 170); // fading tail of the first hit, no new rise
      vibe(0.25, 200);
      quiet(70, 260);
      camera(CameraGateState.valid, 250);
      frame(95.0, 260);
      quiet(270, 430);
      expect(controller.punchCount.value, 2);
      expect(rows('IMPACT').last['vibe_rose'], 'no');
      expect(controller.recorder.totals.counter('impact.vibe_tail_only'), 1);
    });
  });

  test('a spike below the audio target never opens a window', () {
    quiet(0, 60);
    camera(CameraGateState.valid, 50);
    vibe(0.6, 60);
    frame(72.0, 60); // below the 75 dB target
    quiet(70, 220);
    expect(controller.punchCount.value, 0);
    expect(codes(), contains('AUDIO_BELOW_TARGET'));
  });
}
