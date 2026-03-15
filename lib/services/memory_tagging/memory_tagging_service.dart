import 'package:flutter/foundation.dart';
import 'package:deardays/services/ai/ai_service.dart';

/// Fire-and-forget service that triggers the ai-tag edge function after a
/// journal entry is successfully saved online.
///
/// Called with [unawaited()] so it never blocks the save flow.
/// Failures are logged but never surfaced to the user.
class MemoryTaggingService {
  MemoryTaggingService._internal();

  static final MemoryTaggingService _instance = MemoryTaggingService._internal();
  static MemoryTaggingService get instance => _instance;
  factory MemoryTaggingService() => _instance;

  final _aiService = AiService();

  /// Sends the entry content to the ai-tag edge function for async tagging.
  /// This method returns immediately — the HTTP call happens in the background.
  Future<void> tagEntry({
    required String entryId,
    required String content,
  }) async {
    if (!_aiService.isConfigured) return;
    if (content.trim().isEmpty) return;

    try {
      await _aiService.tagEntry(entryId: entryId, content: content);
      if (kDebugMode) {
        debugPrint('[MemoryTaggingService] Tagged entry $entryId');
      }
    } catch (e) {
      // Non-fatal: tagging failure does NOT affect the saved entry
      if (kDebugMode) {
        debugPrint('[MemoryTaggingService] Tagging failed for $entryId: $e');
      }
    }
  }
}
