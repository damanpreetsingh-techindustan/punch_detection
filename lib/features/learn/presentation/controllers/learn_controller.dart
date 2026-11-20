import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../data/learn_service.dart';
import '../../domain/lesson.dart';
import '../widgets/safety_sheet.dart';

class LearnController extends GetxController {
  final LearnService service = LearnService.to;
  final RxBool loading = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Usually loaded already (Home starts it): no spinner flash.
    if (service.course.value != null) {
      loading.value = false;
      return;
    }
    service.ensureLoaded().whenComplete(() => loading.value = false);
  }

  bool isDone(Lesson l) => service.completed.contains(l.id);
  bool isLocked(Lesson l) => service.isLocked(l);

  /// Pro lock first, then the one-time safety screen, then the lesson.
  Future<void> open(Lesson lesson) async {
    if (service.isLocked(lesson)) {
      AppNavigator.toPaywall();
      return;
    }
    if (!service.safetyAccepted.value) {
      final ok = await showSafetySheet();
      if (ok != true) return;
      await service.acceptSafety();
    }
    AppNavigator.toLesson(lesson.id);
  }
}
