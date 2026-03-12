/// Accessibility compliance tests for DearDays.
///
/// Run with:
///   flutter test test/a11y/accessibility_test.dart
///
/// Guidelines tested:
///   • androidTapTargetGuideline  — interactive widgets ≥ 48×48 dp (Material spec)
///   • labeledTapTargetGuideline  — every tappable widget has a semantic label
///   • textContrastGuideline      — WCAG AA minimum 4.5:1 contrast (normal text)
///
/// A failure means the screen has a real accessibility regression.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/auth/presentation/screens/login_screen.dart';

import '../helpers/mock_providers.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

const _viewSize = Size(390, 844);

void setView(WidgetTester tester) {
  tester.view.physicalSize = _viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 500));

Future<void> pumpLogin(WidgetTester tester) async {
  setView(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: LoginScreen(onLogin: () {}),
    ),
  );
  await settle(tester);
}

Future<void> pumpHome(WidgetTester tester) async {
  setView(tester);
  await tester.pumpWidget(
    buildTestApp(
      const HomeScreen(),
      overrides: authenticatedOverrides(
        profile: mockProfile,
        streak: mockStreak,
        entries: [mockEntry],
        todayEntry: mockEntry,
      ),
    ),
  );
  await settle(tester);
}

Future<void> pumpTimeline(WidgetTester tester) async {
  setView(tester);
  await tester.pumpWidget(
    buildTestApp(
      const TimelineScreen(),
      overrides: authenticatedOverrides(entries: [mockEntry]),
    ),
  );
  await settle(tester);
}

Future<void> pumpLibrary(WidgetTester tester) async {
  setView(tester);
  await tester.pumpWidget(
    buildTestApp(
      const LibraryScreen(),
      overrides: authenticatedOverrides(books: [mockBook]),
    ),
  );
  await settle(tester);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpTestEnv();

  // ── LoginScreen ──────────────────────────────────────────────────────────────

  group('A11y — LoginScreen', () {
    testWidgets('meets Android tap-target size guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLogin(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('all tappable widgets are labeled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLogin(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text meets WCAG AA contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLogin(tester);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  // ── HomeScreen ───────────────────────────────────────────────────────────────

  group('A11y — HomeScreen', () {
    testWidgets('meets Android tap-target size guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('all tappable widgets are labeled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text meets WCAG AA contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  // ── TimelineScreen ───────────────────────────────────────────────────────────

  group('A11y — TimelineScreen', () {
    testWidgets('meets Android tap-target size guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTimeline(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('all tappable widgets are labeled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTimeline(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text meets WCAG AA contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTimeline(tester);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  // ── LibraryScreen ────────────────────────────────────────────────────────────

  group('A11y — LibraryScreen', () {
    testWidgets('meets Android tap-target size guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLibrary(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('all tappable widgets are labeled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLibrary(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text meets WCAG AA contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLibrary(tester);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
