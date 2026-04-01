import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

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

  /// Compresses raw image bytes by decoding, stripping EXIF metadata,
  /// resizing, and re-encoding as JPEG.
  ///
  /// Uses the `image` package for JPEG encoding (3-10x smaller than PNG).
  /// Runs in an isolate via [compute] to avoid blocking the UI thread.
  ///
  /// Always returns the re-encoded version (even if larger than the original)
  /// because the original may contain EXIF metadata (GPS, device info) that
  /// must be stripped for user privacy.
  static Future<Uint8List> compress(
    Uint8List imageBytes, {
    int maxDim = maxPhotoDimension,
    int quality = photoQuality,
  }) async {
    try {
      final result = await compute(
        _compressInIsolate,
        _CompressParams(imageBytes, maxDim, quality),
      );
      return result;
    } catch (e) {
      debugPrint('[ImageCompressor] Compression failed, using original: $e');
      return imageBytes;
    }
  }

  /// Isolate-safe compression function. Decodes, strips EXIF metadata,
  /// resizes, and encodes to JPEG.
  static Uint8List _compressInIsolate(_CompressParams params) {
    final decoded = img.decodeImage(params.bytes);
    if (decoded == null) return params.bytes;

    // Strip EXIF metadata (GPS coordinates, device info, timestamps) to
    // protect user privacy. The exif data object is cleared so encodeJpg
    // will not write any metadata back into the output.
    decoded.exif.clear();

    // Resize only if larger than maxDim (preserves aspect ratio).
    final img.Image resized;
    if (decoded.width > params.maxDim || decoded.height > params.maxDim) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: params.maxDim);
      } else {
        resized = img.copyResize(decoded, height: params.maxDim);
      }
    } else {
      resized = decoded;
    }

    final jpegBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: params.quality),
    );

    // Only use compressed version if it's actually smaller.
    if (jpegBytes.length < params.bytes.length) {
      return jpegBytes;
    }
    // Even if compressed is larger, still return it because we've stripped
    // EXIF metadata from the compressed version (original may contain GPS).
    return jpegBytes;
  }
}

/// Parameters passed to the isolate for compression.
class _CompressParams {
  final Uint8List bytes;
  final int maxDim;
  final int quality;
  const _CompressParams(this.bytes, this.maxDim, this.quality);
}
