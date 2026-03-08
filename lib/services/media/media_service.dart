import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import 'package:deardays/features/journal/data/models/entry_media.dart';

/// Handles photo/voice upload to Supabase Storage and entry_media records.
class MediaService {
  static const _bucketName = 'entry-media';

  final SupabaseClient _client;

  MediaService({required SupabaseClient client}) : _client = client;

  String get _userId => _client.auth.currentUser!.id;

  /// Uploads a photo file and creates an entry_media record.
  /// Returns the created [EntryMedia].
  Future<EntryMedia> uploadPhoto({
    required String entryId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    final mediaId = const Uuid().v4();
    final storagePath = '$_userId/$entryId/$mediaId.$ext';

    // Upload to Supabase Storage
    await _client.storage.from(_bucketName).upload(
      storagePath,
      file,
      fileOptions: FileOptions(
        contentType: 'image/$ext',
        upsert: false,
      ),
    );

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
  Future<EntryMedia> uploadPhotoBytes({
    required String entryId,
    required Uint8List bytes,
    String ext = 'jpg',
  }) async {
    final mediaId = const Uuid().v4();
    final storagePath = '$_userId/$entryId/$mediaId.$ext';

    await _client.storage.from(_bucketName).uploadBinary(
      storagePath,
      bytes,
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

  /// Returns a signed URL for a media item (valid for 1 hour).
  Future<String> getSignedUrl(String storagePath) async {
    final url = await _client.storage
        .from(_bucketName)
        .createSignedUrl(storagePath, 3600);
    return url;
  }

  /// Returns the public URL if the bucket is public, otherwise use signed URL.
  String getPublicUrl(String storagePath) {
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
