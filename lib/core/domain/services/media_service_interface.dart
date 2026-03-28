import 'package:flutter/material.dart' show Alignment;
import 'package:flutter/foundation.dart' show Uint8List;

import 'package:deardays/features/journal/data/models/entry_media.dart';

/// Contract for media upload and URL services.
///
/// Implementations: [MediaService] (Supabase Storage), test mocks.
abstract class IMediaService {
  Future<EntryMedia> uploadPhoto({
    required String entryId,
    required String filePath,
    Alignment focalAlignment = Alignment.center,
  });

  Future<EntryMedia> uploadPhotoBytes({
    required String entryId,
    required Uint8List bytes,
    String ext = 'jpg',
  });

  Future<String> getSignedUrl(String storagePath);

  String getPublicUrl(String storagePath);

  String getThumbnailUrl(String storagePath);

  Future<void> deleteMedia(EntryMedia media);

  Future<void> deleteAllMediaForEntry(String entryId);

  void clearCachedUrls(List<String> paths);
}
