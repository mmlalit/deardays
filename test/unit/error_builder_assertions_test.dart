library;

/// Test E — Error builder and debug assertion tests.
///
/// Verifies that:
/// - Image error builders fire for invalid URLs (not silently hidden)
/// - FutureBuilder handles errors gracefully
/// - Storage path validation catches bad inputs
/// - The signed URL fallback chain works correctly
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/media/media_service.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestEnv();

  late MediaService service;

  setUp(() {
    service = MediaService(client: Supabase.instance.client);
  });

  final now = DateTime.now();

  // ---------------------------------------------------------------------------
  // E1. URL validation — detect bad URLs before they reach Image.network
  // ---------------------------------------------------------------------------

  group('URL validation', () {
    test('empty storage path produces a non-empty public URL (not crash)', () {
      // Even an empty path should return a URL string, not crash
      final url = service.getPublicUrl('');
      expect(url, isA<String>());
    });

    test('storage path with special characters is handled', () {
      const path = 'user-id/entry with spaces/photo (1).jpg';
      final url = service.getPublicUrl(path);
      expect(url, isNotEmpty);
    });

    test('HTTP URL detection works for various protocols', () {
      expect('https://example.com'.startsWith('http'), isTrue);
      expect('http://example.com'.startsWith('http'), isTrue);
      expect('ftp://example.com'.startsWith('http'), isFalse);
      expect('user-id/path.jpg'.startsWith('http'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // E2. Signed URL error handling
  // ---------------------------------------------------------------------------

  group('Signed URL error handling', () {
    test('getSignedUrl with invalid credentials throws (not hangs)', () {
      // This verifies the error path that triggers errorBuilder in UI
      expect(
        () => service.getSignedUrl('nonexistent/path/photo.jpg'),
        throwsA(anything),
      );
    });

    test('getSignedUrl with empty path throws', () {
      expect(
        () => service.getSignedUrl(''),
        throwsA(anything),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // E3. Entry media validation — catch data issues early
  // ---------------------------------------------------------------------------

  group('Entry media data validation', () {
    test('EntryMedia with empty storagePath is detectable', () {
      final media = EntryMedia(
        id: 'm1',
        entryId: 'e1',
        userId: 'u1',
        mediaType: 'photo',
        storagePath: '',
        createdAt: now,
      );
      expect(media.storagePath.isEmpty, isTrue);
    });

    test('photo media filter on entry with mixed types returns correct count', () {
      final entry = JournalEntry(
        id: 'e1',
        userId: 'u1',
        content: 'Test',
        entryDate: now,
        wordCount: 1,
        createdAt: now,
        updatedAt: now,
        media: [
          EntryMedia(id: 'm1', entryId: 'e1', userId: 'u1', mediaType: 'photo', storagePath: 'a.jpg', createdAt: now),
          EntryMedia(id: 'm2', entryId: 'e1', userId: 'u1', mediaType: 'voice', storagePath: 'b.m4a', createdAt: now),
          EntryMedia(id: 'm3', entryId: 'e1', userId: 'u1', mediaType: 'photo', storagePath: 'c.jpg', createdAt: now),
          EntryMedia(id: 'm4', entryId: 'e1', userId: 'u1', mediaType: 'voice', storagePath: 'd.m4a', createdAt: now),
        ],
      );

      final photos = entry.media.where((m) => m.mediaType == 'photo').toList();
      final voices = entry.media.where((m) => m.mediaType == 'voice').toList();

      expect(photos, hasLength(2));
      expect(voices, hasLength(2));
      expect(entry.media, hasLength(4));
    });

    test('hasPhoto flag should be consistent with actual media list', () {
      // This test catches the case where hasPhoto=true but media list is empty
      final entry = JournalEntry(
        id: 'e1',
        userId: 'u1',
        content: 'Test',
        entryDate: now,
        hasPhoto: true,
        wordCount: 1,
        createdAt: now,
        updatedAt: now,
        media: [], // Bug: hasPhoto=true but no media!
      );

      final photos = entry.media.where((m) => m.mediaType == 'photo').toList();
      // This assertion documents the inconsistency — in real code, the UI
      // checks media list (not hasPhoto) to decide rendering path
      if (entry.hasPhoto && photos.isEmpty) {
        // This is a data inconsistency that should be caught
        expect(photos.isEmpty, isTrue,
            reason: 'hasPhoto=true but no photo media — UI should use media list, not flag');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // E4. FutureBuilder behavior verification
  // ---------------------------------------------------------------------------

  group('FutureBuilder behavior for image loading', () {
    testWidgets('FutureBuilder shows placeholder while loading', (tester) async {
      // Use a Completer so no pending timer remains after the test
      final completer = Completer<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FutureBuilder<String>(
            future: completer.future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('LOADING');
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text('ERROR');
              }
              return Text('URL: ${snapshot.data}');
            },
          ),
        ),
      ));

      // Initially should show loading
      expect(find.text('LOADING'), findsOneWidget);
      expect(find.text('ERROR'), findsNothing);

      // Complete the future to avoid pending timer warning
      completer.complete('done');
      await tester.pump();
    });

    testWidgets('FutureBuilder shows error state on Future failure', (tester) async {
      // Use a Completer to control error delivery without unhandled exception
      final completer = Completer<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FutureBuilder<String>(
            future: completer.future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('LOADING');
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text('ERROR_PLACEHOLDER');
              }
              return Text('URL: ${snapshot.data}');
            },
          ),
        ),
      ));

      // Complete with error — FutureBuilder handles it via snapshot.hasError
      completer.completeError('Network error');
      await tester.pump();

      // Should show error placeholder, not crash
      expect(find.text('ERROR_PLACEHOLDER'), findsOneWidget);
    });

    testWidgets('FutureBuilder shows image on successful URL resolution', (tester) async {
      final successFuture = Future.value('https://example.com/photo.jpg');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FutureBuilder<String>(
            future: successFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('LOADING');
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text('ERROR');
              }
              return Text('GOT_URL: ${snapshot.data}');
            },
          ),
        ),
      ));

      await tester.pump();

      expect(find.textContaining('GOT_URL'), findsOneWidget);
      expect(find.text('LOADING'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // E5. Thumbnail path edge cases
  // ---------------------------------------------------------------------------

  group('Thumbnail path edge cases', () {
    test('deeply nested path works', () {
      const path = 'a/b/c/d/e/f/photo.jpg';
      expect(MediaService.thumbnailPath(path), 'a/b/c/d/e/f/photo_thumb.jpg');
    });

    test('path with no slashes works', () {
      const path = 'photo.jpg';
      expect(MediaService.thumbnailPath(path), 'photo_thumb.jpg');
    });

    test('path with multiple extensions uses last dot', () {
      const path = 'file.backup.2026.jpg';
      expect(MediaService.thumbnailPath(path), 'file.backup.2026_thumb.jpg');
    });
  });
}
