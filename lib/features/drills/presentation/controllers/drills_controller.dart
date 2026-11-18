import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/usage_service.dart';
import '../../data/drill_service.dart';
import '../../domain/drill_program.dart';

class DrillsController extends GetxController {
  final DrillService service = DrillService.to;
  final RxBool loading = true.obs;

  RxBool get southpaw => StorageService.to.southpaw;

  List<DrillProgram> get basics =>
      service.builtIn.where((p) => p.category == 'basic').toList();
  List<DrillProgram> get styles =>
      service.builtIn.where((p) => p.category != 'basic').toList();

  @override
  void onInit() {
    super.onInit();
    service.ensureLoaded().whenComplete(() => loading.value = false);
  }

  void toggleSouthpaw() =>
      StorageService.to.setSouthpaw(!StorageService.to.southpaw.value);

  bool isLocked(DrillProgram p) => service.isLocked(p);

  /// Start [program] with the rounds chosen on its detail sheet.
  void start(DrillProgram program, RoundPlan plan) {
    if (Get.isBottomSheetOpen ?? false) Get.back();
    if (service.isLocked(program)) {
      AppNavigator.toPaywall();
      return;
    }
    if (UsageService.to.limitReached) {
      AppNavigator.toPaywall(fromLimit: true);
      return;
    }
    service.select(program.copyWith(roundPlan: plan));
    AppNavigator.toGetReady(sessionType: 'prompt', difficulty: program.title);
  }

  void createDrill() {
    if (!service.canCreateCustom) {
      AppNavigator.toPaywall();
      return;
    }
    AppNavigator.toDrillEditor();
  }

  void editDrill(DrillProgram program) {
    if (Get.isBottomSheetOpen ?? false) Get.back();
    AppNavigator.toDrillEditor(program: program);
  }

  Future<void> deleteDrill(BuildContext context, DrillProgram program) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${program.title}"?'),
        content: const Text('This drill will be removed from your phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (Get.isBottomSheetOpen ?? false) Get.back();
    await service.deleteCustom(program.id);
  }
}
