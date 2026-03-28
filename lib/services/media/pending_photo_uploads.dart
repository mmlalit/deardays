import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Alignment;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_service.dart';

/// Persists failed photo uploads so they can be retried when connectivity
/// is restored. Uses an unencrypted Hive box (only stores entry IDs and
/// local file paths — no sensitive content).
class PendingPhotoUploads {
  PendingPhotoUploads._();
  static final PendingPhotoUploads _instance = PendingPhotoUploads._();
  factory PendingPhotoUploads() => _instance;

  static const _boxName = 'pending_photo_uploads';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    if (kDebugMode) {
      debugPrint('[PendingPhotoUploads] ${_box!.length} pending.');
    }
  }

  /// Queue a failed photo upload for later retry.
  Future<void> add({
    required String entryId,
    required String filePath,
    required Alignment focalAlignment,
  }) async {
    final box = _box;
    if (box == null) return;

    final json = jsonEncode({
      'entryId': entryId,
      'filePath': filePath,
      'focalX': focalAlignment.x,
      'focalY': focalAlignment.y,
    });
    await box.put(entryId, json);
  }

  /// Remove a completed upload from the queue.
  Future<void> remove(String entryId) async {
    await _box?.delete(entryId);
  }

  /// Returns true if there are pending uploads.
  bool get hasPending => (_box?.isNotEmpty ?? false);

  /// Retry all pending photo uploads. Call when connectivity is restored.
  Future<void> retryAll() async {
    final box = _box;
    if (box == null || box.isEmpty) return;

    final media = MediaService(client: Supabase.instance.client);
    final keys = box.keys.cast<String>().toList();

    for (final key in keys) {
      final raw = box.get(key);
      if (raw == null) continue;

      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        await media.uploadPhoto(
          entryId: data['entryId'] as String,
          filePath: data['filePath'] as String,
          focalAlignment: Alignment(
            (data['focalX'] as num).toDouble(),
            (data['focalY'] as num).toDouble(),
          ),
        );
        await box.delete(key);
        if (kDebugMode) {
          debugPrint('[PendingPhotoUploads] Retried ${data['entryId']} OK.');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PendingPhotoUploads] Retry failed for $key: $e');
        }
        // Leave in queue for next retry cycle.
      }
    }
  }
}
