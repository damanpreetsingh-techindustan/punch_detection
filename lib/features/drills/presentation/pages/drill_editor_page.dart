import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../controllers/drill_editor_controller.dart';
import '../widgets/punch_bag_view.dart';

/// Create or edit an own drill. Bag on the left in landscape, the form on
/// the right; stacked in portrait.
class DrillEditorPage extends GetView<DrillEditorController> {
  const DrillEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > 700;
              final bag = _bagCard();
              final form = _form();
              return Column(
                children: [
                  _header(),
                  Expanded(
                    child: wide
                        ? Row(
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
                                  child: bag,
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    0,
                                    20,
                                    20,
                                  ),
                                  child: form,
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [bag, 16.height, form],
                            ),
                          ),
                  ),
                  _saveBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
      child: Row(
        children: [
          GlassIconButton(icon: Icons.close_rounded, onPressed: Get.back),
          14.width,
          Text(
            controller.isEditing ? 'Edit drill' : 'New drill',
            style: AppTextStyles.heading2(),
          ),
        ],
      ),
    );
  }

  Widget _bagCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TAP THE BAG TO WRITE A COMBO',
            style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
          ),
          12.height,
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Obx(
                () => PunchBagView(
                  highlight: controller.current.isEmpty
                      ? null
                      : controller.current.last,
                  onTapTarget: controller.tapTarget,
                ),
              ),
            ),
          ),
          12.height,
          Obx(
            () => Container(
              height: 48.r,
              padding: EdgeInsets.symmetric(horizontal: 12.r),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.current.isEmpty
                          ? 'e.g. tap 1, 2, 3'
                          : controller.current.join(' - '),
                      style: controller.current.isEmpty
                          ? AppTextStyles.bodyMedium()
                          : AppTextStyles.number(null, 20),
                    ),
                  ),
                  IconButton(
                    onPressed: controller.undo,
                    icon: const Icon(
                      Icons.backspace_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          10.height,
          Obx(
            () => GhostButton(
              label: 'Add combo',
              icon: Icons.add_rounded,
              onPressed: controller.current.isEmpty
                  ? null
                  : controller.addCombo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Name'),
        TextField(
          controller: controller.name,
          maxLength: 32,
          textCapitalization: TextCapitalization.words,
          style: AppTextStyles.bodyLarge(),
          decoration: InputDecoration(
            hintText: 'My combo drill',
            counterText: '',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        16.height,
        _label('Combos'),
        Obx(
          () => controller.combos.isEmpty
              ? Text('No combos yet.', style: AppTextStyles.bodyMedium())
              : Wrap(
                  spacing: 6.r,
                  runSpacing: 6.r,
                  children: [
                    for (var i = 0; i < controller.combos.length; i++)
                      InputChip(
                        label: Text(
                          controller.combos[i].join('-'),
                          style: AppTextStyles.number(null, 14),
                        ),
                        backgroundColor: AppColors.surfaceRaised,
                        side: BorderSide.none,
                        onDeleted: () => controller.removeCombo(i),
                        deleteIconColor: AppColors.textSecondary,
                      ),
                  ],
                ),
        ),
        16.height,
        _label('Pace (time between calls)'),
        Obx(
          () => _choices<int>(
            DrillEditorController.paceOptionsMs,
            controller.intervalMs.value,
            (v) => '${(v / 1000).toStringAsFixed(1)} s',
            (v) => controller.intervalMs.value = v,
          ),
        ),
        16.height,
        _label('Rounds'),
        Obx(() {
          final plan = controller.roundPlan.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _choices<int>(
                const [0, 1, 3, 5],
                plan.rounds,
                (v) => v == 0 ? 'Open' : '$v',
                (v) => controller.roundPlan.value = plan.copyWith(rounds: v),
              ),
              if (!plan.isOpen) ...[
                10.height,
                _choices<int>(
                  const [60, 120, 180],
                  plan.roundSeconds,
                  (v) => '${v ~/ 60} min',
                  (v) => controller.roundPlan.value = plan.copyWith(
                    roundSeconds: v,
                  ),
                ),
                10.height,
                _choices<int>(
                  const [30, 45, 60],
                  plan.restSeconds,
                  (v) => '$v s rest',
                  (v) => controller.roundPlan.value = plan.copyWith(
                    restSeconds: v,
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }

  Widget _saveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(
            () => controller.error.value.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Text(
                      controller.error.value,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium().copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
          ),
          PrimaryButton(
            label: 'Save drill',
            icon: Icons.check_rounded,
            onPressed: controller.save,
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
    ),
  );

  Widget _choices<T>(
    List<T> options,
    T selected,
    String Function(T) label,
    ValueChanged<T> onPick,
  ) {
    return Wrap(
      spacing: 8.r,
      runSpacing: 8.r,
      children: [
        for (final o in options)
          PressScale(
            onTap: () => onPick(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 8.r),
              decoration: BoxDecoration(
                gradient: o == selected ? AppColors.primaryGradient : null,
                color: o == selected ? null : AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label(o),
                style: AppTextStyles.bodyMedium().copyWith(
                  color: o == selected
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
