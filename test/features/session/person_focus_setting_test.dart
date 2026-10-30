import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/person_focus/i_person_focus_strategy.dart';

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

/// Records calls and returns a different image so the test can tell which
/// image the pose detector would get.
class _SpyPersonFocus implements IPersonFocusStrategy {
  int prepareCalls = 0;
  int resetCalls = 0;
  bool closed = false;
  final InputImage focused = frame();

  @override
  Future<PersonFocusResult> prepare(InputImage original) async {
    prepareCalls++;
    return PersonFocusResult(
      image: focused,
      masked: true,
      facesSeen: 2,
      switched: true,
    );
  }

  @override
  void reset() => resetCalls++;

  @override
  Future<void> close() async => closed = true;
}

InputImage frame() => InputImage.fromBytes(
  bytes: Uint8List(24),
  metadata: InputImageMetadata(
    size: const Size(4, 4),
    rotation: InputImageRotation.rotation0deg,
    format: InputImageFormat.nv21,
    bytesPerRow: 4,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FreeSessionController controller;
  late _SpyPersonFocus spy;

  setUp(() {
    AppConstants.changeSettingToDefault();
    spy = _SpyPersonFocus();
    controller = FreeSessionController(
      audioLevelService: _MockAudioLevelService(),
      personFocus: spy,
    );
  });

  tearDown(() => controller.onClose());

  test('switch is ON by default', () {
    expect(AppConstants.personFocusEnabledDefault, isTrue);
    expect(controller.isPersonFocusEnabled.value, isTrue);
  });

  test('ON: the pose detector gets the focused image', () async {
    final InputImage original = frame();
    final InputImage poseInput = await controller.preparePoseInputForTesting(
      original,
    );
    expect(identical(poseInput, spy.focused), isTrue);
    expect(spy.prepareCalls, 1);
    expect(controller.recorder.totals.counter('focus.masked_frames'), 1);
    expect(controller.recorder.totals.counter('focus.switches'), 1);
    expect(controller.summaryTable.toCsv(), contains('FOCUS_SWITCHED'));
  });

  test(
    'OFF: the pose detector gets the original frame, no face check',
    () async {
      controller.togglePersonFocus(false);
      final InputImage original = frame();
      final InputImage poseInput = await controller.preparePoseInputForTesting(
        original,
      );
      expect(identical(poseInput, original), isTrue);
      expect(spy.prepareCalls, 0);
    },
  );

  test('toggling updates the shared setting and drops the held person', () {
    controller.togglePersonFocus(false);
    expect(AppConstants.personFocusEnabled, isFalse);
    expect(spy.resetCalls, 1);
    controller.togglePersonFocus(true);
    expect(AppConstants.personFocusEnabled, isTrue);
    expect(spy.resetCalls, 2);
  });

  test('Reset to defaults turns it back ON', () {
    controller.togglePersonFocus(false);
    controller.resetAllSettingsToDefault();
    expect(controller.isPersonFocusEnabled.value, isTrue);
    expect(AppConstants.personFocusEnabled, isTrue);
  });

  test('a new session starts with the default', () {
    AppConstants.personFocusEnabled = false;
    AppConstants.changeSettingToDefault();
    expect(AppConstants.personFocusEnabled, isTrue);
  });

  test('closing the session closes the focus strategy', () async {
    controller.onClose();
    await Future<void>.delayed(Duration.zero);
    expect(spy.closed, isTrue);
  });
}
