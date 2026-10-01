import 'package:flutter/material.dart';

/// Hyper Hitter Official Brand Mark & Lockup Logo Widget
class HyperHitterLogo extends StatelessWidget {
  final double scale;
  final bool showLockup;

  const HyperHitterLogo({
    super.key,
    this.scale = 1.0,
    this.showLockup = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Custom SVG/Painter Boxing Glove Mark in Brand Cyan & Navy Accent
        Container(
          width: 32 * scale,
          height: 32 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFF080B2B), // Brand Navy
            borderRadius: BorderRadius.circular(10 * scale),
            border: Border.all(
              color: const Color(0xFF2FBAD1), // Glove Cyan
              width: 1.5 * scale,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2FBAD1).withValues(alpha: 0.3),
                blurRadius: 10 * scale,
                spreadRadius: 1 * scale,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8 * scale),
            child: Image.asset(
              'assets/images/app_ic.png',
              width: 24 * scale,
              height: 24 * scale,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.sports_mma_rounded,
                color: const Color(0xFF6FD8E8),
                size: 20 * scale,
              ),
            ),
          ),
        ),
        if (showLockup) ...[
          SizedBox(width: 10 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'HYPER ',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF2F6FC),
                        letterSpacing: 1.2,
                      ),
                    ),
                    TextSpan(
                      text: 'HITTER',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2FBAD1), // Glove Cyan
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'PUNCH DETECTION',
                style: TextStyle(
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF93A1B8),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
