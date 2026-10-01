import 'package:get/get.dart';
import '../../features/diagnostics/presentation/bindings/diagnostics_binding.dart';
import '../../features/diagnostics/presentation/pages/diagnostics_page.dart';
import '../../features/history/presentation/bindings/history_binding.dart';
import '../../features/history/presentation/pages/history_detail_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/home/presentation/bindings/home_binding.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/mode_selection/presentation/bindings/mode_selection_binding.dart';
import '../../features/mode_selection/presentation/pages/mode_selection_page.dart';
import '../../features/mount_guide/presentation/bindings/mount_guide_binding.dart';
import '../../features/mount_guide/presentation/pages/mount_guide_page.dart';
import '../../features/onboarding/presentation/bindings/onboarding_binding.dart';
import '../../features/onboarding/presentation/pages/onboarding_flow_page.dart';
import '../../features/results/presentation/bindings/results_binding.dart';
import '../../features/results/presentation/pages/results_page.dart';
import '../../features/session/presentation/bindings/free_session_binding.dart';
import '../../features/session/presentation/bindings/prompt_session_binding.dart';
import '../../features/session/presentation/pages/free_session_page.dart';
import '../../features/session/presentation/pages/prompt_session_page.dart';
import '../../features/session_precheck/presentation/bindings/session_precheck_binding.dart';
import '../../features/session_precheck/presentation/pages/session_precheck_page.dart';
import '../../features/settings/presentation/bindings/settings_binding.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/splash/presentation/bindings/splash_binding.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/workout_setup/presentation/bindings/workout_setup_binding.dart';
import '../../features/workout_setup/presentation/pages/workout_setup_page.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingFlowPage(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.permissions,
      page: () => const OnboardingFlowPage(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.mountGuide,
      page: () => const MountGuidePage(),
      binding: MountGuideBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.modeSelection,
      page: () => const ModeSelectionPage(),
      binding: ModeSelectionBinding(),
    ),
    GetPage(
      name: AppRoutes.workoutSetup,
      page: () => const WorkoutSetupPage(),
      binding: WorkoutSetupBinding(),
    ),
    GetPage(
      name: AppRoutes.sessionPreCheck,
      page: () => const SessionPreCheckPage(),
      binding: SessionPreCheckBinding(),
    ),
    GetPage(
      name: AppRoutes.calibration,
      page: () => const SessionPreCheckPage(),
      binding: SessionPreCheckBinding(),
    ),
    GetPage(
      name: AppRoutes.promptSession,
      page: () => const PromptSessionPage(),
      binding: PromptSessionBinding(),
    ),
    GetPage(
      name: AppRoutes.freeSession,
      page: () => const FreeSessionPage(),
      binding: FreeSessionBinding(),
    ),
    GetPage(
      name: AppRoutes.results,
      page: () => const ResultsPage(),
      binding: ResultsBinding(),
    ),
    GetPage(
      name: AppRoutes.history,
      page: () => const HistoryPage(),
      binding: HistoryBinding(),
    ),
    GetPage(
      name: AppRoutes.historyDetail,
      page: () => const HistoryDetailPage(),
      binding: HistoryBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsPage(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.diagnostics,
      page: () => const DiagnosticsPage(),
      binding: DiagnosticsBinding(),
    ),
  ];
}
