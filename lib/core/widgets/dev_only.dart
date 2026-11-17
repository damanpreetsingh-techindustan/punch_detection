import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';

/// Shows [child] only while Developer mode is on (Settings → tap the version
/// 7 times). Engineering controls and telemetry go behind this.
class DevOnly extends StatelessWidget {
  final Widget child;

  const DevOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => StorageService.to.developerMode.value
          ? child
          : const SizedBox.shrink(),
    );
  }
}
