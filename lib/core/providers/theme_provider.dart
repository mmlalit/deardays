import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/theme/app_theme.dart';

class ThemeState {
  final AppThemeColor themeColor;
  final ThemeMode themeMode;

  const ThemeState({
    this.themeColor = AppThemeColor.warmIndigo,
    this.themeMode = ThemeMode.light,
  });

  ThemeData get lightTheme => AppTheme.lightFrom(themeColor);
  ThemeData get darkTheme => AppTheme.darkFrom(themeColor);

  /// Effective brightness based on user preference.
  ThemeMode get effectiveThemeMode => themeMode;
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _loadSaved();
  }

  static const _boxName = 'settings';
  static const _colorKey = 'theme_color';
  static const _modeKey = 'theme_mode';

  Future<void> _loadSaved() async {
    final box = await Hive.openBox(_boxName);
    final savedColor = box.get(_colorKey) as String?;
    final savedMode = box.get(_modeKey) as String?;

    AppThemeColor color = state.themeColor;
    ThemeMode mode = state.themeMode;

    if (savedColor != null) {
      final match = AppThemeColor.values.where((c) => c.name == savedColor);
      if (match.isNotEmpty) color = match.first;
    }
    if (savedMode != null) {
      final match = ThemeMode.values.where((m) => m.name == savedMode);
      if (match.isNotEmpty) mode = match.first;
    }

    state = ThemeState(themeColor: color, themeMode: mode);
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    state = ThemeState(themeColor: color, themeMode: state.themeMode);
    final box = await Hive.openBox(_boxName);
    await box.put(_colorKey, color.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = ThemeState(themeColor: state.themeColor, themeMode: mode);
    final box = await Hive.openBox(_boxName);
    await box.put(_modeKey, mode.name);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
