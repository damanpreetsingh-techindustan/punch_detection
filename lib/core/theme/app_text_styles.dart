import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/size_box.dart';
import 'app_colors.dart';

/// KnockUp type scale: Sora for headings, Space Grotesk for numbers,
/// Inter for body copy.
class AppTextStyles {
  /// Both paths give the same size: [TextSize.ts] with a context, [FontSize.fs]
  /// without one. (Plain `.sp` would be ~2.2x too big in landscape.)
  static double _size(BuildContext? context, double size) =>
      context != null ? size.ts(context) : size.fs;

  /// Hero numbers: punch counter, prompt combo, results total.
  static TextStyle number([BuildContext? context, double size = 64]) =>
      GoogleFonts.spaceGrotesk(
        fontSize: _size(context, size),
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -1.5,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle display([BuildContext? context]) => GoogleFonts.sora(
    fontSize: _size(context, 36),
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
  );

  static TextStyle heading1([BuildContext? context]) => GoogleFonts.sora(
    fontSize: _size(context, 32),
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static TextStyle heading2([BuildContext? context]) => GoogleFonts.sora(
    fontSize: _size(context, 24),
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static TextStyle heading3([BuildContext? context]) => GoogleFonts.sora(
    fontSize: _size(context, 18),
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyLarge([BuildContext? context]) => GoogleFonts.inter(
    fontSize: _size(context, 15),
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMedium([BuildContext? context]) => GoogleFonts.inter(
    fontSize: _size(context, 13),
    fontWeight: FontWeight.normal,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static TextStyle tag([BuildContext? context]) => GoogleFonts.inter(
    fontSize: _size(context, 11),
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AppColors.primary,
  );

  static TextStyle buttonLabel([BuildContext? context]) => GoogleFonts.sora(
    fontSize: _size(context, 15),
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AppColors.onPrimary,
  );
}
