import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/audio_level/audio_level_sample.dart';
import 'package:punch_detection_demo/core/services/audio_level/i_audio_level_service.dart';
import 'package:punch_detection_demo/features/session_precheck/presentation/controllers/session_precheck_controller.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/free_session_controller.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/prompt_session_controller.dart';

/// Mock implementation of [IAudioLevelService] for isolated unit testing
class MockAudioLevelService implements IAudioLevelService {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();
  double _mockDb = 45.0;
  bool _monitoring = false;

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
  double get currentDecibels => _mockDb;

  @override
  bool get isMonitoring => _monitoring;

  @override
  bool get isEarbudsConnected => false;

  @override
  Future<bool> checkEarbudsConnected() async => false;

  @override
  Future<bool> startMonitoring({int sampleIntervalMs = 50}) async {
    _monitoring = true;
    return true;
  }

  @override
  Future<void> stopMonitoring() async {
    _monitoring = false;
  }

  @override
  Future<void> updateSampleInterval(int sampleIntervalMs) async {}

  @override
  void dispose() {
    _monitoring = false;
    _controller.close();
  }

  void emitDecibels(double db) {
    _mockDb = db;
    if (!_controller.isClosed) {
      _controller.add(db);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IAudioLevelService & Dependency Inversion Unit Tests', () {
    late MockAudioLevelService mockAudioService;

    setUp(() {
      mockAudioService = MockAudioLevelService();
    });

    tearDown(() {
      mockAudioService.dispose();
    });

    test('MockAudioLevelService emits real-time decibel events to listeners',
        () async {
      final List<double> receivedDb = [];
      final sub = mockAudioService.decibelStream.listen((db) {
        receivedDb.add(db);
      });

      await mockAudioService.startMonitoring();
      expect(mockAudioService.isMonitoring, isTrue);

      mockAudioService.emitDecibels(55.0);
      mockAudioService.emitDecibels(78.5);
      mockAudioService.emitDecibels(92.0);

      await Future.delayed(const Duration(milliseconds: 20));

      expect(receivedDb, [55.0, 78.5, 92.0]);
      expect(mockAudioService.currentDecibels, 92.0);

      await sub.cancel();
    });

    test(
        'SessionPreCheckController seamlessly receives audio levels via injected IAudioLevelService',
        () async {
      final controller = SessionPreCheckController(
        sessionType: 'free',
        audioLevelService: mockAudioService,
      );

      // Verify dependency inversion
      expect(controller, isNotNull);
      expect(controller.decibels.value, 0);

      await mockAudioService.startMonitoring();
      mockAudioService.emitDecibels(68.0);

      expect(mockAudioService.currentDecibels, 68.0);
      controller.onClose();
    });

    test(
        'FreeSessionController seamlessly receives audio levels via injected IAudioLevelService',
        () async {
      final controller = FreeSessionController(
        audioLevelService: mockAudioService,
      );

      expect(controller, isNotNull);
      expect(controller.liveDecibelLevel.value, 0.0);

      await mockAudioService.startMonitoring();
      mockAudioService.emitDecibels(88.0);

      expect(mockAudioService.currentDecibels, 88.0);
      controller.onClose();
    });

    test(
        'PromptSessionController seamlessly receives audio levels via injected IAudioLevelService',
        () async {
      final controller = PromptSessionController(
        audioLevelService: mockAudioService,
      );

      expect(controller, isNotNull);
      expect(controller.liveDecibelLevel.value, 0.0);

      await mockAudioService.startMonitoring();
      mockAudioService.emitDecibels(75.0);

      expect(mockAudioService.currentDecibels, 75.0);
      controller.onClose();
    });
  });
}
