import 'package:get/get.dart';
import '../../features/history/data/datasources/local_history_datasource.dart';
import '../../features/history/data/repositories/history_repository_impl.dart';
import '../../features/history/domain/repositories/history_repository.dart';
import '../services/config_service.dart';
import '../services/usage_service.dart';
import '../services/monotonic_clock_service.dart';
import '../services/logger_service.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<LoggerService>(LoggerService(), permanent: true);
    Get.put<MonotonicClockService>(MonotonicClockService(), permanent: true);
    Get.put<ConfigService>(ConfigService(), permanent: true);
    // Free daily punch limit, counted live in sessions.
    Get.put<UsageService>(UsageService(), permanent: true);
    // Saved sessions: written by Results, read by Home and History.
    Get.put<HistoryRepository>(
      HistoryRepositoryImpl(localDatasource: LocalHistoryDatasource()),
      permanent: true,
    );
  }
}
