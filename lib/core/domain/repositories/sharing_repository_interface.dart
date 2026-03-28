import 'package:deardays/features/sharing/data/models/memory_share.dart';

/// Contract for memory sharing data access.
///
/// Implementations: [SharingRepository] (Supabase), test mocks.
abstract class ISharingRepository {
  Future<MemoryShare> createShare(String memoryId);

  Future<MemoryShare?> getShareByToken(String token);

  Future<void> requestAccess({
    required String shareId,
    required String recipientName,
    String? recipientId,
  });

  Future<void> respondToRequest({
    required String shareId,
    required bool approve,
  });

  Future<void> revokeShare(String shareId);

  Future<List<MemoryShare>> getPendingRequests();

  Future<List<MemoryShare>> getSharesForMemory(String memoryId);

  Future<List<SharedMemoryItem>> getSharedWithMe();

  Future<void> recordView(String shareId);

  Stream<List<Map<String, dynamic>>> watchShare(String shareId);

  Stream<List<Map<String, dynamic>>> watchPendingRequests();
}
