import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/core/providers/locale_provider.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// A single day's entry in the Life Book.
class LifeBookEntry {
  final DateTime date;
  final String? mood;
  final String rawText;
  final String? polishedText;
  final bool isPolishing;
  final int messageCount;

  const LifeBookEntry({
    required this.date,
    this.mood,
    required this.rawText,
    this.polishedText,
    this.isPolishing = false,
    this.messageCount = 0,
  });

  String get displayText => polishedText ?? rawText;
  bool get hasPolished => polishedText != null;
}

/// A chapter grouping entries by month.
class LifeBookChapter {
  final String title;
  final int year;
  final int month;
  final List<LifeBookEntry> entries;

  const LifeBookChapter({
    required this.title,
    required this.year,
    required this.month,
    required this.entries,
  });

  int get entryCount => entries.length;
  int get totalMessages =>
      entries.fold(0, (sum, e) => sum + e.messageCount);
}

/// Full state for the Life Book view.
class LifeBookState {
  final List<LifeBookChapter> chapters;
  final int? activeChapterIndex;
  final int? activeEntryIndex;
  final bool isLoading;

  const LifeBookState({
    this.chapters = const [],
    this.activeChapterIndex,
    this.activeEntryIndex,
    this.isLoading = true,
  });

  LifeBookState copyWith({
    List<LifeBookChapter>? chapters,
    int? activeChapterIndex,
    int? activeEntryIndex,
    bool? isLoading,
  }) {
    return LifeBookState(
      chapters: chapters ?? this.chapters,
      activeChapterIndex: activeChapterIndex ?? this.activeChapterIndex,
      activeEntryIndex: activeEntryIndex ?? this.activeEntryIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  LifeBookEntry? get activeEntry {
    if (activeChapterIndex == null || activeEntryIndex == null) return null;
    if (activeChapterIndex! >= chapters.length) return null;
    final ch = chapters[activeChapterIndex!];
    if (activeEntryIndex! >= ch.entries.length) return null;
    return ch.entries[activeEntryIndex!];
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class LifeBookNotifier extends StateNotifier<LifeBookState> {
  LifeBookNotifier(this._aiService, {this.language, this.writingStyle = 'memoir'})
      : super(const LifeBookState()) {
    _loadAllEntries();
  }

  final AiService _aiService;
  final String? language;
  final String writingStyle;

  static const _conversationsBox = 'checkin_conversations';
  static const _polishCacheBox = 'life_book_polish_cache';

  /// Opens a Hive box with encryption when available.
  static Future<Box> _openBox(String name) async {
    try {
      final cipher = LocalStorageService.instance.cipher;
      return await Hive.openBox(name, encryptionCipher: cipher);
    } catch (e, st) {
      debugPrint('[LifeBook] Encryption cipher failed: $e');
      if (kReleaseMode) {
        rethrow; // In production, don't silently expose data
      }
      // In debug, fall through to unencrypted for development convenience
      debugPrintStack(stackTrace: st, label: '[LifeBook] cipher stack');
      return await Hive.openBox(name);
    }
  }

  /// Load all conversation dates from Hive and group by month.
  Future<void> _loadAllEntries() async {
    final box = await _openBox(_conversationsBox);
    final cacheBox = await _openBox(_polishCacheBox);
    final keys = box.keys.cast<String>().toList();

    // Parse dates and sort newest first
    final dateEntries = <DateTime, Map<String, dynamic>>{};
    for (final key in keys) {
      try {
        final date = DateTime.parse(key);
        final raw = box.get(key);
        if (raw != null) {
          if (raw is! String) {
            debugPrint('[LifeBook] Hive value has wrong type for key $key, skipping');
            box.delete(key); // Remove corrupted entry
            continue;
          }
          dateEntries[date] = jsonDecode(raw) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    final sortedDates = dateEntries.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Group by year-month
    final chapterMap = <String, List<LifeBookEntry>>{};
    for (final date in sortedDates) {
      final data = dateEntries[date]!;
      final mood = data['mood'] as String?;
      final sections = (data['sections'] as List<dynamic>)
          .map((s) => ConversationSection.fromJson(s as Map<String, dynamic>))
          .toList();

      // Extract all user messages as raw text
      final userMessages = <String>[];
      int msgCount = 0;
      for (final section in sections) {
        for (final msg in section.messages) {
          msgCount++;
          if (msg.isUser) {
            userMessages.add(msg.text);
          }
        }
      }

      if (userMessages.isEmpty) continue;

      final rawText = userMessages.join('\n\n');
      final cacheKey = CheckInNotifier.dateKey(date);
      final cached = cacheBox.get(cacheKey) as String?;

      final entry = LifeBookEntry(
        date: date,
        mood: mood,
        rawText: rawText,
        polishedText: cached,
        messageCount: msgCount,
      );

      final monthKey = DateFormat('yyyy-MM').format(date);
      chapterMap.putIfAbsent(monthKey, () => []).add(entry);
    }

    // Build chapters
    final chapters = chapterMap.entries.map((e) {
      final date = DateTime.parse('${e.key}-01');
      final title = DateFormat('MMMM yyyy').format(date);
      return LifeBookChapter(
        title: title,
        year: date.year,
        month: date.month,
        entries: e.value,
      );
    }).toList();

    state = LifeBookState(
      chapters: chapters,
      activeChapterIndex: chapters.isNotEmpty ? 0 : null,
      activeEntryIndex: chapters.isNotEmpty && chapters.first.entries.isNotEmpty ? 0 : null,
      isLoading: false,
    );

    // Auto-polish the first entry if not already cached
    if (state.activeEntry != null && !state.activeEntry!.hasPolished) {
      _polishEntry(0, 0);
    }
  }

  void selectChapter(int index) {
    state = state.copyWith(
      activeChapterIndex: index,
      activeEntryIndex: 0,
    );
    final entry = state.activeEntry;
    if (entry != null && !entry.hasPolished) {
      _polishEntry(index, 0);
    }
  }

  void selectEntry(int chapterIndex, int entryIndex) {
    state = state.copyWith(
      activeChapterIndex: chapterIndex,
      activeEntryIndex: entryIndex,
    );
    final entry = state.activeEntry;
    if (entry != null && !entry.hasPolished) {
      _polishEntry(chapterIndex, entryIndex);
    }
  }

  /// Polish a specific entry via AiService and cache the result.
  Future<void> _polishEntry(int chapterIdx, int entryIdx) async {
    if (!_aiService.isConfigured) return;

    final chapters = [...state.chapters];
    if (chapterIdx >= chapters.length) return;
    final entries = [...chapters[chapterIdx].entries];
    if (entryIdx >= entries.length) return;

    final entry = entries[entryIdx];
    if (entry.hasPolished || entry.isPolishing) return;

    // Mark as polishing
    entries[entryIdx] = LifeBookEntry(
      date: entry.date,
      mood: entry.mood,
      rawText: entry.rawText,
      polishedText: null,
      isPolishing: true,
      messageCount: entry.messageCount,
    );
    chapters[chapterIdx] = LifeBookChapter(
      title: chapters[chapterIdx].title,
      year: chapters[chapterIdx].year,
      month: chapters[chapterIdx].month,
      entries: entries,
    );
    state = state.copyWith(chapters: chapters);

    try {
      final polished = await _aiService.polishNarrative(
        entry.rawText,
        style: writingStyle,
        language: language,
      );

      // Cache the result
      final cacheBox = await _openBox(_polishCacheBox);
      final cacheKey = CheckInNotifier.dateKey(entry.date);
      await cacheBox.put(cacheKey, polished);

      // Update state
      final updatedChapters = [...state.chapters];
      final updatedEntries = [...updatedChapters[chapterIdx].entries];
      updatedEntries[entryIdx] = LifeBookEntry(
        date: entry.date,
        mood: entry.mood,
        rawText: entry.rawText,
        polishedText: polished,
        isPolishing: false,
        messageCount: entry.messageCount,
      );
      updatedChapters[chapterIdx] = LifeBookChapter(
        title: updatedChapters[chapterIdx].title,
        year: updatedChapters[chapterIdx].year,
        month: updatedChapters[chapterIdx].month,
        entries: updatedEntries,
      );
      state = state.copyWith(chapters: updatedChapters);
    } catch (_) {
      // Polishing failed — revert isPolishing flag, show raw text
      final updatedChapters = [...state.chapters];
      final updatedEntries = [...updatedChapters[chapterIdx].entries];
      updatedEntries[entryIdx] = LifeBookEntry(
        date: entry.date,
        mood: entry.mood,
        rawText: entry.rawText,
        polishedText: null,
        isPolishing: false,
        messageCount: entry.messageCount,
      );
      updatedChapters[chapterIdx] = LifeBookChapter(
        title: updatedChapters[chapterIdx].title,
        year: updatedChapters[chapterIdx].year,
        month: updatedChapters[chapterIdx].month,
        entries: updatedEntries,
      );
      state = state.copyWith(chapters: updatedChapters);
    }
  }

  /// Force re-polish an entry (clears cache).
  Future<void> repolishEntry(int chapterIdx, int entryIdx) async {
    final chapters = state.chapters;
    if (chapterIdx >= chapters.length) return;
    final entries = chapters[chapterIdx].entries;
    if (entryIdx >= entries.length) return;

    // Clear cache
    final cacheBox = await _openBox(_polishCacheBox);
    final cacheKey = CheckInNotifier.dateKey(entries[entryIdx].date);
    await cacheBox.delete(cacheKey);

    // Reset polished text
    final updatedChapters = [...state.chapters];
    final updatedEntries = [...updatedChapters[chapterIdx].entries];
    final entry = updatedEntries[entryIdx];
    updatedEntries[entryIdx] = LifeBookEntry(
      date: entry.date,
      mood: entry.mood,
      rawText: entry.rawText,
      polishedText: null,
      isPolishing: false,
      messageCount: entry.messageCount,
    );
    updatedChapters[chapterIdx] = LifeBookChapter(
      title: updatedChapters[chapterIdx].title,
      year: updatedChapters[chapterIdx].year,
      month: updatedChapters[chapterIdx].month,
      entries: updatedEntries,
    );
    state = state.copyWith(chapters: updatedChapters);

    await _polishEntry(chapterIdx, entryIdx);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final lifeBookProvider =
    StateNotifierProvider<LifeBookNotifier, LifeBookState>((ref) {
  final language = ref.watch(localeProvider).languageName;
  return LifeBookNotifier(
    AiService(),
    language: language,
  );
});
