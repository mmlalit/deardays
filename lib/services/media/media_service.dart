import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';

import 'package:deardays/features/journal/data/models/entry_media.dart';
import 'package:deardays/services/media/image_compressor.dart';

/// Handles photo/voice upload to Supabase Storage and entry_media records.
class MediaService {
  static const _bucketName = 'entry-media';
  static const _thumbSuffix = '_thumb';

  final SupabaseClient _client;

  MediaService({required SupabaseClient client}) : _client = client;

  String get _userId => _client.auth.currentUser!.id;

  /// Uploads a photo file and creates an entry_media record.
  /// Also generates and uploads a thumbnail for timeline/gallery use.
  /// Returns the created [EntryMedia].
  Future<EntryMedia> uploadPhoto({
    required String entryId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    final mediaId = const Uuid().v4();
    final storagePath = '$_userId/$entryId/$mediaId.$ext';

    // Upload full-size to Supabase Storage
    await _client.storage.from(_bucketName).upload(
      storagePath,
      file,
      fileOptions: FileOptions(
        contentType: 'image/$ext',
        upsert: false,
      ),
    );

    // Generate and upload thumbnail (fire-and-forget, don't block)
    _uploadThumbnail(file.readAsBytesSync(), entryId, mediaId, ext);

    // Create entry_media record
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

    await _client.from('entry_media').insert(media.toMap());

    return media;
  }

  /// Uploads raw bytes as a photo (for web or in-memory images).
  /// Compresses the image before upload to reduce storage costs.
  Future<EntryMedia> uploadPhotoBytes({
    required String entryId,
    required Uint8List bytes,
    String ext = 'jpg',
  }) async {
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

    await _client.from('entry_media').insert(media.toMap());

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
  String getThumbnailUrl(String storagePath) {
    if (storagePath.startsWith('http')) return storagePath;
    return _client.storage.from(_bucketName).getPublicUrl(thumbnailPath(storagePath));
  }

  /// Returns a signed URL for a media item (valid for 1 hour).
  Future<String> getSignedUrl(String storagePath) async {
    final url = await _client.storage
        .from(_bucketName)
        .createSignedUrl(storagePath, 3600);
    return url;
  }

  /// Returns the public URL if the bucket is public, otherwise use signed URL.
  /// If storagePath is already a full URL (e.g. demo data), returns it as-is.
  String getPublicUrl(String storagePath) {
    if (storagePath.startsWith('http')) return storagePath;
    return _client.storage.from(_bucketName).getPublicUrl(storagePath);
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

  /// Deletes all media for a given entry.
  Future<void> deleteAllMediaForEntry(String entryId) async {
    // Fetch all media records first
    final response = await _client
        .from('entry_media')
        .select('storage_path')
        .eq('entry_id', entryId)
        .eq('user_id', _userId);

    final paths = (response as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['storage_path'] as String)
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
