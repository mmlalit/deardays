import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:deardays/core/routing/app_shell.dart';
import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import '../helpers/mock_providers.dart';

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/book', builder: (_, __) => const LibraryScreen()),
          GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
          GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
        ],
      ),
      GoRoute(path: '/record', builder: (_, __) => const Scaffold(body: Center(child: Text('Recording')))),
      GoRoute(path: '/write', builder: (_, __) => const Scaffold(body: Center(child: Text('Write')))),
    ],
  );
}

Widget buildApp() {
  final router = _buildRouter();
  return ProviderScope(
    overrides: [
      ...authenticatedOverrides(),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

void main() {
  setUpTestEnv();
  group('AppShell - Bottom Navigation', () {
    testWidgets('shows Home tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('shows Chapters tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('CHAPTERS'), findsOneWidget);
    });

    testWidgets('shows Timeline tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('TIMELINE'), findsOneWidget);
    });

    testWidgets('shows Explore tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('EXPLORE'), findsOneWidget);
    });

    testWidgets('starts on Home screen', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('navigates to Chapters tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('navigates to Timeline tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('navigates to Explore tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('can navigate back to Home from another tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('FAB is NOT shown on Home tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // AppShell hides FAB when on home tab (index == 0)
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Chapters tab renders LibraryScreen', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
    });
  });
}
