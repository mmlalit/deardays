import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareCardRenderer {
  static Future<Uint8List> renderToPng(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Shares the image via the platform share sheet.
  ///
  /// On Windows (where share_plus may not fully work), falls back to saving
  /// the image to the downloads folder and copying the path to clipboard.
  static Future<void> shareImage(
    Uint8List pngBytes, {
    String? subject,
  }) async {
    if (Platform.isWindows) {
      // Windows fallback: save to downloads and copy path to clipboard
      final path = await saveToGallery(pngBytes);
      await Clipboard.setData(ClipboardData(text: path));
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/deardays_share_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes);
    await Share.shareXFiles([XFile(file.path)], subject: subject);

    // Clean up temporary share image after sharing.
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Saves the PNG to the user's downloads directory (or temp as fallback).
  static Future<String> saveToGallery(Uint8List pngBytes) async {
    final dir =
        await getDownloadsDirectory() ?? await getTemporaryDirectory();
    final fileName = 'DearDays_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  /// Whether the current platform supports native share sheet.
  static bool get supportsNativeShare => !Platform.isWindows;
}
