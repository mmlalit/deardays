import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/theme/app_colors.dart';

void main() {
  group('ThemeState', () {
    test('defaults to Classic White', () {
      const state = ThemeState();
      expect(state.themeColor, equals(AppThemeColor.classicWhite));
    });

    test('lightTheme uses correct scaffold background', () {
      const state = ThemeState(themeColor: AppThemeColor.warmCream);
      expect(
        state.lightTheme.scaffoldBackgroundColor,
        equals(AppThemeColor.warmCream.light.bg),
      );
    });

    test('darkTheme uses correct scaffold background', () {
      const state = ThemeState(themeColor: AppThemeColor.sageGreen);
      expect(
        state.darkTheme.scaffoldBackgroundColor,
        equals(AppThemeColor.sageGreen.dark.bg),
      );
    });

    test('each palette generates distinct light themes', () {
      final themes = AppThemeColor.values.map((c) {
        return ThemeState(themeColor: c).lightTheme.scaffoldBackgroundColor;
      }).toSet();
      expect(themes.length, equals(AppThemeColor.values.length));
    });
  });

  group('ThemeNotifier', () {
    test('initial state is Classic White', () {
      final notifier = ThemeNotifier();
      expect(notifier.debugState.themeColor, equals(AppThemeColor.classicWhite));
    });

    test('setThemeColor changes state', () {
      final notifier = ThemeNotifier();
      notifier.setThemeColor(AppThemeColor.sageGreen);
      expect(notifier.debugState.themeColor, equals(AppThemeColor.sageGreen));
    });

    test('setThemeColor updates to Warm Cream', () {
      final notifier = ThemeNotifier();
      notifier.setThemeColor(AppThemeColor.warmCream);
      expect(notifier.debugState.themeColor, equals(AppThemeColor.warmCream));
    });
  });

  group('ThemeProvider with Riverpod', () {
    test('reads default theme', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(themeProvider);
      expect(state.themeColor, equals(AppThemeColor.classicWhite));
    });

    test('switching theme updates provider state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(themeProvider.notifier).setThemeColor(AppThemeColor.sageGreen);
      final state = container.read(themeProvider);
      expect(state.themeColor, equals(AppThemeColor.sageGreen));
    });
  });

  group('AppThemeColor enum', () {
    test('has exactly 4 options', () {
      expect(AppThemeColor.values.length, equals(4));
    });

    test('all have non-empty labels', () {
      for (final color in AppThemeColor.values) {
        expect(color.label.isNotEmpty, isTrue);
      }
    });

    test('Warm Cream light bg is correct', () {
      expect(AppThemeColor.warmCream.light.bg, equals(const Color(0xFFF8F4EF)));
    });

    test('Sage Green light bg is correct', () {
      expect(AppThemeColor.sageGreen.light.bg, equals(const Color(0xFFF4F7F4)));
    });

    test('Classic White light bg is correct', () {
      expect(AppThemeColor.classicWhite.light.bg, equals(const Color(0xFFFAF8F5)));
    });

    test('all light nav backgrounds are white', () {
      final lightPalettes = [
        AppThemeColor.warmCream,
        AppThemeColor.sageGreen,
        AppThemeColor.classicWhite,
      ];
      for (final color in lightPalettes) {
        expect(color.light.navBg, equals(const Color(0xFFFFFFFF)));
      }
    });

    test('warmDark isDark is true', () {
      expect(AppThemeColor.warmDark.isDark, isTrue);
    });

    test('other palettes isDark is false', () {
      expect(AppThemeColor.warmCream.isDark, isFalse);
      expect(AppThemeColor.sageGreen.isDark, isFalse);
      expect(AppThemeColor.classicWhite.isDark, isFalse);
    });
  });

  group('AppColors static constants', () {
    test('mood colors are all distinct', () {
      final moods = {
        AppColors.moodGreat,
        AppColors.moodGood,
        AppColors.moodOkay,
        AppColors.moodLow,
        AppColors.moodTough,
      };
      expect(moods.length, equals(5));
    });

    test('error color is red', () {
      expect(AppColors.error, equals(const Color(0xFFEF4444)));
    });

    test('success color is green', () {
      expect(AppColors.success, equals(const Color(0xFF10B981)));
    });
  });
}
