import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/services/backup/backup_service.dart';

/// Screen for managing cloud backup and restore operations.
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  final _backupService = BackupService();
  bool _isOperating = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final info = _backupService.getBackupInfo();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Backup status card
                    _buildStatusCard(colors, info),
                    const SizedBox(height: 24),

                    // Backup section
                    _buildSectionHeader(
                        colors, 'Cloud Backup', Icons.cloud_upload_rounded),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      colors,
                      title: 'Backup Now',
                      subtitle:
                          'Sync all local entries to the cloud for safekeeping',
                      icon: Icons.backup_rounded,
                      onTap: _isOperating ? null : _performBackup,
                    ),
                    const SizedBox(height: 24),

                    // Restore section
                    _buildSectionHeader(
                        colors, 'Restore Data', Icons.cloud_download_rounded),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      colors,
                      title: 'Restore from Cloud',
                      subtitle:
                          'Download all your memories to this device',
                      icon: Icons.restore_rounded,
                      onTap: _isOperating ? null : _performRestore,
                    ),
                    const SizedBox(height: 24),

                    // Info section
                    _buildInfoCard(colors),

                    // Status message
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.accent.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: colors.accent.withAlpha(30)),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.cardBg,
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: colors.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              'Backup & Restore',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AppPalette colors, BackupInfo info) {
    final hasBackup = info.lastBackupTime != null;
    final statusColor = info.status == BackupStatus.completed
        ? Colors.green
        : info.status == BackupStatus.failed
            ? Colors.red
            : colors.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withAlpha(15),
            colors.accent.withAlpha(5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withAlpha(25)),
      ),
      child: Column(
        children: [
          Icon(
            hasBackup ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 40,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            hasBackup ? 'Backup Active' : 'No Backup Yet',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasBackup
                ? 'Last backup: ${DateFormat('MMM dd, yyyy \'at\' h:mm a').format(info.lastBackupTime!)}'
                : 'Back up your memories to keep them safe',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (hasBackup) ...[
            const SizedBox(height: 8),
            Text(
              '${info.backedUpCount} entries backed up',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ],
          if (_isOperating) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(colors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      AppPalette colors, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    AppPalette colors, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withAlpha(15),
              ),
              child: Icon(icon, size: 22, color: colors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: onTap != null
                          ? colors.textPrimary
                          : colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(AppPalette colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withAlpha(20)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your data is encrypted end-to-end. Only you can read your journal entries.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') || msg.contains('network') || msg.contains('connection')) {
      return 'Network error. Check your connection and try again.';
    }
    if (msg.contains('permission') || msg.contains('unauthorized') || msg.contains('403')) {
      return 'Permission denied. Please sign in again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _performBackup() async {
    setState(() {
      _isOperating = true;
      _statusMessage = 'Backing up your memories...';
    });

    try {
      final count = await _backupService.performBackup(
        repository: ref.read(journalRepositoryProvider),
        localStorage: ref.read(localStorageProvider),
      );
      setState(() {
        _statusMessage = 'Backup complete! $count entries synced.';
      });
    } catch (e) {
      debugPrint('[BackupRestore] performBackup: $e');
      setState(() {
        _statusMessage = 'Backup failed: ${_friendlyError(e)}';
      });
    } finally {
      setState(() => _isOperating = false);
    }
  }

  Future<void> _performRestore() async {
    // Confirm restore
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Restore from Cloud?',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700, color: colors.textPrimary)),
          content: Text(
            'This will download all your cloud entries to this device. Existing local entries will be preserved.',
            style: GoogleFonts.manrope(
                fontSize: 14, color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.manrope(color: colors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Restore',
                  style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700, color: colors.accent)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isOperating = true;
      _statusMessage = 'Restoring your memories...';
    });

    try {
      final count = await _backupService.performRestore(
        repository: ref.read(journalRepositoryProvider),
        localStorage: ref.read(localStorageProvider),
      );
      setState(() {
        _statusMessage = 'Restore complete! $count entries recovered.';
      });
    } catch (e) {
      debugPrint('[BackupRestore] performRestore: $e');
      setState(() {
        _statusMessage = 'Restore failed: ${_friendlyError(e)}';
      });
    } finally {
      setState(() => _isOperating = false);
    }
  }
}
