import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:record/record.dart';
import '../../utils/constants.dart';
import 'i_audio_level_service.dart';

/// Active implementation of [IAudioLevelService] using the `record` package (`^7.1.1` & `^5.x`).
class RecordAudioLevelService implements IAudioLevelService {
  static RecordAudioLevelService? _activeGlobalService;

  AudioRecorder? _audioRecorder;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _pcmSubscription;
  final StreamController<double> _decibelStreamController =
      StreamController<double>.broadcast();

  double _currentDecibels = 0.0;
  bool _isMonitoring = false;

  /// Moving average sample buffer to smooth out instantaneous micro-jitters
  final List<double> _rollingSampleBuffer = [];

  bool _isEarbudsConnected = false;

  @override
  Stream<double> get decibelStream => _decibelStreamController.stream;

  @override
  double get currentDecibels => _currentDecibels;

  @override
  bool get isMonitoring => _isMonitoring;

  @override
  bool get isEarbudsConnected => _isEarbudsConnected;

  @override
  Future<bool> checkEarbudsConnected() async {
    if (_audioRecorder == null) return _isEarbudsConnected;
    try {
      final List<InputDevice> devices = await _audioRecorder!
          .listInputDevices();
      bool found = false;
      for (final dev in devices) {
        final label = dev.label.toLowerCase();
        final id = dev.id.toLowerCase();
        if (label.contains('bluetooth') ||
            label.contains('headset') ||
            label.contains('headphone') ||
            label.contains('earbud') ||
            label.contains('airpod') ||
            label.contains('buds') ||
            id.contains('bluetooth')) {
          found = true;
          break;
        }
      }
      _isEarbudsConnected = found;
    } catch (_) {}
    return _isEarbudsConnected;
  }

  /// Unified amplitude processing with rolling average smoothing
  void _onRawAmplitudeReceived(Amplitude amplitude) {
    final double rawDbFS = amplitude.current;
    if (rawDbFS >= -0.5) {
      developer.log(
        '=-=-=-=-= HARDWARE MAX LIMIT REACHED! Mic is at 100% Saturation (0.0 dBFS)',
        name: 'RecordAudioLevelService',
      );
    } else {
      developer.log(
        '=-=-=-=-= Mic Level: ${rawDbFS.toStringAsFixed(1)} dBFS',
        name: 'RecordAudioLevelService',
      );
    }
    if (rawDbFS.isNaN || !rawDbFS.isFinite) return;

    // ---------------------------------------------------------------------
    // BACKUP: NATURAL FULL-SCALE DYNAMIC MAPPING (-80 dBFS to 0 dBFS):
    // final double safeDb = (rawDbFS.clamp(-80.0, 0.0) + 95.0).clamp(
    //   30.0,
    //   AppConstants.maxSystemAudioDb,
    // );
    // ---------------------------------------------------------------------

    // RESTORED PREVIOUS FORMULA:
    // Dynamic linear SPL scaling: dBFS (-60.0 to 0.0) -> SPL dB (35.0 to 110.0)
    final double safeDb = ((rawDbFS.clamp(-60.0, 0.0) + 60.0) * 1.25 + 35.0)
        .clamp(30.0, AppConstants.maxSystemAudioDb);

    // ROLLING MOVING AVERAGE BUFFER (Controlled by AppConstants.useAvarageAudioFormate):
    // When enabled: Averages consecutive frames to eliminate micro-noises.
    // When disabled: Passes instantaneous raw safeDb directly.
    if (AppConstants.useAvarageAudioFormate) {
      _rollingSampleBuffer.add(safeDb);
      final int maxWindow = AppConstants.audioRollingAverageFrames > 0
          ? AppConstants.audioRollingAverageFrames
          : 3;
      if (_rollingSampleBuffer.length > maxWindow) {
        _rollingSampleBuffer.removeAt(0);
      }

      final double smoothedDb =
          _rollingSampleBuffer.reduce((a, b) => a + b) /
          _rollingSampleBuffer.length;

      _currentDecibels = smoothedDb;
    } else {
      _rollingSampleBuffer.clear();
      _currentDecibels = safeDb;
    }
    if (!_decibelStreamController.isClosed) {
      _decibelStreamController.add(_currentDecibels);
    }
  }

