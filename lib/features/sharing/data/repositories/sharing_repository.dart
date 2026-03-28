import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/core/domain/repositories/sharing_repository_interface.dart';

class SharingRepository implements ISharingRepository {
  final SupabaseClient _client;
  SharingRepository({required SupabaseClient client}) : _client = client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Returns the current user ID or throws a descriptive error.
  String get _requireUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Session expired — please sign in again.');
    }
    return id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: create a share token for a memory
  // ─────────────────────────────────────────────────────────────────────────

  Future<MemoryShare> createShare(String memoryId) async {
    final row = await _client
        .from('memory_shares')
        .insert({'memory_id': memoryId, 'sharer_id': _requireUserId})
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
        .select('id, token, memory_id, status, expires_at, created_at, sharer_id')
        .eq('token', token)
        .limit(1)
        .timeout(const Duration(seconds: 10));
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
    }).eq('id', shareId).eq('status', 'pending').isFilter('recipient_id', null);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: approve or deny a request
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> respondToRequest({
    required String shareId,
    required bool approve,
  }) async {
    // C-21 FIX: Proper error handling for non-atomic two-step DB update.
    try {
      // Chain .select() onto UPDATE to get recipient_id in one round-trip (avoids N+1).
      final result = await _client.from('memory_shares').update({
        'status':      approve ? 'approved' : 'denied',
        if (approve) 'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', shareId).eq('sharer_id', _requireUserId).select('recipient_id').maybeSingle();

      if (result == null) {
        throw Exception('Share not found or not owned by current user');
      }

      // Flag recipient's profile so "Shared with me" appears on their Explore tab.
      // NOTE: This is a known non-atomic operation — the share status update above
      // and this profile flag are two independent writes. If this second write fails,
      // the share is still approved; only the "Shared with me" badge will be missing
      // until the next share approval. Acceptable trade-off vs. an RPC/transaction.
      if (approve) {
        final recipientId = result['recipient_id'] as String?;
        if (recipientId != null) {
          try {
            await _client
                .from('profiles')
                .update({'has_received_share': true})
                .eq('id', recipientId);
          } catch (e) {
            debugPrint('[Sharing] WARNING: Non-atomic write failed — profile '
                'update for recipient $recipientId: $e');
            // Non-critical: share is approved, just the badge won't show immediately
          }
        }
      }
    } on PostgrestException catch (e) {
      throw Exception('Could not respond to share request: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: revoke access
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> revokeShare(String shareId) async {
    await _client.from('memory_shares').update({
      'status':     'revoked',
      'revoked_at': DateTime.now().toIso8601String(),
    }).eq('id', shareId).eq('sharer_id', _requireUserId);
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
        .eq('sharer_id', _requireUserId)
        .eq('status', 'pending')
        .not('recipient_name', 'is', null)
        .order('requested_at', ascending: false)
        .limit(100)
        .timeout(const Duration(seconds: 10));
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
        .eq('sharer_id', _requireUserId)
        .order('created_at', ascending: false)
        .limit(100)
        .timeout(const Duration(seconds: 10));
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
        .eq('recipient_id', _requireUserId)
        .inFilter('status', ['approved', 'revoked'])
        .order('approved_at', ascending: false)
        .limit(100)
        .timeout(const Duration(seconds: 10));
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
  Stream<List<Map<String, dynamic>>> watchPendingRequests() {
    final uid = _userId;
    if (uid == null) {
      return Stream.value([]);
    }
    return _client
        .from('memory_shares')
        .stream(primaryKey: ['id'])
        .eq('sharer_id', uid);
  }

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
