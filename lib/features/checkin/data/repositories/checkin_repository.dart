import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/network/network_client.dart';
import 'package:deardays/services/encryption/encryption_service.dart';

/// Handles Supabase persistence for check-in conversations.
/// Hive remains the primary local cache; this class syncs in the background
/// so conversations survive reinstalls and work across devices.
class CheckInRepository {
  final SupabaseClient _client;
  final NetworkClient _network = NetworkClient();

  CheckInRepository({required SupabaseClient client}) : _client = client;

  String? get _userId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // E2E encryption helpers (mirrors JournalRepository pattern)
  // ---------------------------------------------------------------------------

  String? get _e2eKey => EncryptionService().currentKey;

  /// Encrypts a string if E2E is active, otherwise returns it as-is.
  String? _enc(String? value) {
    final key = _e2eKey;
    if (key == null || value == null || value.isEmpty) return value;
    return EncryptionService().encryptText(value, key);
  }

  /// Decrypts a string if E2E is active and the row is client-encrypted.
  String? _dec(String? value, bool isClientEncrypted) {
    final key = _e2eKey;
    if (key == null || !isClientEncrypted || value == null || value.isEmpty) {
      return value;
    }
    try {
      return EncryptionService().decryptText(value, key);
    } on EncryptionException catch (e) {
      debugPrint('[CheckInRepository] Decryption failed: $e');
      return null;
    }
  }

  /// Upsert today's (or any date's) conversation data to Supabase.
  /// Fire-and-forget — caller should not await unless it needs confirmation.
  /// If E2E encryption is active, the sections JSON is encrypted before writing.
  Future<void> upsertConversation(
    String dateKey,
    Map<String, dynamic> data,
  ) async {
    final uid = _userId;
    if (uid == null) return;

    // Encrypt sections JSON if E2E is active
    final sectionsRaw = data['sections'];
    final sectionsJson = sectionsRaw is String ? sectionsRaw : jsonEncode(sectionsRaw);
    final isEncrypted = _e2eKey != null;
    final sectionsValue = isEncrypted ? _enc(sectionsJson) : sectionsRaw;

    await _network.query(() => _client.from('check_in_conversations').upsert(
      {
        'user_id': uid,
        'date_key': dateKey,
        // Mood is intentionally left unencrypted: it's needed server-side for
        // aggregate mood-trend queries (weekly/monthly stats) that run without
        // the client-side E2E key. The mood value is a single generic word
        // (great/good/okay/low/tough) with minimal PII risk.
        'mood': data['mood'],
        'sections': sectionsValue,
        'is_client_encrypted': isEncrypted,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,date_key',
    ));
  }

  /// Fetch a single conversation by date key. Returns null if not found.
  /// If the row is client-encrypted, decrypts the sections before returning.
  Future<Map<String, dynamic>?> getConversation(String dateKey) async {
    final uid = _userId;
    if (uid == null) return null;

    final result = await _network.query(() => _client
        .from('check_in_conversations')
        .select()
        .eq('user_id', uid)
        .eq('date_key', dateKey)
        .maybeSingle());

    if (result == null) return result;

    // Decrypt sections if needed
    final isEncrypted = (result['is_client_encrypted'] as bool?) ?? false;
    if (isEncrypted && result['sections'] is String) {
      final decrypted = _dec(result['sections'] as String, true);
      if (decrypted != null) {
        result['sections'] = jsonDecode(decrypted);
      }
    }

    return result;
  }

  /// Returns all date keys (YYYY-MM-DD) that have a synced conversation,
  /// newest first.
  Future<List<String>> getAvailableDateKeys() async {
    final uid = _userId;
    if (uid == null) return [];

    final result = await _network.query(() => _client
        .from('check_in_conversations')
        .select('date_key')
        .eq('user_id', uid)
        .order('date_key', ascending: false));

    return (result as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['date_key'] as String)
        .toList();
  }
}
