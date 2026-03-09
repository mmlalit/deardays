import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/save_success_overlay.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/encryption/encryption_service.dart';
import 'package:deardays/services/media/media_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';

/// Data passed between RecordingScreen → ProcessingScreen → ReviewSaveScreen.
class ReviewData {
  final String rawText;
  final String? mood;
  final String? locationName;
  final String? attachedPhotoPath;
  final String? audioPath;
  final bool isVoice;
  final bool polishWithAI;

  const ReviewData({
    required this.rawText,
    this.mood,
    this.locationName,
    this.attachedPhotoPath,
    this.audioPath,
    this.isVoice = false,
    this.polishWithAI = false,
  });
}

class ReviewSaveScreen extends ConsumerStatefulWidget {
  final ReviewData data;

  const ReviewSaveScreen({super.key, required this.data});

  @override
  ConsumerState<ReviewSaveScreen> createState() => _ReviewSaveScreenState();
}

class _ReviewSaveScreenState extends ConsumerState<ReviewSaveScreen>
    with SingleTickerProviderStateMixin {
  final _aiService = AiService();
  late final JournalRepository _repository = JournalRepository(
    client: Supabase.instance.client,
    encryption: EncryptionService(),
  );
  late final MediaService _mediaService = MediaService(
    client: Supabase.instance.client,
  );
  final _imagePicker = ImagePicker();

  // Polish state
  bool _isPolishing = false;
  double _polishProgress = 0.0;
  String? _cleanedText; // light polish: grammar/spelling fixed
  String? _polishedText; // full AI literary narrative
  String? _generatedTitle;
  String? _polishError;

  // View toggle: 0 = AI Story, 1 = Clean Original, 2 = Raw Words
  int _activeTab = 0;

  // Save state
  bool _isSaving = false;
  String? _attachedPhotoPath;
  String? _locationName;

  // Shimmer animation
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _attachedPhotoPath = widget.data.attachedPhotoPath;
    _locationName = widget.data.locationName;

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Only auto-polish if the user turned on AI Polish
    if (widget.data.polishWithAI) {
      _polishText();
    } else {
      _activeTab = 2; // Show original/raw text by default
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _polishText() async {
    setState(() {
      _isPolishing = true;
      _polishProgress = 0.0;
      _polishError = null;
    });

    try {
      // Step 1: Light polish — fix grammar/spelling (0% → 40%)
      _animateProgress(0.0, 0.4);
      final cleaned = await _aiService.lightPolish(widget.data.rawText);
      if (!mounted) return;
      setState(() => _cleanedText = cleaned);

      // Step 2: Literary polish — full AI narrative (40% → 100%)
      _animateProgress(0.4, 0.85);
      final result = await _aiService.polishNarrative(
        cleaned,
        style: 'memoir',
      );

      // Extract title (first line) and body
      final lines = result.split('\n').where((l) => l.trim().isNotEmpty).toList();
      String title;
      String body;

      if (lines.length > 1 && lines.first.length < 80) {
        title = lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();
        body = lines.skip(1).join('\n\n').trim();
      } else {
        title = _generateFallbackTitle();
        body = result.trim();
      }

      if (mounted) {
        setState(() {
          _generatedTitle = title;
          _polishedText = body;
          _isPolishing = false;
          _polishProgress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPolishing = false;
          _polishError = 'AI polishing failed. You can save your original text.';
          _polishProgress = 0.0;
          // Default to cleaned text if available, otherwise raw
          _activeTab = _cleanedText != null ? 1 : 2;
        });
      }
    }
  }

  void _animateProgress(double from, double to) async {
    final steps = 5;
    final increment = (to - from) / steps;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && _isPolishing) {
        setState(() => _polishProgress = from + increment * i);
      }
    }
  }

  String _generateFallbackTitle() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return 'A ${months[now.month - 1]} Reflection';
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _attachedPhotoPath = picked.path);
    }
  }

  Future<void> _saveEntry() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toUtc();
      // content = light-polished (or raw if polish failed)
      final content = _cleanedText ?? widget.data.rawText;
      // polishedContent = full AI literary narrative
      final polishedContent = _polishedText != null
          ? '${_generatedTitle ?? ''}\n\n$_polishedText'
          : null;

      final entry = JournalEntry(
        id: const Uuid().v4(),
        userId: Supabase.instance.client.auth.currentUser!.id,
        content: content,
        rawContent: widget.data.rawText,
        polishedContent: polishedContent,
        mood: widget.data.mood,
        entryDate: now,
        entryTime: TimeOfDay.fromDateTime(now),
        isAiPolished: _polishedText != null,
        locationName: _locationName,
        hasPhoto: _attachedPhotoPath != null,
        hasVoice: widget.data.isVoice,
        wordCount: content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
        createdAt: now,
        updatedAt: now,
      );

      final saved = await _repository.createEntry(entry);

      // Auto-create book if none exists
      try {
        final profile = await ref.read(profileProvider.future);
        final organization = profile?.bookOrganization ?? 'yearly';
        final bookRepo = ref.read(bookRepositoryProvider);
        await bookRepo.ensureDefaultBook(organization);
      } catch (_) {}

      // Upload photo if attached
      if (_attachedPhotoPath != null) {
        try {
          await _mediaService.uploadPhoto(
            entryId: saved.id,
            filePath: _attachedPhotoPath!,
          );
        } catch (_) {}
      }

      // Check streak: show milestone notification + update daily reminder
      try {
        final profileRepo = ProfileRepository(
          client: Supabase.instance.client,
        );
        final streak = await profileRepo.getStreak();
        if (streak != null) {
          // Show milestone celebration if applicable
          if (NotificationService.isStreakMilestone(streak.currentStreak)) {
            await NotificationService().showStreakNotification(
              streak.currentStreak,
            );
          }
          // Re-schedule daily reminder with updated streak count
          final profile = await profileRepo.getProfile();
          if (profile?.reminderTime != null) {
            final parts = profile!.reminderTime!.split(':');
            if (parts.length >= 2) {
              final time = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
              await NotificationService().scheduleDailyReminder(
                time,
                streak: streak.currentStreak,
              );
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        // Invalidate providers so home screen and timeline refresh
        ref.invalidate(todayEntryProvider);
        ref.invalidate(timelineEntriesProvider);
        ref.invalidate(booksProvider);

        await SaveSuccessOverlay.show(
          context,
          onDismiss: () {
            if (mounted) {
              // Pop back to home (through any intermediate screens)
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo or gradient banner
                  _buildPhotoOrGradientBanner(),

                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      _generatedTitle ?? (_isPolishing ? 'Writing your story...' : 'Your Memory'),
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab bar: Story | Transcript | Audio
                  _buildTabBar(colors),
                  Divider(height: 1, color: colors.border),

                  // AI progress indicator
                  if (_isPolishing) ...[
                    _buildPolishProgress(),
                    const SizedBox(height: 16),
                    _buildShimmerPlaceholders(),
                  ],
                  // Content views
                  if (!_isPolishing) ...[
                    if (_polishedText != null || _cleanedText != null) ...[
                      const SizedBox(height: 8),
                      if (_activeTab == 0 || _activeTab == 1)
                        _buildRevertButton(),
                      const SizedBox(height: 8),
                    ] else if (!widget.data.isVoice) ...[
                      const SizedBox(height: 8),
                      _buildAIPolishButton(),
                      const SizedBox(height: 8),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],
                    if (_polishError != null) ...[
                      _buildErrorState(),
                      const SizedBox(height: 24),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _activeTab == 0 && _polishedText != null
                          ? _buildPolishedView()
                          : _activeTab == 1 && _cleanedText != null
                              ? _buildCleanedView()
                              : _buildOriginalView(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Add photo pill
                  _buildActionPills(),
                ],
              ),
            ),
          ),
          // Bottom dual button bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accentFaint,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.arrow_back_rounded, size: 18, color: colors.textPrimary),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Your Memory',
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share coming soon')),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accentFaint,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.ios_share_outlined, size: 18, color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoOrGradientBanner() {
    final colors = AppColors.of(context);
    if (_attachedPhotoPath != null) {
      return Container(
        height: 220,
        width: double.infinity,
        color: colors.border,
        child: Image.asset(
          _attachedPhotoPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGradientBanner(colors),
        ),
      );
    }
    return _buildGradientBanner(colors);
  }

  Widget _buildGradientBanner(AppPalette colors) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, colors.accentLight],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.menu_book_rounded, size: 120, color: Colors.white.withAlpha(20)),
          ),
          Center(
            child: Icon(Icons.auto_stories_rounded, size: 48, color: Colors.white.withAlpha(200)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI Polish Progress
  // ---------------------------------------------------------------------------

  Widget _buildPolishProgress() {
    final percent = (_polishProgress * 100).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.of(context).accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _polishProgress < 0.4
                      ? 'Cleaning up your words...'
                      : 'AI is writing your story...',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _polishProgress,
              backgroundColor: AppColors.of(context).accent.withAlpha(26),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.of(context).accent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shimmer Placeholders
  // ---------------------------------------------------------------------------

  Widget _buildShimmerPlaceholders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _shimmerBar(width: 200, height: 16),
              const SizedBox(height: 16),
              _shimmerBar(width: double.infinity, height: 12),
              const SizedBox(height: 10),
              _shimmerBar(width: double.infinity, height: 12),
              const SizedBox(height: 10),
              _shimmerBar(width: 250, height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _shimmerBar({required double width, required double height}) {
    final shimmerValue = _shimmerController.value;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.0 * shimmerValue, 0),
          end: Alignment(-1.0 + 2.0 * shimmerValue + 1.0, 0),
          colors: [
            const Color(0xFFE8E4DF),
            const Color(0xFFF5F0EA),
            const Color(0xFFE8E4DF),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI Polish Button (shown when text hasn't been polished yet)
  // ---------------------------------------------------------------------------

  Widget _buildAIPolishButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _polishText,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.of(context).accent.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.of(context).accent.withAlpha(51)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_fix_high, size: 18, color: AppColors.of(context).accent),
              const SizedBox(width: 8),
              Text(
                'AI Polish',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '— Fix spelling & improve readability',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Revert Button (shown when viewing polished text)
  // ---------------------------------------------------------------------------

  Widget _buildRevertButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.undo, size: 14, color: AppColors.of(context).textSecondary),
            const SizedBox(width: 6),
            Text(
              'Revert to original',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.of(context).textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab Bar — Story | Transcript | Audio
  // ---------------------------------------------------------------------------

  Widget _buildTabBar(AppPalette colors) {
    final tabs = <({String label, int index})>[];
    tabs.add((label: 'Story', index: 0));
    if (_cleanedText != null) tabs.add((label: 'Transcript', index: 1));
    tabs.add((label: 'Raw', index: 2));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: tabs.map((tab) {
          final isActive = _activeTab == tab.index;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab.index),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? colors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tab.label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? colors.accent : colors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Keep legacy method for any callers
  Widget _buildViewToggle() => _buildTabBar(AppColors.of(context));

  // ---------------------------------------------------------------------------
  // Polished Story View
  // ---------------------------------------------------------------------------

  Widget _buildPolishedView() {
    final colors = AppColors.of(context);
    final paragraphs = _polishedText!
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Padding(
      key: const ValueKey('polished'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First paragraph as blockquote
          if (paragraphs.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: colors.accent, width: 3),
                ),
              ),
              child: Text(
                '"${paragraphs.first}"',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                  height: 1.8,
                ),
              ),
            ),
          // Remaining paragraphs
          if (paragraphs.length > 1) ...[
            const SizedBox(height: 20),
            ...paragraphs.skip(1).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                p,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  color: colors.textPrimary,
                  height: 1.8,
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cleaned Original View (grammar/spelling fixed, user's voice preserved)
  // ---------------------------------------------------------------------------

  Widget _buildCleanedView() {
    return Padding(
      key: const ValueKey('cleaned'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.of(context).accent.withAlpha(26), height: 1),
          const SizedBox(height: 24),
          Text(
            _cleanedText!,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: AppColors.of(context).textPrimary.withAlpha(215),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Raw Words View (exactly what user typed, unmodified)
  // ---------------------------------------------------------------------------

  Widget _buildOriginalView() {
    return Padding(
      key: const ValueKey('original'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.of(context).accent.withAlpha(26), height: 1),
          const SizedBox(height: 24),
          Text(
            widget.data.rawText,
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: AppColors.of(context).textPrimary.withAlpha(204),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error State
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _polishError!,
                style: GoogleFonts.manrope(fontSize: 13, color: Colors.orange.shade900, height: 1.4),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _polishText,
              child: Text(
                'Retry',
                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.of(context).accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action Pills — Add photo, Add location
  // ---------------------------------------------------------------------------

  Widget _buildActionPills() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _actionPill(
            icon: Icons.photo_library_outlined,
            label: _attachedPhotoPath != null ? 'Photo added' : 'Add photo',
            isActive: _attachedPhotoPath != null,
            onTap: _pickPhoto,
          ),
          const SizedBox(width: 12),
          _actionPill(
            icon: Icons.camera_alt_outlined,
            label: 'Take photo',
            isActive: false,
            onTap: () async {
              final picked = await _imagePicker.pickImage(
                source: ImageSource.camera,
                maxWidth: 1920,
                imageQuality: 85,
              );
              if (picked != null && mounted) {
                setState(() => _attachedPhotoPath = picked.path);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.of(context).accent.withAlpha(13) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? AppColors.of(context).accent.withAlpha(51) : AppColors.of(context).textMuted.withAlpha(51),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? AppColors.of(context).accent : AppColors.of(context).textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? AppColors.of(context).accent : AppColors.of(context).textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Bar — Save to Book
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              // Edit Memory button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final displayText = _polishedText ?? _cleanedText ?? widget.data.rawText;
                    context.push('/edit-memory', extra: ReviewData(
                      rawText: displayText,
                      isVoice: widget.data.isVoice,
                      audioPath: widget.data.audioPath,
                      attachedPhotoPath: _attachedPhotoPath,
                      mood: widget.data.mood,
                      locationName: _locationName,
                    ));
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.accentFaint,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded, size: 18, color: colors.textPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'Edit Memory',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save Memory button
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: (_isSaving || _isPolishing) ? null : _saveEntry,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: (_isSaving || _isPolishing)
                          ? colors.accent.withAlpha(120)
                          : colors.accent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _isSaving ? 'Saving...' : 'Save Memory',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
