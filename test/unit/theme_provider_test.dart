import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Prevent google_fonts from making async HTTP requests in tests, which
    // would cause "test failed after it had already completed" errors.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ThemeState', () {
    test('defaults to Warm Indigo', () {
      const state = ThemeState();
      expect(state.themeColor, equals(AppThemeColor.warmIndigo));
    });

    test('light palette bg is fully opaque', () {
      expect((AppThemeColor.golden.light.bg.a * 255.0).round(), equals(255));
      expect((AppThemeColor.morningSage.light.bg.a * 255.0).round(), equals(255));
    });

    test('dark palette bg is darker than light palette bg', () {
      final lightBg = AppThemeColor.golden.light.bg;
      final darkBg  = AppThemeColor.golden.dark.bg;
      expect(darkBg.computeLuminance(), lessThan(lightBg.computeLuminance()));
    });

    test('each palette generates a distinct accent color', () {
      final accents = AppThemeColor.values.map((c) {
        return c.light.accent;
      }).toSet();
      expect(accents.length, equals(AppThemeColor.values.length));
    });
  });

  group('ThemeNotifier', () {
    test('initial state is Warm Indigo', () {
      final notifier = ThemeNotifier();
      expect(notifier.debugState.themeColor, equals(AppThemeColor.warmIndigo));
    });

    test('setThemeColor changes state', () {
      final notifier = ThemeNotifier();
      notifier.setThemeColor(AppThemeColor.morningSage);
      expect(notifier.debugState.themeColor, equals(AppThemeColor.morningSage));
    });

    test('setThemeColor updates to Golden', () {
      final notifier = ThemeNotifier();
      notifier.setThemeColor(AppThemeColor.golden);
      expect(notifier.debugState.themeColor, equals(AppThemeColor.golden));
    });
  });

  group('ThemeProvider with Riverpod', () {
    test('reads default theme', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(themeProvider);
      expect(state.themeColor, equals(AppThemeColor.warmIndigo));
    });

    test('switching theme updates provider state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(themeProvider.notifier).setThemeColor(AppThemeColor.morningSage);
      final state = container.read(themeProvider);
      expect(state.themeColor, equals(AppThemeColor.morningSage));
    });
  });

  group('AppThemeColor enum', () {
    test('has exactly 5 options', () {
      expect(AppThemeColor.values.length, equals(5));
    });

    test('all have non-empty labels', () {
      for (final color in AppThemeColor.values) {
        expect(color.label.isNotEmpty, isTrue);
      }
    });

    test('Golden accent is correct', () {
      expect(AppThemeColor.golden.light.accent, equals(const Color(0xFFF59E0B)));
    });

    test('Morning Sage accent is correct', () {
      expect(AppThemeColor.morningSage.light.accent, equals(const Color(0xFF10B981)));
    });

    test('Rose Quartz accent is correct', () {
      expect(AppThemeColor.roseQuartz.light.accent, equals(const Color(0xFFE8729A)));
    });

    test('all light nav backgrounds are white', () {
      for (final color in AppThemeColor.values) {
        expect(color.light.navBg, equals(const Color(0xFFFFFFFF)));
      }
    });

    test('all palettes have both light and dark modes', () {
      for (final color in AppThemeColor.values) {
        final lightBg = color.light.bg;
        final darkBg = color.dark.bg;
        expect(darkBg.computeLuminance(), lessThan(lightBg.computeLuminance()));
      }
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
