import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/theme/app_colors.dart';

void main() {
  group('ThemeState', () {
    test('defaults to Warm Cream', () {
      const state = ThemeState();
      expect(state.themeColor, equals(AppThemeColor.warmCream));
    });

    test('lightTheme uses correct scaffold background', () {
      const state = ThemeState(themeColor: AppThemeColor.warmCream);
      expect(
        state.lightTheme.scaffoldBackgroundColor,
        equals(AppThemeColor.warmCream.bg),
      );
    });

    test('darkTheme uses correct scaffold background', () {
      const state = ThemeState(themeColor: AppThemeColor.sageGreen);
      expect(
        state.darkTheme.scaffoldBackgroundColor,
        equals(AppThemeColor.sageGreen.bgDark),
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
    test('initial state is Warm Cream', () {
      final notifier = ThemeNotifier();
      expect(notifier.debugState.themeColor, equals(AppThemeColor.warmCream));
    });

    test('setThemeColor changes state', () {
      final notifier = ThemeNotifier();
      notifier.setThemeColor(AppThemeColor.sageGreen);
      expect(notifier.debugState.themeColor, equals(AppThemeColor.sageGreen));
    });

    test('setThemeColor updates to Classic White', () {
      final notifier = ThemeNotifier();
      notifier.setThemeColor(AppThemeColor.classicWhite);
      expect(notifier.debugState.themeColor, equals(AppThemeColor.classicWhite));
    });
  });

  group('ThemeProvider with Riverpod', () {
    test('reads default theme', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(themeProvider);
      expect(state.themeColor, equals(AppThemeColor.warmCream));
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
    test('has exactly 3 options', () {
      expect(AppThemeColor.values.length, equals(3));
    });

    test('all have non-empty labels', () {
      for (final color in AppThemeColor.values) {
        expect(color.label.isNotEmpty, isTrue);
      }
    });

    test('Warm Cream bg is #FCF9F5', () {
      expect(AppThemeColor.warmCream.bg, equals(const Color(0xFFFCF9F5)));
    });

    test('Sage Green bg is #F7FAF8', () {
      expect(AppThemeColor.sageGreen.bg, equals(const Color(0xFFF7FAF8)));
    });

    test('Classic White bg is #FFFFFF', () {
      expect(AppThemeColor.classicWhite.bg, equals(const Color(0xFFFFFFFF)));
    });

    test('all nav backgrounds are white', () {
      for (final color in AppThemeColor.values) {
        expect(color.navBg, equals(const Color(0xFFFFFFFF)));
      }
    });
  });

  group('AppColors', () {
    test('primary is sage green #7C9A82', () {
      expect(AppColors.primary, equals(const Color(0xFF7C9A82)));
    });

    test('bgLight is warm cream #FCF9F5', () {
      expect(AppColors.bgLight, equals(const Color(0xFFFCF9F5)));
    });

    test('navBg is white', () {
      expect(AppColors.navBg, equals(const Color(0xFFFFFFFF)));
    });

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
  });
}
