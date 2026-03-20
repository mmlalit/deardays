import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';

class SharingRepository {
  final SupabaseClient _client;
  SharingRepository({required SupabaseClient client}) : _client = client;

  String? get _userId => _client.auth.currentUser?.id;

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: create a share token for a memory
  // ─────────────────────────────────────────────────────────────────────────

  Future<MemoryShare> createShare(String memoryId) async {
    final row = await _client
        .from('memory_shares')
        .insert({'memory_id': memoryId, 'sharer_id': _userId})
        .select()
        .single();
    return MemoryShare.fromMap(row);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token lookup — called by RequestAccessScreen (may be unauthenticated)
  // Returns minimal share info; full content only after approval
  // ─────────────────────────────────────────────────────────────────────────

  Future<MemoryShare?> getShareByToken(String token) async {
    final rows = await _client
        .from('memory_shares')
        .select()
        .eq('token', token)
        .limit(1);
    if (rows.isEmpty) return null;
    return MemoryShare.fromMap(rows.first);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mum: submit access request
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> requestAccess({
    required String shareId,
    required String recipientName,
    String? recipientId,
  }) async {
    await _client.from('memory_shares').update({
      'recipient_name': recipientName.trim(),
      'recipient_id':   recipientId,
      'requested_at':   DateTime.now().toIso8601String(),
      'status':         'pending',
    }).eq('id', shareId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: approve or deny a request
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> respondToRequest({
    required String shareId,
    required bool approve,
  }) async {
    await _client.from('memory_shares').update({
      'status':      approve ? 'approved' : 'denied',
      if (approve) 'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', shareId).eq('sharer_id', _userId!);

    // Flag recipient's profile so "Shared with me" appears on their Explore tab
    if (approve) {
      final rows = await _client
          .from('memory_shares')
          .select('recipient_id')
          .eq('id', shareId)
          .limit(1);
      final recipientId = rows.firstOrNull?['recipient_id'] as String?;
      if (recipientId != null) {
        await _client
            .from('profiles')
            .update({'has_received_share': true})
            .eq('id', recipientId);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: revoke access
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> revokeShare(String shareId) async {
    await _client.from('memory_shares').update({
      'status':     'revoked',
      'revoked_at': DateTime.now().toIso8601String(),
    }).eq('id', shareId).eq('sharer_id', _userId!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: all pending requests awaiting her approval
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<MemoryShare>> getPendingRequests() async {
    if (_userId == null) return [];
    final rows = await _client
        .from('memory_shares')
        .select('''
          *,
          journal_entries!memory_id(title)
        ''')
        .eq('sharer_id', _userId!)
        .eq('status', 'pending')
        .not('recipient_name', 'is', null)
        .order('requested_at', ascending: false);
    return rows.map((r) => _flattenWithTitle(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: all shares for a specific memory (management screen)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<MemoryShare>> getSharesForMemory(String memoryId) async {
    if (_userId == null) return [];
    final rows = await _client
        .from('memory_shares')
        .select()
        .eq('memory_id', memoryId)
        .eq('sharer_id', _userId!)
        .order('created_at', ascending: false);
    return rows.map((r) => MemoryShare.fromMap(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mum: memories approved and shared with her
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<SharedMemoryItem>> getSharedWithMe() async {
    if (_userId == null) return [];
    final rows = await _client
        .from('memory_shares')
        .select('''
          *,
          journal_entries!memory_id(id, title, polished_content, content, entry_date, mood),
          profiles!sharer_id(display_name)
        ''')
        .eq('recipient_id', _userId!)
        .inFilter('status', ['approved', 'revoked'])
        .order('approved_at', ascending: false);
    return rows.map((r) => SharedMemoryItem.fromMap(r)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mum: record that she viewed an approved memory
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> recordView(String shareId) async {
    await _client.rpc('increment_share_view', params: {'p_share_id': shareId});
  }

  // Realtime stream — Mum watches for approval on her specific share
  Stream<List<Map<String, dynamic>>> watchShare(String shareId) =>
      _client
          .from('memory_shares')
          .stream(primaryKey: ['id'])
          .eq('id', shareId);

  // Realtime stream — Sarah watches for new pending requests
  Stream<List<Map<String, dynamic>>> watchPendingRequests() =>
      _client
          .from('memory_shares')
          .stream(primaryKey: ['id'])
          .eq('sharer_id', _userId ?? '');

  // ─────────────────────────────────────────────────────────────────────────
  // Helper: flatten joined title into the share row
  // ─────────────────────────────────────────────────────────────────────────

  MemoryShare _flattenWithTitle(Map<String, dynamic> row) {
    final entry = row['journal_entries'] as Map<String, dynamic>? ?? {};
    final flat = Map<String, dynamic>.from(row)
      ..['memory_title'] = entry['title']
      ..remove('journal_entries');
    return MemoryShare.fromMap(flat);
  }
}

// Extension for convenient pending-requests count
extension MemoryShareListExt on List<MemoryShare> {
  int get pendingCount => where((s) => s.isPending).length;
}
