import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Supabase persistence for check-in conversations.
/// Hive remains the primary local cache; this class syncs in the background
/// so conversations survive reinstalls and work across devices.
class CheckInRepository {
  final SupabaseClient _client;

  CheckInRepository({required SupabaseClient client}) : _client = client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Upsert today's (or any date's) conversation data to Supabase.
  /// Fire-and-forget — caller should not await unless it needs confirmation.
  Future<void> upsertConversation(
    String dateKey,
    Map<String, dynamic> data,
  ) async {
    final uid = _userId;
    if (uid == null) return;

    await _client.from('check_in_conversations').upsert(
      {
        'user_id': uid,
        'date_key': dateKey,
        'mood': data['mood'],
        'sections': data['sections'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,date_key',
    );
  }

  /// Fetch a single conversation by date key. Returns null if not found.
  Future<Map<String, dynamic>?> getConversation(String dateKey) async {
    final uid = _userId;
    if (uid == null) return null;

    final result = await _client
        .from('check_in_conversations')
        .select()
        .eq('user_id', uid)
        .eq('date_key', dateKey)
        .maybeSingle();

    return result;
  }

  /// Returns all date keys (YYYY-MM-DD) that have a synced conversation,
  /// newest first.
  Future<List<String>> getAvailableDateKeys() async {
    final uid = _userId;
    if (uid == null) return [];

    final result = await _client
        .from('check_in_conversations')
        .select('date_key')
        .eq('user_id', uid)
        .order('date_key', ascending: false);

    return (result as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['date_key'] as String)
        .toList();
  }
}
