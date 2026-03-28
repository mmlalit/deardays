import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Contract for journal entry data access.
///
/// Implementations: [JournalRepository] (Supabase), test mocks.
abstract class IJournalRepository {
  Future<List<JournalEntry>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? mood,
    int limit = 50,
    int offset = 0,
    List<String>? ids,
  });

  Future<JournalEntry?> getEntry(String id);

  Future<JournalEntry> createEntry(JournalEntry entry);

  Future<JournalEntry> updateEntry(JournalEntry entry);

  Future<void> deleteEntry(String id);

  Future<List<JournalEntry>> getEntriesByChapter(
    String chapterId, {
    int offset = 0,
    int limit = 200,
  });

  Future<void> updateEntryChapter(String entryId, String chapterId);

  Future<List<JournalEntry>> getOnThisDay({DateTime? date});

  Future<List<Map<String, String>>> getMoodsByDateRange({int days = 7});

  Future<Map<String, int>> getMoodStatsByRange({
    required DateTime start,
    required DateTime end,
  });

  Future<Map<String, int>> getMoodStats();

  Future<List<JournalEntry>> getEntriesByIds(List<String> ids);

  Future<int> getTotalEntries();
}
