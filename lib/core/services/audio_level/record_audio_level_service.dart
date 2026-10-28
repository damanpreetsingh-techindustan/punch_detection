import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../../utils/constants.dart';
import 'audio_level_sample.dart';
import 'i_audio_level_service.dart';
import 'pcm_level_extractor.dart';

/// Active implementation of [IAudioLevelService] using the `record` package (`^7.1.1` & `^5.x`).
///
/// Two modes:
///  - Legacy (default): the plugin's per-chunk amplitude polled every
///    `sampleIntervalMs`. Used by the Prompt session and the pre-check screens.
///  - Sub-block PCM ([enableSubBlockPcm]): the raw PCM stream is split into
///    10 ms blocks with back-dated timestamps and published on [sampleStream].
///    Falls back to legacy automatically if the PCM stream cannot start.
class RecordAudioLevelService implements IAudioLevelService {
  RecordAudioLevelService({this.enableSubBlockPcm = false});

  /// Whether to use the sub-block PCM pipeline for [sampleStream].
  final bool enableSubBlockPcm;

  static RecordAudioLevelService? _activeGlobalService;

  /// Same rate the legacy Android configuration records at, so a comparison of
  /// the two modes only differs in chunking, not in sample rate.
  static final int _pcmSampleRate = Platform.isAndroid ? 16000 : 44100;

  AudioRecorder? _audioRecorder;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _pcmSubscription;
  final StreamController<double> _decibelStreamController =
      StreamController<double>.broadcast();
  final StreamController<AudioLevelSample> _sampleStreamController =
      StreamController<AudioLevelSample>.broadcast();

  double _currentDecibels = 0.0;
  bool _isMonitoring = false;

  /// Moving average sample buffer to smooth out instantaneous micro-jitters
  final List<double> _rollingSampleBuffer = [];

  bool _isEarbudsConnected = false;

  // Sub-block PCM state
  bool _pcmActive = false;
  PcmLevelExtractor? _extractor;
  Completer<void>? _firstChunk;
  int _chunkIndex = 0;
  int _lastChunkArrivalMs = 0;
  int _lastChunkBytes = 0;
  int _chunkIntervalCount = 0;
  double _chunkIntervalSum = 0.0;
  int _chunkIntervalMin = 1 << 30;
  int _chunkIntervalMax = 0;
  final Map<String, Object?> _startInfo = <String, Object?>{};

  @override
  Stream<double> get decibelStream => _decibelStreamController.stream;

  @override
  Stream<AudioLevelSample> get sampleStream => _sampleStreamController.stream;

