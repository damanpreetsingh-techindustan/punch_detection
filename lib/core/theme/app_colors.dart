import 'package:flutter/material.dart';

/// KnockUp "Ember Black" brand tokens.
///
/// New screens use the semantic tokens (bg, surface, primary, gold, success...).
/// The legacy names further down (cyan, lime, panel...) are kept so existing
/// screens pick up the new palette without edits; migrate them as each screen
/// is redesigned.
class AppColors {
  // Canvas & surfaces
  static const Color bg = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF16161D);
  static const Color surfaceRaised = Color(0xFF1F1F28);
  static const Color stroke = Color(0xFF2A2A35);
  static const Color glass = Color(0x14FFFFFF);
  static const Color glassStroke = Color(0x1FFFFFFF);

  // Brand
  static const Color primary = Color(0xFFFF4D2E); // Ember
  static const Color primaryLight = Color(0xFFFF8A3D);
  static const Color primaryDeep = Color(0xFFC92A12);
  static const Color gold = Color(0xFFFFB547);

  // Status
  static const Color success = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFFFC857);
  static const Color danger = Color(0xFFFF3B5C);

  // Typography
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF8E8E99);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, primaryLight],
  );

  static const RadialGradient backgroundGlow = RadialGradient(
    center: Alignment(0, -1.1),
    radius: 1.2,
    colors: [Color(0x33FF4D2E), Color(0x00FF4D2E)],
  );

  // --- Legacy names (mapped onto Ember Black) ---
  static const Color navy = bg;
  static const Color cyan = primary;
  static const Color cyanHighlight = primaryLight;
  static const Color ink = Color(0xFF1A0B06); // Text on accent fills
  static const Color accentBg = Color(0xFF2A120C);
  static const Color accentLine = Color(0xFF5A2416);

  static const Color background = bg;
  static const Color panel = surface;
  static const Color panel2 = surfaceRaised;
  static const Color border = stroke;
  static const Color line = stroke;

  static const Color textMuted = textSecondary;

  static const Color lime = primary;
  static const Color blue = gold;
  static const Color red = danger;
  static const Color amber = warning;
  static const Color green = success;

  static const Color selectedBg = accentBg;
  static const Color selectedBorder = Color(0xFF7A2E1C);

  static const Color secondary = gold;
  static const Color surfaceLight = surfaceRaised;
}
