import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/usage_service.dart';
import '../../../core/utils/constants.dart';
import '../domain/lesson.dart';

/// The Learn course: content from `assets/learn/basics.json`, which lessons
/// are done, and the one-time safety screen.
class LearnService extends GetxService {
  static LearnService get to => Get.find();

  static const String courseAsset = 'assets/learn/basics.json';
  static const String _kCompleted = 'learn_completed_v1';
  static const String _kSafety = 'learn_safety_ok';

  final Rxn<Course> course = Rxn<Course>();
  final RxSet<String> completed = <String>{}.obs;
  final RxBool safetyAccepted = false.obs;

  Future<void>? _loading;

  @override
  void onInit() {
    super.onInit();
    final storage = StorageService.to;
    completed.addAll(
      (storage.getString(_kCompleted) ?? '')
          .split(',')
          .where((s) => s.isNotEmpty),
    );
    safetyAccepted.value = storage.getString(_kSafety) == 'true';
  }

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      course.value = Course.tryParse(
        jsonDecode(await rootBundle.loadString(courseAsset)),
      );
    } catch (_) {
      course.value = null;
    }
  }

  List<Lesson> get lessons => course.value?.lessons ?? const [];

  Lesson? byId(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// First lesson not done yet (or the last one when all are done).
  Lesson? get nextLesson {
    for (final l in lessons) {
      if (!completed.contains(l.id)) return l;
    }
    return lessons.isEmpty ? null : lessons.last;
  }

  int get doneCount => lessons.where((l) => completed.contains(l.id)).length;

  bool isLocked(Lesson l) =>
      AppConstants.lockProLessons && l.proOnly && !UsageService.to.isPro.value;

  Future<void> markComplete(String lessonId) async {
    if (!completed.add(lessonId)) return;
    await StorageService.to.setString(_kCompleted, completed.join(','));
  }

  Future<void> acceptSafety() async {
    safetyAccepted.value = true;
    await StorageService.to.setString(_kSafety, 'true');
  }

  /// Called by Results: a lesson's practice drill (id `lesson_<id>`) that
  /// ended with enough punches completes the lesson. Returns the lesson
  /// completed just now, or null.
  Future<Lesson?> onDrillFinished(String? drillId, int punches) async {
    if (drillId == null || !drillId.startsWith('lesson_')) return null;
    await ensureLoaded();
    final lesson = byId(drillId.substring('lesson_'.length));
    if (lesson == null || punches < lesson.practice.minPunches) return null;
    final isNew = !completed.contains(lesson.id);
    await markComplete(lesson.id);
    return isNew ? lesson : null;
  }
}
