import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../../core/navigation/app_navigator.dart';
import '../../../../../core/services/usage_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/size_box.dart';
import '../../../../../core/widgets/ui/app_buttons.dart';

/// Counts the session's punches towards today's free limit and stops counting
/// when the limit is reached: [onStopCounting] runs once (the session closes
/// its punch gate) and the limit sheet opens. The session keeps running.
/// If the user becomes Pro meanwhile, [onResumeCounting] reopens the gate.
class DailyLimitGuard extends StatefulWidget {
  final RxInt punchCount;
  final VoidCallback onStopCounting;
  final VoidCallback onResumeCounting;
  final VoidCallback onEndSession;
  final Widget child;

  const DailyLimitGuard({
    super.key,
    required this.punchCount,
    required this.onStopCounting,
    required this.onResumeCounting,
    required this.onEndSession,
    required this.child,
  });

  @override
  State<DailyLimitGuard> createState() => _DailyLimitGuardState();
}

class _DailyLimitGuardState extends State<DailyLimitGuard> {
  final UsageService _usage = UsageService.to;
  late final List<Worker> _workers;

  @override
  void initState() {
    super.initState();
    _usage.countingStopped.value = false;
    _workers = [
      _usage.trackSession(widget.punchCount),
      ever<int>(_usage.todayPunches, (_) => _check()),
      ever<bool>(_usage.isPro, (_) => _check()),
    ];
    // Already used up before this session started.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted) return;
    final stopped = _usage.countingStopped.value;
    if (_usage.limitReached && !stopped) {
      _usage.countingStopped.value = true;
      widget.onStopCounting();
      HapticFeedback.heavyImpact();
      showDailyLimitSheet(context, onEndSession: widget.onEndSession);
    } else if (!_usage.limitReached && stopped) {
      // Went Pro from the paywall during the session.
      _usage.countingStopped.value = false;
      widget.onResumeCounting();
    }
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _usage.countingStopped.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "That's today's free punches": go unlimited, end the session, or keep
/// training without counting.
void showDailyLimitSheet(
  BuildContext context, {
  required VoidCallback onEndSession,
}) {
  final limit = UsageService.to.dailyLimit;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.gold,
                  size: 32.r,
                ),
              ),
            ),
            14.height,
            Text(
              'That\'s today\'s $limit free punches',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading2(),
            ),
            8.height,
            Text(
              'Great work! Punches aren\'t counted for the rest of today. '
              'Go Pro for unlimited punches, or come back tomorrow: your free '
              'punches reset at midnight.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(),
            ),
            20.height,
            PrimaryButton(
              label: 'Go unlimited',
              icon: Icons.all_inclusive_rounded,
              onPressed: () {
                Navigator.pop(sheetContext);
                AppNavigator.toPaywall(fromLimit: true);
              },
            ),
            10.height,
            GhostButton(
              label: 'End session',
              icon: Icons.flag_rounded,
              onPressed: () {
                Navigator.pop(sheetContext);
                onEndSession();
              },
            ),
            4.height,
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(
                'Keep training (not counted)',
                style: AppTextStyles.bodyMedium(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
