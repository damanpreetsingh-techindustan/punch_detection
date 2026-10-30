import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/services/device_vibration/i_device_vibration_service.dart';
import 'package:punch_detection_demo/core/services/session_recording/session_summary_table.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/fusion/domain/body_motion_gate/models/body_motion_evaluation.dart';
import 'package:punch_detection_demo/features/fusion/domain/body_motion_gate/models/body_motion_frame.dart';
import 'package:punch_detection_demo/features/fusion/domain/body_motion_gate/services/landmark_motion_gate.dart';
import 'package:punch_detection_demo/features/fusion/domain/services/impact_gate_evaluator.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';
import 'package:punch_detection_demo/features/vision_detection/data/mappers/pose_motion_frame_mapper.dart';

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

/// No-op vibration service: Defaults restarts vibration monitoring, which must
/// not touch the real accelerometer plugin (missing in unit tests).
class _FakeVibrationService implements IDeviceVibrationService {
  final StreamController<double> _magnitudes =
      StreamController<double>.broadcast();
  final StreamController<VibrationRawSample> _raw =
      StreamController<VibrationRawSample>.broadcast();

  @override
  Stream<double> get vibrationMagnitudeStream => _magnitudes.stream;

  @override
  Stream<VibrationRawSample> get rawSampleStream => _raw.stream;

  @override
  double get currentVibrationMagnitude => 0.0;

  @override
  double get recentPeakVibrationMagnitude => 0.0;

  @override
  int get lastVibrationTimestampMs => 0;

  @override
  int get recentPeakTimestampMs => 0;

  @override
  bool hasRecentVibration(int nowMs, {int maxAgeMs = 350}) => false;

  @override
  void startMonitoring({double minVibrationThreshold = 0.35}) {}

  @override
  void stopMonitoring() {}

  @override
  void consumeRecentPeak() {}

  @override
  void resetMagnitude() {}

  @override
  void dispose() {
    _magnitudes.close();
    _raw.close();
  }
}

// ── Synthetic camera frames (body width 200 px, ~30 fps) ─────────────────────

/// Small deterministic ML Kit-like jitter (±2 px).
double _jitter(int i, int salt) => ((i * 7 + salt * 3) % 5 - 2).toDouble();

/// User standing still: face + both shoulders with jitter only.
BodyMotionFrame _stillFrame(int tMs, int i) => BodyMotionFrame(
  tMs: tMs,
  bodyScale: 200,
  points: <BodyMotionPoint, Point<double>>{
    BodyMotionPoint.face: Point<double>(200 + _jitter(i, 1), 150 + _jitter(i, 2)),
    BodyMotionPoint.leftShoulder: Point<double>(
      100 + _jitter(i, 3),
      300 + _jitter(i, 4),
    ),
    BodyMotionPoint.rightShoulder: Point<double>(
      300 + _jitter(i, 5),
      300 + _jitter(i, 6),
    ),
  },
);

/// Punch: the right shoulder drives forward/down by up to [shift] px and the
/// head shifts a little, around [punchMs]. Only face + shoulders visible.
BodyMotionFrame _punchFrame(int tMs, int i, int punchMs, {double shift = 40}) {
  final int d = (tMs - punchMs).abs();
  final double k = d >= 150 ? 0.0 : 1.0 - d / 150.0; // 0..1 near the impact
  final BodyMotionFrame still = _stillFrame(tMs, i);
  return BodyMotionFrame(
    tMs: tMs,
    bodyScale: 200,
    points: <BodyMotionPoint, Point<double>>{
      BodyMotionPoint.face: still.points[BodyMotionPoint.face]! +
          Point<double>(8 * k, 4 * k),
      BodyMotionPoint.leftShoulder: still.points[BodyMotionPoint.leftShoulder]!,
      BodyMotionPoint.rightShoulder:
          still.points[BodyMotionPoint.rightShoulder]! +
          Point<double>(-shift * k, shift * 0.5 * k),
    },
  );
}

