import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Button that only fires after being held for [holdDuration], with a fill
/// sweeping across it. Used for "Finish" so a stray tap mid-workout can't end
/// the session.
class HoldToConfirmButton extends StatefulWidget {
  final String label;
  final String holdingLabel;
  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final IconData icon;
  final double? height;

  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdingLabel = 'Keep holding…',
    this.holdDuration = const Duration(milliseconds: 900),
    this.icon = Icons.stop_rounded,
    this.height,
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
      _ctrl.reset();
    }
  }

  void _start() {
    HapticFeedback.lightImpact();
    _ctrl.forward();
  }

  void _cancel() {
    if (_ctrl.isCompleted) return;
    _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? 56.h;
    final radius = BorderRadius.circular(18.r);
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final holding = _ctrl.value > 0;
          return AnimatedScale(
            scale: holding ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: ClipRRect(
              borderRadius: radius,
              child: Container(
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: radius,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: _ctrl.value,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                      ),
                    ),
                    // Scales down instead of overflowing in narrow spots
                    // (the landscape session side panel).
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.r),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.icon,
                                color: AppColors.onPrimary,
                                size: 20.r,
                              ),
                              SizedBox(width: 8.r),
                              Text(
                                holding ? widget.holdingLabel : widget.label,
                                maxLines: 1,
                                // No context: `.ts` would shrink the label in landscape.
                                style: AppTextStyles.buttonLabel(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
