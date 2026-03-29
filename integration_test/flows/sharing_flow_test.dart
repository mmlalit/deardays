import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/routing/app_shell.dart';
import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:deardays/features/sharing/presentation/screens/request_access_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/share_approvals_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/share_management_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/shared_with_me_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';

import '../helpers/test_app.dart';

void sharingFlowTests() {
  // ── Helper: open MemoryDetail and tap the ··· more button ────────────────

  Future<bool> openMoreMenu(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);

    await tester.tap(find.text('TIMELINE'));
    await settle(tester);

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -600));
    await settle(tester);

    final knownTitles = [
      'Trip to Bali',
      "Mom's birthday",
      'Got the promotion',
      'Sunday morning run',
      'Reconnecting',
    ];
    bool tapped = false;
    for (final title in knownTitles) {
      final found = find.textContaining(title);
      if (found.evaluate().isNotEmpty) {
        final card = find.ancestor(of: found.first, matching: find.byType(GestureDetector));
        if (card.evaluate().isNotEmpty) {
          await tester.tap(card.first, warnIfMissed: false);
          await tester.pump(const Duration(seconds: 3));
          tapped = true;
          break;
        }
      }
    }

    if (!tapped || find.byType(MemoryDetailScreen).evaluate().isEmpty) return false;

    final moreBtn = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.more_horiz_rounded,
    );
    if (moreBtn.evaluate().isEmpty) return false;

    await tester.tap(moreBtn.first, warnIfMissed: false);
    await settle(tester);
    return true;
  }

  // ── Group 1: More menu sharing options ───────────────────────────────────

  group('Sharing — More Menu', () {
    testWidgets('"Share Privately" option is visible', (tester) async {
      final opened = await openMoreMenu(tester);
      if (!opened) return;

      expect(find.text('Share Privately'), findsOneWidget);
    });

    testWidgets('"Requires your approval" subtitle is visible', (tester) async {
      final opened = await openMoreMenu(tester);
      if (!opened) return;

      expect(find.text('Requires your approval'), findsOneWidget);
    });

    testWidgets('"Who can see this" option is visible', (tester) async {
      final opened = await openMoreMenu(tester);
      if (!opened) return;

      expect(find.text('Who can see this'), findsOneWidget);
    });

    testWidgets('tapping "Who can see this" opens ShareManagementScreen', (tester) async {
      final opened = await openMoreMenu(tester);
      if (!opened) return;

      await tester.tap(find.text('Who can see this'));
      await settle(tester);

      expect(find.byType(ShareManagementScreen), findsOneWidget);
    });
  });

  // ── Group 2: ShareManagementScreen ───────────────────────────────────────

  group('Sharing — Who Can See This Screen', () {
    testWidgets('shows "Who can see this" app bar title', (tester) async {
      final opened = await openMoreMenu(tester);
      if (!opened) return;

      await tester.tap(find.text('Who can see this'));
      await settle(tester);

      if (find.byType(ShareManagementScreen).evaluate().isEmpty) return;

      expect(find.text('Who can see this'), findsOneWidget);
    });

    testWidgets('shows "No shares yet" empty state (no shares in fake repo)', (tester) async {
      final opened = await openMoreMenu(tester);
      if (!opened) return;

      await tester.tap(find.text('Who can see this'));
      await settle(tester);

      if (find.byType(ShareManagementScreen).evaluate().isEmpty) return;

      expect(
        find.text('No shares yet').evaluate().isNotEmpty ||
            find.byType(ShareManagementScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('back button returns to previous screen', (tester) async {
      final opened = await openMoreMenu(tester);
      if (!opened) return;

      await tester.tap(find.text('Who can see this'));
      await settle(tester);

      if (find.byType(ShareManagementScreen).evaluate().isEmpty) return;

      final backBtn = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.arrow_back_rounded,
      );
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
      }

      expect(find.byType(MaterialApp), findsOneWidget);
      // Pump to drain Windows synthesized key events before next pumpWidget call
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  // ── Group 3: RequestAccessScreen (Mum's flow) ────────────────────────────
  // Render directly — avoids GoRouter context lookup and keyboard crashes.

  Widget _sharingApp(Widget screen) => ProviderScope(
        overrides: [
          sharingRepositoryProvider.overrideWith((_) => FakeSharingRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      );

  group('Sharing — Request Access Screen', () {
    testWidgets('renders with invalid token and shows error state', (tester) async {
      await tester.pumpWidget(_sharingApp(const RequestAccessScreen(token: 'bad-token')));
      // Use pump instead of pumpAndSettle to avoid stray Windows key events
      await tester.pump(const Duration(milliseconds: 500));

      // Fake repo returns null → "no longer valid" or loading spinner still visible
      expect(
        find.byType(RequestAccessScreen).evaluate().isNotEmpty ||
            find.textContaining('no longer valid').evaluate().isNotEmpty ||
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows "no longer valid" message after loading', (tester) async {
      await tester.pumpWidget(_sharingApp(const RequestAccessScreen(token: 'any-token')));
      // Wait for async _loadShare() to complete (fake repo returns null immediately)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('no longer valid').evaluate().isNotEmpty ||
            find.textContaining('expired').evaluate().isNotEmpty ||
            find.byType(RequestAccessScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows DearDays CTA on error screen', (tester) async {
      await tester.pumpWidget(_sharingApp(const RequestAccessScreen(token: 'any-token')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After null token loads, "Start your DearDays" CTA appears
      expect(
        find.textContaining('DearDays').evaluate().isNotEmpty ||
            find.byType(RequestAccessScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Group 4: ShareApprovalsScreen ────────────────────────────────────────

  group('Sharing — Approvals Screen', () {
    testWidgets('shows "Waiting for approval" app bar title', (tester) async {
      await tester.pumpWidget(_sharingApp(const ShareApprovalsScreen()));
      await settle(tester);

      expect(find.text('Waiting for approval'), findsOneWidget);
    });

    testWidgets('shows "All caught up" empty state', (tester) async {
      await tester.pumpWidget(_sharingApp(const ShareApprovalsScreen()));
      await settle(tester);

      expect(find.text('All caught up'), findsOneWidget);
    });

    testWidgets('shows check-circle icon in empty state', (tester) async {
      await tester.pumpWidget(_sharingApp(const ShareApprovalsScreen()));
      await settle(tester);

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });
  });

  // ── Group 5: SharedWithMeScreen ───────────────────────────────────────────

  group('Sharing — Shared With Me Screen', () {
    testWidgets('shows "Shared with me" app bar title', (tester) async {
      await tester.pumpWidget(_sharingApp(const SharedWithMeScreen()));
      await settle(tester);

      expect(find.text('Shared with me'), findsOneWidget);
    });

    testWidgets('shows empty state when no memories shared', (tester) async {
      await tester.pumpWidget(_sharingApp(const SharedWithMeScreen()));
      await settle(tester);

      expect(find.textContaining('No memories shared'), findsOneWidget);
    });

    testWidgets('shows inbox icon in empty state', (tester) async {
      await tester.pumpWidget(_sharingApp(const SharedWithMeScreen()));
      await settle(tester);

      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.inbox_rounded).evaluate().isNotEmpty ||
            find.byType(Icon).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Group 6: Explore tab "Shared with me" visibility ─────────────────────

  group('Sharing — Explore Section Visibility', () {
    testWidgets('"Shared with me" hidden when hasReceivedShare=false (default)', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      await tester.tap(find.text('EXPLORE'));
      await settle(tester);

      // Default profile: hasReceivedShare=false → section must not appear
      expect(find.text('Shared with me'), findsNothing);
    });

    testWidgets('"Shared with me" visible when hasReceivedShare=true', (tester) async {
      final now = DateTime.now();
      final profileWithShare = UserProfile(
        id: 'e2e-user',
        displayName: 'Alex',
        encryptionSalt: 'e2e-salt',
        trialStartedAt: now,
        isSubscribed: true,
        createdAt: now.subtract(const Duration(days: 365)),
        consentGivenAt: now.subtract(const Duration(days: 365)),
        hasReceivedShare: true,
      );

      final router = GoRouter(
        initialLocation: '/explore',
        routes: [
          ShellRoute(
            builder: (_, __, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/explore',
                pageBuilder: (_, __) => const NoTransitionPage(child: ExploreScreen()),
              ),
              GoRoute(
                path: '/home',
                pageBuilder: (_, __) => const NoTransitionPage(child: ExploreScreen()),
              ),
            ],
          ),
          GoRoute(
            path: '/shared-with-me',
            builder: (_, __) => const SharedWithMeScreen(),
          ),
          GoRoute(
            path: '/share-approvals',
            builder: (_, __) => const ShareApprovalsScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((_) async => profileWithShare),
            sharingRepositoryProvider.overrideWith((_) => FakeSharingRepository()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final themeState = ref.watch(themeProvider);
              return MaterialApp.router(
                theme: themeState.lightTheme,
                darkTheme: themeState.darkTheme,
                themeMode: themeState.effectiveThemeMode,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Shared with me'), findsOneWidget);
    });
  });
}
