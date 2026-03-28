import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/network/network_client.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';
import 'package:deardays/services/encryption/encryption_service.dart';

/// Handles Supabase persistence for draft entries.
/// Hive remains the primary local cache; this class syncs in the background
/// so drafts survive reinstalls and work across devices.
class DraftRepository {
  final SupabaseClient _client;
  final NetworkClient _network = NetworkClient();

  DraftRepository({required SupabaseClient client}) : _client = client;

  String? get _userId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // E2E encryption helpers (mirrors JournalRepository pattern)
  // ---------------------------------------------------------------------------

  String? get _e2eKey => EncryptionService().currentKey;

  String? _enc(String? value) {
    final key = _e2eKey;
    if (key == null || value == null || value.isEmpty) return value;
    return EncryptionService().encryptText(value, key);
  }

  String? _dec(String? value, bool isClientEncrypted) {
    final key = _e2eKey;
    if (key == null || !isClientEncrypted || value == null || value.isEmpty) {
      return value;
    }
    try {
      return EncryptionService().decryptText(value, key);
    } on EncryptionException catch (e) {
      debugPrint('[DraftRepository] Decryption failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _encryptMap(Map<String, dynamic> map) {
    final key = _e2eKey;
    if (key == null) return map;
    return {
      ...map,
      'raw_text': _enc(map['raw_text'] as String?),
      'cleaned_text': _enc(map['cleaned_text'] as String?),
      'polished_text': _enc(map['polished_text'] as String?),
      'generated_title': _enc(map['generated_title'] as String?),
      'location_name': _enc(map['location_name'] as String?),
      'is_client_encrypted': true,
    };
  }

  Map<String, dynamic> _decryptRow(Map<String, dynamic> row) {
    final isClientEncrypted = (row['is_client_encrypted'] as bool?) ?? false;
    if (!isClientEncrypted || _e2eKey == null) return row;
    return {
      ...row,
      'raw_text': _dec(row['raw_text'] as String?, isClientEncrypted),
      'cleaned_text': _dec(row['cleaned_text'] as String?, isClientEncrypted),
      'polished_text': _dec(row['polished_text'] as String?, isClientEncrypted),
      'generated_title': _dec(row['generated_title'] as String?, isClientEncrypted),
      'location_name': _dec(row['location_name'] as String?, isClientEncrypted),
    };
  }

  /// Upsert a draft to Supabase. Fire-and-forget from the caller.
  /// If E2E encryption is active, text fields are encrypted before writing.
  Future<void> upsertDraft(DraftEntry draft) async {
    final uid = _userId;
    if (uid == null) return;

    final map = _encryptMap(draft.toSupabaseMap());
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
              DraftEntry.fromSupabaseMap(_decryptRow(row as Map<String, dynamic>)))
          .toList();
    } catch (e) {
      debugPrint('[DraftRepository] getRemoteDrafts failed: $e');
      return [];
    }
  }
}
