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

  // Title editing
  late final TextEditingController _titleEditController;
  bool _isEditingTitle = false;

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
    _titleEditController = TextEditingController();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    if (widget.data.polishWithAI) {
      _polishText();
    } else {
      _activeTab = 2; // Show original/raw text by default
      _generateTitleOnly(); // Still auto-generate title from content
    }
  }

  @override
  void dispose() {
    _titleEditController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  /// Lightweight title generation used when full AI polish is not requested.
  Future<void> _generateTitleOnly() async {
    try {
      final cleaned = await _aiService.lightPolish(widget.data.rawText);
      if (!mounted) return;
      final title = _extractTitle(cleaned ?? widget.data.rawText);
      setState(() {
        _cleanedText = cleaned;
        _generatedTitle = title;
        _titleEditController.text = title;
      });
    } catch (_) {
      final title = _generateFallbackTitle();
      if (mounted) {
        setState(() {
          _generatedTitle = title;
          _titleEditController.text = title;
        });
      }
    }
  }

  String _extractTitle(String text) {
    final trimmed = text.trim();
    // First sentence up to 60 chars
    final match = RegExp(r'^(.{10,60}[.!?])').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.replaceAll(RegExp(r'[.!?]$'), '').trim();
    }
    // Fallback: first 7 words
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length <= 7) return words.join(' ');
    return '${words.take(7).join(' ')}...';
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
        _titleEditController.text = title;
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
            backgroundColor: AppColors.error,
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

                  // Title + date section
                  _buildTitleSection(colors),

                  // Tab bar: Audio | Transcript | Story
                  _buildTabBar(colors),

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_rounded, size: 22, color: colors.textPrimary),
                ),
              ),
              Expanded(
                child: Text(
                  'Memory Preview',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share coming soon')),
                  );
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.ios_share_rounded, size: 22, color: colors.textPrimary),
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
    final title = _isEditingTitle ? _titleEditController.text.trim() : _generatedTitle;

    Widget imageChild;
    if (_attachedPhotoPath != null) {
      imageChild = Image.asset(
        _attachedPhotoPath!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 300,
        errorBuilder: (_, __, ___) => _fallbackBannerBg(colors),
      );
    } else {
      imageChild = _fallbackBannerBg(colors);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(0),
        bottomRight: Radius.circular(0),
      ),
      child: Stack(
        children: [
          SizedBox(height: 300, width: double.infinity, child: imageChild),
          // Dark gradient overlay (bottom → transparent)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(180),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Italic serif title overlaid at bottom-left
          if (title != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 60,
              child: Text(
                title,
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  height: 1.3,
                  shadows: [
                    Shadow(color: Colors.black.withAlpha(8), blurRadius: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallbackBannerBg(AppPalette colors) {
    return Container(
      height: 300,
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
            child: Icon(Icons.menu_book_rounded, size: 160, color: colors.textSecondary.withAlpha(15)),
          ),
          Center(
            child: Icon(Icons.auto_stories_rounded, size: 56, color: colors.textSecondary),
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
    final colors = AppColors.of(context);
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
            colors.border,
            colors.card,
            colors.border,
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
    final tabs = [
      (icon: Icons.graphic_eq_rounded, label: 'AUDIO', index: 2),
      (icon: Icons.description_rounded, label: 'TRANSCRIPT', index: 1),
      (icon: Icons.auto_stories_rounded, label: 'STORY', index: 0),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isActive = _activeTab == tab.index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = tab.index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? colors.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 22,
                      color: isActive ? colors.accent : colors.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? colors.accent : colors.textMuted,
                        letterSpacing: 0.8,
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

  // Keep legacy method for any callers
  Widget _buildViewToggle() => _buildTabBar(AppColors.of(context));

  // ---------------------------------------------------------------------------
  // Title + Date Section
  // ---------------------------------------------------------------------------

  Widget _buildTitleSection(AppPalette colors) {
    final now = DateTime.now();
    final months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final dateStr =
        '${months[now.month - 1].toUpperCase()} ${now.day}, ${now.year} • ${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        children: [
          if (_isEditingTitle)
            TextField(
              controller: _titleEditController,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: colors.accent,
              style: GoogleFonts.newsreader(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.25,
              ),
              decoration: InputDecoration(
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.accent, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                isDense: true,
              ),
              onSubmitted: (v) {
                setState(() {
                  if (v.trim().isNotEmpty) _generatedTitle = v.trim();
                  _isEditingTitle = false;
                });
              },
              onTapOutside: (_) {
                setState(() {
                  final v = _titleEditController.text.trim();
                  if (v.isNotEmpty) _generatedTitle = v;
                  _isEditingTitle = false;
                });
              },
            )
          else
            GestureDetector(
              onTap: _isPolishing
                  ? null
                  : () {
                      _titleEditController.text = _generatedTitle ?? '';
                      setState(() => _isEditingTitle = true);
                    },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _generatedTitle ?? (_isPolishing ? 'Writing your story...' : 'Your Memory'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (!_isPolishing) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.edit_rounded, size: 16, color: colors.textMuted),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            dateStr,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Polished Story View
  // ---------------------------------------------------------------------------

  Widget _buildPolishedView() {
    final colors = AppColors.of(context);
    final paragraphs = _polishedText!
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return _buildContentCard(
      key: const ValueKey('polished'),
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            p,
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              color: colors.textPrimary,
              height: 1.75,
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cleaned Original View (grammar/spelling fixed, user's voice preserved)
  // ---------------------------------------------------------------------------

  Widget _buildCleanedView() {
    final colors = AppColors.of(context);
    final paragraphs = _cleanedText!
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return _buildContentCard(
      key: const ValueKey('cleaned'),
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            p,
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              color: colors.textPrimary,
              height: 1.75,
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Raw Words View (exactly what user typed, unmodified)
  // ---------------------------------------------------------------------------

  Widget _buildOriginalView() {
    final colors = AppColors.of(context);
    final paragraphs = widget.data.rawText
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return _buildContentCard(
      key: const ValueKey('original'),
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            p,
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              color: colors.textPrimary.withAlpha(210),
              height: 1.75,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildContentCard({required AppPalette colors, required Widget child, Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Error State
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.moodOkay.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.moodOkay.withAlpha(80)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.moodOkay),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _polishError!,
                style: GoogleFonts.manrope(fontSize: 13, color: colors.textPrimary, height: 1.4),
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
        color: colors.bg.withAlpha(230),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              // Edit Story button
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
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 20, color: colors.textPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'Edit Story',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save to Vault button
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: (_isSaving || _isPolishing) ? null : _saveEntry,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: (_isSaving || _isPolishing)
                          ? colors.accent.withAlpha(120)
                          : colors.accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (_isSaving || _isPolishing)
                          ? []
                          : [
                              BoxShadow(
                                color: colors.accent.withAlpha(70),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
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
                            : const Icon(Icons.bookmark_added_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _isSaving ? 'Saving...' : 'Save to Vault',
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
