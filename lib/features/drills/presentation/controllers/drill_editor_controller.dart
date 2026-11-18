import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/drill_service.dart';
import '../../domain/drill_program.dart';

/// Build your own drill: tap the bag to write a combo, add as many combos as
/// you like, pick the pace and rounds. Saved in the same format as the
/// built-in drills, so the session runs it the same way.
class DrillEditorController extends GetxController {
  static const int maxComboLength = 8;
  static const List<int> paceOptionsMs = [1500, 1200, 900, 600, 400, 300];

  /// The drill being edited (null = new).
  final DrillProgram? original = Get.arguments is DrillProgram
      ? Get.arguments as DrillProgram
      : null;

  late final TextEditingController name = TextEditingController(
    text: original?.title ?? '',
  );
  late final RxList<List<int>> combos = <List<int>>[...?original?.combos].obs;
  final RxList<int> current = <int>[].obs;
  late final RxInt intervalMs = (original?.callIntervalMs ?? 900).obs;
  late final Rx<RoundPlan> roundPlan =
      (original?.roundPlan ??
              const RoundPlan(rounds: 3, roundSeconds: 120, restSeconds: 45))
          .obs;
  final RxString error = ''.obs;

  bool get isEditing => original != null;

  void tapTarget(int n) {
    if (current.length >= maxComboLength) return;
    current.add(n);
    error.value = '';
  }

  void undo() {
    if (current.isNotEmpty) current.removeLast();
  }

  void addCombo() {
    if (current.isEmpty) return;
    combos.add(List<int>.from(current));
    current.clear();
  }

  void removeCombo(int index) => combos.removeAt(index);

  Future<void> save() async {
    // A combo still being written counts too.
    if (current.isNotEmpty) addCombo();
    final title = name.text.trim();
    if (title.isEmpty) {
      error.value = 'Give your drill a name.';
      return;
    }
    if (combos.isEmpty) {
      error.value = 'Add at least one combo: tap the numbers on the bag.';
      return;
    }
    final program = DrillProgram(
      id: original?.id ?? DrillService.newCustomId(),
      title: title,
      subtitle: '${combos.length} combo${combos.length == 1 ? '' : 's'}',
      category: 'custom',
      level: intervalMs.value <= 400
          ? 'advanced'
          : intervalMs.value <= 700
          ? 'intermediate'
          : 'beginner',
      combos: List<List<int>>.from(combos),
      callIntervalMs: intervalMs.value,
      roundPlan: roundPlan.value,
    );
    await DrillService.to.saveCustom(program);
    Get.back();
  }

  @override
  void onClose() {
    name.dispose();
    super.onClose();
  }
}
