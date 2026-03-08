import 'package:flutter/material.dart';

/// DearDays brand color palette.
///
/// Warm gold accent — feels like candlelight on paper.
/// Users can switch to Sage Green or Classic White in Settings.
class AppColors {
  AppColors._();

  // --- Brand primary (warm gold accent) ---
  static const Color primary = Color(0xFFD4A373);
  static const Color primaryLight = Color(0xFFE8C9A0);
  static const Color primaryDark = Color(0xFFB8875A);

  // --- Default background: Warm Cream (#F8F7F6) ---
  static const Color bgLight = Color(0xFFF8F7F6);
  static const Color bgDark = Color(0xFF1E1914);
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

  // Moods (warm palette to match primary)
  static const Color moodGreat = Color(0xFF8DB580);
  static const Color moodGood = Color(0xFFB8C98A);
  static const Color moodOkay = Color(0xFFD4A373);
  static const Color moodLow = Color(0xFFD49A6A);
  static const Color moodTough = Color(0xFFCB8B8B);

  // Utility
  static const Color border = Color(0xFFE8E4DF);
  static const Color borderDark = Color(0xFF334155);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
}

/// Theme color palettes the user can choose from in Settings.
enum AppThemeColor {
  warmCream('Warm Cream', Color(0xFFF8F7F6), Color(0xFFFFFFFF), Color(0xFFE8E4DF), Color(0xFF1E1914), Color(0xFF252220), Color(0xFF1E1B18)),
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