  @override
  Future<bool> startMonitoring({int? sampleIntervalMs}) async {
    if (_isMonitoring) return true;

    final int effectiveInterval =
        sampleIntervalMs ?? AppConstants.globalAudioSampleIntervalMs;

    try {
      if (_activeGlobalService != null && _activeGlobalService != this) {
        await _activeGlobalService!.stopMonitoring();
        await Future.delayed(const Duration(milliseconds: 80));
      }
      _activeGlobalService = this;

      await stopMonitoring();

      _audioRecorder = AudioRecorder();
      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        if (!_decibelStreamController.isClosed) {
          _decibelStreamController.addError('Microphone permission denied');
        }
        return false;
      }

      _rollingSampleBuffer.clear();

      // 1. Listen to native amplitude events (emitted in dBFS from -80 to 0)
      _amplitudeSubscription = _audioRecorder!
          .onAmplitudeChanged(Duration(milliseconds: effectiveInterval))
          .listen(
            _onRawAmplitudeReceived,
            onError: (Object error) {
              if (!_decibelStreamController.isClosed) {
                _decibelStreamController.addError(error);
              }
            },
          );

      // Query available input devices to lock onto built-in phone mic (bypassing earbud mic)
      InputDevice? builtInMicDevice;
      bool earbudsDetected = false;
      try {
        final List<InputDevice> devices = await _audioRecorder!
            .listInputDevices();
        for (final dev in devices) {
          final label = dev.label.toLowerCase();
          final id = dev.id.toLowerCase();
          if (label.contains('bluetooth') ||
              label.contains('headset') ||
              label.contains('headphone') ||
              label.contains('earbud') ||
              label.contains('airpod') ||
              label.contains('buds') ||
              id.contains('bluetooth')) {
            earbudsDetected = true;
          }
          if (builtInMicDevice == null &&
              (label.contains('built-in') ||
                  label.contains('builtin') ||
                  label.contains('phone') ||
                  label.contains('bottom') ||
                  (label.contains('mic') &&
                      !label.contains('bluetooth') &&
                      !label.contains('headset') &&
                      !label.contains('earbud') &&
                      !id.contains('bluetooth')))) {
            builtInMicDevice = dev;
            developer.log(
              'Selected Built-In Phone Mic: ${dev.label} (${dev.id})',
              name: 'RecordAudioLevelService',
            );
          }
        }
      } catch (e) {
        developer.log(
          'Error listing input devices: $e',
          name: 'RecordAudioLevelService',
        );
      }
      _isEarbudsConnected = earbudsDetected;

      final RecordConfig recordConfig = RecordConfig(
        device: builtInMicDevice,
        echoCancel: true,
        autoGain:
            false, // Disables Automatic Gain Control so quiet background noise isn't boosted
        noiseSuppress: true, // Enables hardware background noise suppression
      );

      // 2. Start streaming recording session to activate native microphone sampler
      final Stream<Uint8List> pcmStream = await _audioRecorder!.startStream(
        recordConfig,
      );

      // Subscribing to pcmStream keeps the native audio pipe flowing
      _pcmSubscription = pcmStream.listen((_) {});

      _isMonitoring = true;
      return true;
    } catch (e) {
      if (!_decibelStreamController.isClosed) {
        _decibelStreamController.addError(e);
      }
      return false;
    }
  }

  @override
  Future<void> updateSampleInterval(int newIntervalMs) async {
    if (!_isMonitoring || _audioRecorder == null) return;
    try {
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _audioRecorder!
          .onAmplitudeChanged(Duration(milliseconds: newIntervalMs))
          .listen(
            _onRawAmplitudeReceived,
            onError: (Object error) {
              if (!_decibelStreamController.isClosed) {
                _decibelStreamController.addError(error);
              }
            },
          );
    } catch (_) {}
  }

  @override
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _rollingSampleBuffer.clear();
    if (_activeGlobalService == this) {
      _activeGlobalService = null;
    }

    try {
      await _amplitudeSubscription?.cancel();
    } catch (_) {}
    _amplitudeSubscription = null;

    try {
      await _pcmSubscription?.cancel();
    } catch (_) {}
    _pcmSubscription = null;

    try {
      if (_audioRecorder != null) {
        final isRecording = await _audioRecorder!.isRecording();
        if (isRecording) {
          await _audioRecorder!.stop();
        }
        await _audioRecorder!.dispose();
      }
    } catch (_) {}
    _audioRecorder = null;
  }

  @override
  void dispose() {
    stopMonitoring();
    _decibelStreamController.close();
  }
}
