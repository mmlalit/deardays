import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized spacing scale used throughout the app.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Centralized border-radius scale.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 100;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Centralized shadow presets. Use with AppColors palette for theme-aware shadows.
class AppShadows {
  AppShadows._();

  /// Subtle card shadow.
  static List<BoxShadow> subtle(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withAlpha(brightness == Brightness.dark ? 40 : 8),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  /// Medium elevation shadow (modals, floating elements).
  static List<BoxShadow> medium(Brightness brightness) => [
        BoxShadow(
          color:
              Colors.black.withAlpha(brightness == Brightness.dark ? 60 : 15),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  /// Strong elevation shadow (FABs, overlays).
  static List<BoxShadow> strong(Brightness brightness) => [
        BoxShadow(
          color:
              Colors.black.withAlpha(brightness == Brightness.dark ? 80 : 25),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Centralized typography helpers built on GoogleFonts.manrope.
///
/// Use these for inline styles when the Material textTheme doesn't fit.
/// Prefer `Theme.of(context).textTheme` when possible.
class AppTypography {
  AppTypography._();

  // --- Display / Hero ---
  static TextStyle display(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: colors.textPrimary,
        letterSpacing: -0.5,
      );

  // --- Headings ---
  static TextStyle h1(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
      );

  static TextStyle h2(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      );

  static TextStyle h3(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      );

  // --- Body ---
  static TextStyle body(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.5,
      );

  static TextStyle bodySecondary(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        height: 1.5,
      );

  // --- Journal / Literary content (serif) ---
  static TextStyle journal(AppPalette colors) => GoogleFonts.newsreader(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.7,
      );

  // --- Captions & Labels ---
  static TextStyle caption(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      );

  static TextStyle label(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: colors.textMuted,
        letterSpacing: 0.5,
      );

  static TextStyle labelUppercase(AppPalette colors) => GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: colors.textMuted,
        letterSpacing: 1.5,
      );

  // --- Button ---
  static TextStyle button() => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      );
}
