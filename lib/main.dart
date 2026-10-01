import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'core/di/initial_bindings.dart';
import 'core/navigation/app_pages.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error filter to suppress camera_android_camerax plugin teardown race condition exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    final String exceptionStr = details.exception.toString();
    final String stackStr = details.stack?.toString() ?? '';

    if (exceptionStr.contains('Null check operator used on a null value') &&
        (stackStr.contains('camera_android_camerax') ||
            stackStr.contains('Analyzer.pigeon_setUpMessageHandlers'))) {
      return;
    }

    FlutterError.presentError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
        final String errStr = error.toString();
        final String stackStr = stack.toString();

        if (errStr.contains('Null check operator used on a null value') &&
            (stackStr.contains('camera_android_camerax') ||
                stackStr.contains('Analyzer.pigeon_setUpMessageHandlers'))) {
          return true; // Error handled and suppressed
        }

        return false;
      };

  // Configure preferred orientations to allow both portrait and landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const HyperHitterApp());
}

class HyperHitterApp extends StatelessWidget {
  const HyperHitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(
        AppConstants.designWidth,
        AppConstants.designHeight,
      ),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          initialBinding: InitialBindings(),
          getPages: AppPages.pages,
          initialRoute: AppRoutes.splash,
        );
      },
    );
  }
}
