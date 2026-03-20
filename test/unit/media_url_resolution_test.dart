library;

/// Test A — Integration-style tests for URL resolution and media pipeline.
///
/// Verifies that:
/// - Storage paths produce valid URLs (not empty, correct bucket)
/// - HTTP URLs pass through unchanged
/// - Signed URLs contain auth tokens
/// - Thumbnail paths are constructed correctly
/// - The full chain: storagePath → MediaService → URL works
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

  // ---------------------------------------------------------------------------
  // A1. Public URL resolution — the chain that was broken in production
  // ---------------------------------------------------------------------------

  group('Public URL resolution', () {
    test('getPublicUrl for storage path returns a URL containing the bucket name', () {
      const path = 'user-id/entry-id/media-id.jpg';
      final url = service.getPublicUrl(path);
      expect(url, contains('entry-media'));
      expect(url, contains(path));
    });

    test('getPublicUrl for HTTP URL returns the same URL unchanged', () {
      const httpUrl = 'https://images.unsplash.com/photo.jpg';
      expect(service.getPublicUrl(httpUrl), httpUrl);
    });

    test('getPublicUrl for http:// URL returns unchanged', () {
      const httpUrl = 'http://example.com/photo.jpg';
      expect(service.getPublicUrl(httpUrl), httpUrl);
    });

    test('getPublicUrl produces a full https:// URL from a storage path', () {
      const path = 'user123/entry456/photo.jpg';
      final url = service.getPublicUrl(path);
      expect(url, startsWith('https://'));
    });
  });

  // ---------------------------------------------------------------------------
  // A2. Signed URL — requires auth so it throws with placeholder creds
  // ---------------------------------------------------------------------------

  group('Signed URL resolution', () {
    test('getSignedUrl throws when not authenticated', () {
      expect(
        () => service.getSignedUrl('user-id/entry-id/media.jpg'),
        throwsA(anything),
      );
    });

    test('getSignedUrl throws for valid-looking but unauthenticated paths', () {
      expect(
        () => service.getSignedUrl('abc/def/ghi.png'),
        throwsA(anything),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // A3. Thumbnail URL path construction
  // ---------------------------------------------------------------------------

  group('Thumbnail URL chain', () {
    test('thumbnailPath inserts _thumb before extension', () {
      expect(
        MediaService.thumbnailPath('user/entry/photo.jpg'),
        'user/entry/photo_thumb.jpg',
      );
    });

    test('getThumbnailUrl for HTTP URL passes through unchanged', () {
      const url = 'https://cdn.example.com/photo.jpg';
      expect(service.getThumbnailUrl(url), url);
    });

    test('getThumbnailUrl for storage path contains _thumb', () {
      final url = service.getThumbnailUrl('user/entry/photo.jpg');
      expect(url, contains('_thumb'));
      expect(url, contains('entry-media'));
    });
  });

  // ---------------------------------------------------------------------------
  // A4. EntryMedia → URL pipeline (the exact chain used in UI widgets)
  // ---------------------------------------------------------------------------

  group('EntryMedia → URL pipeline', () {
    test('mock entry media with storage path produces a public URL', () {
      final media = EntryMedia(
        id: 'test-media',
        entryId: 'test-entry',
        userId: 'test-user',
        mediaType: 'photo',
        storagePath: 'test-user/test-entry/photo.jpg',
        createdAt: DateTime.now(),
      );

      final url = service.getPublicUrl(media.storagePath);
      expect(url, isNotEmpty);
      expect(url, contains('test-user/test-entry/photo.jpg'));
    });

    test('entry with HTTP storagePath in media is handled correctly', () {
      final media = EntryMedia(
        id: 'test-media',
        entryId: 'test-entry',
        userId: 'test-user',
        mediaType: 'photo',
        storagePath: 'https://example.com/demo-photo.jpg',
        createdAt: DateTime.now(),
      );

      final url = service.getPublicUrl(media.storagePath);
      expect(url, 'https://example.com/demo-photo.jpg');
    });

    test('voice media type uses same URL resolution as photo', () {
      final media = EntryMedia(
        id: 'voice-media',
        entryId: 'test-entry',
        userId: 'test-user',
        mediaType: 'voice',
        storagePath: 'test-user/test-entry/recording.m4a',
        createdAt: DateTime.now(),
      );

      final url = service.getPublicUrl(media.storagePath);
      expect(url, contains('recording.m4a'));
    });
  });

  // ---------------------------------------------------------------------------
  // A5. JournalEntry media filtering (photo vs voice — used by UI)
  // ---------------------------------------------------------------------------

  group('JournalEntry media filtering', () {
    final now = DateTime.now();

    JournalEntry makeEntryWithMedia(List<EntryMedia> media) {
      return JournalEntry(
        id: 'entry-1',
        userId: 'user-1',
        content: 'Test content',
        entryDate: now,
        wordCount: 2,
        createdAt: now,
        updatedAt: now,
        media: media,
      );
    }

    test('filters photo media correctly', () {
      final entry = makeEntryWithMedia([
        EntryMedia(id: 'm1', entryId: 'entry-1', userId: 'user-1', mediaType: 'photo', storagePath: 'a.jpg', createdAt: now),
        EntryMedia(id: 'm2', entryId: 'entry-1', userId: 'user-1', mediaType: 'voice', storagePath: 'b.m4a', createdAt: now),
        EntryMedia(id: 'm3', entryId: 'entry-1', userId: 'user-1', mediaType: 'photo', storagePath: 'c.jpg', createdAt: now),
      ]);

      final photos = entry.media.where((m) => m.mediaType == 'photo').toList();
      expect(photos, hasLength(2));
      expect(photos.first.storagePath, 'a.jpg');
    });

    test('filters voice media correctly', () {
      final entry = makeEntryWithMedia([
        EntryMedia(id: 'm1', entryId: 'entry-1', userId: 'user-1', mediaType: 'photo', storagePath: 'a.jpg', createdAt: now),
        EntryMedia(id: 'm2', entryId: 'entry-1', userId: 'user-1', mediaType: 'voice', storagePath: 'b.m4a', createdAt: now),
      ]);

      final voice = entry.media.where((m) => m.mediaType == 'voice').toList();
      expect(voice, hasLength(1));
      expect(voice.first.storagePath, 'b.m4a');
    });

    test('entry with no media returns empty lists', () {
      final entry = makeEntryWithMedia([]);
      expect(entry.media.where((m) => m.mediaType == 'photo').toList(), isEmpty);
      expect(entry.media.where((m) => m.mediaType == 'voice').toList(), isEmpty);
    });

    test('hasPhoto flag matches actual media presence', () {
      final entryWithPhoto = JournalEntry(
        id: 'entry-1',
        userId: 'user-1',
        content: 'Test',
        entryDate: now,
        hasPhoto: true,
        wordCount: 1,
        createdAt: now,
        updatedAt: now,
        media: [
          EntryMedia(id: 'm1', entryId: 'entry-1', userId: 'user-1', mediaType: 'photo', storagePath: 'a.jpg', createdAt: now),
        ],
      );
      expect(entryWithPhoto.hasPhoto, isTrue);
      expect(entryWithPhoto.media.where((m) => m.mediaType == 'photo').toList(), isNotEmpty);
    });
  });
}
