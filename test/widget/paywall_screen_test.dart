import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';
import 'package:deardays/core/providers/subscription_providers.dart';
import 'package:deardays/services/subscription/revenuecat_service.dart';
import 'package:deardays/services/subscription/subscription_state.dart';
import '../helpers/mock_providers.dart';

/// Fake SubscriptionNotifier that does not call RevenueCat.
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  _FakeSubscriptionNotifier() : super(RevenueCatService());

  @override
  Future<void> refresh() async {
    state = const SubscriptionState(isLoading: false);
  }
}

void main() {
  setUpTestEnv();

  Widget buildApp() {
    return buildTestApp(
      const PaywallScreen(),
      overrides: [
        ...authenticatedOverrides(),
        subscriptionProvider.overrideWith((_) => _FakeSubscriptionNotifier()),
      ],
    );
  }

  group('PaywallScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PaywallScreen), findsOneWidget);
    });

    testWidgets('shows DearDays header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('DearDays'), findsOneWidget);
    });

    testWidgets('shows headline text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('Keep writing'),
        findsOneWidget,
      );
    });

    testWidgets('shows CTA button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('shows Restore Purchases link', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // May need to scroll to find it
      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Restore Purchases'), findsOneWidget);
    });
  });
}
