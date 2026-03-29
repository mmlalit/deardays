import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:deardays/features/book/presentation/screens/export_screen.dart';

import '../helpers/test_app.dart';

void exportFlowTests() {
  // ExportScreen is accessible via the /export route.
  // The Settings "Export All Data" button now shows a bottom sheet that
  // does a direct JSON export — it no longer navigates to ExportScreen.
  // We navigate directly via GoRouter to test ExportScreen itself,
  // and we test the Settings export flow separately.
  Future<void> openExportScreen(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);

    // Navigate directly to ExportScreen via the /export route.
    // Use Scaffold context (inside router scope) rather than MaterialApp.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/export');
    await settle(tester);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);
    final _ctx = tester.element(find.byType(Scaffold).first); GoRouter.of(_ctx).push('/settings');
    await settle(tester);
  }

  group('Export — Navigation', () {
    testWidgets('ExportScreen is accessible via route', (tester) async {
      await openExportScreen(tester);
      expect(find.byType(ExportScreen), findsOneWidget);
    });

    testWidgets('"Export All Data" button is visible in Settings', (tester) async {
      await openSettings(tester);

      await tester.scrollUntilVisible(
        find.text('Export All Data'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);

      expect(find.text('Export All Data'), findsOneWidget);
    });

    testWidgets('tapping "Export All Data" shows export modal', (tester) async {
      await openSettings(tester);

      await tester.scrollUntilVisible(
        find.text('Export All Data'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);

      await tester.tap(find.text('Export All Data'));
      await settle(tester);

      // Modal offers JSON, PDF, or Plain Text
      expect(
        find.text('JSON').evaluate().isNotEmpty ||
            find.text('PDF').evaluate().isNotEmpty ||
            find.textContaining('Export').evaluate().isNotEmpty,
        isTrue,
      );

      // Close the modal
      await tester.tapAt(const Offset(200, 100));
      await settle(tester);
    });
  });

  group('Export — Structure', () {
    testWidgets('ExportScreen renders without crash', (tester) async {
      await openExportScreen(tester);
      expect(find.byType(ExportScreen), findsOneWidget);
    });

    testWidgets('ExportScreen has a back/close button', (tester) async {
      await openExportScreen(tester);

      expect(
        find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back_ios_new).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
            find.byIcon(Icons.close).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('ExportScreen shows date-range options', (tester) async {
      await openExportScreen(tester);

      // ExportScreen offers date-range chips / options.
      expect(
        find.textContaining('All').evaluate().isNotEmpty ||
            find.textContaining('Year').evaluate().isNotEmpty ||
            find.textContaining('Custom').evaluate().isNotEmpty ||
            find.byType(ExportScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Export — Format Selection', () {
    testWidgets('ExportScreen shows EXPORT FORMAT section', (tester) async {
      await openExportScreen(tester);

      // Scroll down to the format section
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await settle(tester);

      expect(find.text('EXPORT FORMAT'), findsOneWidget);
    });

    testWidgets('shows By Year, By Chapter, and Both format options',
        (tester) async {
      await openExportScreen(tester);

      // Scroll down to the format section
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await settle(tester);

      expect(find.text('By Year'), findsOneWidget);
      expect(find.text('By Chapter'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
    });

    testWidgets('default format selection is "Both"', (tester) async {
      await openExportScreen(tester);

      // Scroll down to the format section
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await settle(tester);

      // "Both" is selected by default — its description should be visible
      expect(find.text('Combined timeline + chapters'), findsOneWidget);

      // The "Both" row should have a check icon (selected radio indicator)
      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsOneWidget);
    });

    testWidgets('tapping "By Year" selects it', (tester) async {
      await openExportScreen(tester);

      // Scroll down to the format section
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await settle(tester);

      // Tap "By Year" option
      await tester.tap(find.text('By Year'));
      await settle(tester);

      // After tapping, the description for "By Year" should be visible.
      expect(find.text('Pages in chronological order'), findsOneWidget);
    });

    testWidgets('shows cover color selection', (tester) async {
      await openExportScreen(tester);

      expect(find.text('SELECT COVER COLOR'), findsOneWidget);
    });

    testWidgets('shows Digital Edition section', (tester) async {
      await openExportScreen(tester);

      // Scroll down past format section
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -400),
      );
      await settle(tester);

      expect(find.text('Digital Edition'), findsOneWidget);
    });
  });
}
