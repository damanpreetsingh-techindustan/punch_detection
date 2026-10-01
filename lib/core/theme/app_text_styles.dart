import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/size_box.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle heading1([BuildContext? context]) => GoogleFonts.inter(
        fontSize: context != null ? 32.ts(context) : 32.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle heading2([BuildContext? context]) => GoogleFonts.inter(
        fontSize: context != null ? 24.ts(context) : 24.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle heading3([BuildContext? context]) => GoogleFonts.inter(
        fontSize: context != null ? 18.ts(context) : 18.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle bodyLarge([BuildContext? context]) => GoogleFonts.inter(
        fontSize: context != null ? 15.ts(context) : 15.sp,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  static TextStyle bodyMedium([BuildContext? context]) => GoogleFonts.inter(
        fontSize: context != null ? 13.ts(context) : 13.sp,
        fontWeight: FontWeight.normal,
        height: 1.45,
        color: AppColors.textMuted,
      );

  static TextStyle tag([BuildContext? context]) => GoogleFonts.inter(
        fontSize: context != null ? 11.ts(context) : 11.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: AppColors.cyan,
      );

  static TextStyle buttonLabel([BuildContext? context]) => GoogleFonts.inter(
        fontSize: context != null ? 15.ts(context) : 15.sp,
        fontWeight: FontWeight.w800,
        color: AppColors.background,
      );
}
