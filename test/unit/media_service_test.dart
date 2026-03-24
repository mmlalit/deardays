import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/media/media_service.dart';
import 'package:deardays/services/media/image_compressor.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestEnv();

  // ---------------------------------------------------------------------------
  // ImageCompressor constants — pure Dart, no Supabase needed
  // ---------------------------------------------------------------------------

  group('ImageCompressor constants', () {
    test('maxPhotoDimension is 1920', () {
      expect(ImageCompressor.maxPhotoDimension, 1920);
    });

    test('maxThumbnailDimension is 400', () {
      expect(ImageCompressor.maxThumbnailDimension, 400);
    });

    test('maxCoverDimension is 800', () {
      expect(ImageCompressor.maxCoverDimension, 800);
    });

    test('maxAvatarDimension is 512', () {
      expect(ImageCompressor.maxAvatarDimension, 512);
    });

    test('photoQuality is 75', () {
      expect(ImageCompressor.photoQuality, 75);
    });

    test('coverQuality is 80', () {
      expect(ImageCompressor.coverQuality, 80);
    });

    test('avatarQuality is 80', () {
      expect(ImageCompressor.avatarQuality, 80);
    });

    test('thumbnailQuality is 60', () {
      expect(ImageCompressor.thumbnailQuality, 60);
    });
  });

  // ---------------------------------------------------------------------------
  // MediaService.thumbnailPath — static, pure string logic
  // ---------------------------------------------------------------------------

  group('MediaService.thumbnailPath', () {
    test('inserts _thumb before the extension', () {
      const path = 'user-id/entry-id/media-id.jpg';
      expect(MediaService.thumbnailPath(path), 'user-id/entry-id/media-id_thumb.jpg');
    });

    test('works with png extension', () {
      const path = 'user-id/entry-id/media-id.png';
      expect(MediaService.thumbnailPath(path), 'user-id/entry-id/media-id_thumb.png');
    });

    test('works with uppercase extension', () {
      const path = 'user-id/entry-id/media-id.JPG';
      expect(MediaService.thumbnailPath(path), 'user-id/entry-id/media-id_thumb.JPG');
    });

    test('appends _thumb when there is no extension', () {
      const path = 'user-id/entry-id/media-id';
      expect(MediaService.thumbnailPath(path), 'user-id/entry-id/media-id_thumb');
    });

    test('handles path with multiple dots — only the last dot is used', () {
      const path = 'user-id/entry.2026/media-id.jpg';
      expect(MediaService.thumbnailPath(path), 'user-id/entry.2026/media-id_thumb.jpg');
    });

    test('is idempotent in structure — calling twice produces _thumb_thumb', () {
      // Clarifies the function does not guard against double-application.
      const path = 'a/b/c.jpg';
      final once = MediaService.thumbnailPath(path);
      final twice = MediaService.thumbnailPath(once);
      expect(twice, 'a/b/c_thumb_thumb.jpg');
    });
  });

  // ---------------------------------------------------------------------------
  // MediaService instance methods that do NOT require a logged-in user
  // ---------------------------------------------------------------------------

  group('MediaService', () {
    late MediaService service;

    setUp(() {
      service = MediaService(client: Supabase.instance.client);
    });

    test('can be instantiated with a SupabaseClient', () {
      expect(service, isA<MediaService>());
    });

    test('getThumbnailUrl returns the URL as-is when storagePath is an http URL', () {
      const url = 'https://example.com/photo.jpg';
      final result = service.getThumbnailUrl(url);
      expect(result, url);
    });

    test('getThumbnailUrl returns the URL as-is when storagePath starts with https', () {
      const url = 'https://images.unsplash.com/photo-123?w=800';
      final result = service.getThumbnailUrl(url);
      expect(result, url);
    });

    test('getPublicUrl returns the URL as-is when storagePath is an http URL', () {
      const url = 'http://cdn.example.com/image.jpg';
      final result = service.getPublicUrl(url);
      expect(result, url);
    });

    test('getPublicUrl returns the URL as-is when storagePath starts with https', () {
      const url = 'https://images.unsplash.com/photo-456';
      final result = service.getPublicUrl(url);
      expect(result, url);
    });

    test('getThumbnailUrl for a storage path returns a non-empty string', () {
      // With placeholder Supabase URL, getPublicUrl returns a constructed URL string.
      const path = 'user-id/entry-id/media-id.jpg';
      final result = service.getThumbnailUrl(path);
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('getPublicUrl for a storage path returns a non-empty string', () {
      const path = 'user-id/entry-id/media-id.jpg';
      final result = service.getPublicUrl(path);
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('getThumbnailUrl for storage path contains _thumb', () {
      // The thumbnail URL is built from thumbnailPath() so it must contain the suffix.
      const path = 'user-id/entry-id/media-id.jpg';
      final result = service.getThumbnailUrl(path);
      expect(result.contains('_thumb'), isTrue);
    });

    test('getSignedUrl throws when not authenticated (no current user)', () async {
      // Supabase is initialised with placeholder creds and no user session.
      // createSignedUrl will throw because the storage API call fails.
      expect(
        () => service.getSignedUrl('user-id/entry-id/media-id.jpg'),
        throwsA(anything),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // EntryMedia model — used extensively by MediaService
  // ---------------------------------------------------------------------------

  group('EntryMedia', () {
    final now = DateTime(2026, 3, 13, 12, 0);

    EntryMedia makeMedia({
      String id = 'media-id',
      String entryId = 'entry-id',
      String userId = 'user-id',
      String mediaType = 'photo',
      String storagePath = 'user-id/entry-id/media-id.jpg',
      int sortOrder = 0,
    }) {
      return EntryMedia(
        id: id,
        entryId: entryId,
        userId: userId,
        mediaType: mediaType,
        storagePath: storagePath,
        sortOrder: sortOrder,
        createdAt: now,
      );
    }

    test('can be constructed with required fields', () {
      final media = makeMedia();
      expect(media, isA<EntryMedia>());
    });

    test('encryptedMetadata defaults to null', () {
      final media = makeMedia();
      expect(media.encryptedMetadata, isNull);
    });

    test('sortOrder defaults to 0', () {
      final media = makeMedia();
      expect(media.sortOrder, 0);
    });

    test('equality is based on id and storagePath', () {
      final a = makeMedia(id: 'same-id', storagePath: 'path/same.jpg');
      final b = makeMedia(id: 'same-id', storagePath: 'path/same.jpg');
      expect(a, equals(b));
    });

    test('same id but different storagePath are not equal', () {
      final a = makeMedia(id: 'same-id', storagePath: 'path/a.jpg');
      final b = makeMedia(id: 'same-id', storagePath: 'path/b.jpg');
      expect(a, isNot(equals(b)));
    });

    test('different ids are not equal', () {
      final a = makeMedia(id: 'id-a');
      final b = makeMedia(id: 'id-b');
      expect(a, isNot(equals(b)));
    });

    test('hashCode is derived from id', () {
      final media = makeMedia(id: 'test-id');
      expect(media.hashCode, 'test-id'.hashCode);
    });

    test('toString includes id, entryId, and mediaType', () {
      final media = makeMedia();
      final s = media.toString();
      expect(s, contains('media-id'));
      expect(s, contains('entry-id'));
      expect(s, contains('photo'));
    });

    test('toMap serialises all fields correctly', () {
      final media = makeMedia();
      final map = media.toMap();
      expect(map['id'], 'media-id');
      expect(map['entry_id'], 'entry-id');
      expect(map['user_id'], 'user-id');
      expect(map['media_type'], 'photo');
      expect(map['storage_path'], 'user-id/entry-id/media-id.jpg');
      expect(map['sort_order'], 0);
      expect(map['encrypted_metadata'], isNull);
      expect(map['created_at'], now.toIso8601String());
    });

    test('fromMap round-trips through toMap', () {
      final original = makeMedia();
      final roundTripped = EntryMedia.fromMap(original.toMap());
      expect(roundTripped.id, original.id);
      expect(roundTripped.entryId, original.entryId);
      expect(roundTripped.userId, original.userId);
      expect(roundTripped.mediaType, original.mediaType);
      expect(roundTripped.storagePath, original.storagePath);
      expect(roundTripped.sortOrder, original.sortOrder);
      expect(roundTripped.encryptedMetadata, original.encryptedMetadata);
      expect(roundTripped.createdAt.toIso8601String(), now.toIso8601String());
    });

    test('fromMap parses sort_order from int', () {
      final map = makeMedia().toMap();
      map['sort_order'] = 3;
      final media = EntryMedia.fromMap(map);
      expect(media.sortOrder, 3);
    });

    test('fromMap treats missing sort_order as 0', () {
      final map = makeMedia().toMap();
      map['sort_order'] = null;
      final media = EntryMedia.fromMap(map);
      expect(media.sortOrder, 0);
    });

    test('copyWith changes only specified fields', () {
      final original = makeMedia();
      final copy = original.copyWith(mediaType: 'voice', sortOrder: 2);
      expect(copy.mediaType, 'voice');
      expect(copy.sortOrder, 2);
      // Unchanged fields
      expect(copy.id, original.id);
      expect(copy.entryId, original.entryId);
      expect(copy.storagePath, original.storagePath);
    });

    test('copyWith with no arguments returns equivalent object', () {
      final original = makeMedia();
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.mediaType, original.mediaType);
      expect(copy.storagePath, original.storagePath);
    });

    test('voice mediaType is preserved', () {
      final media = makeMedia(mediaType: 'voice');
      expect(media.mediaType, 'voice');
      expect(media.toMap()['media_type'], 'voice');
    });
  });
}
