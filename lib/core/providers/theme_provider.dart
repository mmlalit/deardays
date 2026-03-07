import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/theme/app_theme.dart';

class ThemeState {
  final AppThemeColor themeColor;

  const ThemeState({this.themeColor = AppThemeColor.warmCream});

  ThemeData get lightTheme => AppTheme.lightFrom(themeColor);
  ThemeData get darkTheme => AppTheme.darkFrom(themeColor);
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState());

  void setThemeColor(AppThemeColor color) {
    state = ThemeState(themeColor: color);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
