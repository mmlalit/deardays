import 'dart:io';
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
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/media/media_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/sync/sync_queue.dart';
import 'package:deardays/services/sync/sync_operation.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';
import 'package:deardays/services/location/location_service.dart';

/// Data passed between RecordingScreen → ProcessingScreen → ReviewSaveScreen.
class ReviewData {
  final String rawText;
  final String? mood;
  final String? locationName;
  final String? attachedPhotoPath;
  final String? audioPath;
  final bool isVoice;
  final bool polishWithAI;

  // Pre-computed by ProcessingScreen so ReviewSaveScreen loads instantly
  final String? cleanedText;     // light polish: grammar/spelling fixed
  final String? polishedText;    // full AI literary narrative
  final String? generatedTitle;  // AI-extracted title

  const ReviewData({
    required this.rawText,
    this.mood,
    this.locationName,
    this.attachedPhotoPath,
    this.audioPath,
    this.isVoice = false,
    this.polishWithAI = false,
    this.cleanedText,
    this.polishedText,
    this.generatedTitle,
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
  final List<String> _tags = [];
  final _locationService = LocationService();
  final _tagController = TextEditingController();
  final _scrollController = ScrollController();

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

    // Auto-fetch GPS location if not already set
    if (_locationName == null) {
      _autoFetchLocation();
    }

    // Use pre-computed results from ProcessingScreen if available
    if (widget.data.cleanedText != null || widget.data.polishedText != null) {
      _cleanedText = widget.data.cleanedText;
      _polishedText = widget.data.polishedText;
      _generatedTitle = widget.data.generatedTitle ?? _generateFallbackTitle();
      _titleEditController.text = _generatedTitle!;
      _activeTab = 0; // Show story tab by default
    } else if (widget.data.polishWithAI) {
      _polishText();
    } else {
      _activeTab = 2; // Show original/raw text by default
      _generateTitleOnly();
    }
  }

  @override
  void dispose() {
    _titleEditController.dispose();
    _tagController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Lightweight title generation used when full AI polish is not requested.
  Future<void> _generateTitleOnly() async {
    try {
      // Run light polish and AI title generation in parallel
      final results = await Future.wait([
        _aiService.lightPolish(widget.data.rawText),
        _aiService.generateTitle(widget.data.rawText).catchError((_) => ''),
      ]);
      if (!mounted) return;
      final cleaned = results[0];
      final aiTitle = results[1];
      final title = aiTitle.isNotEmpty ? aiTitle : _generateFallbackTitle();
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

      // Step 2: Literary polish + title generation in parallel (40% → 100%)
      _animateProgress(0.4, 0.85);
      final results = await Future.wait([
        _aiService.polishNarrative(cleaned, style: 'memoir'),
        _aiService.generateTitle(cleaned).catchError((_) => ''),
      ]);

      final result = results[0];
      final aiTitle = results[1];

      // Strip any leading markdown header from polished text
      String body = result.trim();
      final lines = body.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length > 1 && lines.first.startsWith('#')) {
        body = lines.skip(1).join('\n\n').trim();
      }

      final title = aiTitle.isNotEmpty ? aiTitle : _generateFallbackTitle();

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
    const steps = 5;
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final timeOfDay = now.hour < 12 ? 'Morning' : now.hour < 17 ? 'Afternoon' : 'Evening';
    return '$timeOfDay, ${months[now.month - 1]} ${now.day}';
  }

  Future<void> _pickPhoto() async {
    await _pickPhotoFromGallery();
  }

  void _showSaveConfirmation() {
    HapticFeedback.lightImpact();
    final colors = AppColors.of(context);
    final title = _generatedTitle ?? _generateFallbackTitle();
    final content = _cleanedText ?? widget.data.rawText;
    final preview = content.length > 120 ? '${content.substring(0, 120)}...' : content;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(25),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Text(
              'Save this memory?',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // Memory card preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo + title row
                  Row(
                    children: [
                      if (_attachedPhotoPath != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_attachedPhotoPath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Content preview
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  // Tags
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$tag',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Center(
                        child: Text(
                          'Go back',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _saveEntry();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withAlpha(60),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Looks good, save!',
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
          ],
        ),
      ),
    );
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

      JournalEntry saved;
      bool savedOffline = false;

      try {
        debugPrint('[SAVE] Attempting online save...');
        saved = await _repository.createEntry(entry);
        debugPrint('[SAVE] Online save SUCCESS');
      } catch (networkError) {
        debugPrint('[SAVE] Online save FAILED: $networkError — saving offline');
        // Network failed — save locally and queue for sync
        await LocalStorageService().cacheEntry(entry);
        await SyncQueue().enqueue(SyncOperation(
          id: entry.id,
          type: SyncOperationType.create,
          tableName: 'journal_entries',
          payload: entry.toSupabaseMap(),
          createdAt: now,
        ));
        saved = entry;
        savedOffline = true;
      }

      // Auto-create book if none exists (skip when offline)
      if (!savedOffline) {
        try {
          final profile = await ref.read(profileProvider.future);
          final organization = profile?.bookOrganization ?? 'yearly';
          final bookRepo = ref.read(bookRepositoryProvider);
          await bookRepo.ensureDefaultBook(organization);
        } catch (_) {}
      }

      // Upload photo if attached (skip when offline — photo syncs on reconnect)
      if (_attachedPhotoPath != null && !savedOffline) {
        try {
          await _mediaService.uploadPhoto(
            entryId: saved.id,
            filePath: _attachedPhotoPath!,
          );
        } catch (e) {
          debugPrint('[ReviewSaveScreen] Photo upload failed: $e');
        }
      }

      // Check streak: show milestone notification + update daily reminder
      if (!savedOffline) {
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
      }

      // Clean up temporary audio recording file after successful save.
      if (widget.data.audioPath != null) {
        try {
          final audioFile = File(widget.data.audioPath!);
          if (await audioFile.exists()) await audioFile.delete();
        } catch (_) {}
      }

      debugPrint('[SAVE] Post-save: mounted=$mounted, savedOffline=$savedOffline');
      if (mounted) {
        if (savedOffline) {
          debugPrint('[SAVE] Taking OFFLINE path → /home');
          // Invalidate providers so home screen refreshes
          ref.invalidate(todayEntryProvider);
          ref.invalidate(timelineEntriesProvider);
          ref.invalidate(booksProvider);

          // Show offline-save confirmation instead of full success overlay
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Saved offline. Will sync when you reconnect.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.of(context).accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          // Navigate back to home
          if (mounted) context.go('/home');
        } else {
          // Navigate to post-save confirmation screen.
          // Store data in provider so it survives go_router refreshes
          // (Supabase DB writes trigger onAuthStateChange which causes
          // go_router to rebuild and lose route `extra` data).
          if (mounted) {
            final title = _generatedTitle ?? _generateFallbackTitle();
            final entryContent = _cleanedText ?? widget.data.rawText;
            final entryId = saved.id;

            final postSaveData = PostSaveData(
              entryId: entryId,
              title: title,
              content: entryContent,
            );

            // Store in provider (survives router refresh)
            ref.read(postSaveDataProvider.notifier).state = postSaveData;

            // Invalidate data providers so home/timeline refresh later
            ref.invalidate(todayEntryProvider);
            ref.invalidate(timelineEntriesProvider);
            ref.invalidate(booksProvider);

            // Navigate to post-save
            debugPrint('[SAVE] Taking ONLINE path → navigating to /post-save');
            if (mounted) context.go('/post-save');
            debugPrint('[SAVE] context.go(/post-save) called');
          }
        }
      }
    } catch (e, stack) {
      debugPrint('[SAVE] OUTER CATCH: $e');
      debugPrint('[SAVE] Stack: $stack');
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
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo or gradient banner
                  _buildPhotoOrGradientBanner(),

                  // Title + date section
                  _buildTitleSection(colors),

                  // Tags & location (top for visibility)
                  _buildMetadataRow(colors),

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
                      child: _activeTab == 2 && widget.data.isVoice
                          ? _buildAudioView()
                          : _activeTab == 0 && _polishedText != null
                              ? _buildPolishedView()
                              : _activeTab == 1 && _cleanedText != null
                                  ? _buildCleanedView()
                                  : _buildOriginalView(),
                    ),
                  ],
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

    Widget imageChild;
    if (_attachedPhotoPath != null) {
      imageChild = Image.file(
        File(_attachedPhotoPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 300,
        errorBuilder: (_, __, ___) => _fallbackBannerBg(colors),
      );
    } else {
      imageChild = _fallbackBannerBg(colors);
    }

    return ClipRRect(
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
          // Edit photo button (top-right)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withAlpha(100),
                ),
                child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: colors.textMuted.withAlpha(60), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Add Photo', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 16),
            _photoOptionTile(ctx, Icons.photo_library_outlined, 'Choose from gallery', () async {
              Navigator.of(ctx).pop();
              await _pickPhotoFromGallery();
            }),
            const SizedBox(height: 8),
            _photoOptionTile(ctx, Icons.camera_alt_outlined, 'Take a photo', () async {
              Navigator.of(ctx).pop();
              await _takePhoto();
            }),
            if (_attachedPhotoPath != null) ...[
              const SizedBox(height: 8),
              _photoOptionTile(ctx, Icons.delete_outline_rounded, 'Remove photo', () {
                Navigator.of(ctx).pop();
                setState(() => _attachedPhotoPath = null);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photoOptionTile(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textPrimary),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotoFromGallery() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 75,
    );
    if (picked != null && mounted) {
      setState(() => _attachedPhotoPath = picked.path);
      _showPhotoConfirmation(true);
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        setState(() => _attachedPhotoPath = picked.path);
        _showPhotoConfirmation(true);
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        _showPhotoConfirmation(false);
      }
    }
  }

  void _showPhotoConfirmation(bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Photo added successfully!' : 'Could not add photo. Please try again.'),
        backgroundColor: success ? AppColors.of(context).accent : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
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
  // ---------------------------------------------------------------------------
  // Tab Bar — Story | Transcript | Audio
  // ---------------------------------------------------------------------------

  Widget _buildTabBar(AppPalette colors) {
    final tabs = widget.data.isVoice
        ? [
            (icon: Icons.graphic_eq_rounded, label: 'AUDIO', index: 2),
            (icon: Icons.description_rounded, label: 'TRANSCRIPT', index: 1),
            (icon: Icons.auto_stories_rounded, label: 'STORY', index: 0),
          ]
        : [
            (icon: Icons.article_rounded, label: 'ORIGINAL', index: 2),
            (icon: Icons.auto_fix_high_rounded, label: 'POLISHED', index: 1),
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
    final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                        fontSize: 26,
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
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
              letterSpacing: 0.5,
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

  // ---------------------------------------------------------------------------
  // Audio Player View (shown on AUDIO tab when voice entry)
  // ---------------------------------------------------------------------------

  Widget _buildAudioView() {
    final colors = AppColors.of(context);
    final hasAudio = widget.data.audioPath != null && widget.data.audioPath!.isNotEmpty;
    final transcript = widget.data.rawText.trim();

    return _buildContentCard(
      key: const ValueKey('audio'),
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio player section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.accent.withAlpha(30)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Play button (visual — audio playback is platform-dependent)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withAlpha(60),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Recording',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Waveform placeholder bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 24,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: List.generate(20, (i) {
                                  final h = 6.0 + (i % 5) * 3.0 + (i % 3) * 2.0;
                                  return Expanded(
                                    child: Container(
                                      height: h.clamp(6.0, 20.0),
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: colors.accent.withAlpha(80),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!hasAudio) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Audio playback not available',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Raw transcript section
          if (transcript.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.description_rounded, size: 16, color: colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'RAW TRANSCRIPT',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...transcript
                .split('\n')
                .where((p) => p.trim().isNotEmpty)
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        p,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: colors.textPrimary.withAlpha(200),
                          height: 1.7,
                        ),
                      ),
                    )),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'No transcript available for this recording.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
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
            const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.moodOkay),
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
  // Metadata Row — Tags & Location (shown at top for visibility)
  // ---------------------------------------------------------------------------

  Widget _buildMetadataRow(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _actionPill(
                icon: Icons.sell_outlined,
                label: _tags.isNotEmpty ? '${_tags.length} tag${_tags.length == 1 ? '' : 's'}' : 'Add tags',
                isActive: _tags.isNotEmpty,
                onTap: _showTagsSheet,
              ),
              const SizedBox(width: 12),
              _actionPill(
                icon: Icons.location_on_outlined,
                label: _locationName ?? 'Add location',
                isActive: _locationName != null,
                onTap: _addLocation,
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) => GestureDetector(
                onTap: () => setState(() => _tags.remove(tag)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.accent.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tag, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: colors.accent)),
                      const SizedBox(width: 4),
                      Icon(Icons.close_rounded, size: 12, color: colors.accent.withAlpha(150)),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  static const _suggestedTags = [
    'Family', 'Travel', 'Work', 'Friends', 'Nature',
    'Food', 'Health', 'Gratitude', 'Achievement', 'Funny',
  ];

  void _showTagsSheet() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Tags', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 12),
              TextField(
                controller: _tagController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Type a tag...',
                  hintStyle: GoogleFonts.manrope(color: colors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.check_rounded, color: colors.accent),
                    onPressed: () {
                      final tag = _tagController.text.trim();
                      if (tag.isNotEmpty && !_tags.contains(tag)) {
                        setState(() => _tags.add(tag));
                        setSheet(() {});
                      }
                      _tagController.clear();
                    },
                  ),
                ),
                onSubmitted: (v) {
                  final tag = v.trim();
                  if (tag.isNotEmpty && !_tags.contains(tag)) {
                    setState(() => _tags.add(tag));
                    setSheet(() {});
                  }
                  _tagController.clear();
                },
              ),
              const SizedBox(height: 16),
              if (_tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) => GestureDetector(
                    onTap: () {
                      setState(() => _tags.remove(tag));
                      setSheet(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tag, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(width: 4),
                          Icon(Icons.close_rounded, size: 14, color: Colors.white.withAlpha(200)),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Text('Suggestions', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedTags.where((t) => !_tags.contains(t)).map((t) => GestureDetector(
                  onTap: () {
                    setState(() => _tags.add(t));
                    setSheet(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: colors.accentFaint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(t, style: GoogleFonts.manrope(fontSize: 13, color: colors.textPrimary)),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _autoFetchLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location?.locationName != null && mounted) {
        setState(() => _locationName = location!.locationName);
      }
    } catch (_) {}
  }

  Future<void> _addLocation() async {
    if (_locationName != null) {
      setState(() => _locationName = null);
      return;
    }
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not get location. Check permissions.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    final name = await _locationService.getLocationName(
      position.latitude,
      position.longitude,
    );
    if (mounted) {
      setState(() => _locationName = name ?? 'My Location');
    }
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
                  onTap: (_isSaving || _isPolishing) ? null : _showSaveConfirmation,
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
