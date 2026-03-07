import 'package:flutter/material.dart';

/// DearDays brand color palette.
///
/// Default theme: Warm Cream — feels like high-quality paper.
/// Users can switch to Sage Green or Classic White in Settings.
class AppColors {
  AppColors._();

  // --- Brand primary (warm sage accent) ---
  static const Color primary = Color(0xFF7C9A82);
  static const Color primaryLight = Color(0xFFA3BFA8);
  static const Color primaryDark = Color(0xFF5E7D63);

  // --- Default background: Warm Cream (#FCF9F5) ---
  static const Color bgLight = Color(0xFFFCF9F5);
  static const Color bgDark = Color(0xFF1A1816);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF252220);

  // Reading / Book view — Kindle-style warm parchment
  static const Color readingBg = Color(0xFFFBF0D9);
  static const Color readingText = Color(0xFF3D3228);

  // Bottom navigation — white to contrast with body
  static const Color navBg = Color(0xFFFFFFFF);
  static const Color navBgDark = Color(0xFF1E1B18);

  // Text
  static const Color navy = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Moods
  static const Color moodGreat = Color(0xFF4CAF50);
  static const Color moodGood = Color(0xFF8BC34A);
  static const Color moodOkay = Color(0xFFFFC107);
  static const Color moodLow = Color(0xFFFF9800);
  static const Color moodTough = Color(0xFFE57373);

  // Utility
  static const Color border = Color(0xFFE8E4DF);
  static const Color borderDark = Color(0xFF334155);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
}

/// Theme color palettes the user can choose from in Settings.
enum AppThemeColor {
  warmCream('Warm Cream', Color(0xFFFCF9F5), Color(0xFFFFFFFF), Color(0xFFE8E4DF), Color(0xFF1A1816), Color(0xFF252220), Color(0xFF1E1B18)),
  sageGreen('Sage Green', Color(0xFFF7FAF8), Color(0xFFFFFFFF), Color(0xFFE2E8F0), Color(0xFF161E18), Color(0xFF1E2A20), Color(0xFF1A241C)),
  classicWhite('Classic White', Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFE5E7EB), Color(0xFF111111), Color(0xFF1C1C1C), Color(0xFF161616));

  const AppThemeColor(this.label, this.bg, this.navBg, this.border, this.bgDark, this.cardDark, this.navBgDark);

  final String label;
  final Color bg;
  final Color navBg;
  final Color border;
  final Color bgDark;
  final Color cardDark;
  final Color navBgDark;
}
