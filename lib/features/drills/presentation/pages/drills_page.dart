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
import '../../domain/drill_program.dart';
import '../controllers/drills_controller.dart';
import '../widgets/drill_detail_sheet.dart';
import '../widgets/punch_bag_view.dart';

/// Reaction Drill library: quick start of the last drill, a bag legend, the
/// basics, fight styles and the user's own drills. Two columns when wide.
class DrillsPage extends GetView<DrillsController> {
  const DrillsPage({super.key});

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
            return LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth > 700;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1100 : 560),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                      children: [
                        _header(),
                        16.height,
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _legend(context)),
                              const SizedBox(width: 20),
                              Expanded(child: _lists(context, columns: 1)),
                            ],
                          )
                        else ...[
                          _legend(context),
                          20.height,
                          _lists(context, columns: 1),
                        ],
                      ].animate(interval: 50.ms).fadeIn(duration: 300.ms),
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
    return Row(
      children: [
        GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: Get.back),
        14.width,
        Expanded(
          child: Text('Reaction Drills', style: AppTextStyles.heading2()),
        ),
        Obx(
          () => _StanceToggle(
            southpaw: controller.southpaw.value,
            onTap: controller.toggleSouthpaw,
          ),
        ),
      ],
    );
  }

  /// Bag legend + "start last drill".
  Widget _legend(BuildContext context) {
    final last = controller.service.active.value;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'HOW THE CALLS WORK',
            style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
          ),
          6.height,
          Text(
            'A number is called; hit that spot on the bag. Tap a number to '
            'see the punch.',
            style: AppTextStyles.bodyMedium(),
          ),
          12.height,
          const BagLegend(),
          if (last != null) ...[
            16.height,
            PrimaryButton(
              label: 'Start ${last.title}',
              icon: Icons.play_arrow_rounded,
              onPressed: () => controller.start(last, last.roundPlan),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lists(BuildContext context, {required int columns}) {
    final custom = controller.service.custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Basics'),
        for (final p in controller.basics) _card(context, p),
        12.height,
        _section('Fight styles'),
        for (final p in controller.styles) _card(context, p),
        12.height,
        Row(
          children: [
            Expanded(child: _section('My drills')),
            TextButton.icon(
              onPressed: controller.createDrill,
              icon: Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 18.r,
              ),
              label: Text('Create', style: AppTextStyles.tag()),
            ),
          ],
        ),
        if (custom.isEmpty)
          _emptyCustom()
        else
          for (final p in custom) _card(context, p),
      ],
    );
  }

  Widget _section(String text) => Padding(
    padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
    ),
  );

  Widget _emptyCustom() {
    return PressScale(
      onTap: controller.createDrill,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 26.r),
            12.width,
            Expanded(
              child: Text(
                'Build your own drill: tap the bag to write combos, pick the '
                'pace and rounds.',
                style: AppTextStyles.bodyMedium(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, DrillProgram p) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: ProgramCard(
        program: p,
        locked: controller.isLocked(p),
        onTap: () => showDrillDetailSheet(context, p, controller),
      ),
    );
  }
}

/// Orthodox / Southpaw switch (mirrors the bag targets).
class _StanceToggle extends StatelessWidget {
  final bool southpaw;
  final VoidCallback onTap;

  const _StanceToggle({required this.southpaw, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.primary,
              size: 16.r,
            ),
            6.width,
            Text(
              southpaw ? 'Southpaw' : 'Orthodox',
              style: AppTextStyles.bodyMedium().copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.fs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bag with tappable targets and the name of the tapped punch.
class BagLegend extends StatefulWidget {
  final double maxSize;

  const BagLegend({super.key, this.maxSize = 260});

  @override
  State<BagLegend> createState() => _BagLegendState();
}

class _BagLegendState extends State<BagLegend> {
  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    final t = _targetName(_selected);
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxSize),
          child: PunchBagView(
            highlight: _selected,
            onTapTarget: (n) => setState(() => _selected = n),
          ),
        ),
        8.height,
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$_selected  ',
                style: AppTextStyles.number(
                  null,
                  20,
                ).copyWith(color: AppColors.primary),
              ),
              TextSpan(text: t.$1, style: AppTextStyles.heading3()),
              TextSpan(text: '  ·  ${t.$2}', style: AppTextStyles.bodyMedium()),
            ],
          ),
        ),
      ],
    );
  }

  (String, String) _targetName(int n) => switch (n) {
    1 => ('Jab', 'Lead hand'),
    2 => ('Cross', 'Rear hand'),
    3 => ('Lead hook', 'Lead hand'),
    4 => ('Rear hook', 'Rear hand'),
    5 => ('Lead uppercut', 'Lead hand'),
    _ => ('Rear uppercut', 'Rear hand'),
  };
}

/// One drill in the list: title, subtitle, level, pace, rounds, PRO tag.
class ProgramCard extends StatelessWidget {
  final DrillProgram program;
  final bool locked;
  final VoidCallback onTap;

  const ProgramCard({
    super.key,
    required this.program,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = program;
    final levelBars = switch (p.level) {
      'advanced' => 3,
      'intermediate' => 2,
      _ => 1,
    };
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Row(
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                switch (p.category) {
                  'basic' => Icons.sports_mma_rounded,
                  'style' => Icons.emoji_events_rounded,
                  _ => Icons.edit_note_rounded,
                },
                color: AppColors.primary,
                size: 22.r,
              ),
            ),
            12.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge().copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (p.proOnly) ...[6.width, _proTag(locked)],
                    ],
                  ),
                  2.height,
                  if (p.subtitle.isNotEmpty)
                    Text(
                      p.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium(),
                    ),
                  4.height,
                  Text(
                    '${p.paceLabel} · ${p.roundPlan.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium().copyWith(fontSize: 11.fs),
                  ),
                ],
              ),
            ),
            8.width,
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: EdgeInsets.only(left: 2.r),
                    width: 4.r,
                    height: (7 + i * 5).r,
                    decoration: BoxDecoration(
                      color: i < levelBars
                          ? AppColors.primary
                          : AppColors.stroke,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _proTag(bool locked) => Container(
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
  );
}
