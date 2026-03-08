import 'package:flutter/material.dart';

/// DearDays brand color palette — Savinka-inspired Indigo theme.
///
/// Electric Indigo accent with clean Slate/Zinc scales.
/// Users can switch background palettes in Settings.
class AppColors {
  AppColors._();

  // --- Brand primary (Electric Indigo) ---
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFFA5B4FC);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryFaint = Color(0xFFE0E7FF);
  static const Color primaryGlow = Color(0x336366F1);

  // --- Accent ---
  static const Color accent = Color(0xFF5145CD);
  static const Color accentLight = Color(0xFFEEF2FF);

  // --- Backgrounds ---
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color bgDark = Color(0xFF09090B);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF27272A);

  // Reading / Book view
  static const Color readingBg = Color(0xFFFBF0D9);
  static const Color readingText = Color(0xFF3D3228);

  // Bottom navigation
  static const Color navBg = Color(0xFFFFFFFF);
  static const Color navBgDark = Color(0xFF18181B);

  // --- Text ---
  static const Color navy = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textFaint = Color(0xFFCBD5E1);

  // --- Moods (vibrant palette) ---
  static const Color moodGreat = Color(0xFF10B981);
  static const Color moodGood = Color(0xFF34D399);
  static const Color moodOkay = Color(0xFFF59E0B);
  static const Color moodLow = Color(0xFFF97316);
  static const Color moodTough = Color(0xFFEF4444);

  // --- Category / accent colors ---
  static const Color rose = Color(0xFFF43F5E);
  static const Color roseBg = Color(0xFFFFF1F2);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueBg = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleBg = Color(0xFFF5F3FF);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeBg = Color(0xFFFFF7ED);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldBg = Color(0xFFECFDF5);
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoBg = Color(0xFFEEF2FF);

  // --- Utility ---
  static const Color border = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFF27272A);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);

  // --- Zinc scale (dark mode) ---
  static const Color zinc50 = Color(0xFFFAFAFA);
  static const Color zinc100 = Color(0xFFF4F4F5);
  static const Color zinc200 = Color(0xFFE4E4E7);
  static const Color zinc300 = Color(0xFFD4D4D8);
  static const Color zinc400 = Color(0xFFA1A1AA);
  static const Color zinc500 = Color(0xFF71717A);
  static const Color zinc700 = Color(0xFF3F3F46);
  static const Color zinc800 = Color(0xFF27272A);
  static const Color zinc900 = Color(0xFF18181B);
  static const Color zinc950 = Color(0xFF09090B);

  // --- Slate scale (light mode) ---
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate900 = Color(0xFF0F172A);
}

/// Theme color palettes the user can choose from in Settings.
enum AppThemeColor {
  warmCream('Warm Cream', Color(0xFFF8F7F6), Color(0xFFFFFFFF), Color(0xFFE8E4DF), Color(0xFF1E1914), Color(0xFF252220), Color(0xFF1E1B18)),
  sageGreen('Sage Green', Color(0xFFF7FAF8), Color(0xFFFFFFFF), Color(0xFFE2E8F0), Color(0xFF161E18), Color(0xFF1E2A20), Color(0xFF1A241C)),
  classicWhite('Classic White', Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFE5E7EB), Color(0xFF111111), Color(0xFF1C1C1C), Color(0xFF161616)),
  warmDark('Dark', Color(0xFF1E1914), Color(0xFF252220), Color(0xFF3D3228), Color(0xFF1E1914), Color(0xFF252220), Color(0xFF1E1B18));

  const AppThemeColor(this.label, this.bg, this.navBg, this.border, this.bgDark, this.cardDark, this.navBgDark);

  final String label;
  final Color bg;
  final Color navBg;
  final Color border;
  final Color bgDark;
  final Color cardDark;
  final Color navBgDark;

  /// Whether this palette is inherently dark.
  bool get isDark => this == warmDark;
}
