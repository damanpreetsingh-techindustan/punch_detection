import 'package:flutter_tts/flutter_tts.dart';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../domain/entities/prompt_combo.dart';
import '../../domain/entities/prompt_config.dart';

abstract class ITTSPromptDatasource {
  Future<PromptCombo> speak(String id, String text, PromptConfig config);
  Future<void> stop();
}

class TTSPromptDatasource implements ITTSPromptDatasource {
  final FlutterTts flutterTts;
  final MonotonicClockService clockService;

  TTSPromptDatasource({
    FlutterTts? tts,
    required this.clockService,
  }) : flutterTts = tts ?? FlutterTts();

  @override
  Future<PromptCombo> speak(String id, String text, PromptConfig config) async {
    await flutterTts.setSpeechRate(config.speechRate);
    await flutterTts.setPitch(config.pitch);
    await flutterTts.setLanguage('en-US');
    await flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );

    final int startUs = clockService.nowUs();
    await flutterTts.speak(text);

    return PromptCombo(
      id: id,
      calloutText: text,
      audioStartTimestampUs: startUs,
    );
  }

  @override
  Future<void> stop() async {
    await flutterTts.stop();
  }
}
