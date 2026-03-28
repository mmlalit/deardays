import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/services/sync/offline_write_service.dart';
import 'package:deardays/services/connectivity/connectivity_service.dart';

/// Provides the singleton [OfflineWriteService].
final offlineWriteServiceProvider = Provider<OfflineWriteService>((ref) {
  return OfflineWriteService();
});

/// Stream of pending write counts, updated whenever a write is queued or replayed.
final pendingWriteCountProvider = StreamProvider<int>((ref) {
  return OfflineWriteService().statusStream.map((s) => s.pendingCount);
});

/// Stream of online/offline status from [ConnectivityService].
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ConnectivityService().onlineStatus;
});
