import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Default light theme (Warm Cream).
  static ThemeData get light => lightFrom(AppThemeColor.warmCream);

  /// Default dark theme.
  static ThemeData get dark => darkFrom(AppThemeColor.warmCream);

  /// Generate a light theme from the chosen color palette.
  static ThemeData lightFrom(AppThemeColor palette) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: palette.bg,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: palette.bg,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: AppColors.bgDark,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: _textTheme(Brightness.light),
        appBarTheme: AppBarTheme(
          backgroundColor: palette.bg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.primary.withAlpha(26)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: palette.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: palette.navBg,
          selectedItemColor: AppColors.primaryDark,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.primary.withAlpha(26),
          thickness: 1,
        ),
      );

  /// Generate a dark theme from the chosen color palette.
  static ThemeData darkFrom(AppThemeColor palette) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: palette.bgDark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: palette.bgDark,
          error: AppColors.error,
          onPrimary: palette.bgDark,
          onSecondary: palette.bgDark,
          onSurface: Colors.white,
        ),
        textTheme: _textTheme(Brightness.dark),
        appBarTheme: AppBarTheme(
          backgroundColor: palette.bgDark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: palette.cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.primary.withAlpha(26)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: palette.bgDark,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: palette.navBgDark,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      );

  static TextTheme _textTheme(Brightness brightness) {
    final color =
        brightness == Brightness.light ? AppColors.textPrimary : Colors.white;

    return TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      bodyLarge: GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.normal,
        color: color,
        height: 1.7,
        fontStyle: FontStyle.italic,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: color,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: 1.5,
      ),
    );
  }
}
