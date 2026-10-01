import 'package:flutter/material.dart';

/// Hyper Hitter Official Brand Tokens (Sampled directly from hyper_hitter_punch_detection_mobile.html)
class AppColors {
  // Brand & Accent Colors
  static const Color navy = Color(0xFF080B2B); // Logo navy
  static const Color cyan = Color(
    0xFF2FBAD1,
  ); // Glove cyan — primary brand accent
  static const Color cyanHighlight = Color(0xFF6FD8E8); // Glove cyan highlight
  static const Color ink = Color(0xFF04141B); // Text on accent fills
  static const Color accentBg = Color(0xFF0B2530); // Accent subtle fill
  static const Color accentLine = Color(0xFF1C5364); // Accent border line

  // Main Canvas & Surface Panels
  static const Color background = Color(0xFF05070F); // Deep dark background
  static const Color panel = Color(0xFF0F1522); // Primary card surface
  static const Color panel2 = Color(0xFF161F2F); // Sub-card surface
  static const Color border = Color(0xFF26314A); // Card borders & lines
  static const Color line = Color(0xFF26314A);

  // Typography
  static const Color textPrimary = Color(0xFFF2F6FC);
  static const Color textMuted = Color(0xFF93A1B8);

  // Signal & Status Accents (Migrated to Blue/Cyan Theme Palette)
  static const Color lime = Color(0xFF2FBAD1); // Primary Blue/Cyan accent
  static const Color blue = Color(0xFF5B8CFF); // Secondary sensor accent
  static const Color red = Color(0xFFFF5D62); // Danger & error
  static const Color amber = Color(0xFFFFC04D); // Warning & fallback
  static const Color green = Color(0xFF00B4D8); // Live electric blue status

  // Selection Card States (Blue Theme)
  static const Color selectedBg = Color(0xFF0A1E30);
  static const Color selectedBorder = Color(0xFF1C5364);

  // Aliases for Clean Architecture components & themes
  static const Color primary = cyan; // Primary Hyper Hitter Glove Cyan
  static const Color secondary = blue; // Vision & motion accent
  static const Color surface = panel;
  static const Color surfaceLight = panel2;
}
