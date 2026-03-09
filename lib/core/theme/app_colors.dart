import 'package:flutter/material.dart';

/// Palette-aware theme colors accessible via `AppColors.of(context)`.
///
/// Static constants remain for global values (moods, status, categories).
/// Per-palette colors (text, card, border, accent, icons) come from the
/// [AppPalette] ThemeExtension attached to every ThemeData.
class AppColors {
  AppColors._();

  /// Get the current palette colors from the nearest Theme.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  // --- Moods (constant across all palettes) ---
  static const Color moodGreat = Color(0xFF10B981);
  static const Color moodGood = Color(0xFF34D399);
  static const Color moodOkay = Color(0xFFF59E0B);
  static const Color moodLow = Color(0xFFF97316);
  static const Color moodTough = Color(0xFFEF4444);

  // --- Category colors (constant across all palettes) ---
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

  // --- Status (constant across all palettes) ---
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);

  // --- Reading / Book view ---
  static const Color readingBg = Color(0xFFFBF0D9);
  static const Color readingText = Color(0xFF3D3228);
}

/// All per-palette colors: text, card, border, accent, icons.
/// Attached to ThemeData as a ThemeExtension.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color card;
  final Color navBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentLight;
  final Color accentFaint;
  final Color iconActive;
  final Color iconInactive;
  final Color border;
  final Color highlight;
  final Color highlightFaint;

  const AppPalette({
    required this.bg,
    required this.card,
    required this.navBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentLight,
    required this.accentFaint,
    required this.iconActive,
    required this.iconInactive,
    required this.border,
    required this.highlight,
    required this.highlightFaint,
  });

  @override
  AppPalette copyWith({
    Color? bg, Color? card, Color? navBg,
    Color? textPrimary, Color? textSecondary, Color? textMuted,
    Color? accent, Color? accentLight, Color? accentFaint,
    Color? iconActive, Color? iconInactive,
    Color? border, Color? highlight, Color? highlightFaint,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      navBg: navBg ?? this.navBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentFaint: accentFaint ?? this.accentFaint,
      iconActive: iconActive ?? this.iconActive,
      iconInactive: iconInactive ?? this.iconInactive,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      highlightFaint: highlightFaint ?? this.highlightFaint,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      navBg: Color.lerp(navBg, other.navBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentFaint: Color.lerp(accentFaint, other.accentFaint, t)!,
      iconActive: Color.lerp(iconActive, other.iconActive, t)!,
      iconInactive: Color.lerp(iconInactive, other.iconInactive, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      highlightFaint: Color.lerp(highlightFaint, other.highlightFaint, t)!,
    );
  }
}

/// Theme color palettes the user can choose from in Settings.
enum AppThemeColor {
  sereneDuskBlue('Serene Dusk Blue'),
  warmCream('Warm Cream'),
  sageGreen('Sage Green'),
  classicWhite('Classic White'),
  warmDark('Dark');

  const AppThemeColor(this.label);
  final String label;

  /// Whether this palette is inherently dark.
  bool get isDark => this == warmDark;

  /// Light mode palette.
  AppPalette get light {
    switch (this) {
      case AppThemeColor.sereneDuskBlue:
        return const AppPalette(
          bg:             Color(0xFFFFFFFF), // Pure White
          card:           Color(0xFFF8FAFF), // Off-white blue-tinted card
          navBg:          Color(0xFFFFFFFF),
          textPrimary:    Color(0xFF0F172A), // Midnight Navy
          textSecondary:  Color(0xFF64748B), // Secondary Slate
          textMuted:      Color(0xFF94A3B8), // Light Slate
          accent:         Color(0xFF195DE6), // Primary Blue
          accentLight:    Color(0xFF4B7CF3), // Lighter Blue
          accentFaint:    Color(0xFFF1F5F9), // Soft Indigo
          iconActive:     Color(0xFF195DE6),
          iconInactive:   Color(0xFF94A3B8),
          border:         Color(0xFFE2E8F0), // Cool Gray
          highlight:      Color(0xFF195DE6),
          highlightFaint: Color(0xFFF1F5F9),
        );
      case AppThemeColor.warmCream:
        return const AppPalette(
          bg: Color(0xFFF8F4EF),
          card: Color(0xFFFFFFFF),
          navBg: Color(0xFFFFFFFF),
          textPrimary: Color(0xFF2C1810),
          textSecondary: Color(0xFF7A6E64),
          textMuted: Color(0xFFA89F97),
          accent: Color(0xFFC49A3C),
          accentLight: Color(0xFFDDB86A),
          accentFaint: Color(0xFFFBF3E0),
          iconActive: Color(0xFF8B6914),
          iconInactive: Color(0xFFB5AA9E),
          border: Color(0xFFE8DFD5),
          highlight: Color(0xFFC49A3C),
          highlightFaint: Color(0xFFFBF3E0),
        );
      case AppThemeColor.sageGreen:
        return const AppPalette(
          bg: Color(0xFFF4F7F4),
          card: Color(0xFFFFFFFF),
          navBg: Color(0xFFFFFFFF),
          textPrimary: Color(0xFF1A2E1A),
          textSecondary: Color(0xFF5F7A5F),
          textMuted: Color(0xFF8FA68F),
          accent: Color(0xFF2D8F5E),
          accentLight: Color(0xFF5CB88A),
          accentFaint: Color(0xFFE8F5EC),
          iconActive: Color(0xFF4A7C59),
          iconInactive: Color(0xFFA3B8A3),
          border: Color(0xFFDCE6DC),
          highlight: Color(0xFF2D8F5E),
          highlightFaint: Color(0xFFE8F5EC),
        );
      case AppThemeColor.classicWhite:
        return const AppPalette(
          bg: Color(0xFFFAF8F5),
          card: Color(0xFFFFFFFF),
          navBg: Color(0xFFFFFFFF),
          textPrimary: Color(0xFF111111),
          textSecondary: Color(0xFF6B7280),
          textMuted: Color(0xFF9CA3AF),
          accent: Color(0xFF6366F1),
          accentLight: Color(0xFFA5B4FC),
          accentFaint: Color(0xFFEEF2FF),
          iconActive: Color(0xFF6366F1),
          iconInactive: Color(0xFF9CA3AF),
          border: Color(0xFFE5E7EB),
          highlight: Color(0xFF6366F1),
          highlightFaint: Color(0xFFEEF2FF),
        );
      case AppThemeColor.warmDark:
        return dark; // Dark palette is the same for both modes
    }
  }

  /// Dark mode palette.
  AppPalette get dark {
    switch (this) {
      case AppThemeColor.sereneDuskBlue:
        return const AppPalette(
          bg:             Color(0xFF0B1426), // Deep Navy
          card:           Color(0xFF111D35), // Navy card
          navBg:          Color(0xFF0D1830),
          textPrimary:    Color(0xFFF1F5F9), // Soft Indigo inverted
          textSecondary:  Color(0xFF94A3B8),
          textMuted:      Color(0xFF475569),
          accent:         Color(0xFF4B7CF3), // Lighter Blue (readable on dark)
          accentLight:    Color(0xFF195DE6),
          accentFaint:    Color(0xFF1E2D4F), // Dark blue tint
          iconActive:     Color(0xFF4B7CF3),
          iconInactive:   Color(0xFF475569),
          border:         Color(0xFF1E2D4F),
          highlight:      Color(0xFF4B7CF3),
          highlightFaint: Color(0xFF1E2D4F),
        );
      case AppThemeColor.warmCream:
        return const AppPalette(
          bg: Color(0xFF1A1412),
          card: Color(0xFF2A2220),
          navBg: Color(0xFF1E1B18),
          textPrimary: Color(0xFFE8E0D8),
          textSecondary: Color(0xFFA89F97),
          textMuted: Color(0xFF6E6560),
          accent: Color(0xFFDDB86A),
          accentLight: Color(0xFFC49A3C),
          accentFaint: Color(0xFF2A2210),
          iconActive: Color(0xFFDDB86A),
          iconInactive: Color(0xFF6E6560),
          border: Color(0xFF3D3228),
          highlight: Color(0xFFDDB86A),
          highlightFaint: Color(0xFF2A2210),
        );
      case AppThemeColor.sageGreen:
        return const AppPalette(
          bg: Color(0xFF121A14),
          card: Color(0xFF1E2A20),
          navBg: Color(0xFF1A241C),
          textPrimary: Color(0xFFD8E8D8),
          textSecondary: Color(0xFF8FA68F),
          textMuted: Color(0xFF5A6E5A),
          accent: Color(0xFF5CB88A),
          accentLight: Color(0xFF2D8F5E),
          accentFaint: Color(0xFF142A1A),
          iconActive: Color(0xFF5CB88A),
          iconInactive: Color(0xFF5A6E5A),
          border: Color(0xFF2E3E30),
          highlight: Color(0xFF5CB88A),
          highlightFaint: Color(0xFF142A1A),
        );
      case AppThemeColor.classicWhite:
        return const AppPalette(
          bg: Color(0xFF111111),
          card: Color(0xFF1C1C1C),
          navBg: Color(0xFF161616),
          textPrimary: Color(0xFFE8E8E8),
          textSecondary: Color(0xFFA0A0A0),
          textMuted: Color(0xFF666666),
          accent: Color(0xFF818CF8),
          accentLight: Color(0xFF6366F1),
          accentFaint: Color(0xFF1E1B4B),
          iconActive: Color(0xFF818CF8),
          iconInactive: Color(0xFF666666),
          border: Color(0xFF2E2E2E),
          highlight: Color(0xFF818CF8),
          highlightFaint: Color(0xFF1E1B4B),
        );
      case AppThemeColor.warmDark:
        return const AppPalette(
          bg: Color(0xFF121212),
          card: Color(0xFF1E1E1E),
          navBg: Color(0xFF161616),
          textPrimary: Color(0xFFE8E8E8),
          textSecondary: Color(0xFFA0A0A0),
          textMuted: Color(0xFF666666),
          accent: Color(0xFFA5B4FC),
          accentLight: Color(0xFF818CF8),
          accentFaint: Color(0xFF1E1B4B),
          iconActive: Color(0xFFA5B4FC),
          iconInactive: Color(0xFF666666),
          border: Color(0xFF2A2A2A),
          highlight: Color(0xFF818CF8),
          highlightFaint: Color(0xFF1E1B4B),
        );
    }
  }
}
