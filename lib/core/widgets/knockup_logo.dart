import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// KnockUp brand mark (glove tile) with optional "KNOCKUP" wordmark lockup.
class KnockUpLogo extends StatelessWidget {
  final double scale;
  final bool showLockup;
  final bool showTagline;

  const KnockUpLogo({
    super.key,
    this.scale = 1.0,
    this.showLockup = true,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KnockUpMark(size: 36 * scale),
        if (showLockup) ...[
          SizedBox(width: 10 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  style: GoogleFonts.sora(
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.0,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Knock',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    TextSpan(
                      text: 'Up',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              if (showTagline)
                Padding(
                  padding: EdgeInsets.only(top: 3 * scale),
                  child: Text(
                    'LEARN BOXING',
                    style: GoogleFonts.inter(
                      fontSize: 8 * scale,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ember gradient tile with the glove glyph.
class KnockUpMark extends StatelessWidget {
  final double size;

  const KnockUpMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.sports_mma_rounded,
        color: AppColors.onPrimary,
        size: size * 0.6,
      ),
    );
  }
}
