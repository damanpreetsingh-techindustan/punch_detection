import 'package:flutter/material.dart';

/// Professional Animated Counter Text Widget with smooth spring pop, scale, and slide transitions.
class AnimatedPunchCountText extends StatelessWidget {
  final int count;
  final TextStyle style;
  final TextAlign textAlign;
  final Duration duration;

  const AnimatedPunchCountText({
    super.key,
    required this.count,
    required this.style,
    this.textAlign = TextAlign.center,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.30),
          end: Offset.zero,
        ).animate(animation);

        final scaleAnimation = Tween<double>(
          begin: 0.70,
          end: 1.0,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          ),
        );
      },
      child: Text(
        '$count',
        key: ValueKey<int>(count),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
