import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Alignment;

import 'package:deardays/core/config/cdn_config.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';
import 'package:deardays/services/media/image_compressor.dart';
import 'package:deardays/core/domain/services/media_service_interface.dart';

/// Handles photo/voice upload to Supabase Storage and entry_media records.
class MediaService implements IMediaService {
  static const _bucketName = 'entry-media';
  static const _thumbSuffix = '_thumb';

  /// Maximum file size for photo uploads (10 MB).
  static const maxPhotoSizeBytes = 10 * 1024 * 1024;

  /// Maximum file size for audio uploads (50 MB).
  static const maxAudioSizeBytes = 50 * 1024 * 1024;

  final SupabaseClient _client;

  /// Signed URL cache entries older than this are evicted and re-fetched.
  static const _urlTtl = Duration(minutes: 50);

  /// In-memory cache of signed URLs keyed by storagePath.
  /// Each entry stores both the Future and the time it was cached.
  /// Prevents re-fetching the same URL when widgets rebuild (e.g. on scroll).
  /// Capped at [_maxCacheSize] entries; oldest entries evicted when full.
  static const _maxCacheSize = 200;
  final Map<String, (Future<String>, DateTime)> _signedUrlCache = {};

  MediaService({required SupabaseClient client}) : _client = client;

  String get _userId => _client.auth.currentUser?.id ?? (throw StateError('No authenticated user'));

