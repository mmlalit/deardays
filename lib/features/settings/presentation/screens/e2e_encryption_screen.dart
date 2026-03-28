import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/snack_bar_helper.dart';
import 'package:deardays/features/settings/presentation/screens/set_e2e_passphrase_screen.dart';
import 'package:deardays/features/settings/presentation/screens/e2e_migration_screen.dart';
import 'package:deardays/services/encryption/encryption_service.dart';

/// Shows the current E2E encryption status and lets users enable / disable it.
class E2EEncryptionScreen extends ConsumerWidget {
  const E2EEncryptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(colors: colors),
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text('Could not load profile',
                      style: GoogleFonts.manrope(color: colors.textSecondary)),
                ),
                data: (profile) {
                  if (profile == null) {
                    return Center(
                      child: Text('No profile found',
                          style: GoogleFonts.manrope(
                              color: colors.textSecondary)),
                    );
                  }
                  if (profile.e2eEnabled) {
                    return _EnabledState(colors: colors, profile: profile);
                  }
                  return _DisabledState(colors: colors);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final AppPalette colors;
  const _Header({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: colors.textPrimary),
          ),
          const SizedBox(width: 4),
          Text(
            'End-to-End Encryption',
            style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Disabled state — explain benefits, offer setup
// ---------------------------------------------------------------------------

class _DisabledState extends StatelessWidget {
  final AppPalette colors;
  const _DisabledState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.lock_outline_rounded, size: 36, color: colors.accent),
          ),
          const SizedBox(height: 20),
          Text(
            'Only you can read\nyour entries',
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'With end-to-end encryption, your journal is encrypted '
            'on your device before it ever reaches our servers.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
                fontSize: 14, height: 1.6, color: colors.textSecondary),
          ),
          const SizedBox(height: 32),

          // Benefit / risk list
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(children: [
              _BenefitRow(
                colors: colors,
                icon: Icons.check_circle_outline_rounded,
                iconColor: colors.accent,
                title: 'Your key, your data',
                subtitle:
                    'The encryption key is derived from your passphrase and never leaves your device.',
              ),
              _BenefitRow(
                colors: colors,
                icon: Icons.check_circle_outline_rounded,
                iconColor: colors.accent,
                title: "We can't read your journal",
                subtitle:
                    'Even DearDays sees only encrypted ciphertext on the server.',
              ),
              _BenefitRow(
                colors: colors,
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Passphrase required on new devices',
                subtitle: "You'll enter it once per device after signing in.",
              ),
              _BenefitRow(
                colors: colors,
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'No recovery if you forget',
                subtitle:
                    'There is no way to recover your entries without your passphrase — not even DearDays support.',
                isLast: true,
              ),
            ]),
          ),

          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.border.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Currently: Standard encryption (server-managed)',
              style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SetE2EPassphraseScreen()),
              ),
              child: Text(
                'Set Up Encryption',
                style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enabled state — show status, offer passphrase change / disable
// ---------------------------------------------------------------------------

class _EnabledState extends ConsumerWidget {
  final AppPalette colors;
  final dynamic profile;
  const _EnabledState({required this.colors, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAt = profile.e2eEnabledAt as DateTime?;
    final dateStr = enabledAt != null
        ? '${enabledAt.day} ${_month(enabledAt.month)} ${enabledAt.year}'
        : 'Active';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, size: 36, color: colors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'Encryption is active',
            style: GoogleFonts.newsreader(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Your entries are encrypted before leaving your device.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
                fontSize: 13, height: 1.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 28),

          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(children: [
              _StatusRow(colors: colors, label: 'Status', value: 'Protected',
                  valueColor: colors.accent),
              _StatusRow(colors: colors, label: 'Active since', value: dateStr),
              _StatusRow(colors: colors, label: 'Algorithm', value: 'AES-256-GCM'),
              _StatusRow(colors: colors, label: 'Key derivation',
                  value: 'PBKDF2 · 100k rounds'),
              _StatusRow(colors: colors, label: 'Covers', value: 'Text & Voice',
                  isLast: true),
            ]),
          ),
          const SizedBox(height: 20),

          _ActionRow(
            colors: colors,
            icon: Icons.key_rounded,
            label: 'Change Passphrase',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) =>
                      const SetE2EPassphraseScreen(isChangingPassphrase: true)),
            ),
          ),
          const SizedBox(height: 12),

          _ActionRow(
            colors: colors,
            icon: Icons.lock_open_rounded,
            label: 'Disable E2E Encryption',
            labelColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: () => _confirmDisable(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisable(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Disable E2E Encryption?',
            style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.error)),
        content: Text(
          'Your entries will be re-encrypted using standard server-side '
          'encryption. Your passphrase will no longer be required on login.',
          style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.5,
              color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Encryption',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Disable',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600, color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => E2EMigrationScreen(
          isDisabling: true,
          onComplete: () {
            EncryptionService().clearKey();
            if (context.mounted) {
              Navigator.of(context)
                  .popUntil((r) => r.isFirst || r.settings.name == '/settings');
              AppSnackBar.success(context, 'E2E encryption disabled.');
            }
          },
        ),
      ),
    );
  }

  String _month(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _BenefitRow extends StatelessWidget {
  final AppPalette colors;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLast;

  const _BenefitRow({
    required this.colors,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.manrope(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: colors.border),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final AppPalette colors;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _StatusRow({
    required this.colors,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(label,
                  style: GoogleFonts.manrope(
                      fontSize: 13, color: colors.textSecondary)),
              const Spacer(),
              Text(value,
                  style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? colors.textPrimary)),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: colors.border),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final AppPalette colors;
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ActionRow({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? colors.accent),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? colors.textPrimary)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
