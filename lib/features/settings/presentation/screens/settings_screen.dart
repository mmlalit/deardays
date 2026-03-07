import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/features/auth/presentation/screens/pin_screen.dart';
import 'package:deardays/features/auth/presentation/screens/pattern_screen.dart';
import 'package:deardays/features/settings/presentation/screens/terms_screen.dart';
import 'package:deardays/features/settings/presentation/screens/privacy_screen.dart';
import 'package:deardays/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:deardays/features/settings/presentation/screens/subscription_screen.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/core/widgets/snack_bar_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricLockEnabled = false;
  bool _biometricAvailable = false;
  String _lockMethod = 'none';
  final _secureStorage = SecureStorageService();
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final enabled = await _secureStorage.getBiometricEnabled();
      final lockMethod = await _secureStorage.getLockMethod();

      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck && isDeviceSupported;
          _biometricLockEnabled = enabled;
          _lockMethod = lockMethod;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && _biometricAvailable) {
      // Verify biometric before enabling
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to enable biometric lock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (!authenticated) return;
    }

    await _secureStorage.saveBiometricEnabled(value);
    if (mounted) {
      setState(() => _biometricLockEnabled = value);
    }
  }

  Future<void> _setupPin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PinScreen(mode: PinMode.setup, onSuccess: () {}),
      ),
    );
    if (result == true && mounted) {
      setState(() => _lockMethod = 'pin');
    }
  }

  Future<void> _setupPattern() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatternScreen(mode: PatternMode.setup, onSuccess: () {}),
      ),
    );
    if (result == true && mounted) {
      setState(() => _lockMethod = 'pattern');
    }
  }

  Future<void> _clearLockMethod() async {
    await _secureStorage.saveLockMethod('none');
    await _secureStorage.clearPin();
    await _secureStorage.clearPattern();
    if (mounted) {
      setState(() => _lockMethod = 'none');
    }
  }

  // ---------------------------------------------------------------------------
  // Daily Reminder
  // ---------------------------------------------------------------------------

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 30),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    await NotificationService().scheduleDailyReminder(picked);
    if (mounted) {
      AppSnackBar.success(context, 'Daily reminder set for ${picked.format(context)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Writing Style
  // ---------------------------------------------------------------------------

  Future<void> _pickWritingStyle() async {
    final styles = ['Memoir', 'Diary', 'Story'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Writing Style',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...styles.map((s) => ListTile(
                  leading: Icon(
                    s == 'Memoir'
                        ? Icons.auto_stories
                        : s == 'Diary'
                            ? Icons.book
                            : Icons.movie_creation_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(s, style: GoogleFonts.inter(fontSize: 15)),
                  subtitle: Text(
                    s == 'Memoir'
                        ? 'Third-person narrative, reflective tone'
                        : s == 'Diary'
                            ? 'First-person, casual daily entries'
                            : 'Cinematic storytelling, vivid scenes',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  onTap: () => Navigator.pop(ctx, s.toLowerCase()),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final profile = await profileRepo.getProfile();
      if (profile != null) {
        await profileRepo.updateProfile(profile.copyWith(writingStyle: picked));
      }
      if (mounted) {
        AppSnackBar.success(context, 'Writing style updated to ${picked[0].toUpperCase()}${picked.substring(1)}');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to update writing style.');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Book Organization
  // ---------------------------------------------------------------------------

  Future<void> _pickBookOrganization() async {
    final options = [
      {'value': 'yearly', 'label': 'Yearly', 'desc': 'One book per year (default)'},
      {'value': 'monthly', 'label': 'Monthly', 'desc': 'One book per month'},
      {'value': 'quarterly', 'label': 'Quarterly', 'desc': 'One book per quarter'},
      {'value': 'manual', 'label': 'Manual Only', 'desc': 'Create books manually'},
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Organize Books By',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...options.map((o) => ListTile(
                  leading: Icon(Icons.library_books_outlined, color: AppColors.primary),
                  title: Text(o['label']!, style: GoogleFonts.inter(fontSize: 15)),
                  subtitle: Text(
                    o['desc']!,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  onTap: () => Navigator.pop(ctx, o['value']),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final profile = await profileRepo.getProfile();
      if (profile != null) {
        await profileRepo.updateProfile(profile.copyWith(bookOrganization: picked));
      }
      if (mounted) {
        final label = options.firstWhere((o) => o['value'] == picked)['label']!;
        AppSnackBar.success(context, 'Books organized by $label');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to update book organization.');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Encryption Info
  // ---------------------------------------------------------------------------

  void _showEncryptionInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text('Zero-Knowledge Encryption',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Algorithm', 'AES-256-GCM'),
            _infoRow('Key Derivation', 'PBKDF2 (100,000 iterations)'),
            _infoRow('Salt', 'Unique 256-bit per user'),
            const SizedBox(height: 12),
            Text(
              'Your encryption key is derived from your password and never leaves '
              'your device. The server stores only encrypted blobs — we cannot '
              'read your journal entries.',
              style: GoogleFonts.inter(
                fontSize: 13, height: 1.5, color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Export All Data
  // ---------------------------------------------------------------------------

  Future<void> _exportAllData() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Export Your Data',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.code, color: AppColors.primary),
              title: Text('JSON', style: GoogleFonts.inter(fontSize: 15)),
              subtitle: Text('Machine-readable, includes all fields',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
              title: Text('PDF', style: GoogleFonts.inter(fontSize: 15)),
              subtitle: Text('Print-ready book format',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (format == null || !mounted) return;

    if (format == 'pdf') {
      // Navigate to existing export screen
      Navigator.of(context).pushNamed('/export');
      return;
    }

    // JSON export
    try {
      AppSnackBar.success(context, 'Exporting your data...');

      final journalRepo = ref.read(journalRepositoryProvider);
      final entries = await journalRepo.getEntries(limit: 10000);

      final exportData = {
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'total_entries': entries.length,
        'entries': entries.map((e) => {
              'id': e.id,
              'date': e.entryDate.toIso8601String(),
              'content': e.content,
              'raw_content': e.rawContent,
              'mood': e.mood,
              'location': e.locationName,
              'word_count': e.wordCount,
              'is_ai_polished': e.isAiPolished,
              'created_at': e.createdAt.toIso8601String(),
            }).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/deardays_export.json');
      await file.writeAsString(jsonStr);

      if (mounted) {
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Export failed: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete Account
  // ---------------------------------------------------------------------------

  Future<void> _deleteAccount() async {
    // First confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red.shade700)),
        content: Text(
          'This will permanently delete your account and all journal entries. '
          'This action cannot be undone.\n\n'
          'Your encrypted data will be erased from the server.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete Everything',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.red.shade700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Second confirmation — type DELETE
    final deleteConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Type DELETE to confirm',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'DELETE',
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim() == 'DELETE') {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text('Confirm Delete',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: Colors.red.shade700)),
            ),
          ],
        );
      },
    );

    if (deleteConfirmed != true || !mounted) return;

    try {
      // Delete profile (cascades to entries, media, streaks, etc.)
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('profiles').delete().eq('id', userId);
      }

      // Sign out
      await client.auth.signOut();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to delete account. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildProfileSection(),
              const SizedBox(height: 28),
              _buildSectionLabel('ACCOUNT'),
              _buildSettingsRow(
                icon: Icons.email_outlined,
                label: 'Email',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Supabase.instance.client.auth.currentUser?.email ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 22),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.lock_outline,
                label: 'Password',
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Subscription',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('JOURNALING'),
              _buildSettingsRow(
                icon: Icons.notifications_none_rounded,
                label: 'Daily Reminder',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '8:30 PM',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                onTap: _pickReminderTime,
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.edit_note_rounded,
                label: 'Writing Style',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Memoir',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 22),
                  ],
                ),
                onTap: _pickWritingStyle,
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.auto_stories_outlined,
                label: 'Chapter Organization',
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
                onTap: () => Navigator.of(context).pushNamed('/chapters'),
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('LIBRARY'),
              _buildSettingsRow(
                icon: Icons.library_books_outlined,
                label: 'Organize Books By',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Yearly',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 22),
                  ],
                ),
                onTap: _pickBookOrganization,
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('LANGUAGE'),
              _buildLanguageSelector(),
              const SizedBox(height: 28),
              _buildSectionLabel('APPEARANCE'),
              _buildThemeSelector(),
              const SizedBox(height: 28),
              _buildSectionLabel('PRIVACY & SECURITY'),
              _buildSettingsRow(
                icon: Icons.fingerprint,
                label: 'Biometric Lock',
                trailing: Switch(
                  value: _biometricLockEnabled,
                  onChanged: _biometricAvailable ? _toggleBiometric : null,
                  activeColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.dialpad,
                label: 'PIN Lock',
                trailing: _lockMethod == 'pin'
                    ? GestureDetector(
                        onTap: _clearLockMethod,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Active',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _setupPin,
                        child: Text(
                          'Set up',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.pattern,
                label: 'Pattern Lock',
                trailing: _lockMethod == 'pattern'
                    ? GestureDetector(
                        onTap: _clearLockMethod,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Active',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _setupPattern,
                        child: Text(
                          'Set up',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.enhanced_encryption_outlined,
                label: 'Encryption Info',
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
                onTap: _showEncryptionInfo,
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('DATA'),
              _buildSettingsRow(
                icon: Icons.download_outlined,
                label: 'Export All Data',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PDF / JSON',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 22),
                  ],
                ),
                onTap: _exportAllData,
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.delete_outline,
                label: 'Delete Account',
                labelColor: Colors.red.shade600,
                iconColor: Colors.red.shade600,
                trailing: Icon(Icons.chevron_right,
                    color: Colors.red.shade300, size: 22),
                onTap: _deleteAccount,
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('ABOUT'),
              _buildSettingsRow(
                icon: Icons.info_outline,
                label: 'Version',
                trailing: Text(
                  '1.2.0',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                ),
              ),
              const SizedBox(height: 36),
              _buildFooter(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return const DearDaysHeader(
      title: 'Settings',
      mode: HeaderMode.push,
    );
  }

  Widget _buildProfileSection() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final meta = user?.userMetadata;
    final displayName = meta?['display_name'] as String? ??
        meta?['full_name'] as String? ??
        email.split('@').first;
    final initials = displayName.isNotEmpty
        ? displayName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(38),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgLight, width: 2),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(
              'Edit Profile',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade400,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    Color? labelColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? Colors.grey.shade600, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final currentLocale = ref.watch(localeProvider).appLocale;

    return _buildSettingsRow(
      icon: Icons.language,
      label: 'App Language',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLocale.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
        ],
      ),
      onTap: () => _pickLanguage(),
    );
  }

  Future<void> _pickLanguage() async {
    final currentLocale = ref.read(localeProvider).appLocale;

    final picked = await showModalBottomSheet<AppLocale>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'App Language',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...AppLocale.values.map((locale) => ListTile(
                  leading: Icon(
                    locale == AppLocale.system
                        ? Icons.phone_android
                        : Icons.translate,
                    color: AppColors.primary,
                  ),
                  title: Text(locale.label, style: GoogleFonts.inter(fontSize: 15)),
                  trailing: locale == currentLocale
                      ? Icon(Icons.check_circle, color: AppColors.primary, size: 22)
                      : null,
                  onTap: () => Navigator.pop(ctx, locale),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;
    ref.read(localeProvider.notifier).setLocale(picked);
  }

  Widget _buildThemeSelector() {
    final currentTheme = ref.watch(themeProvider).themeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: AppThemeColor.values.map((palette) {
          final isSelected = palette == currentTheme;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setThemeColor(palette),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: palette.bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.primary.withAlpha(76), blurRadius: 6)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      palette.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.primary : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
          const SizedBox(height: 6),
          Text(
            'DearDays',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
