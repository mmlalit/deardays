import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/data/repositories/sharing_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repository provider
// ─────────────────────────────────────────────────────────────────────────────

final sharingRepositoryProvider = Provider<SharingRepository>((ref) {
  return SharingRepository(client: Supabase.instance.client);
});

// ─────────────────────────────────────────────────────────────────────────────
// Pending deep-link token — set when app opens from a share link
// ─────────────────────────────────────────────────────────────────────────────

final pendingShareTokenProvider = StateProvider<String?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────────────
// Sarah: pending approval requests
// ─────────────────────────────────────────────────────────────────────────────

final pendingShareRequestsProvider =
    FutureProvider.autoDispose<List<MemoryShare>>((ref) async {
  return ref.read(sharingRepositoryProvider).getPendingRequests()
      .timeout(const Duration(seconds: 10));
});

// ─────────────────────────────────────────────────────────────────────────────
// Sarah: shares for a specific memory (management screen)
// ─────────────────────────────────────────────────────────────────────────────

final sharesForMemoryProvider =
    FutureProvider.autoDispose.family<List<MemoryShare>, String>((ref, memoryId) async {
  return ref.read(sharingRepositoryProvider).getSharesForMemory(memoryId)
      .timeout(const Duration(seconds: 10));
});

// ─────────────────────────────────────────────────────────────────────────────
// Mum: memories shared with her
// ─────────────────────────────────────────────────────────────────────────────

final sharedWithMeProvider =
    FutureProvider.autoDispose<List<SharedMemoryItem>>((ref) async {
  return ref.read(sharingRepositoryProvider).getSharedWithMe()
      .timeout(const Duration(seconds: 10));
});

// ─────────────────────────────────────────────────────────────────────────────
// Share actions notifier — handles create/approve/deny/revoke
// ─────────────────────────────────────────────────────────────────────────────

class ShareActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final SharingRepository _repo;
  final Ref _ref;

  ShareActionsNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<MemoryShare?> createShare(String memoryId) async {
    state = const AsyncValue.loading();
    try {
      final share = await _repo.createShare(memoryId);
      state = const AsyncValue.data(null);
      return share;
    } catch (e, st) {
      debugPrint('[SharingProvider] createShare: $e');
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> requestAccess({
    required String shareId,
    required String recipientName,
    String? recipientId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.requestAccess(
        shareId: shareId,
        recipientName: recipientName,
        recipientId: recipientId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      debugPrint('[SharingProvider] requestAccess: $e');
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> approve(String shareId) => _respond(shareId, true);
  Future<bool> deny(String shareId)    => _respond(shareId, false);

  Future<bool> _respond(String shareId, bool approve) async {
    state = const AsyncValue.loading();
    try {
      await _repo.respondToRequest(shareId: shareId, approve: approve);
      _ref.invalidate(pendingShareRequestsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      debugPrint('[SharingProvider] _respond (approve=$approve): $e');
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> revoke(String shareId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.revokeShare(shareId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      debugPrint('[SharingProvider] revoke: $e');
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final shareActionsProvider =
    StateNotifierProvider.autoDispose<ShareActionsNotifier, AsyncValue<void>>(
  (ref) => ShareActionsNotifier(ref.read(sharingRepositoryProvider), ref),
);
