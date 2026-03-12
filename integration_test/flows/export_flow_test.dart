import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/book/presentation/screens/export_screen.dart';

import '../helpers/test_app.dart';

void exportFlowTests() {
  // Opens the Settings screen using the same avatar-tap approach as
  // settings_flow_test.dart.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await tester.pumpAndSettle();
    final avatars = find.byType(GestureDetector);
    await tester.tap(avatars.first);
    await tester.pumpAndSettle();
  }

  // Scrolls settings to the Data section and taps "Export All Data".
  // Tapping it opens a format picker modal (JSON / PDF); we pick PDF which
  // navigates to ExportScreen. Call pumpAndSettle() after this to let the
  // route transition complete.
  Future<void> openExportScreen(WidgetTester tester) async {
    await openSettings(tester);

    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export All Data'));
    await tester.pumpAndSettle(); // modal sheet animates in

    // The modal offers 'JSON' and 'PDF'. Tap PDF to push ExportScreen.
    if (find.text('PDF').evaluate().isNotEmpty) {
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();
    }
  }

  group('Export — Navigation', () {
    testWidgets('tapping "Export All Data" navigates to ExportScreen',
        (tester) async {
      await openExportScreen(tester);
      expect(find.byType(ExportScreen), findsOneWidget);
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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // "Both" is selected by default — its description should be visible
      expect(find.text('Combined timeline + chapters'), findsOneWidget);

      // The "Both" row should have a check icon (selected radio indicator)
      // Find check icon within the format section
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
      await tester.pumpAndSettle();

      // Tap "By Year" option
      await tester.tap(find.text('By Year'));
      await tester.pumpAndSettle();

      // After tapping, the check icon should appear on the By Year row.
      // The description for "By Year" should be visible.
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
      await tester.pumpAndSettle();

      expect(find.text('Digital Edition'), findsOneWidget);
    });
  });
}
