import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';

import '../helpers/test_app.dart';

/// E2E tests for the PaywallScreen.
///
/// Navigate directly via GoRouter push to '/paywall' — same approach used
/// for ExportScreen and BookCreationScreen.

void paywallFlowTests() {
  Future<void> openPaywall(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await tester.pumpAndSettle();

    // Navigate directly to PaywallScreen via the /paywall route.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/paywall');
    await tester.pumpAndSettle();
  }

  group('Paywall — Screen Structure', () {
    testWidgets('PaywallScreen renders when navigated to directly',
        (tester) async {
      await openPaywall(tester);
      expect(find.byType(PaywallScreen), findsOneWidget);
    });

    testWidgets('PaywallScreen shows headline text', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('Keep writing'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows "DearDays" brand text', (tester) async {
      await openPaywall(tester);
      expect(find.text('DearDays'), findsWidgets);
    });

    testWidgets('PaywallScreen shows feature checklist', (tester) async {
      await openPaywall(tester);
      expect(find.text('Unlimited entries'), findsOneWidget);
      expect(find.text('PDF exports'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows pricing cards', (tester) async {
      await openPaywall(tester);

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
      await openPaywall(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('BEST VALUE'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows "Continue my story" CTA button',
        (tester) async {
      await openPaywall(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -400),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Continue my story'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows "Restore Purchases" link',
        (tester) async {
      await openPaywall(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -500),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Restore Purchases'), findsOneWidget);
    });

    testWidgets('PaywallScreen shows Terms and Privacy links',
        (tester) async {
      await openPaywall(tester);

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
      await openPaywall(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('tapping close button dismisses PaywallScreen',
        (tester) async {
      await openPaywall(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PaywallScreen), findsNothing);
    });
  });
}
