import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/monotonic_clock_service.dart';
import '../../data/datasources/native_audio_stream_datasource.dart';
import '../../data/repositories/audio_analyzer_repository_impl.dart';
import '../../domain/repositories/audio_analyzer_repository.dart';
import '../../domain/usecases/analyze_audio_frame.dart';
import '../controllers/audio_detection_controller.dart';

class AudioDetectionBinding extends Bindings {
  @override
  void dependencies() {
    final clockService = Get.find<MonotonicClockService>();
    final configService = Get.find<ConfigService>();

    final nativeDatasource = NativeAudioStreamDatasource(clockService: clockService);
    final repository = AudioAnalyzerRepositoryImpl(nativeDatasource: nativeDatasource);
    Get.lazyPut<AudioAnalyzerRepository>(() => repository);

    final analyzeUseCase = AnalyzeAudioFrame(repository);
    Get.lazyPut<AnalyzeAudioFrame>(() => analyzeUseCase);

    Get.lazyPut<AudioDetectionController>(
      () => AudioDetectionController(
        analyzeAudioFrameUseCase: analyzeUseCase,
        configService: configService,
      ),
    );
  }
}
