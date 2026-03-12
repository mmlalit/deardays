import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';

/// Small sync status pill shown in the top-right of the app shell.
class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final syncStatus = ref.watch(syncStatusProvider);
    final isOnline = ref.watch(connectivityProvider);

    // Determine display state
    late final _StatusDisplay display;
    if (!isOnline) {
      display = const _StatusDisplay(
        color: AppColors.moodTough,
        label: 'Offline',
        icon: Icons.cloud_off_rounded,
        pulse: false,
      );
    } else {
      switch (syncStatus) {
        case SyncStatus.synced:
          display = const _StatusDisplay(
            color: AppColors.moodGreat,
            label: 'Synced',
            icon: Icons.cloud_done_rounded,
            pulse: false,
          );
        case SyncStatus.pending:
          display = const _StatusDisplay(
            color: AppColors.moodOkay,
            label: 'Pending',
            icon: Icons.cloud_upload_rounded,
            pulse: true,
          );
        case SyncStatus.syncing:
          display = const _StatusDisplay(
            color: AppColors.blue,
            label: 'Syncing',
            icon: Icons.sync_rounded,
            pulse: true,
          );
        case SyncStatus.error:
          display = const _StatusDisplay(
            color: AppColors.moodTough,
            label: 'Sync Error',
            icon: Icons.error_outline_rounded,
            pulse: false,
          );
      }
    }

    // Control pulse animation
    if (display.pulse) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }

    return GestureDetector(
      onTap: () => _showSyncDetails(context, colors, syncStatus, isOnline),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final opacity = display.pulse
              ? 0.6 + 0.4 * _pulseController.value
              : 1.0;
          return Opacity(opacity: opacity, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: display.color.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: display.color.withAlpha(50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(display.icon, size: 12, color: display.color),
              const SizedBox(width: 4),
              Text(
                display.label,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: display.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSyncDetails(
    BuildContext context,
    AppPalette colors,
    SyncStatus status,
    bool isOnline,
  ) {
    final message = !isOnline
        ? 'You are offline. Changes will sync when you reconnect.'
        : switch (status) {
            SyncStatus.synced => 'All changes are synced.',
            SyncStatus.pending => 'Changes are queued and will sync shortly.',
            SyncStatus.syncing => 'Syncing your changes now...',
            SyncStatus.error =>
              'Some changes failed to sync. They will retry automatically.',
          };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _StatusDisplay {
  final Color color;
  final String label;
  final IconData icon;
  final bool pulse;

  const _StatusDisplay({
    required this.color,
    required this.label,
    required this.icon,
    required this.pulse,
  });
}
