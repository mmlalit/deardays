import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';

import '../helpers/test_app.dart';

/// E2E tests for the PaywallScreen.
///
/// The PaywallScreen is reached via `context.push('/paywall')`. In the E2E test
/// app the user is already subscribed (isSubscribed: true), but the paywall
/// route is still accessible. We navigate directly by tapping elements that
/// trigger the paywall or by verifying the route exists.
///
/// Since the E2E user is "subscribed" the paywall may not be triggered by
/// normal flows. Instead we use a workaround: the Explore/Home flow can
/// sometimes trigger it, or we rely on the route being registered. For a robust
/// test we navigate directly to /paywall via go_router if available, but since
/// that requires programmatic access, we test what we can reach through UI.
///
/// The PaywallScreen is also reachable from SubscriptionScreen or when the
/// trial expires. We test the screen structure by navigating the route.

void paywallFlowTests() {
  group('Paywall — Screen Structure', () {
    testWidgets('PaywallScreen renders when navigated to directly',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Navigate programmatically to /paywall since the E2E user is subscribed
      // and the paywall wouldn't trigger via normal UI flow.
      // Find the app's Navigator and push the paywall route.
      final context = tester.element(find.byType(MaterialApp));
      // go_router is configured in the E2E app — we can use GoRouter.of(context)
      // but that requires importing go_router. Instead, we look for a way to
      // trigger the route. The simplest approach: use Navigator.push to push
      // the PaywallScreen directly.
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PaywallScreen), findsOneWidget);
    });

    testWidgets('PaywallScreen shows headline text', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Keep writing'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows "DearDays" brand text', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('DearDays'), findsWidgets);
    });

    testWidgets('PaywallScreen shows feature checklist', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Unlimited entries'), findsOneWidget);
      expect(find.text('PDF exports'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows pricing cards', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      // Scroll down to pricing cards.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await tester.pump(const Duration(seconds: 1));

      // Pricing text contains "/ year" or "/ month".
      final hasPricing =
          find.textContaining('/ year').evaluate().isNotEmpty ||
              find.textContaining('/ month').evaluate().isNotEmpty;
      expect(hasPricing, isTrue);
    });

    testWidgets('PaywallScreen shows "BEST VALUE" badge', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('BEST VALUE'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows "Continue my story" CTA button',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -400),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Continue my story'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows "Restore Purchases" link',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -500),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Restore Purchases'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows Terms and Privacy links',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -600),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });

  group('Paywall — Close Navigation', () {
    testWidgets('PaywallScreen has a close button', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('tapping close button dismisses PaywallScreen',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PaywallScreen), findsNothing);
    });
  });
}
