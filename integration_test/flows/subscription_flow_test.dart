import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/settings/presentation/screens/subscription_screen.dart';

import '../helpers/test_app.dart';

void subscriptionFlowTests() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);
    final _ctx = tester.element(find.byType(Scaffold).first); GoRouter.of(_ctx).push('/settings');
    await settle(tester);
  }

  group('Subscription — Navigation', () {
    testWidgets('"Subscription" row is visible in Settings', (tester) async {
      await openSettings(tester);
      expect(find.text('Subscription'), findsOneWidget);
    });

    testWidgets('tapping "Subscription" opens SubscriptionScreen',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Subscription'));
      // SubscriptionScreen may query RevenueCat — use pump(Duration) to avoid
      // pumpAndSettle waiting on async platform channels indefinitely.
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(SubscriptionScreen), findsOneWidget);
    });
  });

  group('Subscription — Structure', () {
    testWidgets('SubscriptionScreen renders without crash', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Subscription'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(SubscriptionScreen), findsOneWidget);
    });

    testWidgets('SubscriptionScreen has a back or close button',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Subscription'));
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back_ios_new).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
            find.byIcon(Icons.close).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
