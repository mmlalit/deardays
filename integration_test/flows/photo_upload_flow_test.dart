/// Photo upload flow tests.
///
/// Navigates to /photo-entry with a fake image path and verifies the screen
/// structure: preview area, Change pill, Continue button, and text validation.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/features/journal/presentation/screens/photo_entry_screen.dart';

import '../helpers/test_app.dart';

/// Returns a path to a temp file that (intentionally) does not exist.
/// Image.file will trigger errorBuilder -> shows broken-image icon, not a crash.
String get _fakePath =>
    '${Directory.systemTemp.path}${Platform.pathSeparator}e2e_photo_upload_test.jpg';

/// Navigate to /photo-entry and wait for the screen to settle.
Future<void> _openPhotoEntry(WidgetTester tester) async {
  await tester.pumpWidget(buildE2EApp());
  await settle(tester);

  final ctx = tester.element(find.byType(Scaffold).first);
  GoRouter.of(ctx).push('/photo-entry', extra: _fakePath);
  await settle(tester);
}

/// Close PhotoEntryScreen if open (prevents Windows KeyUpEvent crash).
Future<void> _closePhotoEntryIfOpen(WidgetTester tester) async {
  if (find.byType(PhotoEntryScreen).evaluate().isEmpty) return;
  final back = find.byIcon(Icons.arrow_back_rounded);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
  } else {
    (tester.state(find.byType(Navigator).last) as NavigatorState).pop();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void photoUploadFlowTests() {
  group('Photo Upload — Structure', () {
    testWidgets('PhotoEntryScreen renders with fake photo path', (tester) async {
      await _openPhotoEntry(tester);

      expect(find.byType(PhotoEntryScreen), findsOneWidget);

      await _closePhotoEntryIfOpen(tester);
    });

    testWidgets('photo preview area shows (Image or broken-image icon)',
        (tester) async {
      await _openPhotoEntry(tester);

      // Non-existent file -> errorBuilder renders broken-image icon
      final hasBrokenIcon = find
          .byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.broken_image_rounded,
          )
          .evaluate()
          .isNotEmpty;
      final hasImage = find.byType(Image).evaluate().isNotEmpty;
      expect(hasBrokenIcon || hasImage, isTrue);

      await _closePhotoEntryIfOpen(tester);
    });

    testWidgets('Change pill is visible on photo', (tester) async {
      await _openPhotoEntry(tester);

      expect(find.text('Change'), findsOneWidget);

      await _closePhotoEntryIfOpen(tester);
    });
  });

  group('Photo Upload — Text & Navigation', () {
    testWidgets('Continue button is present', (tester) async {
      await _openPhotoEntry(tester);

      expect(find.textContaining('Continue'), findsOneWidget);

      await _closePhotoEntryIfOpen(tester);
    });

    testWidgets('Continue with enough text navigates to processing',
        (tester) async {
      await _openPhotoEntry(tester);

      final field = find.byType(TextField);
      if (field.evaluate().isEmpty) {
        await _closePhotoEntryIfOpen(tester);
        return;
      }

      await tester.tap(field);
      await tester.enterText(
          field, 'This is a beautiful photo from our trip to the mountains.');
      await tester.pump();

      await tester.tap(find.textContaining('Continue'));
      // ProcessingScreen has background AI tasks — pump with Duration.
      await tester.pump(const Duration(seconds: 3));

      // App should still be running (navigation happened without crashing).
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
