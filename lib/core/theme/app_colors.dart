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
  static const Color readingBg = Color(0xFFF8FAFC);
  static const Color readingText = Color(0xFF1E293B);
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

  /// Alias for [card] — used across screens for card backgrounds.
  Color get cardBg => card;

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
  warmIndigo('Warm Indigo'),
  sereneDuskBlue('Serene Dusk Blue'),
  golden('Golden'),
  morningSage('Morning Sage'),
  roseQuartz('Rose Quartz');

  const AppThemeColor(this.label);
  final String label;

  /// Light mode palette.
  AppPalette get light {
    switch (this) {
      case AppThemeColor.warmIndigo:
        return const AppPalette(
          bg:             Color(0xFFF9F7F3),
          card:           Color(0xFFFFFFFF),
          navBg:          Color(0xFFFFFFFF),
          textPrimary:    Color(0xFF1C1917),
          textSecondary:  Color(0xFF78716C),
          textMuted:      Color(0xFFA8A29E),
          accent:         Color(0xFF6366F1),
          accentLight:    Color(0xFF818CF8),
          accentFaint:    Color(0xFFEEF2FF),
          iconActive:     Color(0xFF6366F1),
          iconInactive:   Color(0xFFA8A29E),
          border:         Color(0xFFE7E5E4),
          highlight:      Color(0xFF6366F1),
          highlightFaint: Color(0xFFEEF2FF),
        );
      case AppThemeColor.sereneDuskBlue:
        return const AppPalette(
          bg:             Color(0xFFF8FAFC),
          card:           Color(0xFFFFFFFF),
          navBg:          Color(0xFFFFFFFF),
          textPrimary:    Color(0xFF0F172A),
          textSecondary:  Color(0xFF64748B),
          textMuted:      Color(0xFF94A3B8),
          accent:         Color(0xFF195DE6),
          accentLight:    Color(0xFF4B7CF3),
          accentFaint:    Color(0xFFF1F5F9),
          iconActive:     Color(0xFF195DE6),
          iconInactive:   Color(0xFF94A3B8),
          border:         Color(0xFFE2E8F0),
          highlight:      Color(0xFF195DE6),
          highlightFaint: Color(0xFFF1F5F9),
        );
      case AppThemeColor.golden:
        return const AppPalette(
          bg:             Color(0xFFFFFBF5),
          card:           Color(0xFFFFFFFF),
          navBg:          Color(0xFFFFFFFF),
          textPrimary:    Color(0xFF1C1408),
          textSecondary:  Color(0xFF78684E),
          textMuted:      Color(0xFFA89878),
          accent:         Color(0xFFF59E0B),
          accentLight:    Color(0xFFFBBF24),
          accentFaint:    Color(0xFFFFF8E1),
          iconActive:     Color(0xFFD97706),
          iconInactive:   Color(0xFFB5AA9E),
          border:         Color(0xFFF0E6D4),
          highlight:      Color(0xFFF59E0B),
          highlightFaint: Color(0xFFFFF8E1),
        );
      case AppThemeColor.morningSage:
        return const AppPalette(
          bg:             Color(0xFFF6FBF8),
          card:           Color(0xFFFFFFFF),
          navBg:          Color(0xFFFFFFFF),
          textPrimary:    Color(0xFF0C1F14),
          textSecondary:  Color(0xFF4B7A5E),
          textMuted:      Color(0xFF84AB92),
          accent:         Color(0xFF10B981),
          accentLight:    Color(0xFF34D399),
          accentFaint:    Color(0xFFECFDF5),
          iconActive:     Color(0xFF059669),
          iconInactive:   Color(0xFF9CB8A8),
          border:         Color(0xFFD5EAE0),
          highlight:      Color(0xFF10B981),
          highlightFaint: Color(0xFFECFDF5),
        );
      case AppThemeColor.roseQuartz:
        return const AppPalette(
          bg:             Color(0xFFFDF6F8),
          card:           Color(0xFFFFFFFF),
          navBg:          Color(0xFFFFFFFF),
          textPrimary:    Color(0xFF2D1620),
          textSecondary:  Color(0xFF8E6478),
          textMuted:      Color(0xFFB894A4),
          accent:         Color(0xFFE8729A),
          accentLight:    Color(0xFFF9A8C9),
          accentFaint:    Color(0xFFFFF0F5),
          iconActive:     Color(0xFFD85888),
          iconInactive:   Color(0xFFC4A8B4),
          border:         Color(0xFFF2DDE4),
          highlight:      Color(0xFFE8729A),
          highlightFaint: Color(0xFFFFF0F5),
        );
    }
  }

  /// Dark mode palette.
  AppPalette get dark {
    switch (this) {
      case AppThemeColor.warmIndigo:
        return const AppPalette(
          bg:             Color(0xFF13111A),
          card:           Color(0xFF1C1A2A),
          navBg:          Color(0xFF181624),
          textPrimary:    Color(0xFFF1F0FF),
          textSecondary:  Color(0xFF9CA3AF),
          textMuted:      Color(0xFF6B7280),
          accent:         Color(0xFF818CF8),
          accentLight:    Color(0xFF6366F1),
          accentFaint:    Color(0xFF1E1B3A),
          iconActive:     Color(0xFF818CF8),
          iconInactive:   Color(0xFF6B7280),
          border:         Color(0xFF2D2B3D),
          highlight:      Color(0xFF818CF8),
          highlightFaint: Color(0xFF1E1B3A),
        );
      case AppThemeColor.sereneDuskBlue:
        return const AppPalette(
          bg:             Color(0xFF0B1426),
          card:           Color(0xFF111D35),
          navBg:          Color(0xFF0D1830),
          textPrimary:    Color(0xFFF1F5F9),
          textSecondary:  Color(0xFF94A3B8),
          textMuted:      Color(0xFF475569),
          accent:         Color(0xFF4B7CF3),
          accentLight:    Color(0xFF195DE6),
          accentFaint:    Color(0xFF1E2D4F),
          iconActive:     Color(0xFF4B7CF3),
          iconInactive:   Color(0xFF475569),
          border:         Color(0xFF1E2D4F),
          highlight:      Color(0xFF4B7CF3),
          highlightFaint: Color(0xFF1E2D4F),
        );
      case AppThemeColor.golden:
        return const AppPalette(
          bg:             Color(0xFF1A1508),
          card:           Color(0xFF262010),
          navBg:          Color(0xFF1E1A0C),
          textPrimary:    Color(0xFFF0E8D8),
          textSecondary:  Color(0xFFB5A580),
          textMuted:      Color(0xFF7A6E50),
          accent:         Color(0xFFFBBF24),
          accentLight:    Color(0xFFF59E0B),
          accentFaint:    Color(0xFF2A2410),
          iconActive:     Color(0xFFFBBF24),
          iconInactive:   Color(0xFF6E6550),
          border:         Color(0xFF3D3520),
          highlight:      Color(0xFFFBBF24),
          highlightFaint: Color(0xFF2A2410),
        );
      case AppThemeColor.morningSage:
        return const AppPalette(
          bg:             Color(0xFF0C1A12),
          card:           Color(0xFF14261C),
          navBg:          Color(0xFF10201A),
          textPrimary:    Color(0xFFD8F0E4),
          textSecondary:  Color(0xFF84AB92),
          textMuted:      Color(0xFF4D7A5E),
          accent:         Color(0xFF34D399),
          accentLight:    Color(0xFF10B981),
          accentFaint:    Color(0xFF0A2A1A),
          iconActive:     Color(0xFF34D399),
          iconInactive:   Color(0xFF4D7A5E),
          border:         Color(0xFF1E3E2A),
          highlight:      Color(0xFF34D399),
          highlightFaint: Color(0xFF0A2A1A),
        );
      case AppThemeColor.roseQuartz:
        return const AppPalette(
          bg:             Color(0xFF1A0E14),
          card:           Color(0xFF281820),
          navBg:          Color(0xFF1E1218),
          textPrimary:    Color(0xFFF0D8E4),
          textSecondary:  Color(0xFFB894A4),
          textMuted:      Color(0xFF785060),
          accent:         Color(0xFFF9A8C9),
          accentLight:    Color(0xFFE8729A),
          accentFaint:    Color(0xFF2A1020),
          iconActive:     Color(0xFFF9A8C9),
          iconInactive:   Color(0xFF785060),
          border:         Color(0xFF3E2030),
          highlight:      Color(0xFFF9A8C9),
          highlightFaint: Color(0xFF2A1020),
        );
    }
  }
}