void _addFrames(
  void Function(BodyMotionFrame) add,
  int fromMs,
  int toMs,
  BodyMotionFrame Function(int tMs, int i) make,
) {
  int i = 0;
  for (int t = fromMs; t <= toMs; t += 33) {
    add(make(t, i++));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── 1. The gate's measurement (pure) ──────────────────────────────────────
  group('LandmarkMotionGate', () {
    late LandmarkMotionGate gate;
    const int audio = 10000;
    setUp(() => gate = LandmarkMotionGate());

    BodyMotionEvaluation eval({double minScore = 0.08, bool required = true}) =>
        gate.evaluate(audioTsMs: audio, minScore: minScore, isRequired: required);

    test('standing still (jitter only) is "still"', () {
      _addFrames(gate.addFrame, audio - 600, audio + 300, _stillFrame);
      final BodyMotionEvaluation r = eval();
      expect(r.state, BodyMotionGateState.still);
      expect(r.score!, lessThan(0.03));
    });

    test('punch with only face + shoulders visible is "moved"', () {
      _addFrames(
        gate.addFrame,
        audio - 600,
        audio + 300,
        (int t, int i) => _punchFrame(t, i, audio - 60),
      );
      final BodyMotionEvaluation r = eval();
      expect(r.state, BodyMotionGateState.moved);
      expect(r.topPoint, BodyMotionPoint.rightShoulder);
      expect(r.score!, greaterThan(AppConstants.bodyMotionMinScoreNormal));
    });

    test('punch with only face + ONE shoulder visible is "moved"', () {
      _addFrames(gate.addFrame, audio - 600, audio + 300, (int t, int i) {
        final BodyMotionFrame f = _punchFrame(t, i, audio - 60);
        return BodyMotionFrame(
          tMs: t,
          bodyScale: 200,
          points: Map<BodyMotionPoint, Point<double>>.of(f.points)
            ..remove(BodyMotionPoint.leftShoulder),
        );
      });
      expect(eval().state, BodyMotionGateState.moved);
    });

    test('a single-frame ML Kit glitch is not movement', () {
      int i = 0;
      for (int t = audio - 600; t <= audio + 300; t += 33) {
        final BodyMotionFrame f = _stillFrame(t, i);
        gate.addFrame(
          i == 15 // one frame where the shoulder "jumps" 60 px
              ? BodyMotionFrame(
                  tMs: t,
                  bodyScale: 200,
                  points: Map<BodyMotionPoint, Point<double>>.of(f.points)
                    ..[BodyMotionPoint.leftShoulder] = const Point<double>(
                      160,
                      300,
                    ),
                )
              : f,
        );
        i++;
      }
      expect(eval().state, BodyMotionGateState.still);
    });

    test('the score does not depend on the distance to the camera', () {
      // Same punch filmed at half the size (user twice as far away).
      BodyMotionFrame half(BodyMotionFrame f) => BodyMotionFrame(
        tMs: f.tMs,
        bodyScale: f.bodyScale! / 2,
        points: f.points.map(
          (BodyMotionPoint k, Point<double> p) =>
              MapEntry<BodyMotionPoint, Point<double>>(k, p * 0.5),
        ),
      );
      final LandmarkMotionGate far = LandmarkMotionGate();
      _addFrames(gate.addFrame, audio - 600, audio + 300, (int t, int i) {
        final BodyMotionFrame f = _punchFrame(t, i, audio - 60);
        far.addFrame(half(f));
        return f;
      });
      final double near = eval().score!;
      final double farScore = far
          .evaluate(audioTsMs: audio, minScore: 0.08, isRequired: true)
          .score!;
      expect(farScore, closeTo(near, 0.02));
    });

    test('movement outside the window does not count', () {
      // A punch 1 s BEFORE this impact, standing still around the impact.
      _addFrames(
        gate.addFrame,
        audio - 1500,
        audio + 300,
        (int t, int i) => t < audio - 700
            ? _punchFrame(t, i, audio - 1000)
            : _stillFrame(t, i),
      );
      expect(eval().state, BodyMotionGateState.still);
    });

    test('too few frames is "unknown"', () {
      gate.addFrame(_stillFrame(audio - 50, 0));
      gate.addFrame(_stillFrame(audio, 1));
      final BodyMotionEvaluation r = eval();
      expect(r.state, BodyMotionGateState.unknown);
      expect(r.score, isNull);
    });

    test('gate not required: state notRequired but the score is still measured', () {
      _addFrames(gate.addFrame, audio - 600, audio + 300, _stillFrame);
      final BodyMotionEvaluation r = eval(required: false);
      expect(r.state, BodyMotionGateState.notRequired);
      expect(r.score, isNotNull);
      expect(r.wouldPass, isFalse);
    });

    test('levels: the same movement passes Easy but not Strict', () {
      _addFrames(
        gate.addFrame,
        audio - 600,
        audio + 300,
        (int t, int i) => _punchFrame(t, i, audio - 60, shift: 22),
      );
      final double score = eval().score!;
      expect(score, greaterThan(AppConstants.bodyMotionMinScoreEasy));
      expect(score, lessThan(AppConstants.bodyMotionMinScoreStrict));
    });

    test('reset forgets old frames', () {
      _addFrames(gate.addFrame, audio - 600, audio + 300, _stillFrame);
      gate.reset();
      expect(gate.frameCount, 0);
    });
  });

  // ── 2. Decision rules with the motion input ───────────────────────────────
  group('ImpactGateEvaluator with body motion', () {
    const ImpactGateEvaluator evaluator = ImpactGateEvaluator();

    ImpactGateResult run(BodyMotionGateState motion, {bool closed = false}) =>
        evaluator.evaluate(
          vibration: VibrationGateState.present,
          camera: CameraGateState.valid,
          windowClosed: closed,
          motion: motion,
        );

    test('moved -> valid at once (same code as before)', () {
      final ImpactGateResult r = run(BodyMotionGateState.moved);
      expect(r.isValid, isTrue);
      expect(r.code, 'IMPACT_VALID_AUDIO_VIBE_CAM');
      expect(r.reasonLabel, contains('Body Motion'));
    });

    test('still -> waits while open, rejected when closed', () {
      expect(run(BodyMotionGateState.still).isPending, isTrue);
      final ImpactGateResult r = run(BodyMotionGateState.still, closed: true);
      expect(r.isRejected, isTrue);
      expect(r.code, 'IMPACT_REJECTED_NO_BODY_MOTION');
    });

    test('unknown -> waits while open, passes when closed (default)', () {
      expect(run(BodyMotionGateState.unknown).isPending, isTrue);
      expect(run(BodyMotionGateState.unknown, closed: true).isValid, isTrue);
    });

    test('unknown with unknownIsValid=false -> rejected when closed', () {
      final ImpactGateResult r = evaluator.evaluate(
        vibration: VibrationGateState.present,
        camera: CameraGateState.valid,
        windowClosed: true,
        motion: BodyMotionGateState.unknown,
        motionUnknownIsValid: false,
      );
      expect(r.code, 'IMPACT_REJECTED_MOTION_UNKNOWN');
    });

    test('vibration / camera problems keep their own codes first', () {
      final ImpactGateResult r = evaluator.evaluate(
        vibration: VibrationGateState.missing,
        camera: CameraGateState.valid,
        windowClosed: true,
        motion: BodyMotionGateState.still,
      );
      expect(r.code, 'IMPACT_REJECTED_NO_VIBRATION');
    });

    test('without the motion argument nothing changes', () {
      final ImpactGateResult r = evaluator.evaluate(
        vibration: VibrationGateState.present,
        camera: CameraGateState.valid,
        windowClosed: false,
      );
      expect(r.isValid, isTrue);
      expect(r.reasonLabel, 'Valid Punch (Audio + Vibration + Camera)');
    });
  });

  // ── 3. ML Kit pose -> frame adapter ───────────────────────────────────────
  group('PoseMotionFrameMapper', () {
    PoseLandmark lm(PoseLandmarkType t, double x, double y, double l) =>
        PoseLandmark(type: t, x: x, y: y, z: 0, likelihood: l);

    test('keeps confident face / shoulders / arms and measures body width', () {
      final Pose pose = Pose(
        landmarks: <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.nose: lm(PoseLandmarkType.nose, 200, 150, 0.9),
          PoseLandmarkType.leftShoulder: lm(
            PoseLandmarkType.leftShoulder,
            100,
            300,
            0.9,
          ),
          PoseLandmarkType.rightShoulder: lm(
            PoseLandmarkType.rightShoulder,
            300,
            300,
            0.9,
          ),
          PoseLandmarkType.leftElbow: lm(PoseLandmarkType.leftElbow, 90, 420, 0.8),
          // Weak point: ignored.
          PoseLandmarkType.rightWrist: lm(
            PoseLandmarkType.rightWrist,
            350,
            500,
            0.2,
          ),
        },
      );
      final BodyMotionFrame f = const PoseMotionFrameMapper().map(pose, tMs: 5);
      expect(f.tMs, 5);
      expect(f.points.keys, <BodyMotionPoint>{
        BodyMotionPoint.face,
        BodyMotionPoint.leftShoulder,
        BodyMotionPoint.rightShoulder,
        BodyMotionPoint.leftElbow,
      });
      expect(f.bodyScale, closeTo(200, 0.01));
    });

    test('one shoulder + eyes: body width comes from the face', () {
      final Pose pose = Pose(
        landmarks: <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.leftEye: lm(PoseLandmarkType.leftEye, 180, 140, 0.9),
          PoseLandmarkType.rightEye: lm(PoseLandmarkType.rightEye, 220, 140, 0.9),
          PoseLandmarkType.leftShoulder: lm(
            PoseLandmarkType.leftShoulder,
            100,
            300,
            0.9,
          ),
        },
      );
      final BodyMotionFrame f = const PoseMotionFrameMapper().map(pose, tMs: 0);
      expect(f.points[BodyMotionPoint.face], const Point<double>(200, 140));
      expect(f.bodyScale, closeTo(40 * 2.8, 0.01));
    });
  });

  // ── 4. Full session: the reported problem ─────────────────────────────────
  group('Free session with the body-motion gate', () {
    late FreeSessionController controller;
    const int t0 = 1000000000000;

    void frame(double db, int t) {
      controller.liveDecibelLevel.value = db;
      controller.checkPunchDetectionForTesting(frameTimestampMs: t0 + t);
    }

    void quiet(int from, int to) {
      for (int t = from; t < to; t += 10) {
        frame(50.0, t);
      }
    }

    void knock(int t) {
      controller.vibrationGate.addRawSample(
        sensorMs: t0 + t - 20,
        rawMag: 0.0,
        rawX: 0.0,
        rawY: 0.0,
        rawZ: 0.0,
      );
      controller.vibrationGate.addRawSample(
        sensorMs: t0 + t,
        rawMag: 1.5,
        rawX: 1.2,
        rawY: 0.3,
        rawZ: 0.8,
      );
    }

    void motionFrames(BodyMotionFrame Function(int tMs, int i) make) =>
        _addFrames(controller.addBodyMotionFrameForTesting, t0 - 300, t0 + 600, make);

    List<String> codes() =>
        controller.telemetryEvents.map((e) => e.decisionCode).toList();

    Map<String, String> impactRow() {
      final List<String> lines = controller.summaryTable.toCsv().trim().split(
        '\n',
      );
      final List<String> cells = lines
          .skip(1)
          .map((String l) => l.split(','))
          .lastWhere((List<String> c) => c[1] == 'IMPACT');
      return <String, String>{
        for (int i = 0; i < SessionSummaryTable.columns.length; i++)
          SessionSummaryTable.columns[i]: cells[i],
      };
    }

    setUp(() {
      AppConstants.changeSettingToDefault();
      AppConstants.warmUpDurationInMiliSeconds = 0;
      controller = FreeSessionController(
        audioLevelService: _MockAudioLevelService(),
        vibrationService: _FakeVibrationService(),
      );
      controller.sessionMode.value = DetectionMode.fusion;
      controller.mountType.value = MountType.wall;
      controller.minVibrationThreshold.value = 0.18;
      controller.isVisionConfirmationRequired.value = true;
      controller.isCameraInitialized.value = true;
      controller.isCameraUnavailable.value = false;
      controller.staticCalibratedAudioDb.value = 70.0;
      controller.customTargetAudioDb.value = 75.0;
      controller.minAudioPunchSpikeDb.value = 5.0;
    });

    tearDown(() => controller.onClose());

    void bangAndBumpAt300() {
      quiet(0, 300);
      controller.setCameraObservationForTesting(
        CameraGateState.valid,
        atMs: t0 + 280,
      );
      knock(290);
      frame(95.0, 300); // loud background sound
      quiet(310, 520);
    }

    test('gate ON: standing still + noise + knock is NOT a punch', () {
      controller.toggleBodyMotionGate(true);
      motionFrames(_stillFrame);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 0);
      expect(codes(), contains('IMPACT_REJECTED_NO_BODY_MOTION'));
      expect(impactRow()['motion_state'], 'still');
      expect(
        controller.recorder.totals.counter('motion.rejected_still'),
        1,
      );
    });

    test('gate ON: a real punch (face + shoulders moving) counts', () {
      controller.toggleBodyMotionGate(true);
      motionFrames((int t, int i) => _punchFrame(t, i, t0 + 260));
      bangAndBumpAt300();
      expect(controller.punchCount.value, 1);
      expect(impactRow()['motion_state'], 'moved');
      expect(impactRow()['motion_top_point'], 'rightShoulder');
    });

    test('gate ON: camera frames missing -> punch still counts (unknown)', () {
      controller.toggleBodyMotionGate(true);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 1);
      expect(impactRow()['motion_state'], 'unknown');
    });

    test('gate is ON by default', () {
      expect(controller.isBodyMotionGateEnabled.value, isTrue);
    });

    test('gate OFF: counted as before, log says it would reject', () {
      controller.toggleBodyMotionGate(false);
      motionFrames(_stillFrame);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 1);
      expect(impactRow()['motion_state'], 'off(still)');
      expect(controller.recorder.totals.counter('motion.would_reject'), 1);
    });

    test('Strict rejects a small movement that Easy accepts', () {
      controller.toggleBodyMotionGate(true);
      motionFrames((int t, int i) => _punchFrame(t, i, t0 + 260, shift: 22));

      controller.setBodyMotionLevel(BodyMotionLevel.strict);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 0);
    });

    test('Easy accepts the same small movement', () {
      controller.toggleBodyMotionGate(true);
      motionFrames((int t, int i) => _punchFrame(t, i, t0 + 260, shift: 22));

      controller.setBodyMotionLevel(BodyMotionLevel.easy);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 1);
    });

    test('audio + vibration mode is never affected (no camera)', () {
      controller.toggleBodyMotionGate(true);
      controller.sessionMode.value = DetectionMode.audioVibration;
      motionFrames(_stillFrame);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 1);
    });

    test('vision confirmation off: never affected', () {
      controller.toggleBodyMotionGate(true);
      controller.isVisionConfirmationRequired.value = false;
      motionFrames(_stillFrame);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 1);
    });

    test('the levels go from most sensitive to strictest', () {
      final List<double> scores = <BodyMotionLevel>[
        BodyMotionLevel.veryLight,
        BodyMotionLevel.light,
        BodyMotionLevel.easy,
        BodyMotionLevel.normal,
        BodyMotionLevel.strict,
      ].map(AppConstants.bodyMotionMinScore).toList();
      for (int i = 1; i < scores.length; i++) {
        expect(scores[i], greaterThan(scores[i - 1]));
      }
    });

    test('Light accepts a movement that Easy rejects', () {
      controller.toggleBodyMotionGate(true);
      // ~4.5 % movement: above Light (4 %), below Easy (5 %).
      motionFrames((int t, int i) => _punchFrame(t, i, t0 + 260, shift: 15));
      controller.setBodyMotionLevel(BodyMotionLevel.light);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 1);
    });

    test('a preset chip sets the score the gate uses', () {
      controller.setBodyMotionLevel(BodyMotionLevel.veryLight);
      expect(
        controller.bodyMotionMinScore.value,
        AppConstants.bodyMotionMinScoreVeryLight,
      );
      controller.setBodyMotionLevel(BodyMotionLevel.strict);
      expect(
        controller.bodyMotionMinScore.value,
        AppConstants.bodyMotionMinScoreStrict,
      );
    });

    test('slider: any value works, matching presets highlight, others are custom', () {
      controller.setBodyMotionMinScore(0.063);
      // Snapped to the 0.5 % step.
      expect(controller.bodyMotionMinScore.value, closeTo(0.065, 1e-9));
      expect(controller.bodyMotionLevel.value, BodyMotionLevel.custom);

      controller.setBodyMotionMinScore(0.04);
      expect(controller.bodyMotionLevel.value, BodyMotionLevel.light);

      // Clamped to the slider range.
      controller.setBodyMotionMinScore(0.5);
      expect(controller.bodyMotionMinScore.value, AppConstants.bodyMotionSliderMax);
      controller.setBodyMotionMinScore(0.0);
      expect(controller.bodyMotionMinScore.value, AppConstants.bodyMotionSliderMin);
    });

    test('a custom slider value is what the gate decides with', () {
      controller.toggleBodyMotionGate(true);
      // ~6.4 % movement (shift 22).
      motionFrames((int t, int i) => _punchFrame(t, i, t0 + 260, shift: 22));
      controller.setBodyMotionMinScore(0.07); // just above it
      bangAndBumpAt300();
      expect(controller.punchCount.value, 0);
    });

    test('a custom slider value just below the movement lets it count', () {
      controller.toggleBodyMotionGate(true);
      motionFrames((int t, int i) => _punchFrame(t, i, t0 + 260, shift: 22));
      controller.setBodyMotionMinScore(0.055);
      bangAndBumpAt300();
      expect(controller.punchCount.value, 1);
    });

    test('Defaults resets the slider value too', () {
      controller.setBodyMotionMinScore(0.15);
      controller.resetAllSettingsToDefault();
      expect(
        controller.bodyMotionMinScore.value,
        AppConstants.bodyMotionMinScoreNormal,
      );
    });

    test('Defaults resets the switch and the level', () {
      controller.toggleBodyMotionGate(true);
      controller.setBodyMotionLevel(BodyMotionLevel.strict);
      controller.resetAllSettingsToDefault();
      expect(
        controller.isBodyMotionGateEnabled.value,
        AppConstants.bodyMotionGateEnabledDefault,
      );
      expect(controller.bodyMotionLevel.value, BodyMotionLevel.normal);
    });
  });
}
