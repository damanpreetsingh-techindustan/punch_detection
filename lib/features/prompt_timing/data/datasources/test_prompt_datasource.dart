import '../../../../core/services/monotonic_clock_service.dart';
import '../../domain/entities/prompt_combo.dart';
import '../../domain/entities/prompt_config.dart';
import 'tts_prompt_datasource.dart';

class TestPromptDatasource implements ITTSPromptDatasource {
  final MonotonicClockService clockService;

  TestPromptDatasource({required this.clockService});

  @override
  Future<PromptCombo> speak(String id, String text, PromptConfig config) async {
    final int startUs = clockService.nowUs();
    return PromptCombo(
      id: id,
      calloutText: text,
      audioStartTimestampUs: startUs,
    );
  }

  @override
  Future<void> stop() async {}
}
