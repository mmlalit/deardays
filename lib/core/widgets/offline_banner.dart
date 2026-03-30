import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/offline_providers.dart';
import 'package:deardays/services/sync/sync_queue.dart';

/// A slim banner shown at the top of the screen when the device is offline
/// or when there are pending writes waiting to sync.
///
/// States:
/// - Offline with pending: "You're offline. N changes will sync when connected."
/// - Offline, no pending: "You're offline."
/// - Online, syncing: "Syncing N changes..."
/// - Online, synced: hidden
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final pendingAsync = ref.watch(pendingWriteCountProvider);
    final offlineWritePending = pendingAsync.valueOrNull ?? 0;
    final syncQueuePending = SyncQueue().count;
    final pendingCount = offlineWritePending + syncQueuePending;
    final syncStatus = ref.watch(syncStatusProvider);

    // Fully online with nothing pending — hide banner
    if (isOnline && pendingCount == 0 && syncStatus == SyncStatus.synced) {
      return const SizedBox.shrink();
    }
    // Online and sync completed but SyncQueue just hasn't been rechecked — hide
    if (isOnline && syncStatus != SyncStatus.syncing && offlineWritePending == 0 && syncQueuePending == 0) {
      return const SizedBox.shrink();
    }

    final String message;
    final IconData icon;
    final Color bgColor;
    final Color textColor;

    if (!isOnline) {
      icon = Icons.cloud_off_rounded;
      bgColor = const Color(0xFFFEF3C7); // warm amber background
      textColor = const Color(0xFF92400E);
      if (pendingCount > 0) {
        message = "You're offline. $pendingCount change${pendingCount == 1 ? '' : 's'} will sync when connected.";
      } else {
        message = "You're offline.";
      }
    } else if (syncStatus == SyncStatus.syncing) {
      icon = Icons.sync_rounded;
      bgColor = const Color(0xFFEEF2FF); // soft indigo background
      textColor = const Color(0xFF3730A3);
      message = 'Syncing $pendingCount change${pendingCount == 1 ? '' : 's'}...';
    } else if (pendingCount > 0) {
      icon = Icons.sync_rounded;
      bgColor = const Color(0xFFEEF2FF);
      textColor = const Color(0xFF3730A3);
      message = '$pendingCount change${pendingCount == 1 ? '' : 's'} pending sync.';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: textColor.withAlpha(30), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
