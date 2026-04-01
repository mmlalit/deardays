import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/offline_providers.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/sync/sync_queue.dart';

/// A slim banner shown at the top of the screen when the device is offline
/// or when there are pending writes waiting to sync.
///
/// States:
/// - Offline with pending: "You're offline. N changes will sync when connected."
/// - Offline, no pending: "You're offline."
/// - Online, syncing: "Syncing N changes..."
/// - Online, synced: hidden
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  Timer? _recheckTimer;

  @override
  void dispose() {
    _recheckTimer?.cancel();
    super.dispose();
  }

  int _safeSyncQueueCount() {
    try {
      return SyncQueue().count;
    } catch (e) {
      debugPrint('[OfflineBanner] SyncQueue().count error: $e');
      return 0;
    }
  }

  void _scheduleRecheck() {
    _recheckTimer?.cancel();
    _recheckTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        ref.invalidate(connectivityProvider);
        ref.invalidate(pendingWriteCountProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider);
    final pendingAsync = ref.watch(pendingWriteCountProvider);
    final offlineWritePending = pendingAsync.valueOrNull ?? 0;
    final syncQueuePending = _safeSyncQueueCount();
    final pendingCount = offlineWritePending + syncQueuePending;
    final syncStatus = ref.watch(syncStatusProvider);

    // Fully online with nothing pending — hide banner
    if (isOnline && pendingCount == 0 && syncStatus == SyncStatus.synced) {
      _recheckTimer?.cancel();
      return const SizedBox.shrink();
    }
    // Online and sync completed but SyncQueue just hasn't been rechecked — hide
    if (isOnline && syncStatus != SyncStatus.syncing && offlineWritePending == 0 && syncQueuePending == 0) {
      _recheckTimer?.cancel();
      return const SizedBox.shrink();
    }

    final colors = AppColors.of(context);
    final String message;
    final IconData icon;
    final Color bgColor;
    final Color textColor;

    if (!isOnline) {
      icon = Icons.cloud_off_rounded;
      bgColor = colors.accentFaint;
      textColor = colors.accent;
      if (pendingCount > 0) {
        message = "You're offline. $pendingCount change${pendingCount == 1 ? '' : 's'} will sync when connected.";
      } else {
        message = "You're offline.";
      }
      // Re-verify connectivity after 5 seconds in case platform state is stale
      _scheduleRecheck();
    } else if (syncStatus == SyncStatus.syncing) {
      icon = Icons.sync_rounded;
      bgColor = colors.accentFaint;
      textColor = colors.accent;
      message = 'Syncing $pendingCount change${pendingCount == 1 ? '' : 's'}...';
    } else if (pendingCount > 0) {
      icon = Icons.sync_rounded;
      bgColor = colors.accentFaint;
      textColor = colors.accent;
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
