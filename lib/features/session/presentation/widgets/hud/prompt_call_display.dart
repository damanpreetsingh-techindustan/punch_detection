import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/size_box.dart';
import '../../../../../core/widgets/ui/ring_progress.dart';
import '../../controllers/prompt_session_controller.dart';
import 'session_hud.dart';

/// Reaction-drill call: the combo number inside a ring that runs down until
/// the next call, the whole combo underneath, and a streak.
///
/// Hit / miss and the streak come from [PromptSessionController]'s drill
/// score (screen-only; it does not change detection).
class PromptCallDisplay extends StatefulWidget {
  final PromptSessionController controller;
  final double size;

  const PromptCallDisplay({
    super.key,
    required this.controller,
    required this.size,
  });

  @override
  State<PromptCallDisplay> createState() => _PromptCallDisplayState();
}

class _PromptCallDisplayState extends State<PromptCallDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: widget.controller.promptRotationIntervalMs,
    ),
  );
  late final List<Worker> _workers;

  PromptSessionController get _c => widget.controller;

  bool _comboJustChanged = true;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _workers = [
      // Fires before promptTick when a new combo starts.
      ever<List<int>>(_c.currentComboSequence, (_) => _comboJustChanged = true),
      ever<int>(_c.promptTick, _onCall),
    ];
  }

  void _onCall(int tick) {
    _stepIndex = _comboJustChanged ? 0 : _stepIndex + 1;
    _comboJustChanged = false;
    _countdown
      ..duration = Duration(milliseconds: _c.promptRotationIntervalMs)
      ..forward(from: 0);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The score (streak, last call) lives in the controller.
    return Obx(() => _build(_c.lastCallAnswered.value, _c.streak.value));
  }

  Widget _build(bool? lastCallAnswered, int streak) {
    final started = _c.promptTick.value > 0;
    final flash = lastCallAnswered == null
        ? AppColors.stroke
        : lastCallAnswered
        ? AppColors.success
        : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bg.withValues(alpha: 0.6),
            boxShadow: [
              BoxShadow(
                color: flash.withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _countdown,
            builder: (context, child) => RingProgress(
              value: started ? 1 - _countdown.value : 0,
              size: widget.size,
              strokeWidth: widget.size * 0.06,
              trackColor: flash.withValues(alpha: 0.35),
              child: child,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                started ? '${_c.promptNumber.value}' : '…',
                key: ValueKey(_c.promptTick.value),
                style: AppTextStyles.number().copyWith(
                  fontSize: widget.size * 0.42,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 10.r),
        if (started) ...[
          _comboDots(),
          SizedBox(height: 6.r),
          _StreakChip(streak: streak),
        ],
      ],
    );
  }

  Widget _comboDots() {
    final combo = _c.currentComboSequence;
    return HudPill(
      padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 5.r),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < combo.length; i++) ...[
            if (i > 0)
              Text(
                ' · ',
                style: AppTextStyles.bodyMedium().copyWith(fontSize: 13.fs),
              ),
            Text(
              '${combo[i]}',
              style: AppTextStyles.number(null, 15).copyWith(
                color: i == _stepIndex
                    ? AppColors.primaryLight
                    : i < _stepIndex
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Calls answered in a row; turns gold from 3.
class _StreakChip extends StatelessWidget {
  final int streak;

  const _StreakChip({required this.streak});

  @override
  Widget build(BuildContext context) {
    final active = streak >= 3;
    return AnimatedScale(
      scale: active ? 1 : 0.92,
      duration: const Duration(milliseconds: 200),
      child: HudPill(
        borderColor: active
            ? AppColors.gold.withValues(alpha: 0.7)
            : AppColors.glassStroke,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: active ? AppColors.gold : AppColors.textSecondary,
              size: 16.r,
            ),
            SizedBox(width: 4.r),
            Text('$streak', style: AppTextStyles.number(null, 15)),
            SizedBox(width: 4.r),
            Text(
              'in a row',
              style: AppTextStyles.bodyMedium().copyWith(fontSize: 12.fs),
            ),
          ],
        ),
      ),
    );
  }
}
