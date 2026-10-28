import 'dart:async';
// import 'package:noise_meter/noise_meter.dart';
import 'audio_level_sample.dart';
import 'i_audio_level_service.dart';

/// Commented out implementation of [IAudioLevelService] using `noise_meter`.
/// Replaced by active [RecordAudioLevelService] using `record`.
class NoiseMeterAudioLevelService implements IAudioLevelService {
  // static NoiseMeterAudioLevelService? _activeGlobalService;
  // NoiseMeter? _noiseMeter;
  // StreamSubscription<NoiseReading>? _noiseSubscription;
  final StreamController<double> _decibelStreamController =
      StreamController<double>.broadcast();

  final double _currentDecibels = 0.0;
  final bool _isMonitoring = false;

  @override
  Stream<double> get decibelStream => _decibelStreamController.stream;

  @override
  Stream<AudioLevelSample> get sampleStream => _decibelStreamController.stream
      .map(
        (double db) => AudioLevelSample(
          db: db,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  @override
  Map<String, Object?> get diagnostics => const <String, Object?>{};

  @override
  double get currentDecibels => _currentDecibels;

  @override
  bool get isEarbudsConnected => false;

  @override
  Future<bool> checkEarbudsConnected() async => false;

  @override
  bool get isMonitoring => _isMonitoring;

  @override
  Future<bool> startMonitoring({int sampleIntervalMs = 50}) async {
    return false;
  }

  @override
  Future<void> stopMonitoring() async {}

  @override
  Future<void> updateSampleInterval(int newIntervalMs) async {}

  @override
  void dispose() {
    stopMonitoring();
    _decibelStreamController.close();
  }
}