  /// Uploads a photo file and creates an entry_media record.
  /// Also generates and uploads a thumbnail for timeline/gallery use.
  /// [focalAlignment] is persisted to [EntryMedia.encryptedMetadata] as JSON
  /// so it can be applied when displaying the photo on detail/book screens.
  /// Returns the created [EntryMedia].
  Future<EntryMedia> uploadPhoto({
    required String entryId,
    required String filePath,
    Alignment focalAlignment = Alignment.center,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    if (fileSize > maxPhotoSizeBytes) {
      throw MediaSizeLimitException(
        'Photo exceeds ${maxPhotoSizeBytes ~/ (1024 * 1024)} MB limit '
        '(${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );
    }
    await _validateImageMagicBytes(filePath);
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    // Normalize jpg → jpeg (Supabase Storage rejects 'image/jpg')
    final mimeExt = ext == 'jpg' ? 'jpeg' : ext;
    final mediaId = const Uuid().v4();
    final storagePath = '$_userId/$entryId/$mediaId.$ext';

    // Read bytes before async gap so file deletion can't affect the thumbnail upload.
    final fileBytes = await file.readAsBytes();

    // Upload full-size to Supabase Storage with retry (3 attempts, exponential backoff).
    Exception? lastUploadError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await _client.storage.from(_bucketName).upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            contentType: 'image/$mimeExt',
            upsert: attempt > 1, // upsert on retry to avoid duplicate key error
          ),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw MediaUploadTimeoutException('Photo upload timed out after 30 seconds (attempt $attempt).');
          },
        );
        lastUploadError = null;
        break; // success
      } catch (e) {
        lastUploadError = e is Exception ? e : Exception(e.toString());
        debugPrint('[MediaService] Upload attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    if (lastUploadError != null) throw lastUploadError;

    // H-01 FIX: Await thumbnail upload within its own try-catch (was fire-and-forget).
    // Non-critical: entry is saved without thumbnail if this fails.
    try {
      await _uploadThumbnail(fileBytes, entryId, mediaId, ext);
    } catch (e, st) {
      debugPrint('[MediaService] Thumbnail upload failed (non-critical): $e\n$st');
    }

    // Create entry_media record
    final now = DateTime.now().toUtc();
    final media = EntryMedia(
      id: mediaId,
      entryId: entryId,
      userId: _userId,
      mediaType: 'photo',
      storagePath: storagePath,
      encryptedMetadata: EntryMedia.encodeFocalAlignment(focalAlignment),
      sortOrder: 0,
      createdAt: now,
    );

    try {
      await _client.from('entry_media').insert(media.toMap());
    } catch (e) {
      // DB insert failed — delete the already-uploaded storage file to avoid orphans.
      // H-02 FIX: Log orphaned file if storage cleanup also fails.
      try {
        await _client.storage.from(_bucketName).remove([storagePath]);
      } catch (storageDeleteError) {
        debugPrint('[MediaService] ORPHANED FILE: $storagePath — DB insert failed and storage cleanup also failed: $storageDeleteError');
        // Best-effort orphan log for background cleanup
        try {
          await _client.from('storage_orphan_log').insert({
            'path': storagePath,
            'reason': 'db_insert_failed_cleanup_failed',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {} // Table may not exist — ignore
      }
      rethrow;
    }

    return media;
  }

  /// Uploads raw bytes as a photo (for web or in-memory images).
  /// Compresses the image before upload to reduce storage costs.
  Future<EntryMedia> uploadPhotoBytes({
    required String entryId,
    required Uint8List bytes,
    String ext = 'jpg',
  }) async {
    if (bytes.length > maxPhotoSizeBytes) {
      throw MediaSizeLimitException(
        'Photo exceeds ${maxPhotoSizeBytes ~/ (1024 * 1024)} MB limit '
        '(${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );
    }
    // Compress before upload to reduce storage and bandwidth costs
    final compressed = await ImageCompressor.compress(bytes);

    final mediaId = const Uuid().v4();
    final storagePath = '$_userId/$entryId/$mediaId.$ext';

    await _client.storage.from(_bucketName).uploadBinary(
      storagePath,
      compressed,
      fileOptions: FileOptions(
        contentType: 'image/$ext',
        upsert: false,
      ),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw MediaUploadTimeoutException('Photo upload timed out after 30 seconds.');
      },
    );

    final now = DateTime.now().toUtc();
    final media = EntryMedia(
      id: mediaId,
      entryId: entryId,
      userId: _userId,
      mediaType: 'photo',
      storagePath: storagePath,
      sortOrder: 0,
      createdAt: now,
    );

    try {
      await _client.from('entry_media').insert(media.toMap());
    } catch (e) {
      // DB insert failed — delete the already-uploaded storage file to avoid orphans.
      // H-02 FIX: Log orphaned file if storage cleanup also fails.
      try {
        await _client.storage.from(_bucketName).remove([storagePath]);
      } catch (storageDeleteError) {
        debugPrint('[MediaService] ORPHANED FILE: $storagePath — DB insert failed and storage cleanup also failed: $storageDeleteError');
        try {
          await _client.from('storage_orphan_log').insert({
            'path': storagePath,
            'reason': 'db_insert_failed_cleanup_failed',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {} // Table may not exist — ignore
      }
      rethrow;
    }

    return media;
  }

  /// Generates a thumbnail and uploads it alongside the original.
  /// Runs async without blocking the main upload flow.
  Future<void> _uploadThumbnail(
    Uint8List originalBytes,
    String entryId,
    String mediaId,
    String ext,
  ) async {
    try {
      final thumbBytes = await ImageCompressor.compress(
        originalBytes,
        maxDim: ImageCompressor.maxThumbnailDimension,
      );
      final thumbPath = '$_userId/$entryId/$mediaId$_thumbSuffix.$ext';
      await _client.storage.from(_bucketName).uploadBinary(
        thumbPath,
        thumbBytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: false,
        ),
      );
    } catch (e) {
      debugPrint('[MediaService] Thumbnail upload failed (non-fatal): $e');
    }
  }

  /// Returns the thumbnail storage path for a given media storage path.
  /// Thumbnail files are stored with a '_thumb' suffix before the extension.
  static String thumbnailPath(String storagePath) {
    final lastDot = storagePath.lastIndexOf('.');
    if (lastDot == -1) return '$storagePath$_thumbSuffix';
    return '${storagePath.substring(0, lastDot)}$_thumbSuffix${storagePath.substring(lastDot)}';
  }

  /// Returns the public URL for a thumbnail. Falls back to the original
  /// if the path is already a full URL (demo data).
  /// When CDN is configured, uses CDN thumbnail transforms for faster delivery.
  String getThumbnailUrl(String storagePath) {
    if (storagePath.startsWith('http')) return storagePath;
    try {
      if (CdnConfig.isEnabled) {
        final fullUrl = _client.storage.from(_bucketName).getPublicUrl(storagePath);
        return CdnConfig.thumbnailUrl(fullUrl);
      }
      return _client.storage.from(_bucketName).getPublicUrl(thumbnailPath(storagePath));
    } catch (e) {
      // CDN unavailable — fall back to direct Supabase public URL.
      debugPrint('[MediaService] getThumbnailUrl CDN error, falling back: $e');
      try {
        return _client.storage.from(_bucketName).getPublicUrl(storagePath);
      } catch (e2) {
        debugPrint('[MediaService] getThumbnailUrl fallback also failed: $e2');
        return storagePath; // last resort: return raw path
      }
    }
  }

  /// Removes the given paths from the signed URL cache.
  /// Call after replacing or deleting a photo so the next load fetches a fresh URL.
  void clearCachedUrls(List<String> paths) {
    for (final path in paths) {
      _signedUrlCache.remove(path);
    }
  }

  /// Returns a signed URL for a media item (valid for 1 hour).
  /// Results are cached in-memory so repeated calls for the same path
  /// (e.g. on scroll rebuild) reuse the existing Future without a new request.
  /// Cache entries older than [_urlTtl] (50 minutes) are evicted automatically.
  Future<String> getSignedUrl(String storagePath) {
    if (storagePath.startsWith('http')) return Future.value(storagePath);

    // Evict expired entry if present.
    final existing = _signedUrlCache[storagePath];
    if (existing != null) {
      final cachedAt = existing.$2;
      if (DateTime.now().difference(cachedAt) >= _urlTtl) {
        _signedUrlCache.remove(storagePath);
      }
    }

    if (!_signedUrlCache.containsKey(storagePath)) {
      // Evict oldest entries when cache exceeds max size (simple LRU by insert order).
      if (_signedUrlCache.length >= _maxCacheSize) {
        final oldest = _signedUrlCache.keys.first;
        _signedUrlCache.remove(oldest);
      }
      final future =
          _client.storage.from(_bucketName).createSignedUrl(storagePath, 3600);
      _signedUrlCache[storagePath] = (future, DateTime.now());
    }
    return _signedUrlCache[storagePath]!.$1;
  }

  /// Returns the public URL if the bucket is public, otherwise use signed URL.
  /// If storagePath is already a full URL (e.g. demo data), returns it as-is.
  /// When CDN is configured, rewrites URL to use CDN edge for lower latency.
  String getPublicUrl(String storagePath) {
    if (storagePath.startsWith('http')) return storagePath;
    final url = _client.storage.from(_bucketName).getPublicUrl(storagePath);
    return CdnConfig.rewriteUrl(url);
  }

  /// Deletes a media file from storage and removes the entry_media record.
  Future<void> deleteMedia(EntryMedia media) async {
    await _client.storage.from(_bucketName).remove([media.storagePath]);
    await _client
        .from('entry_media')
        .delete()
        .eq('id', media.id)
        .eq('user_id', _userId);
  }

  /// Validates a file by reading its magic bytes to confirm it is a known
  /// image format (JPEG, PNG, WebP, HEIC/HEIF). Throws [MediaInvalidTypeException]
  /// if the bytes do not match any supported format.
  Future<void> _validateImageMagicBytes(String filePath) async {
    final file = File(filePath);
    final bytes = await file.openRead(0, 12).expand((b) => b).take(12).toList();
    if (bytes.length < 4) {
      throw MediaInvalidTypeException('File is not a valid image.');
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47) return;
    // WebP: RIFF????WEBP (bytes 0-3 == RIFF, bytes 8-11 == WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) return;
    // HEIC/HEIF: ftyp box at offset 4 (bytes 4-7 == 'ftyp')
    if (bytes.length >= 8 &&
        bytes[4] == 0x66 && bytes[5] == 0x74 &&
        bytes[6] == 0x79 && bytes[7] == 0x70) return;
    throw MediaInvalidTypeException('File is not a valid image.');
  }

  /// Deletes all media for a given entry.
  Future<void> deleteAllMediaForEntry(String entryId) async {
    // Fetch all media records first
    final response = await _client
        .from('entry_media')
        .select('storage_path')
        .eq('entry_id', entryId)
        .eq('user_id', _userId);

    final paths = (response as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['storage_path'] as String?)
        .whereType<String>()
        .toList();

    if (paths.isNotEmpty) {
      await _client.storage.from(_bucketName).remove(paths);
    }

    await _client
        .from('entry_media')
        .delete()
        .eq('entry_id', entryId)
        .eq('user_id', _userId);
  }
}

/// Thrown when a media file exceeds the allowed size limit.
class MediaSizeLimitException implements Exception {
  final String message;
  const MediaSizeLimitException(this.message);

  @override
  String toString() => 'MediaSizeLimitException: $message';
}

/// Thrown when a photo upload exceeds the allowed time limit.
class MediaUploadTimeoutException implements Exception {
  final String message;
  const MediaUploadTimeoutException(this.message);

  @override
  String toString() => 'MediaUploadTimeoutException: $message';
}

/// Thrown when a file's magic bytes do not match a supported image format.
class MediaInvalidTypeException implements Exception {
  final String message;
  const MediaInvalidTypeException(this.message);

  @override
  String toString() => 'MediaInvalidTypeException: $message';
}
