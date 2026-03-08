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
  bool _doNotSell = false;
  bool _healthConsent = false;
  final _secureStorage = SecureStorageService();
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    _loadPrivacyState();
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
  // Privacy & Consent
  // ---------------------------------------------------------------------------

  Future<void> _loadPrivacyState() async {
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final profile = await profileRepo.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _doNotSell = profile.doNotSell;
          _healthConsent = profile.healthConsentGivenAt != null;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleDoNotSell(bool value) async {
    setState(() => _doNotSell = value);
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final profile = await profileRepo.getProfile();
      if (profile != null) {
        await profileRepo.updateProfile(profile.copyWith(doNotSell: value));
      }
      if (mounted) {
        AppSnackBar.success(
          context,
          value
              ? '"Do Not Sell" preference saved.'
              : '"Do Not Sell" preference removed.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _doNotSell = !value);
        AppSnackBar.error(context, 'Failed to update preference.');
      }
    }
  }

  Future<void> _toggleHealthConsent(bool value) async {
    if (!value) {
      // Withdrawing consent — confirm first
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Withdraw Mood Data Consent?',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Text(
            'Mood tracking will be disabled. Existing mood data in your entries '
            'will not be deleted but will no longer be processed.',
            style: GoogleFonts.inter(
                fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Withdraw Consent',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _healthConsent = value);
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final profile = await profileRepo.getProfile();
      if (profile != null) {
        await profileRepo.updateProfile(profile.copyWith(
          healthConsentGivenAt:
              value ? DateTime.now().toUtc() : null,
          consentWithdrawnAt: value ? null : DateTime.now().toUtc(),
        ));
      }
      if (mounted) {
        AppSnackBar.success(
          context,
          value
              ? 'Mood data consent granted.'
              : 'Mood data consent withdrawn.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _healthConsent = !value);
        AppSnackBar.error(context, 'Failed to update consent.');
      }
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSection(),
                  const SizedBox(height: 24),
                  // ACCOUNT
                  _buildSectionLabel('Account'),
                  _buildCardGroup([
                    _buildCardRow(
                      icon: Icons.mail_outlined,
                      label: 'Email',
                      trailing: Text(
                        Supabase.instance.client.auth.currentUser?.email ?? '',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                    _buildCardRow(
                      icon: Icons.lock_outlined,
                      label: 'Password',
                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted.withAlpha(76)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                    _buildCardRow(
                      icon: Icons.star,
                      iconColor: AppColors.primary,
                      label: 'Subscription',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Premium Plan',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      ),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // JOURNALING
                  _buildSectionLabel('Journaling'),
                  _buildCardGroup([
                    _buildCardRow(
                      icon: Icons.notifications_outlined,
                      label: 'Daily Reminder',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withAlpha(51)),
                        ),
                        child: Text(
                          '8:30 PM',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        ),
                      ),
                      onTap: _pickReminderTime,
                    ),
                    _buildCardRow(
                      icon: Icons.auto_stories_outlined,
                      label: 'Writing Style',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Memoir', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted.withAlpha(76)),
                        ],
                      ),
                      onTap: _pickWritingStyle,
                    ),
                    _buildCardRow(
                      icon: Icons.account_tree_outlined,
                      label: 'Chapter Organization',
                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted.withAlpha(76)),
                      onTap: _pickBookOrganization,
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // LANGUAGE & APPEARANCE
                  _buildSectionLabel('Preferences'),
                  _buildCardGroup([
                    _buildLanguageSelector(),
                    _buildCardRow(
                      icon: Icons.palette_outlined,
                      label: 'Appearance',
                      trailing: const SizedBox.shrink(),
                      isLast: true,
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _buildThemeSelector(),
                  ),
                  const SizedBox(height: 12),
                  _buildCardGroup([
                    _buildCardRow(
                      icon: Icons.dark_mode_outlined,
                      label: 'Dark Mode',
                      trailing: _buildDarkModeToggle(),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // PRIVACY & SECURITY
                  _buildSectionLabel('Privacy & Security'),
                  _buildCardGroup([
                    _buildCardRow(
                      icon: Icons.fingerprint,
                      label: 'Biometric Lock',
                      trailing: _buildCustomToggle(
                        value: _biometricLockEnabled,
                        onChanged: _biometricAvailable ? _toggleBiometric : null,
                      ),
                    ),
                    _buildCardRow(
                      icon: Icons.dialpad,
                      label: 'PIN Lock',
                      trailing: _lockMethod == 'pin'
                          ? GestureDetector(
                              onTap: _clearLockMethod,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Active', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                              ),
                            )
                          : GestureDetector(
                              onTap: _setupPin,
                              child: Text('Set up', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                            ),
                    ),
                    _buildCardRow(
                      icon: Icons.pattern,
                      label: 'Pattern Lock',
                      trailing: _lockMethod == 'pattern'
                          ? GestureDetector(
                              onTap: _clearLockMethod,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Active', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                              ),
                            )
                          : GestureDetector(
                              onTap: _setupPattern,
                              child: Text('Set up', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                            ),
                    ),
                    _buildCardRow(
                      icon: Icons.enhanced_encryption_outlined,
                      label: 'Encryption Info',
                      trailing: Icon(Icons.info_outline, size: 16, color: AppColors.textMuted.withAlpha(102)),
                      onTap: _showEncryptionInfo,
                    ),
                    _buildCardRow(
                      icon: Icons.do_not_disturb_on_outlined,
                      label: 'Do Not Sell My Data',
                      trailing: _buildCustomToggle(value: _doNotSell, onChanged: _toggleDoNotSell),
                    ),
                    _buildCardRow(
                      icon: Icons.health_and_safety_outlined,
                      label: 'Mood Data Consent',
                      trailing: _buildCustomToggle(value: _healthConsent, onChanged: _toggleHealthConsent),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // DATA
                  _buildSectionLabel('Data'),
                  _buildCardGroup([
                    _buildCardRow(
                      icon: Icons.download_outlined,
                      label: 'Export All Data',
                      trailing: Text(
                        'PDF / JSON',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
                      ),
                      onTap: _exportAllData,
                    ),
                    _buildCardRow(
                      icon: Icons.delete_forever,
                      iconColor: Colors.red.shade400,
                      label: 'Delete Account',
                      labelColor: Colors.red.shade500.withAlpha(204),
                      trailing: const SizedBox.shrink(),
                      onTap: _deleteAccount,
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // ABOUT
                  _buildSectionLabel('About'),
                  _buildCardGroup([
                    _buildCardRow(
                      icon: null,
                      label: 'Version',
                      trailing: Text('1.2.0', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    _buildCardRow(
                      icon: null,
                      label: 'Privacy Policy',
                      trailing: Icon(Icons.open_in_new, size: 14, color: AppColors.textMuted.withAlpha(76)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                      ),
                    ),
                    _buildCardRow(
                      icon: null,
                      label: 'Terms of Service',
                      trailing: Icon(Icons.open_in_new, size: 14, color: AppColors.textMuted.withAlpha(76)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                      ),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 36),
                  _buildFooter(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header — frosted, sticky
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgLight.withAlpha(204),
        border: Border(bottom: BorderSide(color: AppColors.primary.withAlpha(26))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Settings',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24), // spacer for symmetry
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile — avatar ring, Playfair name, Edit Profile pill
  // ---------------------------------------------------------------------------

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

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Center(
        child: Column(
          children: [
            // Avatar with gold border ring
            Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withAlpha(38),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
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
            const SizedBox(height: 16),
            // Name — Playfair Display serif bold
            Text(
              displayName,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Edit Profile pill button
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  'Edit Profile',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section label — gold uppercase
  // ---------------------------------------------------------------------------

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card group — white rounded container
  // ---------------------------------------------------------------------------

  Widget _buildCardGroup(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(13)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card row — single row inside a card group
  // ---------------------------------------------------------------------------

  Widget _buildCardRow({
    IconData? icon,
    required String label,
    required Widget trailing,
    Color? iconColor,
    Color? labelColor,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: AppColors.primary.withAlpha(13))),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? AppColors.textPrimary.withAlpha(102), size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
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

  // ---------------------------------------------------------------------------
  // Dark mode toggle
  // ---------------------------------------------------------------------------

  Widget _buildDarkModeToggle() {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == ThemeMode.dark;

    return _buildCustomToggle(
      value: isDark,
      onChanged: (value) {
        ref.read(themeProvider.notifier).setThemeMode(
              value ? ThemeMode.dark : ThemeMode.light,
            );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Custom gold toggle
  // ---------------------------------------------------------------------------

  Widget _buildCustomToggle({
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? AppColors.primary : const Color(0xFFE0DCD7),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final currentLocale = ref.watch(localeProvider).appLocale;

    return _buildCardRow(
      icon: Icons.language,
      label: 'App Language',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLocale.label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted.withAlpha(76)),
        ],
      ),
      onTap: () => _pickLanguage(),
      isLast: true,
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

    return Row(
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
                  color: isSelected ? AppColors.primary : AppColors.primary.withAlpha(26),
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
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.primary.withAlpha(51),
                      ),
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
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Opacity(
        opacity: 0.2,
        child: Column(
          children: [
            Icon(Icons.auto_stories, size: 36, color: AppColors.textPrimary),
            const SizedBox(height: 8),
            Text(
              'DearDays',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
