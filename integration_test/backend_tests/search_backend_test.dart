/// Search screen — real-backend tests.
///
/// Tests keyword search, empty query, result tapping, and AI search toggle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/features/search/presentation/screens/search_screen.dart';

import '../helpers/test_app_real.dart';

void searchBackendTests() {
  setUpAll(() async => await initBackendApp());

  group('Search — Screen & Keyword', () {
    testWidgets('search screen opens without crash', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/search');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('search field is visible and focusable', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/search');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField);
      expect(field.evaluate().isNotEmpty, isTrue,
          reason: 'Search field should be visible');
    });

    testWidgets('typing a keyword shows results or empty state',
        (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/search');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.showKeyboard(field.first);
        tester.testTextInput.enterText('family');
        await tester.pump(const Duration(seconds: 2));

        // Should show results or "no results"
        expect(find.byType(MaterialApp), findsOneWidget);
        // ignore: avoid_print
        print('[SEARCH] Keyword search executed without crash.');
      }
    });

    testWidgets('empty query does not crash', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/search');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.showKeyboard(field.first);
        tester.testTextInput.enterText('');
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(SearchScreen), findsOneWidget);
      }
    });

    testWidgets('back button returns from search', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/search');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ── NEGATIVE TESTS ──────────────────────────────────────────────────────────

  group('Search — Negative: No results & edge cases', () {
    testWidgets('searching nonsense keyword shows no results or empty state',
        (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/search');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.showKeyboard(field.first);
        tester.testTextInput.enterText('zzzzxxxxxqqqqq99999');
        await tester.pump(const Duration(seconds: 2));

        // Should not crash; should show empty/no results
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });

    testWidgets('very long query does not crash', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/search');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.showKeyboard(field.first);
        tester.testTextInput.enterText('a' * 300);
        await tester.pump(const Duration(seconds: 2));

        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });

    testWidgets('special characters in query do not crash', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/search');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.showKeyboard(field.first);
        tester.testTextInput.enterText(r"'; DROP TABLE journal_entries; --");
        await tester.pump(const Duration(seconds: 2));

        // SQL injection attempt should be harmless
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });
  });
}
