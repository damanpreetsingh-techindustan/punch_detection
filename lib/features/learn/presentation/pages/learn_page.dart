import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/meter_bar.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../../domain/lesson.dart';
import '../controllers/learn_controller.dart';
import '../widgets/boxer_figure.dart';

/// Learn Boxing: course progress with "Continue", then every lesson.
/// Landscape: course card on the left, lesson list on the right.
class LearnPage extends GetView<LearnController> {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Obx(() {
            if (controller.loading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final course = controller.service.course.value;
            if (course == null) {
              return Column(
                children: [
                  _header(),
                  const Expanded(
                    child: Center(child: Text('Lessons could not be loaded.')),
                  ),
                ],
              );
            }
            return LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth > 700;
                final summary = _summary(course);
                final list = _lessonList(course);
                if (wide) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        children: [
                          _header(),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      0,
                                      10,
                                      20,
                                    ),
                                    child: summary,
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      0,
                                      20,
                                      20,
                                    ),
                                    children: list,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        _header(),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                            children: [summary, 20.height, ...list],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
      child: Row(
        children: [
          GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: Get.back),
          14.width,
          Expanded(
            child: Text(
              'Learn Boxing',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading2(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(Course course) {
    return Obx(() {
      final s = controller.service;
      final done = s.doneCount;
      final total = course.lessons.length;
      final next = s.nextLesson;
      final allDone = done == total;
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 96.r,
                  child: BoxerFigure(moveId: next?.move ?? 'stance'),
                ),
                14.width,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title.toUpperCase(),
                        style: AppTextStyles.tag(),
                      ),
                      4.height,
                      Text(
                        course.subtitle,
                        style: AppTextStyles.bodyMedium().copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      10.height,
                      Text(
                        '$done of $total lessons done',
                        style: AppTextStyles.bodyMedium(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            12.height,
            MeterBar(value: total == 0 ? 0 : done / total),
            16.height,
            if (next != null)
              PrimaryButton(
                label: allDone
                    ? 'Practise again: ${next.title}'
                    : done == 0
                    ? 'Start lesson 1'
                    : 'Continue: ${next.title}',
                icon: Icons.play_arrow_rounded,
                onPressed: () => controller.open(next),
              ),
          ],
        ),
      );
    });
  }

  List<Widget> _lessonList(Course course) {
    return [
      Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
        child: Text(
          'LESSONS',
          style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
        ),
      ),
      for (final l in course.lessons)
        Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Obx(
            () => _LessonCard(
              lesson: l,
              done: controller.isDone(l),
              isNext: controller.service.nextLesson?.id == l.id,
              locked: controller.isLocked(l),
              onTap: () => controller.open(l),
            ),
          ),
        ),
    ].animate(interval: 40.ms).fadeIn(duration: 300.ms).slideY(begin: 0.06);
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool done;
  final bool isNext;
  final bool locked;
  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.done,
    required this.isNext,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: isNext ? AppColors.accentBg : AppColors.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isNext ? AppColors.primary : AppColors.glassStroke,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppColors.success.withValues(alpha: 0.16)
                    : AppColors.surfaceRaised,
                border: Border.all(
                  color: done ? AppColors.success : AppColors.stroke,
                ),
              ),
              child: done
                  ? Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 20.r,
                    )
                  : Text(
                      '${lesson.number}',
                      style: AppTextStyles.number(
                        null,
                        16,
                      ).copyWith(letterSpacing: 0),
                    ),
            ),
            12.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: AppTextStyles.bodyLarge().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  2.height,
                  Text(
                    '${lesson.subtitle} · ${lesson.minutes} min',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium(),
                  ),
                ],
              ),
            ),
            8.width,
            if (lesson.proOnly)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.r, vertical: 2.r),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locked) ...[
                      Icon(Icons.lock_rounded, size: 9.r, color: AppColors.ink),
                      2.width,
                    ],
                    Text(
                      'PRO',
                      style: AppTextStyles.tag().copyWith(
                        color: AppColors.ink,
                        fontSize: 8.fs,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20.r,
              ),
          ],
        ),
      ),
    );
  }
}
