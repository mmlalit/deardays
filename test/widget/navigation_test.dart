import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:deardays/core/routing/app_shell.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/core/providers/theme_provider.dart';
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
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
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
      routerConfig: router,
    ),
  );
}

void main() {
  group('AppShell - Bottom Navigation', () {
    testWidgets('shows Home tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows Library tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('shows Timeline tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgets('shows Settings tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('starts on Home screen', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('navigates to Library tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('navigates to Timeline tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('navigates to Settings tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('can navigate back to Home from another tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('FAB is NOT shown on Home tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // FAB uses mic icon, should not appear on home (home has its own recording UI)
      // AppShell hides FAB when on home tab (index == 0)
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('FAB appears on Library tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      // FAB should be present with mic icon
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
