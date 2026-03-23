import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dd_logo.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/services/auth/auth_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/features/auth/presentation/screens/pin_screen.dart';
import 'package:deardays/features/auth/presentation/screens/pattern_screen.dart';
import 'package:deardays/features/settings/presentation/screens/terms_screen.dart';
import 'package:deardays/features/settings/presentation/screens/privacy_screen.dart';
import 'package:deardays/features/settings/presentation/screens/cookie_policy_screen.dart';
import 'package:deardays/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:deardays/features/settings/presentation/screens/subscription_screen.dart';
import 'package:deardays/features/settings/presentation/screens/e2e_encryption_screen.dart';
import 'package:deardays/core/widgets/snack_bar_helper.dart';
import 'package:deardays/core/providers/subscription_providers.dart';

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
  bool _aiStoryEnabled = true;
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
      await AuthService().signOut();
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

  void _changePassword() {
    // Navigate to Edit Profile where the in-app password change safely
    // re-encrypts all journal entries with the new key.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
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
                      color: AppColors.error)),
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

    try {
      final box = await Hive.openBox('settings');
      final saved = box.get('ai_story_enabled') as bool?;
      if (mounted) setState(() => _aiStoryEnabled = saved ?? true);
    } catch (_) {}
  }

  Future<void> _toggleStreakMilestones(bool value) async {
    setState(() => _streakMilestonesEnabled = value);
    try {
      final box = await Hive.openBox('settings');
      await box.put('streak_milestones_enabled', value);
    } catch (_) {}
  }

  Future<void> _toggleAiStory(bool value) async {
    setState(() => _aiStoryEnabled = value);
    ref.read(aiStoryEnabledProvider.notifier).set(value);
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);

    try {
      if (value) {
        // Enable: schedule daily reminder + morning writing prompt
        await Future.wait([
          NotificationService().scheduleDailyReminder(_reminderTime),
          NotificationService().scheduleWritingPrompt(
            const TimeOfDay(hour: 9, minute: 0),
          ),
        ]);
        await _saveReminderTimeToProfile(_reminderTime);
        if (mounted) {
          AppSnackBar.success(context, 'Daily reminder set for ${_reminderTime.format(context)}');
        }
      } else {
        // Disable: cancel both notifications and clear time from profile
        await Future.wait([
          NotificationService().cancelReminder(),
          NotificationService().cancelWritingPrompt(),
        ]);
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
                color: AppColors.of(context).border,
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
                        ? 'First-person narrative, reflective tone'
                        : s == 'Diary'
                            ? 'First-person, casual daily entries'
                            : 'Cinematic storytelling, vivid scenes',
                    style: GoogleFonts.manrope(fontSize: 12, color: AppColors.of(context).textMuted),
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
                color: AppColors.of(context).border,
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
                    style: GoogleFonts.manrope(fontSize: 12, color: AppColors.of(context).textMuted),
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
  // Export All Data — polished bottom sheet
  // ---------------------------------------------------------------------------

  Future<void> _exportAllData() async {
    final colors = AppColors.of(context);

    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Export Your Memories',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Download all your entries in your preferred format.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // JSON option (only working export)
              _ExportOptionCard(
                icon: Icons.data_object_rounded,
                iconColor: const Color(0xFF3B82F6),
                label: 'JSON',
                description: 'Full data backup — all entries & metadata',
                onTap: () => Navigator.pop(ctx, 'json'),
                colors: colors,
              ),
              const SizedBox(height: 12),
              // PDF option — coming soon
              _ExportOptionCard(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFFEF4444),
                label: 'PDF',
                description: 'Beautiful formatted document',
                badge: 'Coming soon',
                onTap: null,
                colors: colors,
              ),
              const SizedBox(height: 12),
              // Plain text option — coming soon
              _ExportOptionCard(
                icon: Icons.text_snippet_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Plain Text',
                description: 'Simple text file',
                badge: 'Coming soon',
                onTap: null,
                colors: colors,
              ),
            ],
          ),
        ),
        ),
      ),
    );

    if (format == null || !mounted) return;

    if (format == 'pdf') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preparing your PDF export... This feature is coming soon!',
            style: GoogleFonts.manrope(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: colors.accent,
        ),
      );
      return;
    }

    if (format == 'txt') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preparing your plain text export... This feature is coming soon!',
            style: GoogleFonts.manrope(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: colors.accent,
        ),
      );
      return;
    }

    // JSON export
    try {
      AppSnackBar.success(context, 'Exporting your data...');

      final journalRepo = ref.read(journalRepositoryProvider);
      // Paginated fetch to avoid OOM on accounts with many entries
      final entries = <JournalEntry>[];
      const pageSize = 500;
      var offset = 0;
      while (true) {
        final page = await journalRepo.getEntries(limit: pageSize, offset: offset);
        entries.addAll(page);
        if (page.length < pageSize) break;
        offset += pageSize;
      }

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
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      }

      // Clean up temporary export file after sharing.
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
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
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.error)),
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
                    fontWeight: FontWeight.w600, color: AppColors.error)),
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
              hintStyle: GoogleFonts.manrope(color: AppColors.of(context).textMuted),
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
                      fontWeight: FontWeight.w600, color: AppColors.error)),
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
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      textColor: textColor,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.of(context).textMuted),
                      onTap: _changePassword,
                    ),
                    _buildCardRow(
                      icon: Icons.star,
                      iconColor: AppColors.of(context).accent,
                      label: 'Subscription',
                      textColor: textColor,
                      trailing: Builder(builder: (_) {
                        final sub = ref.watch(subscriptionProvider);
                        final label = sub.isPremium
                            ? (sub.activePlan == 'yearly' ? 'Premium (Yearly)' : 'Premium')
                            : 'Free Plan';
                        final color = sub.isPremium
                            ? AppColors.of(context).accent
                            : AppColors.of(context).textMuted;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                          ),
                        );
                      }),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      ),
                    ),
                    _buildCardRow(
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.error,
                      label: 'Sign Out',
                      textColor: AppColors.error,
                      trailing: const SizedBox.shrink(),
                      onTap: _signOut,
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
                          Text(
                            () {
                              final style = ref.watch(profileProvider).valueOrNull?.writingStyle ?? 'memoir';
                              return style[0].toUpperCase() + style.substring(1);
                            }(),
                            style: GoogleFonts.manrope(fontSize: 12, color: subtextColor),
                          ),
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
                    ),
                    _buildCardRow(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'AI Story',
                      textColor: textColor,
                      subtitle: 'Transform entries into literary narratives',
                      trailing: _buildCustomToggle(
                        value: _aiStoryEnabled,
                        onChanged: _toggleAiStory,
                      ),
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
                      icon: Icons.lock_outline_rounded,
                      label: 'App Lock',
                      textColor: textColor,
                      subtitle: _lockMethod == 'none' && !_biometricLockEnabled
                          ? 'No lock set'
                          : _biometricLockEnabled
                              ? 'Biometric'
                              : _lockMethod == 'pin'
                                  ? 'PIN active'
                                  : 'Pattern active',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_lockMethod != 'none' || _biometricLockEnabled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.of(context).accent.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Active', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.of(context).accent)),
                            ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.of(context).textMuted),
                        ],
                      ),
                      onTap: _showAppLockPicker,
                    ),
                    _buildCardRow(
                      icon: Icons.enhanced_encryption_outlined,
                      label: 'End-to-End Encryption',
                      textColor: textColor,
                      subtitle: ref.watch(profileProvider).valueOrNull?.e2eEnabled == true
                          ? 'Active — only you can read your entries'
                          : 'Off — tap to set up',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ref.watch(profileProvider).valueOrNull?.e2eEnabled == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.of(context).accent.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('On', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.of(context).accent)),
                            ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.of(context).textMuted),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const E2EEncryptionScreen()),
                      ),
                    ),
                    _buildCardRow(
                      icon: Icons.health_and_safety_outlined,
                      label: 'Mood Data Consent',
                      textColor: textColor,
                      subtitle: 'Allow mood analytics to improve AI insights',
                      trailing: _buildCustomToggle(value: _healthConsent, onChanged: _toggleHealthConsent),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // DATA
                  _buildSectionLabel('Data'),
                  _buildCardGroup(cardColor, [
                    _buildCardRow(
                      icon: Icons.cloud_sync_outlined,
                      label: 'Backup & Restore',
                      textColor: textColor,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.of(context).textMuted),
                      onTap: () => context.push('/backup-restore'),
                    ),
                    _buildCardRow(
                      icon: Icons.download_outlined,
                      label: 'Export All Data',
                      textColor: textColor,
                      trailing: Text(
                        'JSON',
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.of(context).accent),
                      ),
                      onTap: _exportAllData,
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // DELETE ACCOUNT — separated from safe data actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: _deleteAccount,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.delete_forever_rounded, size: 22, color: AppColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Delete Account',
                                      style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                                  Text('Permanently erases all your journal data',
                                      style: GoogleFonts.manrope(fontSize: 11, color: AppColors.error.withAlpha(180))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                    ),
                    _buildCardRow(
                      icon: null,
                      label: 'Cookie & Tracking Policy',
                      textColor: textColor,
                      trailing: Icon(Icons.open_in_new, size: 14, color: AppColors.of(context).textMuted.withAlpha(76)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CookiePolicyScreen()),
                      ),
                      isLast: true,
                    ),
                  ]),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.of(context).cardBg,
                  ),
                  child: Icon(Icons.arrow_back_rounded, size: 20, color: textColor),
                ),
              ),
              Expanded(
                child: Text(
                  'Settings',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 40), // balance the back button
            ],
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
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              memCacheWidth: 180,
                              memCacheHeight: 180,
                              errorWidget: (_, __, ___) => _buildInitialsCircle(initials),
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
                  color: AppColors.of(context).textPrimary.withAlpha(12),
                  border: Border.all(color: AppColors.of(context).textPrimary.withAlpha(30)),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  'Edit Profile',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).textPrimary,
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
              color: AppColors.of(context).textPrimary.withAlpha(8),
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
    String? subtitle,
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
              child: subtitle != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: labelColor ?? textColor ?? AppColors.of(context).textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppColors.of(context).textMuted,
                          ),
                        ),
                      ],
                    )
                  : Text(
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

  // ---------------------------------------------------------------------------
  // App Lock Picker
  // ---------------------------------------------------------------------------

  Future<void> _showAppLockPicker() async {
    final colors = AppColors.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('App Lock', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Choose how to protect your journal', style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary)),
              const SizedBox(height: 16),
              _lockOptionTile(ctx, icon: Icons.lock_open_outlined, label: 'No Lock',
                  desc: 'Journal opens without authentication',
                  isActive: _lockMethod == 'none' && !_biometricLockEnabled,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _clearLockMethod();
                    if (_biometricLockEnabled) await _toggleBiometric(false);
                  }, colors: colors),
              _lockOptionTile(ctx, icon: Icons.dialpad, label: 'PIN',
                  desc: '4-digit PIN to unlock',
                  isActive: _lockMethod == 'pin',
                  onTap: () { Navigator.pop(ctx); _setupPin(); }, colors: colors),
              _lockOptionTile(ctx, icon: Icons.pattern, label: 'Pattern',
                  desc: 'Draw a pattern to unlock',
                  isActive: _lockMethod == 'pattern',
                  onTap: () { Navigator.pop(ctx); _setupPattern(); }, colors: colors),
              if (_biometricAvailable)
                _lockOptionTile(ctx, icon: Icons.fingerprint, label: 'Biometric',
                    desc: 'Face ID or fingerprint',
                    isActive: _biometricLockEnabled,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _toggleBiometric(!_biometricLockEnabled);
                    }, colors: colors),
              if (!_biometricAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.fingerprint, size: 20, color: colors.textMuted.withAlpha(100)),
                      const SizedBox(width: 12),
                      Text('Biometric not available on this device',
                          style: GoogleFonts.manrope(fontSize: 13, color: colors.textMuted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lockOptionTile(BuildContext ctx, {
    required IconData icon, required String label, required String desc,
    required bool isActive, required VoidCallback onTap, required AppPalette colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? colors.accent.withAlpha(15) : colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? colors.accent.withAlpha(80) : colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isActive ? colors.accent : colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isActive ? colors.accent : colors.textPrimary)),
                  Text(desc, style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted)),
                ],
              ),
            ),
            if (isActive) Icon(Icons.check_circle_rounded, size: 20, color: colors.accent),
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
          color: value ? AppColors.of(context).accent : AppColors.of(context).border,
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
                color: AppColors.of(context).border,
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
                color: AppColors.of(context).border,
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
                    child: Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.light.accent,
                        ),
                      ),
                    ),
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
            const DdLogo(size: 44),
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

// ─────────────────────────────────────────────────────────────────────────────
// Export option card widget
// ─────────────────────────────────────────────────────────────────────────────

class _ExportOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback? onTap;
  final AppPalette colors;
  final String? badge;

  const _ExportOptionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
    required this.colors,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge!, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: colors.textMuted)),
                )
              else
                Icon(Icons.chevron_right_rounded, size: 20, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
