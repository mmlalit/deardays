import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Shared constants and utilities for image compression.
///
/// Most compression is done at the ImagePicker level (maxWidth, maxHeight,
/// imageQuality). This class handles the uploadPhotoBytes path where raw
/// bytes arrive without prior compression.
class ImageCompressor {
  ImageCompressor._();

  /// Max dimension for journal entry photos (used by ImagePicker).
  static const int maxPhotoDimension = 1920;

  /// JPEG quality for journal entry photos (0-100).
  static const int photoQuality = 75;

  /// Max dimension for book cover images.
  static const int maxCoverDimension = 800;

  /// JPEG quality for book covers.
  static const int coverQuality = 80;

  /// Max dimension for profile avatars.
  static const int maxAvatarDimension = 512;

  /// JPEG quality for avatars.
  static const int avatarQuality = 80;

  /// Max dimension for thumbnails (timeline/gallery).
  static const int maxThumbnailDimension = 400;

  /// JPEG quality for thumbnails.
  static const int thumbnailQuality = 60;

  /// Compresses raw image bytes by decoding and re-encoding at a target size.
  /// Uses dart:ui which strips EXIF metadata as a side benefit.
  ///
  /// Returns compressed PNG bytes (dart:ui only supports PNG encoding).
  /// If the image is already smaller than [maxDim], it is still re-encoded
  /// to strip EXIF and normalize format.
  static Future<Uint8List> compress(
    Uint8List imageBytes, {
    int maxDim = maxPhotoDimension,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: maxDim,
        targetHeight: maxDim,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();

      if (byteData == null) return imageBytes;

      final compressed = byteData.buffer.asUint8List();

      // Only use compressed version if it's actually smaller
      if (compressed.length < imageBytes.length) {
        return compressed;
      }
      return imageBytes;
    } catch (e) {
      debugPrint('[ImageCompressor] Compression failed, using original: $e');
      return imageBytes;
    }
  }
}
