import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/settings/presentation/screens/backup_restore_screen.dart';

import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildScreen() {
    return buildTestApp(
      const BackupRestoreScreen(),
      overrides: authenticatedOverrides(),
    );
  }

  group('BackupRestoreScreen', () {
    testWidgets('renders header with title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Backup & Restore'), findsOneWidget);
    });

    testWidgets('renders back button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.arrow_back_rounded),
        findsOneWidget,
      );
    });

    testWidgets('shows backup status card', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      // Initial state shows "No Backup Yet"
      expect(find.text('No Backup Yet'), findsOneWidget);
      expect(find.text('Back up your memories to keep them safe'),
          findsOneWidget);
    });

    testWidgets('shows Cloud Backup section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Cloud Backup'), findsOneWidget);
      expect(find.text('Backup Now'), findsOneWidget);
      expect(
          find.text('Sync all local entries to the cloud for safekeeping'),
          findsOneWidget);
    });

    testWidgets('shows Restore Data section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Restore Data'), findsOneWidget);
      expect(find.text('Restore from Cloud'), findsOneWidget);
      expect(find.text('Download all your memories to this device'),
          findsOneWidget);
    });

    testWidgets('shows info card about encryption', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text(
            'Your data is encrypted end-to-end. Only you can read your journal entries.'),
        findsOneWidget,
      );
    });

    testWidgets('shows restore confirmation dialog on tap', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      // Tap Restore from Cloud
      await tester.tap(find.text('Restore from Cloud'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Restore from Cloud?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();
    });
  });
}
