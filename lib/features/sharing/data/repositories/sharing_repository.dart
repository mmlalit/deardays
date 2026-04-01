import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/network/network_client.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/core/domain/repositories/sharing_repository_interface.dart';

class SharingRepository implements ISharingRepository {
  final SupabaseClient _client;
  final NetworkClient _network = NetworkClient();
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

  @override
  Future<MemoryShare> createShare(String memoryId) async {
    return _network.query(() async {
      final row = await _client
          .from('memory_shares')
          .insert({'memory_id': memoryId, 'sharer_id': _requireUserId})
          .select()
          .single();
      return MemoryShare.fromMap(row);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token lookup — called by RequestAccessScreen (may be unauthenticated)
  // Returns minimal share info; full content only after approval
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<MemoryShare?> getShareByToken(String token) async {
    return _network.query(() async {
      final rows = await _client
          .from('memory_shares')
          .select('id, token, memory_id, status, expires_at, created_at, sharer_id')
          .eq('token', token)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (rows.isEmpty) return null;
      return MemoryShare.fromMap(rows.first);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mum: submit access request
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> requestAccess({
    required String shareId,
    required String recipientName,
    String? recipientId,
  }) async {
    // Uses SECURITY DEFINER RPC so recipients can claim shares without
    // needing direct UPDATE permission on memory_shares (RLS only allows
    // the sharer to UPDATE). The RPC atomically checks status = 'pending'
    // AND recipient_id IS NULL, preventing race conditions.
    try {
      await _client.rpc('claim_share', params: {
        'p_share_id': shareId,
        'p_recipient_name': recipientName.trim(),
        if (recipientId != null) 'p_recipient_id': recipientId,
      });
    } on PostgrestException {
      // RPC raises exception when share is already claimed or doesn't exist.
      throw Exception('This share link has already been claimed.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: approve or deny a request
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> respondToRequest({
    required String shareId,
    required bool approve,
  }) async {
    try {
      // Atomic RPC: updates share status + flags recipient profile in one
      // transaction (migration 058). Falls back to direct UPDATE if the RPC
      // hasn't been deployed yet.
      if (approve) {
        await _client.rpc('approve_share_request', params: {
          'p_share_id': shareId,
          'p_sharer_id': _requireUserId,
        });
      } else {
        await _client.rpc('deny_share_request', params: {
          'p_share_id': shareId,
          'p_sharer_id': _requireUserId,
        });
      }
    } on PostgrestException catch (e) {
      // If RPC doesn't exist yet (migration not deployed), fall back to
      // direct UPDATE.
      if (e.code == '42883' || e.message.contains('does not exist')) {
        debugPrint('[Sharing] RPC not deployed, falling back to direct UPDATE');
        await _respondToRequestLegacy(shareId: shareId, approve: approve);
        return;
      }
      throw Exception('Could not respond to share request: ${e.message}');
    }
  }

  /// Legacy two-step approval — used when migration 058 RPC is not yet deployed.
  Future<void> _respondToRequestLegacy({
    required String shareId,
    required bool approve,
  }) async {
    final result = await _client.from('memory_shares').update({
      'status': approve ? 'approved' : 'denied',
      if (approve) 'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', shareId).eq('sharer_id', _requireUserId).select('recipient_id').maybeSingle();

    if (result == null) {
      throw Exception('Share not found or not owned by current user');
    }

    if (approve) {
      final recipientId = result['recipient_id'] as String?;
      if (recipientId != null) {
        try {
          await _client
              .from('profiles')
              .update({'has_received_share': true})
              .eq('id', recipientId);
        } catch (e) {
          debugPrint('[Sharing] WARNING: profile update for recipient '
              '$recipientId failed: $e');
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: revoke access
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> revokeShare(String shareId) async {
    await _client.from('memory_shares').update({
      'status':     'revoked',
      'revoked_at': DateTime.now().toIso8601String(),
    }).eq('id', shareId).eq('sharer_id', _requireUserId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: all pending requests awaiting her approval
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<MemoryShare>> getPendingRequests() async {
    if (_userId == null) return [];
    return _network.query(() async {
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
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sarah: all shares for a specific memory (management screen)
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<MemoryShare>> getSharesForMemory(String memoryId) async {
    if (_userId == null) return [];
    return _network.query(() async {
      final rows = await _client
          .from('memory_shares')
          .select()
          .eq('memory_id', memoryId)
          .eq('sharer_id', _requireUserId)
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 10));
      return rows.map((r) => MemoryShare.fromMap(r)).toList();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mum: memories approved and shared with her
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<SharedMemoryItem>> getSharedWithMe() async {
    if (_userId == null) return [];
    return _network.query(() async {
      final rows = await _client
          .from('memory_shares')
          .select('''
            *,
            journal_entries!memory_id(id, title, polished_content, content, entry_date, mood, is_client_encrypted),
            profiles!sharer_id(display_name)
          ''')
          .eq('recipient_id', _requireUserId)
          .inFilter('status', ['approved', 'revoked'])
          .order('approved_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 10));
      return rows.map((r) => SharedMemoryItem.fromMap(r)).toList();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mum: record that she viewed an approved memory
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> recordView(String shareId) async {
    await _client.rpc('increment_share_view', params: {'p_share_id': shareId});
  }

  // Realtime stream — Mum watches for approval on her specific share
  @override
  Stream<List<Map<String, dynamic>>> watchShare(String shareId) =>
      _client
          .from('memory_shares')
          .stream(primaryKey: ['id'])
          .eq('id', shareId);

  // Realtime stream — Sarah watches for new pending requests
  @override
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
