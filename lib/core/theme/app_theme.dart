import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Default light theme (Classic White).
  static ThemeData get light => lightFrom(AppThemeColor.classicWhite);

  /// Default dark theme.
  static ThemeData get dark => darkFrom(AppThemeColor.classicWhite);

  /// Generate a light theme from the chosen color palette.
  static ThemeData lightFrom(AppThemeColor themeColor) {
    final p = themeColor.light;
    final baseTextTheme = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: p.bg,
      extensions: [p],
      colorScheme: ColorScheme.light(
        primary: p.accent,
        secondary: p.accentLight,
        surface: p.bg,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: p.textPrimary,
        onSurface: p.textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.5, color: p.textPrimary),
        displayMedium: baseTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.0, color: p.textPrimary),
        displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: p.textPrimary),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary),
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: p.textPrimary),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: p.textPrimary),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: p.textSecondary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: p.textPrimary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: p.textSecondary),
        labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary),
        labelSmall: baseTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10, color: p.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: p.border),
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.manrope(color: p.textMuted, fontWeight: FontWeight.w500),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.navBg,
        selectedItemColor: p.iconActive,
        unselectedItemColor: p.iconInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 0),
      chipTheme: ChipThemeData(
        backgroundColor: p.accentFaint,
        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.5, color: p.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }

  /// Generate a dark theme from the chosen color palette.
  static ThemeData darkFrom(AppThemeColor themeColor) {
    final p = themeColor.dark;
    final baseTextTheme = GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: p.bg,
      extensions: [p],
      colorScheme: ColorScheme.dark(
        primary: p.accent,
        secondary: p.accentLight,
        surface: p.bg,
        error: AppColors.error,
        onPrimary: p.bg,
        onSecondary: p.bg,
        onSurface: p.textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.5, color: p.textPrimary),
        displayMedium: baseTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.0, color: p.textPrimary),
        displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: p.textPrimary),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary),
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: p.textPrimary),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: p.textPrimary),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: p.textSecondary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: p.textPrimary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: p.textSecondary),
        labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary),
        labelSmall: baseTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10, color: p.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: p.border),
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.manrope(color: p.textMuted, fontWeight: FontWeight.w500),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.navBg,
        selectedItemColor: p.iconActive,
        unselectedItemColor: p.iconInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 0),
      chipTheme: ChipThemeData(
        backgroundColor: p.accentFaint,
        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.5, color: p.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }
}
