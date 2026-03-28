import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:deardays/core/network/network_client.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/services/encryption/encryption_service.dart';
import 'package:deardays/services/connectivity/connectivity_service.dart';
import 'package:deardays/services/sync/offline_write_service.dart';
import 'package:deardays/services/sync/sync_operation.dart';
import 'package:deardays/core/domain/repositories/journal_repository_interface.dart';

class JournalRepository implements IJournalRepository {
  final SupabaseClient _client;
  final NetworkClient _network = NetworkClient();

  JournalRepository({required SupabaseClient client}) : _client = client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthenticationRequiredException();
    return id;
  }

  /// The table for both reads and writes.
  static const _readTable = 'journal_entries';
  static const _writeTable = 'journal_entries';

  // ---------------------------------------------------------------------------
  // E2E helpers
  // ---------------------------------------------------------------------------

  /// Returns the current in-memory E2E key, or null if E2E is not active.
  String? get _e2eKey => EncryptionService().currentKey;

  /// Encrypts a nullable string if E2E is active, otherwise returns it as-is.
  String? _enc(String? value) {
    final key = _e2eKey;
    if (key == null || value == null || value.isEmpty) return value;
    return EncryptionService().encryptText(value, key);
  }

  /// Decrypts a nullable string if E2E is active and the row is client-encrypted.
  String? _dec(String? value, bool isClientEncrypted) {
    final key = _e2eKey;
    if (key == null || !isClientEncrypted || value == null || value.isEmpty) {
      return value;
    }
    try {
      return EncryptionService().decryptText(value, key);
    } on EncryptionException catch (e) {
      debugPrint('[JournalRepository] Decryption failed: $e');
      return null; // Callers handle null as "content unavailable"
    }
  }

  /// Applies client-side encrypt/decrypt fields to a raw Supabase map before
  /// passing it to [JournalEntry.fromSupabaseMap].
  Map<String, dynamic> _decryptRow(Map<String, dynamic> row) {
    final isClientEncrypted = (row['is_client_encrypted'] as bool?) ?? false;
    if (!isClientEncrypted || _e2eKey == null) return row;
    return {
      ...row,
      'content': _dec(row['content'] as String?, isClientEncrypted),
      'raw_content': _dec(row['raw_content'] as String?, isClientEncrypted),
      'polished_content':
          _dec(row['polished_content'] as String?, isClientEncrypted),
      'location_name':
          _dec(row['location_name'] as String?, isClientEncrypted),
    };
  }

  /// Prepares the write map: encrypts content columns if E2E is active and
  /// sets is_client_encrypted accordingly.
  Map<String, dynamic> _prepareWriteMap(Map<String, dynamic> map) {
    final key = _e2eKey;
    if (key == null) return map;
    return {
      ...map,
      'content': _enc(map['content'] as String?),
      'raw_content': _enc(map['raw_content'] as String?),
      'polished_content': _enc(map['polished_content'] as String?),
      'location_name': _enc(map['location_name'] as String?),
      // TODO(M-24): Encrypt latitude/longitude — requires schema change
      // (doubles cannot be encrypted in place; need text columns or a single
      // encrypted JSON blob for location data).
      'is_client_encrypted': true,
    };
  }

  /// Fetches journal entries with optional filters and pagination.
  /// Uses a lightweight media select (id, media_type, storage_path) to reduce
  /// payload size for list/timeline views. Use [getEntry] for full media details.
  @override
  Future<List<JournalEntry>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? mood,
    int limit = 50,
    int offset = 0,
    List<String>? ids,
  }) async {
    return _network.query(() async {
      var query = _client
          .from(_readTable)
          .select('*, entry_media(id, entry_id, user_id, media_type, storage_path, sort_order, created_at)')
          .eq('user_id', _userId);

      if (ids != null && ids.isNotEmpty) {
        query = query.inFilter('id', ids);
      }
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
          .map((row) => JournalEntry.fromSupabaseMap(
              _decryptRow(row as Map<String, dynamic>)))
          .toList();
    });
  }

  /// Fetches a single journal entry by ID.
  @override
  Future<JournalEntry?> getEntry(String id) async {
    return _network.query(() async {
      final response = await _client
          .from(_readTable)
          .select('*, entry_media(*)')
          .eq('id', id)
          .eq('user_id', _userId)
          .maybeSingle();

      if (response == null) return null;

      return JournalEntry.fromSupabaseMap(_decryptRow(response));
    });
  }

  /// Creates a new journal entry. If E2E is active the content columns are
  /// encrypted client-side before upload; otherwise the DB trigger handles it.
  ///
  /// When the device is offline, the write is queued for later replay and a
  /// local-only entry (with a `local_` prefixed ID) is returned so the UI can
  /// show it immediately.
  @override
  Future<JournalEntry> createEntry(JournalEntry entry) async {
    if (!ConnectivityService().isOnline) {
      final map = _prepareWriteMap(entry.toSupabaseMap());
      await OfflineWriteService().write(
        tableName: _writeTable,
        type: SyncOperationType.create,
        payload: map,
        id: entry.id,
      );
      // Return the entry with a temporary local ID so the UI has something
      return entry.copyWith(id: 'local_${const Uuid().v4()}');
    }

    return _network.query(() async {
      final map = _prepareWriteMap(entry.toSupabaseMap());

      // Single round-trip: INSERT + SELECT with entry_media join.
      final response = await _client
          .from(_writeTable)
          .insert(map)
          .select('*, entry_media(*)')
          .maybeSingle();
      if (response == null) throw Exception('Entry insert failed — no row returned');

      return JournalEntry.fromSupabaseMap(_decryptRow(response));
    });
  }

  /// Updates an existing journal entry with E2E-aware encryption.
  ///
  /// When offline, the update is queued and the entry is returned as-is.
  @override
  Future<JournalEntry> updateEntry(JournalEntry entry) async {
    if (!ConnectivityService().isOnline) {
      final map = _prepareWriteMap(entry.toSupabaseMap(forUpdate: true));
      await OfflineWriteService().write(
        tableName: _writeTable,
        type: SyncOperationType.update,
        payload: map,
        id: entry.id,
      );
      return entry;
    }

    return _network.query(() async {
      final map = _prepareWriteMap(entry.toSupabaseMap(forUpdate: true));

      final response = await _client
          .from(_writeTable)
          .update(map)
          .eq('id', entry.id)
          .eq('user_id', _userId)
          .select('*, entry_media(*)')
          .maybeSingle();
      if (response == null) throw Exception('Entry updated but could not be retrieved');

      return JournalEntry.fromSupabaseMap(_decryptRow(response));
    });
  }

  /// Fetches entries for a chapter, ordered chronologically (oldest first).
  ///
  /// [offset] and [limit] support pagination for large chapters.
  /// Default limit is 200 — covers virtually all real chapters while
  /// preventing runaway queries on pathological data.
  @override
  Future<List<JournalEntry>> getEntriesByChapter(
    String chapterId, {
    int offset = 0,
    int limit = 200,
  }) async {
    return _network.query(() async {
      final response = await _client
          .from(_readTable)
          .select('*, entry_media(id, entry_id, user_id, media_type, storage_path, sort_order, created_at)')
          .eq('user_id', _userId)
          .eq('chapter_id', chapterId)
          .order('entry_date', ascending: true)
          .order('created_at', ascending: true)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((row) => JournalEntry.fromSupabaseMap(
              _decryptRow(row as Map<String, dynamic>)))
          .toList();
    });
  }

  /// Updates only the chapter_id of an entry (lightweight — no content re-encryption).
  @override
  Future<void> updateEntryChapter(String entryId, String chapterId) async {
    return _network.query(() async {
      await _client
          .from(_writeTable)
          .update({'chapter_id': chapterId})
          .eq('id', entryId)
          .eq('user_id', _userId);
    });
  }

  /// Deletes a journal entry by ID.
  ///
  /// When offline, the delete is queued for later replay.
  @override
  Future<void> deleteEntry(String id) async {
    if (!ConnectivityService().isOnline) {
      await OfflineWriteService().write(
        tableName: _writeTable,
        type: SyncOperationType.delete,
        payload: {'id': id, 'user_id': _userId},
        id: id,
      );
      return;
    }

    return _network.query(() async {
      await _client
          .from(_writeTable)
          .delete()
          .eq('id', id)
          .eq('user_id', _userId);
    });
  }

  /// Returns entries from the same calendar date in previous years.
  @override
  Future<List<JournalEntry>> getOnThisDay({DateTime? date}) async {
    return _network.query(() async {
      final target = date ?? DateTime.now();
      final monthDay =
          '${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';

      final response = await _client.rpc('get_on_this_day_entries', params: {
        'p_user_id': _userId,
        'p_month_day': monthDay,
      });

      return (response as List<dynamic>)
          .map((row) => JournalEntry.fromSupabaseMap(
              _decryptRow(row as Map<String, dynamic>)))
          .toList();
    });
  }

  /// Returns mood per day for the last [days] days.
  /// Result is a list of {date, mood} maps sorted by date ascending.
  @override
  Future<List<Map<String, String>>> getMoodsByDateRange({int days = 7}) async {
    return _network.query(() async {
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
    });
  }

  /// Returns mood stats for a given date range (server-side aggregation).
  @override
  Future<Map<String, int>> getMoodStatsByRange({
    required DateTime start,
    required DateTime end,
  }) async {
    return _network.query(() async {
      final response = await _client.rpc('get_mood_stats_by_range', params: {
        'p_user_id': _userId,
        'p_start': start.toIso8601String().split('T').first,
        'p_end': end.toIso8601String().split('T').first,
      });

      final rows = response as List<dynamic>;
      final stats = <String, int>{};
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        stats[map['mood'] as String] = (map['count'] as num).toInt();
      }
      return stats;
    });
  }

  /// Returns a map of mood to entry count (server-side aggregation).
  @override
  Future<Map<String, int>> getMoodStats() async {
    return _network.query(() async {
      final response = await _client.rpc('get_mood_stats', params: {
        'p_user_id': _userId,
      });

      final rows = response as List<dynamic>;
      final stats = <String, int>{};
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        stats[map['mood'] as String] = (map['count'] as num).toInt();
      }
      return stats;
    });
  }

  /// Fetches multiple entries by ID list (used by smart memory search to load
  /// entries returned by the memory-search edge function).
  @override
  Future<List<JournalEntry>> getEntriesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    return getEntries(ids: ids, limit: ids.length);
  }

  /// Returns the total number of journal entries for the current user.
  @override
  Future<int> getTotalEntries() async {
    return _network.query(() async {
      // CountOption.exact is used because .estimated ignores WHERE clauses and
      // returns the total table row count. The per-user index
      // idx_journal_entries_user_date makes exact count fast.
      final response = await _client
          .from(_writeTable)
          .select()
          .eq('user_id', _userId)
          .count(CountOption.exact);

      return response.count;
    });
  }
}

/// Thrown by [JournalRepository] when a method is called without an active session.
class AuthenticationRequiredException implements Exception {
  const AuthenticationRequiredException();

  @override
  String toString() => 'Authentication required. Please sign in.';
}