  @override
  Map<String, Object?> get diagnostics => <String, Object?>{
    ..._startInfo,
    'pcmActive': _pcmActive,
    'chunks': _chunkIndex,
    'lastChunkBytes': _lastChunkBytes,
    'lastChunkMs': _lastChunkBytes == 0
        ? null
        : _lastChunkBytes / 2 * 1000 / _pcmSampleRate,
    'chunkIntervalMs': _chunkIntervalCount == 0
        ? null
        : <String, Object?>{
            'n': _chunkIntervalCount,
            'min': _chunkIntervalMin,
            'avg': (_chunkIntervalSum / _chunkIntervalCount).round(),
            'max': _chunkIntervalMax,
          },
  };

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
    // Dynamic linear SPL scaling: dBFS (-60.0 to 0.0) -> SPL dB (35.0 to 110.0).
    // Shared with the PCM path so both read on the identical scale.
    final double safeDb = PcmLevelExtractor.mapDbfsToDb(
      rawDbFS,
      maxDb: AppConstants.maxSystemAudioDb,
    );

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
    // Legacy mode: publish the same value on the timestamped stream, stamped
    // with the delivery time (there is no finer timing to offer).
    if (!_pcmActive && !_sampleStreamController.isClosed) {
      _sampleStreamController.add(
        AudioLevelSample(
          db: _currentDecibels,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          clipped: rawDbFS >= -0.5,
        ),
      );
    }
  }

  /// Handles one raw PCM chunk: splits it into blocks and publishes them with
  /// timestamps back-dated from the chunk arrival time.
  void _onPcmChunk(Uint8List bytes) {
    final int arrivalMs = DateTime.now().millisecondsSinceEpoch;
    final Completer<void>? first = _firstChunk;
    if (first != null && !first.isCompleted) first.complete();

    final PcmLevelExtractor? extractor = _extractor;
    if (extractor == null) return;

    if (_lastChunkArrivalMs > 0) {
      final int gap = arrivalMs - _lastChunkArrivalMs;
      _chunkIntervalCount++;
      _chunkIntervalSum += gap;
      _chunkIntervalMin = min(_chunkIntervalMin, gap);
      _chunkIntervalMax = max(_chunkIntervalMax, gap);
    }
    _lastChunkArrivalMs = arrivalMs;
    _lastChunkBytes = bytes.length;
    _chunkIndex++;

    for (final PcmLevelBlock block in extractor.extract(bytes)) {
      final int timestampMs =
          arrivalMs -
          (block.samplesAfterBlockEnd * 1000 / _pcmSampleRate).round();
      _currentDecibels = block.db;
      if (!_sampleStreamController.isClosed) {
        _sampleStreamController.add(
          AudioLevelSample(
            db: block.db,
            timestampMs: timestampMs,
            clipped: block.clipped,
            chunkIndex: _chunkIndex,
          ),
        );
      }
    }
  }

  void _attachAmplitudePolling(int intervalMs) {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioRecorder!
        .onAmplitudeChanged(Duration(milliseconds: intervalMs))
        .listen(
          _onRawAmplitudeReceived,
          onError: (Object error) {
            if (!_decibelStreamController.isClosed) {
              _decibelStreamController.addError(error);
            }
          },
        );
  }

  /// Buffer size in bytes whose chunk lasts [chunkMs] (`null` = plugin default).
  /// The plugin reads `bufferSize / 2` samples per chunk.
  static int _bufferBytesForChunkMs(int chunkMs) =>
      (chunkMs * _pcmSampleRate / 1000).round() * 2;

  /// Tries the PCM stream with each candidate chunk length (smallest first) and
  /// keeps the first that starts and delivers data. Returns false if none do.
  Future<bool> _startSubBlockPcm(InputDevice? device, int blockMs) async {
    final List<Map<String, Object?>> attempts = <Map<String, Object?>>[];
    final List<int?> candidatesMs = <int?>[
      ...AppConstants.audioStreamChunkCandidatesMs,
      null,
    ];
    for (final int? chunkMs in candidatesMs) {
      final int? bufferBytes = chunkMs == null
          ? null
          : _bufferBytesForChunkMs(chunkMs);
      try {
        final RecordConfig config = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _pcmSampleRate,
          numChannels: 1,
          device: device,
          echoCancel: !AppConstants.audioExperimentDisableMicProcessing,
          autoGain:
              false, // Disables Automatic Gain Control so quiet background noise isn't boosted
          noiseSuppress: !AppConstants.audioExperimentDisableMicProcessing,
          androidConfig: AndroidRecordConfig(
            audioSource: AppConstants.audioExperimentUnprocessedSource
                ? AndroidAudioSource.unprocessed
                : AndroidAudioSource.defaultSource,
          ),
          streamBufferSize: bufferBytes,
        );
        _extractor = PcmLevelExtractor(
          sampleRate: _pcmSampleRate,
          channels: 1,
          blockMs: blockMs,
        );
        _chunkIndex = 0;
        _lastChunkArrivalMs = 0;
        _lastChunkBytes = 0;
        _chunkIntervalCount = 0;
        _chunkIntervalSum = 0.0;
        _chunkIntervalMin = 1 << 30;
        _chunkIntervalMax = 0;
        _firstChunk = Completer<void>();

        final Stream<Uint8List> pcmStream = await _audioRecorder!.startStream(
          config,
        );
        _pcmSubscription = pcmStream.listen(
          _onPcmChunk,
          onError: (Object error) {
            if (!_decibelStreamController.isClosed) {
              _decibelStreamController.addError(error);
            }
          },
        );
        // No data within 1.5 s counts as a failed start.
        await _firstChunk!.future.timeout(const Duration(milliseconds: 1500));

        _pcmActive = true;
        attempts.add(<String, Object?>{
          'requestedChunkMs': chunkMs,
          'bufferBytes': bufferBytes,
          'ok': true,
        });
        _startInfo
          ..['mode'] = 'pcm_subblock'
          ..['requestedChunkMs'] = chunkMs
          ..['bufferBytes'] = bufferBytes
          ..['sampleRate'] = _pcmSampleRate
          ..['blockMs'] = blockMs
          ..['attempts'] = attempts;
        return true;
      } catch (e) {
        attempts.add(<String, Object?>{
          'requestedChunkMs': chunkMs,
          'bufferBytes': bufferBytes,
          'ok': false,
          'error': e.toString(),
        });
        try {
          await _pcmSubscription?.cancel();
        } catch (_) {}
        _pcmSubscription = null;
        try {
          await _audioRecorder?.stop();
        } catch (_) {}
      }
    }
    _extractor = null;
    _startInfo
      ..['mode'] = 'legacy_amplitude'
      ..['fallback'] = 'pcm_subblock failed'
      ..['attempts'] = attempts;
    return false;
  }

  /// Starts the plugin's PCM stream the way the app always has, so the native
  /// microphone sampler runs and `getAmplitude` has data.
  Future<void> _startLegacyStream(InputDevice? builtInMicDevice) async {
    RecordConfig recordConfig = RecordConfig(
      device: builtInMicDevice,
      echoCancel: true,

      autoGain:
          false, // Disables Automatic Gain Control so quiet background noise isn't boosted
      noiseSuppress: true, // Enables hardware background noise suppression
    );

    if (Platform.isAndroid) {
      recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        device: builtInMicDevice,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: false,
      );
    }

    // 2. Start streaming recording session to activate native microphone sampler
    final Stream<Uint8List> pcmStream = await _audioRecorder!.startStream(
      recordConfig,
    );

    // Subscribing to pcmStream keeps the native audio pipe flowing
    _pcmSubscription = pcmStream.listen((_) {});
    _startInfo.putIfAbsent('mode', () => 'legacy_amplitude');
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
      _pcmActive = false;
      _startInfo.clear();

      // 1. Listen to native amplitude events (emitted in dBFS from -80 to 0).
      // In sub-block PCM mode this is only attached if the PCM start fails.
      if (!enableSubBlockPcm) {
        _attachAmplitudePolling(effectiveInterval);
      }

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

      bool pcmStarted = false;
      if (enableSubBlockPcm) {
        pcmStarted = await _startSubBlockPcm(
          builtInMicDevice,
          effectiveInterval,
        );
        if (!pcmStarted) {
          // Fresh recorder, then the legacy pipeline exactly as before.
          try {
            await _audioRecorder?.dispose();
          } catch (_) {}
          _audioRecorder = AudioRecorder();
          _attachAmplitudePolling(effectiveInterval);
        }
      }
      if (!pcmStarted) {
        await _startLegacyStream(builtInMicDevice);
      }

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
    if (_pcmActive) {
      // Only the block length changes; the PCM stream keeps running.
      _extractor = PcmLevelExtractor(
        sampleRate: _pcmSampleRate,
        channels: 1,
        blockMs: newIntervalMs,
      );
      _startInfo['blockMs'] = newIntervalMs;
      return;
    }
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
    _pcmActive = false;
    _extractor = null;
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
    _sampleStreamController.close();
  }
}
