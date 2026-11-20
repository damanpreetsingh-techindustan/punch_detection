import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../../../../core/widgets/ui/ring_progress.dart';
import '../../domain/lesson.dart';
import '../controllers/lesson_controller.dart';
import '../widgets/boxer_figure.dart';

/// One lesson: animated figure, key point, steps, common mistakes and the
/// practice. Landscape: figure on the left, the rest scrolls on the right.
class LessonPage extends GetView<LessonController> {
  const LessonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Obx(() {
            final lesson = controller.current.value;
            if (lesson == null) {
              return Column(
                children: [
                  _header(null),
                  const Expanded(
                    child: Center(child: Text('Lesson not found.')),
                  ),
                ],
              );
            }
            return LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth > 700;
                if (wide) {
                  return Column(
                    children: [
                      _header(lesson),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  10,
                                  16,
                                ),
                                child: _figureCard(lesson, expand: true),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: ListView(
                                key: ValueKey(lesson.id),
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  0,
                                  20,
                                  20,
                                ),
                                children: _content(lesson),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        _header(lesson),
                        Expanded(
                          child: ListView(
                            key: ValueKey(lesson.id),
                            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                            children: [
                              _figureCard(lesson),
                              16.height,
                              ..._content(lesson),
                            ],
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

  Widget _header(Lesson? lesson) {
    final total = controller.service.lessons.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
      child: Row(
        children: [
          GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: Get.back),
          14.width,
          Expanded(
            child: Text(
              lesson == null ? 'Lesson' : 'Lesson ${lesson.number} of $total',
              style: AppTextStyles.heading3(),
            ),
          ),
          if (lesson != null)
            Obx(
              () => controller.isDone
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 18.r,
                        ),
                        4.width,
                        Text(
                          'Done',
                          style: AppTextStyles.bodyMedium().copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  /// Figure with ½× speed and pause.
  Widget _figureCard(Lesson lesson, {bool expand = false}) {
    final figure = Obx(
      () => BoxerFigure(
        moveId: lesson.move,
        speed: controller.slowMotion.value ? 0.5 : 1,
        paused: controller.paused.value,
      ),
    );
    return GlassCard(
      padding: EdgeInsets.all(12.r),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (expand)
            Expanded(child: Center(child: figure))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: figure,
            ),
          8.height,
          Obx(
            () => Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                _chip(
                  controller.paused.value
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  controller.paused.value ? 'Play' : 'Pause',
                  false,
                  controller.togglePause,
                ),

                _chip(
                  Icons.slow_motion_video_rounded,
                  'Slow motion',
                  controller.slowMotion.value,
                  controller.toggleSpeed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, bool on, VoidCallback onTap) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 7.r),
        decoration: BoxDecoration(
          gradient: on ? AppColors.primaryGradient : null,
          color: on ? null : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.r, color: AppColors.textPrimary),
            6.width,
            Text(
              label,
              style: AppTextStyles.bodyMedium().copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(Lesson lesson) {
    return [
      Text(
        lesson.title,
        style: AppTextStyles.heading1().copyWith(fontSize: 28.fs),
      ),
      if (lesson.subtitle.isNotEmpty) ...[
        4.height,
        Text(lesson.subtitle, style: AppTextStyles.bodyMedium()),
      ],
      if (lesson.keyPoint.isNotEmpty) ...[
        16.height,
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.star_rounded, color: AppColors.gold, size: 20.r),
              10.width,
              Expanded(
                child: Text(
                  lesson.keyPoint,
                  style: AppTextStyles.bodyLarge().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      20.height,
      _label('How to do it'),
      for (var i = 0; i < lesson.steps.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28.r,
                height: 28.r,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: AppTextStyles.buttonLabel().copyWith(fontSize: 13.fs),
                ),
              ),
              12.width,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.steps[i].title,
                      style: AppTextStyles.bodyLarge().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    2.height,
                    Text(
                      lesson.steps[i].body,
                      style: AppTextStyles.bodyMedium().copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (lesson.mistakes.isNotEmpty) ...[
        12.height,
        _label('Common mistakes'),
        for (final m in lesson.mistakes)
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: GlassCard(
              padding: EdgeInsets.all(12.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _mistakeLine(Icons.close_rounded, AppColors.danger, m.wrong),
                  6.height,
                  _mistakeLine(Icons.check_rounded, AppColors.success, m.fix),
                ],
              ),
            ),
          ),
      ],
      16.height,
      _label('Practice'),
      _practiceCard(lesson),
      16.height,
      _doneActions(),
    ].animate(interval: 30.ms).fadeIn(duration: 260.ms);
  }

  Widget _mistakeLine(IconData icon, Color color, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 18.r),
      8.width,
      Expanded(
        child: Text(
          text,
          style: AppTextStyles.bodyMedium().copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );

  Widget _practiceCard(Lesson lesson) {
    final p = lesson.practice;
    return GlassCard(
      child: Obx(() {
        if (controller.following.value) {
          final total = p.followSeconds;
          final left = controller.secondsLeft.value;
          return Column(
            children: [
              RingProgress(
                value: total == 0 ? 0 : left / total,
                size: 120.r,
                strokeWidth: 7.r,
                child: Text('$left', style: AppTextStyles.number(null, 36)),
              ),
              12.height,
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  controller.cue.value,
                  key: ValueKey('${controller.cue.value}$left'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading2().copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              14.height,
              GhostButton(
                label: 'Stop',
                icon: Icons.stop_rounded,
                onPressed: controller.stopFollow,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  p.isDrill
                      ? Icons.sports_mma_rounded
                      : Icons.record_voice_over_rounded,
                  color: AppColors.primary,
                  size: 20.r,
                ),
                10.width,
                Expanded(
                  child: Text(
                    p.isDrill
                        ? 'Bag drill · ${p.drill!.roundPlan.label}'
                        : 'Follow along · ${p.followSeconds} s with voice cues',
                    style: AppTextStyles.bodyLarge().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (p.description.isNotEmpty) ...[
              6.height,
              Text(p.description, style: AppTextStyles.bodyMedium()),
            ],
            if (p.isDrill) ...[
              6.height,
              Text(
                'Throw at least ${p.minPunches} punches to complete the lesson.',
                style: AppTextStyles.bodyMedium(),
              ),
            ],
            14.height,
            PrimaryButton(
              label: p.isDrill ? 'Start practice' : 'Start follow-along',
              icon: Icons.play_arrow_rounded,
              onPressed: controller.startPractice,
            ),
          ],
        );
      }),
    );
  }

  /// "Lesson complete" + next lesson, once done.
  Widget _doneActions() {
    return Obx(() {
      if (!controller.isDone || controller.following.value) {
        return const SizedBox.shrink();
      }
      final next = controller.next;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: AppColors.gold,
                size: 20.r,
              ),
              8.width,
              Text('Lesson complete!', style: AppTextStyles.heading3()),
            ],
          ),
          12.height,
          GhostButton(
            label: next == null ? 'Back to lessons' : 'Next: ${next.title}',
            icon: next == null
                ? Icons.list_rounded
                : Icons.arrow_forward_rounded,
            onPressed: controller.openNext,
          ),
        ],
      );
    });
  }

  Widget _label(String text) => Padding(
    padding: EdgeInsets.only(left: 2.w, bottom: 10.h),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
    ),
  );
}
