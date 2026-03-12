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
    test('defaults to Serene Dusk Blue', () {
      const state = ThemeState();
      expect(state.themeColor, equals(AppThemeColor.sereneDuskBlue));
    });

    test('light palette bg is fully opaque', () {
      // Avoid building ThemeData (triggers google_fonts network calls in tests).
      // Verify the palette bg Color directly.
      expect((AppThemeColor.warmCream.light.bg.a * 255.0).round(), equals(255));
      expect((AppThemeColor.sageGreen.light.bg.a * 255.0).round(), equals(255));
    });

    test('dark palette bg is darker than light palette bg', () {
      final lightBg = AppThemeColor.warmCream.light.bg;
      final darkBg  = AppThemeColor.warmCream.dark.bg;
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
    test('initial state is Serene Dusk Blue', () {
      final notifier = ThemeNotifier();
      expect(notifier.debugState.themeColor, equals(AppThemeColor.sereneDuskBlue));
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
      expect(state.themeColor, equals(AppThemeColor.sereneDuskBlue));
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
    test('has exactly 5 options', () {
      expect(AppThemeColor.values.length, equals(5));
    });

    test('all have non-empty labels', () {
      for (final color in AppThemeColor.values) {
        expect(color.label.isNotEmpty, isTrue);
      }
    });

    test('Warm Cream accent is correct', () {
      expect(AppThemeColor.warmCream.light.accent, equals(const Color(0xFFC49A3C)));
    });

    test('Sage Green accent is correct', () {
      expect(AppThemeColor.sageGreen.light.accent, equals(const Color(0xFF2D8F5E)));
    });

    test('Classic White accent is correct', () {
      expect(AppThemeColor.classicWhite.light.accent, equals(const Color(0xFF4F46E5)));
    });

    test('all light nav backgrounds are white', () {
      final lightPalettes = [
        AppThemeColor.warmCream,
        AppThemeColor.sageGreen,
        AppThemeColor.classicWhite,
        AppThemeColor.sereneDuskBlue,
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
      expect(AppThemeColor.sereneDuskBlue.isDark, isFalse);
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
