import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/ai/mood_detection_service.dart';
import 'package:deardays/services/ai/highlight_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Manages offline-first AI processing for journal entries.
///
/// Flow:
/// 1. User saves entry → immediate local analysis (mood, title, highlights) — FREE
/// 2. Entry queued for server AI (polish, themes) — runs when online
/// 3. Server results arrive → update entry in DB + UI
///
/// This gives the user instant feedback while expensive AI runs async.
class OfflineAiQueue {
  OfflineAiQueue._internal();
  static final OfflineAiQueue _instance = OfflineAiQueue._internal();
  factory OfflineAiQueue() => _instance;

  static const String _boxName = 'ai_queue';
  Box<String>? _box;

  final _moodService = MoodDetectionService();
  final _highlightService = HighlightService();

  /// Initialize the queue. Call after Hive.initFlutter().
  Future<void> init() async {
    final cipher = LocalStorageService().cipher;
    _box = await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    if (kDebugMode) {
      debugPrint('[OfflineAiQueue] ${_box!.length} pending items');
    }
  }

  @visibleForTesting
  Future<void> initForTesting() async {
    _box = await Hive.openBox<String>(
        '${_boxName}_test_${DateTime.now().millisecondsSinceEpoch}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 1: Local analysis (instant, free, no network)
  // ─────────────────────────────────────────────────────────────────────────

  /// Performs instant on-device analysis of the entry text.
  /// Returns a [LocalAnalysisResult] with mood, title, and highlight.
  LocalAnalysisResult analyzeLocally(String text) {
    final mood = _moodService.detectMood(text);
    final confidence = _moodService.getConfidence(text, mood);
    final title = _extractTitle(text);
    final highlight = _extractHighlightFromText(text);

    if (kDebugMode) {
      debugPrint('[OfflineAiQueue] Local analysis: mood=$mood (${(confidence * 100).round()}%), title=$title');
    }

    return LocalAnalysisResult(
      mood: mood,
      moodConfidence: confidence,
      title: title,
      highlightQuote: highlight,
    );
  }

  String _extractTitle(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled';

    final first = lines.first.trim();
    // If first line is short (likely a title) and there's more content
    if (first.length < 60 && lines.length > 1) return first;

    // Otherwise, extract first meaningful phrase
    final words = first.split(RegExp(r'\s+')).take(8).join(' ');
    return words.length > 50 ? '${words.substring(0, 47)}...' : words;
  }

  String? _extractHighlightFromText(String text) {
    final entry = JournalEntry(
      id: 'temp',
      userId: 'temp',
      content: text,
      entryDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return _highlightService.extractHighlight(entry);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 2: Server queue (runs when online)
  // ─────────────────────────────────────────────────────────────────────────

  /// Enqueue an entry for server-side AI processing (polish, themes, etc).
  Future<void> enqueue(AiQueueItem item) async {
    if (_box == null || !_box!.isOpen) {
      // M-06: don't silently swallow — callers should know queue is not ready
      debugPrint('[OfflineAiQueue] WARNING: Queue not initialized, cannot enqueue ${item.entryId}');
      throw StateError('OfflineAiQueue not initialized. Call init() first.');
    }
    final key = '${item.createdAt.millisecondsSinceEpoch}_${item.entryId}';
    await _box!.put(key, jsonEncode(item.toJson()));
    if (kDebugMode) {
      debugPrint('[OfflineAiQueue] Queued: ${item.operation.name} for ${item.entryId}');
    }
  }

  /// Remove a completed item.
  Future<void> dequeue(String key) async {
    _ensureOpen();
    await _box!.delete(key);
  }

  /// All pending queue items in FIFO order.
  List<MapEntry<String, AiQueueItem>> getPending() {
    _ensureOpen();
    final entries = <MapEntry<String, AiQueueItem>>[];
    for (final key in _box!.keys.cast<String>()) {
      try {
        final json = jsonDecode(_box!.get(key)!) as Map<String, dynamic>;
        entries.add(MapEntry(key, AiQueueItem.fromJson(json)));
      } catch (_) {
        // Skip malformed entries
      }
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  /// Process all pending items. Call when connectivity is restored.
  Future<ProcessingReport> processQueue(AiService aiService) async {
    final pending = getPending();
    if (pending.isEmpty) return const ProcessingReport();

    int succeeded = 0;
    int failed = 0;
    final results = <String, ServerAnalysisResult>{};

    for (final entry in pending) {
      try {
        final item = entry.value;
        final result = await _processItem(aiService, item);
        if (result != null) {
          results[item.entryId] = result;
        }
        await dequeue(entry.key);
        succeeded++;
      } catch (e) {
        failed++;
        if (kDebugMode) {
          debugPrint('[OfflineAiQueue] Failed: ${entry.value.entryId} — $e');
        }
        // Don't dequeue — will retry next time
      }
    }

    if (kDebugMode) {
      debugPrint('[OfflineAiQueue] Processed: $succeeded ok, $failed failed');
    }

    return ProcessingReport(
      succeeded: succeeded,
      failed: failed,
      results: results,
    );
  }

  Future<ServerAnalysisResult?> _processItem(
      AiService aiService, AiQueueItem item) async {
    switch (item.operation) {
      case QueueOperation.polish:
        final polished = await aiService.polishNarrative(item.text);
        return ServerAnalysisResult(polishedText: polished);

      case QueueOperation.lightPolish:
        final cleaned = await aiService.lightPolish(item.text);
        return ServerAnalysisResult(cleanedText: cleaned);

      case QueueOperation.analyze:
        final result = await aiService.analyzeEntries([item.text]);
        return ServerAnalysisResult(
          themes: List<String>.from(result['themes'] as List? ?? []),
          summary: result['summary'] as String?,
        );
    }
  }

  /// Number of pending items.
  int get pendingCount {
    if (_box == null || !_box!.isOpen) return 0;
    return _box!.length;
  }

  /// Removes queue items older than [maxAge] that were never processed.
  /// Call at startup to prevent unbounded disk growth from stalled entries.
  Future<int> pruneStale({Duration maxAge = const Duration(days: 30)}) async {
    _ensureOpen();
    final cutoff = DateTime.now().subtract(maxAge);
    final toDelete = <String>[];
    for (final key in _box!.keys.cast<String>()) {
      try {
        final json = jsonDecode(_box!.get(key)!) as Map<String, dynamic>;
        final created = DateTime.parse(json['created_at'] as String);
        if (created.isBefore(cutoff)) toDelete.add(key);
      } catch (_) {
        toDelete.add(key); // malformed — remove
      }
    }
    for (final key in toDelete) {
      await _box!.delete(key);
    }
    if (kDebugMode && toDelete.isNotEmpty) {
      debugPrint('[OfflineAiQueue] Pruned ${toDelete.length} stale items');
    }
    return toDelete.length;
  }

  /// Clear all pending items (for testing / account switch).
  Future<void> clear() async {
    _ensureOpen();
    await _box!.clear();
  }

  void _ensureOpen() {
    if (_box == null || !_box!.isOpen) {
      throw StateError('OfflineAiQueue not initialized. Call init() first.');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class LocalAnalysisResult {
  final String mood;
  final double moodConfidence;
  final String title;
  final String? highlightQuote;

  const LocalAnalysisResult({
    required this.mood,
    required this.moodConfidence,
    required this.title,
    this.highlightQuote,
  });
}

class ServerAnalysisResult {
  final String? polishedText;
  final String? cleanedText;
  final List<String>? themes;
  final String? summary;

  const ServerAnalysisResult({
    this.polishedText,
    this.cleanedText,
    this.themes,
    this.summary,
  });
}

enum QueueOperation { polish, lightPolish, analyze }

class AiQueueItem {
  final String entryId;
  final String text;
  final QueueOperation operation;
  final DateTime createdAt;
  final int retryCount;

  const AiQueueItem({
    required this.entryId,
    required this.text,
    required this.operation,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'entry_id': entryId,
        'text': text,
        'operation': operation.name,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
      };

  factory AiQueueItem.fromJson(Map<String, dynamic> json) => AiQueueItem(
        entryId: json['entry_id'] as String,
        text: json['text'] as String,
        operation: QueueOperation.values.firstWhere(
          (o) => o.name == json['operation'],
          orElse: () => QueueOperation.analyze,
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
        retryCount: json['retry_count'] as int? ?? 0,
      );

  AiQueueItem copyWith({int? retryCount}) => AiQueueItem(
        entryId: entryId,
        text: text,
        operation: operation,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
      );
}

class ProcessingReport {
  final int succeeded;
  final int failed;
  final Map<String, ServerAnalysisResult> results;

  const ProcessingReport({
    this.succeeded = 0,
    this.failed = 0,
    this.results = const {},
  });
}
