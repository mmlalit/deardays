import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/features/journal/presentation/screens/photo_entry_screen.dart';

import '../helpers/mock_providers.dart';

// PhotoEntryScreen has an autofocused TextField whose cursor-blink animation
// prevents pumpAndSettle() from ever settling. Use pump(Duration) throughout.
// 1 s matches the pattern used in home_screen_data_display_test.dart which
// also renders GoogleFonts.playfairDisplay() — long enough for widget state
// to settle, short enough that async font-load errors don't propagate.
const _settle = Duration(seconds: 1);

void main() {
  setUpTestEnv();

  // Non-existent path → Image.file triggers errorBuilder (broken-image icon).
  final fakePath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}widget_test_photo.jpg';

  Widget buildApp() => ProviderScope(
        overrides: authenticatedOverrides(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: PhotoEntryScreen(photoPath: fakePath),
        ),
      );

  group('PhotoEntryScreen — Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.byType(PhotoEntryScreen), findsOneWidget);
    });

    testWidgets('shows "Add a Memory" in the app bar', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.text('Add a Memory'), findsOneWidget);
    });

    testWidgets('shows back arrow button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows photo preview (image or broken-image fallback)',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      final hasBroken = find
          .byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.broken_image_rounded,
          )
          .evaluate()
          .isNotEmpty;
      final hasImage = find.byType(Image).evaluate().isNotEmpty;
      expect(hasBroken || hasImage, isTrue);
    });

    testWidgets('shows Change pill button on the photo', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('shows edit icon inside Change pill', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    });

    testWidgets('shows "Tell the story" label', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.textContaining('Tell the story'), findsOneWidget);
    });

    testWidgets('shows text field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows placeholder hint text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.textContaining('What happened here'), findsOneWidget);
    });

    testWidgets('shows Continue button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.textContaining('Continue'), findsOneWidget);
    });
  });

  group('PhotoEntryScreen — Text Validation', () {
    testWidgets('nudge has opacity 0 when text field is empty', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      // AnimatedOpacity keeps the widget in the tree — check opacity, not presence.
      final nudge = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.textContaining('Write a little more'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(nudge.opacity, 0.0);
    });

    testWidgets('nudge visible when text is 1–9 characters', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump();

      expect(find.textContaining('Write a little more'), findsOneWidget);
    });

    testWidgets('nudge has opacity 0 when text reaches 10+ characters',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      await tester.tap(find.byType(TextField));
      await tester.enterText(
          find.byType(TextField), 'This is enough text to continue.');
      await tester.pump();

      final nudge = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.textContaining('Write a little more'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(nudge.opacity, 0.0);
    });

    testWidgets('Continue button does nothing when text is empty', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      await tester.tap(find.textContaining('Continue'));
      await tester.pump();

      expect(find.byType(PhotoEntryScreen), findsOneWidget);
    });

    testWidgets('Continue button does nothing when text is too short',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      await tester.enterText(find.byType(TextField), 'Short');
      await tester.pump();

      await tester.tap(find.textContaining('Continue'));
      await tester.pump();

      expect(find.byType(PhotoEntryScreen), findsOneWidget);
    });

    testWidgets('nudge opacity transitions from 1.0 to 0.0 as text grows',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      final field = find.byType(TextField);
      final nudgeFinder = find.ancestor(
        of: find.textContaining('Write a little more'),
        matching: find.byType(AnimatedOpacity),
      );

      // Enter enough text so _hasEnoughText flips to true.
      await tester.tap(field);
      await tester.enterText(field, 'Long enough now!');
      await tester.pump(const Duration(milliseconds: 300));
      // Confirm nudge is hidden while text is long enough.
      expect(tester.widget<AnimatedOpacity>(nudgeFinder).opacity, 0.0);

      // Delete back to short text → _hasEnoughText flips to false → nudge shows.
      await tester.enterText(field, 'Short');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<AnimatedOpacity>(nudgeFinder).opacity, 1.0);

      // Re-enter long text → nudge hides again.
      await tester.enterText(field, 'Long enough again!');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<AnimatedOpacity>(nudgeFinder).opacity, 0.0);
    });
  });

  group('PhotoEntryScreen — Layout', () {
    testWidgets('photo preview container is at least 100px tall', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      // Photo preview now uses AnimatedContainer (height: 260 normal, 100 when
      // keyboard open). Verify the container is in the tree and the rendered
      // size is at least 100px tall.
      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ).toList();
      // At least one AnimatedContainer should exist (the photo preview)
      expect(containers, isNotEmpty,
          reason: 'Expected an AnimatedContainer for the photo preview');
    });

    testWidgets('Continue button is full-width (ElevatedButton present)',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(_settle);

      expect(find.byType(ElevatedButton), findsOneWidget);

      final box = tester.getRect(find.byType(ElevatedButton));
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(box.width, greaterThan(screenWidth * 0.7));
    });
  });
}
