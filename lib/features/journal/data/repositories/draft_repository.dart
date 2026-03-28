import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/network/network_client.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';

/// Handles Supabase persistence for draft entries.
/// Hive remains the primary local cache; this class syncs in the background
/// so drafts survive reinstalls and work across devices.
class DraftRepository {
  final SupabaseClient _client;
  final NetworkClient _network = NetworkClient();

  DraftRepository({required SupabaseClient client}) : _client = client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Upsert a draft to Supabase. Fire-and-forget from the caller.
  Future<void> upsertDraft(DraftEntry draft) async {
    final uid = _userId;
    if (uid == null) return;

    final map = draft.toSupabaseMap();
    map['user_id'] = uid;

    try {
      await _network.query(() => _client
          .from('drafts')
          .upsert(map, onConflict: 'id'));
    } catch (e) {
      debugPrint('[DraftRepository] upsert failed: $e');
    }
  }

  /// Delete a draft from Supabase.
  Future<void> deleteDraft(String id) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      await _network.query(() => _client
          .from('drafts')
          .delete()
          .eq('id', id)
          .eq('user_id', uid));
    } catch (e) {
      debugPrint('[DraftRepository] delete failed: $e');
    }
  }

  /// Fetch all remote drafts for the current user (for pull-sync on login).
  Future<List<DraftEntry>> getRemoteDrafts() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final result = await _network.query(() => _client
          .from('drafts')
          .select()
          .eq('user_id', uid)
          .order('saved_at', ascending: false));

      return (result as List)
          .map((row) =>
              DraftEntry.fromSupabaseMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DraftRepository] getRemoteDrafts failed: $e');
      return [];
    }
  }
}
