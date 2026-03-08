import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
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

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  bool _biometricLockEnabled = false;
  bool _biometricAvailable = false;
  String _lockMethod = 'none';
  bool _healthConsent = false;
  bool _notificationsEnabled = false;
  bool _streakMilestonesEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 30);
  final _secureStorage = SecureStorageService();
  final _localAuth = LocalAuthentication();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    _loadPrivacyState();
    _loadNotificationState();
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
          _healthConsent = profile.healthConsentGivenAt != null;
        });
      }
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out?',
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary)),
        content: Text(
          'You will need to sign in again to access your journal.',
          style: GoogleFonts.manrope(fontSize: 14, height: 1.5, color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to sign out. Please try again.');
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.of(context).textMuted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text('Take a photo',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text('Choose from gallery',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath = 'avatars/$userId.$ext';
      final bytes = await File(picked.path).readAsBytes();

      await client.storage.from('media').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true,
        ),
      );

      final publicUrl =
          client.storage.from('media').getPublicUrl(storagePath);

      final profileRepo = ref.read(profileRepositoryProvider);
      final profile = await ref.read(profileProvider.future);
      if (profile != null) {
        await profileRepo.updateProfile(profile.copyWith(avatarUrl: publicUrl));
        ref.invalidate(profileProvider);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to update photo: $e');
      }
    }
  }

  Future<void> _changePassword() async {
    final emailController = TextEditingController();
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    emailController.text = email;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Password',
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We will send a password reset link to your email.',
              style: GoogleFonts.manrope(fontSize: 14, height: 1.5, color: AppColors.of(context).textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Send Reset Link',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.of(context).accent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        AppSnackBar.success(context, 'Password reset link sent to $email');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to send reset link.');
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
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Text(
            'Mood tracking will be disabled. Existing mood data in your entries '
            'will not be deleted but will no longer be processed.',
            style: GoogleFonts.manrope(
                fontSize: 14, height: 1.5, color: AppColors.of(context).textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Withdraw Consent',
                  style: GoogleFonts.manrope(
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
  // Notifications
  // ---------------------------------------------------------------------------

  Future<void> _loadNotificationState() async {
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final profile = await profileRepo.getProfile();
      if (profile != null && mounted) {
        final hasReminder = profile.reminderTime != null && profile.reminderTime!.isNotEmpty;
        setState(() {
          _notificationsEnabled = hasReminder;
          if (hasReminder) {
            final parts = profile.reminderTime!.split(':');
            if (parts.length >= 2) {
              _reminderTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          }
        });
      }
    } catch (_) {}

    try {
      final box = await Hive.openBox('settings');
      final saved = box.get('streak_milestones_enabled') as bool?;
      if (saved != null && mounted) {
        setState(() => _streakMilestonesEnabled = saved);
      }
    } catch (_) {}
  }

  Future<void> _toggleStreakMilestones(bool value) async {
    setState(() => _streakMilestonesEnabled = value);
    try {
      final box = await Hive.openBox('settings');
      await box.put('streak_milestones_enabled', value);
    } catch (_) {}
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);

    try {
      if (value) {
        // Enable: schedule notification and save time to profile
        await NotificationService().scheduleDailyReminder(_reminderTime);
        await _saveReminderTimeToProfile(_reminderTime);
        if (mounted) {
          AppSnackBar.success(context, 'Daily reminder set for ${_reminderTime.format(context)}');
        }
      } else {
        // Disable: cancel notification and clear time from profile
        await NotificationService().cancelReminder();
        await _clearReminderTimeFromProfile();
        if (mounted) {
          AppSnackBar.success(context, 'Daily reminder turned off');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notificationsEnabled = !value);
        AppSnackBar.error(context, 'Failed to update notification settings.');
      }
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.of(context).accent),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _reminderTime = picked);

    try {
      await NotificationService().scheduleDailyReminder(picked);
      await _saveReminderTimeToProfile(picked);
      if (mounted) {
        AppSnackBar.success(context, 'Reminder updated to ${picked.format(context)}');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to update reminder time.');
      }
    }
  }

  Future<void> _saveReminderTimeToProfile(TimeOfDay time) async {
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final profileRepo = ref.read(profileRepositoryProvider);
    final profile = await profileRepo.getProfile();
    if (profile != null) {
      await profileRepo.updateProfile(profile.copyWith(reminderTime: timeStr));
    }
  }

  Future<void> _clearReminderTimeFromProfile() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      await client.from('profiles').update({'reminder_time': null}).eq('id', userId);
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
              style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...styles.map((s) => ListTile(
                  leading: Icon(
                    s == 'Memoir'
                        ? Icons.auto_stories
                        : s == 'Diary'
                            ? Icons.book
                            : Icons.movie_creation_outlined,
                    color: AppColors.of(context).accent,
                  ),
                  title: Text(s, style: GoogleFonts.manrope(fontSize: 15)),
                  subtitle: Text(
                    s == 'Memoir'
                        ? 'Third-person narrative, reflective tone'
                        : s == 'Diary'
                            ? 'First-person, casual daily entries'
                            : 'Cinematic storytelling, vivid scenes',
                    style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500),
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
      {'value': 'yearly', 'label': 'Yearly', 'desc': 'A new book is created each year'},
      {'value': 'monthly', 'label': 'Monthly', 'desc': 'A new book is created each month'},
      {'value': 'quarterly', 'label': 'Quarterly', 'desc': 'A new book is created each quarter'},
      {'value': 'manual', 'label': 'One Book', 'desc': 'All entries go into a single book'},
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
              style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...options.map((o) => ListTile(
                  leading: Icon(Icons.library_books_outlined, color: AppColors.of(context).accent),
                  title: Text(o['label']!, style: GoogleFonts.manrope(fontSize: 15)),
                  subtitle: Text(
                    o['desc']!,
                    style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500),
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
            Icon(Icons.shield_outlined, color: AppColors.of(context).accent, size: 24),
            const SizedBox(width: 10),
            Text('Zero-Knowledge Encryption',
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600)),
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
              style: GoogleFonts.manrope(
                fontSize: 13, height: 1.5, color: AppColors.of(context).textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
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
                style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.manrope(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary)),
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
                style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.code, color: AppColors.of(context).accent),
              title: Text('JSON', style: GoogleFonts.manrope(fontSize: 15)),
              subtitle: Text('Machine-readable, includes all fields',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500)),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: AppColors.of(context).accent),
              title: Text('PDF', style: GoogleFonts.manrope(fontSize: 15)),
              subtitle: Text('Print-ready book format',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade500)),
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
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: Colors.red.shade700)),
        content: Text(
          'This will permanently delete your account and all journal entries. '
          'This action cannot be undone.\n\n'
          'Your encrypted data will be erased from the server.',
          style: GoogleFonts.manrope(fontSize: 14, height: 1.5, color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete Everything',
                style: GoogleFonts.manrope(
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
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'DELETE',
              hintStyle: GoogleFonts.manrope(color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim() == 'DELETE') {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text('Confirm Delete',
                  style: GoogleFonts.manrope(
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
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = AppColors.of(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = palette.card;
    final textColor = palette.textPrimary;
    final subtextColor = palette.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          _buildHeader(context, bgColor, textColor),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSection(textColor, subtextColor),
                  const SizedBox(height: 24),
                  // ACCOUNT
                  _buildSectionLabel('Account'),
                  _buildCardGroup(cardColor, [
                    _buildCardRow(
                      icon: Icons.mail_outlined,
                      label: 'Email',
                      textColor: textColor,
                      trailing: Text(
                        Supabase.instance.client.auth.currentUser?.email ?? '',
                        style: GoogleFonts.manrope(fontSize: 12, color: subtextColor),
                      ),
                    ),
                    _buildCardRow(
                      icon: Icons.lock_outlined,
                      label: 'Password',
                      textColor: textColor,
                      trailing: Text('Change', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF111111))),
                      onTap: _changePassword,
                    ),
                    _buildCardRow(
                      icon: Icons.star,
                      iconColor: AppColors.of(context).accent,
                      label: 'Subscription',
                      textColor: textColor,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Premium Plan',
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.of(context).accent),
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      ),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // NOTIFICATIONS
                  _buildSectionLabel('Notifications'),
                  _buildCardGroup(cardColor, [
                    _buildCardRow(
                      icon: Icons.notifications_outlined,
                      label: 'Daily Reminder',
                      textColor: textColor,
                      trailing: _buildCustomToggle(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                      ),
                    ),
                    if (_notificationsEnabled)
                      _buildCardRow(
                        icon: Icons.access_time,
                        label: 'Reminder Time',
                        textColor: textColor,
                        trailing: GestureDetector(
                          onTap: _pickReminderTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.of(context).accent.withAlpha(51)),
                            ),
                            child: Text(
                              _reminderTime.format(context),
                              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
                            ),
                          ),
                        ),
                        isLast: !_notificationsEnabled,
                      ),
                    _buildCardRow(
                      icon: Icons.celebration_outlined,
                      label: 'Streak Milestones',
                      textColor: textColor,
                      trailing: _buildCustomToggle(
                        value: _streakMilestonesEnabled,
                        onChanged: _toggleStreakMilestones,
                      ),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // JOURNALING
                  _buildSectionLabel('Journaling'),
                  _buildCardGroup(cardColor, [
                    _buildCardRow(
                      icon: Icons.auto_stories_outlined,
                      label: 'Writing Style',
                      textColor: textColor,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Memoir', style: GoogleFonts.manrope(fontSize: 12, color: subtextColor)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.of(context).textMuted.withAlpha(76)),
                        ],
                      ),
                      onTap: _pickWritingStyle,
                    ),
                    _buildCardRow(
                      icon: Icons.account_tree_outlined,
                      label: 'Chapter Organization',
                      textColor: textColor,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            () {
                              final org = ref.watch(profileProvider).valueOrNull?.bookOrganization ?? 'yearly';
                              switch (org) {
                                case 'monthly': return 'Monthly';
                                case 'quarterly': return 'Quarterly';
                                case 'manual': return 'One Book';
                                default: return 'Yearly';
                              }
                            }(),
                            style: GoogleFonts.manrope(fontSize: 12, color: subtextColor),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.of(context).textMuted.withAlpha(76)),
                        ],
                      ),
                      onTap: _pickBookOrganization,
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // PREFERENCES
                  _buildSectionLabel('Preferences'),
                  _buildCardGroup(cardColor, [
                    _buildLanguageSelector(textColor, subtextColor),
                    _buildAppearanceDropdown(textColor, subtextColor),
                  ]),
                  const SizedBox(height: 24),
                  // PRIVACY & SECURITY
                  _buildSectionLabel('Privacy & Security'),
                  _buildCardGroup(cardColor, [
                    _buildCardRow(
                      icon: Icons.fingerprint,
                      label: 'Biometric Lock',
                      textColor: textColor,
                      trailing: _buildCustomToggle(
                        value: _biometricLockEnabled,
                        onChanged: _biometricAvailable ? _toggleBiometric : null,
                      ),
                    ),
                    _buildCardRow(
                      icon: Icons.dialpad,
                      label: 'PIN Lock',
                      textColor: textColor,
                      trailing: _lockMethod == 'pin'
                          ? GestureDetector(
                              onTap: _clearLockMethod,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.of(context).accent.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Active', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.of(context).accent)),
                              ),
                            )
                          : GestureDetector(
                              onTap: _setupPin,
                              child: Text('Set up', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.of(context).accent)),
                            ),
                    ),
                    _buildCardRow(
                      icon: Icons.pattern,
                      label: 'Pattern Lock',
                      textColor: textColor,
                      trailing: _lockMethod == 'pattern'
                          ? GestureDetector(
                              onTap: _clearLockMethod,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.of(context).accent.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Active', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.of(context).accent)),
                              ),
                            )
                          : GestureDetector(
                              onTap: _setupPattern,
                              child: Text('Set up', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.of(context).accent)),
                            ),
                    ),
                    _buildCardRow(
                      icon: Icons.enhanced_encryption_outlined,
                      label: 'Encryption Info',
                      textColor: textColor,
                      trailing: Icon(Icons.info_outline, size: 16, color: AppColors.of(context).textMuted.withAlpha(102)),
                      onTap: _showEncryptionInfo,
                    ),
                    _buildCardRow(
                      icon: Icons.health_and_safety_outlined,
                      label: 'Mood Data Consent',
                      textColor: textColor,
                      trailing: _buildCustomToggle(value: _healthConsent, onChanged: _toggleHealthConsent),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // DATA
                  _buildSectionLabel('Data'),
                  _buildCardGroup(cardColor, [
                    _buildCardRow(
                      icon: Icons.download_outlined,
                      label: 'Export All Data',
                      textColor: textColor,
                      trailing: Text(
                        'PDF / JSON',
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.of(context).accent),
                      ),
                      onTap: _exportAllData,
                    ),
                    _buildCardRow(
                      icon: Icons.delete_forever,
                      label: 'Delete Account',
                      textColor: textColor,
                      trailing: const SizedBox.shrink(),
                      onTap: _deleteAccount,
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // ABOUT
                  _buildSectionLabel('About'),
                  _buildCardGroup(cardColor, [
                    _buildCardRow(
                      icon: null,
                      label: 'Version',
                      textColor: textColor,
                      trailing: Text('1.2.0', style: GoogleFonts.manrope(fontSize: 12, color: AppColors.of(context).textMuted)),
                    ),
                    _buildCardRow(
                      icon: null,
                      label: 'Privacy Policy',
                      textColor: textColor,
                      trailing: Icon(Icons.open_in_new, size: 14, color: AppColors.of(context).textMuted.withAlpha(76)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                      ),
                    ),
                    _buildCardRow(
                      icon: null,
                      label: 'Terms of Service',
                      textColor: textColor,
                      trailing: Icon(Icons.open_in_new, size: 14, color: AppColors.of(context).textMuted.withAlpha(76)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                      ),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // SIGN OUT
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(
                          'Sign Out',
                          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0x44EF4444)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  _buildFooter(textColor),
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
  // Header — uses DearDaysHeader pattern
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, Color bgColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor.withAlpha(204),
        border: Border(bottom: BorderSide(color: AppColors.of(context).accent.withAlpha(26))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: Text(
              'Settings',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile — avatar ring, Playfair name, Edit Profile pill
  // ---------------------------------------------------------------------------

  Widget _buildInitialsCircle(String initials) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.of(context).accent.withAlpha(38),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AppColors.of(context).accent,
        ),
      ),
    );
  }

  Widget _buildProfileSection(Color textColor, Color subtextColor) {
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

    final profileAsync = ref.watch(profileProvider);
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Center(
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickProfilePhoto,
              child: Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.of(context).accent, width: 2),
                    ),
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              avatarUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildInitialsCircle(initials),
                            ),
                          )
                        : _buildInitialsCircle(initials),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.of(context).accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.manrope(fontSize: 13, color: subtextColor),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111).withAlpha(12),
                  border: Border.all(color: const Color(0xFF111111).withAlpha(30)),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  'Edit Profile',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.of(context).textMuted,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _buildCardGroup(Color cardColor, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.of(context).accent.withAlpha(13)),
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

  Widget _buildCardRow({
    IconData? icon,
    required String label,
    required Widget trailing,
    Color? iconColor,
    Color? labelColor,
    Color? textColor,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: AppColors.of(context).accent.withAlpha(13))),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? (textColor ?? AppColors.of(context).textPrimary).withAlpha(178), size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? textColor ?? AppColors.of(context).textPrimary,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

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
          color: value ? AppColors.of(context).accent : const Color(0xFFE0DCD7),
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

  Widget _buildLanguageSelector(Color textColor, Color subtextColor) {
    final currentLocale = ref.watch(localeProvider).appLocale;

    return _buildCardRow(
      icon: Icons.language,
      label: 'App Language',
      textColor: textColor,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLocale == AppLocale.system
                ? currentLocale.languageName
                : currentLocale.label,
            style: GoogleFonts.manrope(fontSize: 12, color: subtextColor),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.of(context).textMuted.withAlpha(76)),
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
              style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...AppLocale.values.map((locale) => ListTile(
                  leading: Icon(
                    locale == AppLocale.system
                        ? Icons.phone_android
                        : Icons.translate,
                    color: AppColors.of(context).accent,
                  ),
                  title: Text(locale.label, style: GoogleFonts.manrope(fontSize: 15)),
                  trailing: locale == currentLocale
                      ? Icon(Icons.check_circle, color: AppColors.of(context).accent, size: 22)
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

  // ---------------------------------------------------------------------------
  // Appearance dropdown (replaces old theme selector + dark mode toggle)
  // ---------------------------------------------------------------------------

  Widget _buildAppearanceDropdown(Color textColor, Color subtextColor) {
    final currentTheme = ref.watch(themeProvider).themeColor;

    return _buildCardRow(
      icon: Icons.palette_outlined,
      label: 'Appearance',
      textColor: textColor,
      trailing: GestureDetector(
        onTap: _pickAppearance,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.of(context).accent.withAlpha(51)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: currentTheme.light.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.of(context).accent.withAlpha(76)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                currentTheme.label,
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: subtextColor),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16, color: subtextColor),
            ],
          ),
        ),
      ),
      isLast: true,
    );
  }

  Future<void> _pickAppearance() async {
    final currentTheme = ref.read(themeProvider).themeColor;

    final picked = await showModalBottomSheet<AppThemeColor>(
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
              'Appearance',
              style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...AppThemeColor.values.map((palette) => ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.light.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.of(context).accent.withAlpha(76)),
                    ),
                    child: palette.isDark
                        ? Icon(Icons.dark_mode, size: 16, color: AppColors.of(context).accent)
                        : null,
                  ),
                  title: Text(palette.label, style: GoogleFonts.manrope(fontSize: 15)),
                  trailing: palette == currentTheme
                      ? Icon(Icons.check_circle, color: AppColors.of(context).accent, size: 22)
                      : null,
                  onTap: () => Navigator.pop(ctx, palette),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;
    ref.read(themeProvider.notifier).setThemeColor(picked);
  }

  Widget _buildFooter(Color textColor) {
    return Center(
      child: Opacity(
        opacity: 0.3,
        child: Column(
          children: [
            Image.asset('assets/images/logo.png', width: 44, height: 44),
            const SizedBox(height: 8),
            Text(
              'DearDays',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
