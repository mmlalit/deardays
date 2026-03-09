import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/theme/app_theme.dart';

class ThemeState {
  final AppThemeColor themeColor;
  final ThemeMode themeMode;

  const ThemeState({
    this.themeColor = AppThemeColor.sereneDuskBlue,
    this.themeMode = ThemeMode.light,
  });

  ThemeData get lightTheme => AppTheme.lightFrom(themeColor);
  ThemeData get darkTheme => AppTheme.darkFrom(themeColor);

  /// Effective brightness: dark palette forces dark mode.
  ThemeMode get effectiveThemeMode =>
      themeColor.isDark ? ThemeMode.dark : themeMode;
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState());

  void setThemeColor(AppThemeColor color) {
    state = ThemeState(themeColor: color, themeMode: state.themeMode);
  }

  void setThemeMode(ThemeMode mode) {
    state = ThemeState(themeColor: state.themeColor, themeMode: mode);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
