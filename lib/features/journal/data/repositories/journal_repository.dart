import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';

class JournalRepository {
  final SupabaseClient _client;

  JournalRepository({required SupabaseClient client}) : _client = client;

  String get _userId => _client.auth.currentUser!.id;

  /// The view that auto-decrypts content columns server-side.
  static const _readTable = 'journal_entries_decrypted';

  /// The raw table — the DB trigger auto-encrypts on write.
  static const _writeTable = 'journal_entries';

  /// Fetches journal entries with optional filters and pagination.
  /// Uses a lightweight media select (id, media_type, storage_path) to reduce
  /// payload size for list/timeline views. Use [getEntry] for full media details.
  Future<List<JournalEntry>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? mood,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from(_readTable)
        .select('*, entry_media(id, entry_id, user_id, media_type, storage_path, sort_order, created_at)')
        .eq('user_id', _userId);

    if (startDate != null) {
      query = query.gte('entry_date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('entry_date', endDate.toIso8601String());
    }
    if (mood != null) {
      query = query.eq('mood', mood);
    }

    final response = await query
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => JournalEntry.fromSupabaseMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single journal entry by ID.
  Future<JournalEntry?> getEntry(String id) async {
    final response = await _client
        .from(_readTable)
        .select('*, entry_media(*)')
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) return null;

    return JournalEntry.fromSupabaseMap(response);
  }

  /// Creates a new journal entry. Content is sent as plaintext;
  /// the DB trigger encrypts it server-side before storage.
  Future<JournalEntry> createEntry(JournalEntry entry) async {
    final map = entry.toSupabaseMap();

    // Write to the raw table (trigger encrypts), then read back from
    // the decrypted view to return plaintext to the caller.
    final inserted = await _client
        .from(_writeTable)
        .insert(map)
        .select('id')
        .single();

    final response = await _client
        .from(_readTable)
        .select('*, entry_media(*)')
        .eq('id', inserted['id'] as String)
        .single();

    return JournalEntry.fromSupabaseMap(response);
  }

  /// Updates an existing journal entry. Content is sent as plaintext;
  /// the DB trigger re-encrypts it server-side.
  Future<JournalEntry> updateEntry(JournalEntry entry) async {
    final map = entry.toSupabaseMap();

    await _client
        .from(_writeTable)
        .update(map)
        .eq('id', entry.id)
        .eq('user_id', _userId);

    final response = await _client
        .from(_readTable)
        .select('*, entry_media(*)')
        .eq('id', entry.id)
        .single();

    return JournalEntry.fromSupabaseMap(response);
  }

  /// Deletes a journal entry by ID.
  Future<void> deleteEntry(String id) async {
    await _client
        .from(_writeTable)
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// Returns entries from the same calendar date in previous years.
  Future<List<JournalEntry>> getOnThisDay({DateTime? date}) async {
    final target = date ?? DateTime.now();
    final monthDay =
        '${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';

    // Supabase doesn't support date-part extraction in filters natively,
    // so we use an RPC function for "on this day" queries.
    final response = await _client.rpc('get_on_this_day_entries', params: {
      'p_user_id': _userId,
      'p_month_day': monthDay,
    });

    return (response as List<dynamic>)
        .map((row) => JournalEntry.fromSupabaseMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns mood per day for the last [days] days.
  /// Result is a list of {date, mood} maps sorted by date ascending.
  Future<List<Map<String, String>>> getMoodsByDateRange({int days = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    final startDate = DateTime(start.year, start.month, start.day);

    final response = await _client
        .from(_writeTable)
        .select('entry_date, mood')
        .eq('user_id', _userId)
        .gte('entry_date', startDate.toIso8601String())
        .not('mood', 'is', null)
        .order('entry_date', ascending: true);

    return (response as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      return {
        'date': map['entry_date'] as String,
        'mood': map['mood'] as String,
      };
    }).toList();
  }

  /// Returns mood stats for a given date range.
  Future<Map<String, int>> getMoodStatsByRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _client
        .from(_writeTable)
        .select('mood')
        .eq('user_id', _userId)
        .gte('entry_date', start.toIso8601String())
        .lte('entry_date', end.toIso8601String())
        .not('mood', 'is', null);

    final rows = response as List<dynamic>;
    final stats = <String, int>{};

    for (final row in rows) {
      final mood = (row as Map<String, dynamic>)['mood'] as String;
      stats[mood] = (stats[mood] ?? 0) + 1;
    }

    return stats;
  }

  /// Returns a map of mood to entry count.
  Future<Map<String, int>> getMoodStats() async {
    final response = await _client
        .from(_writeTable)
        .select('mood')
        .eq('user_id', _userId)
        .not('mood', 'is', null);

    final rows = response as List<dynamic>;
    final stats = <String, int>{};

    for (final row in rows) {
      final mood = (row as Map<String, dynamic>)['mood'] as String;
      stats[mood] = (stats[mood] ?? 0) + 1;
    }

    return stats;
  }

  /// Returns the total number of journal entries for the current user.
  Future<int> getTotalEntries() async {
    final response = await _client
        .from(_writeTable)
        .select('id')
        .eq('user_id', _userId)
        .count(CountOption.exact);

    return response.count;
  }
}
