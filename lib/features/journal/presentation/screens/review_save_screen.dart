import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import 'package:deardays/l10n/app_localizations.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';
import 'package:deardays/services/location/location_service.dart';
import 'package:deardays/services/connectivity/connectivity_service.dart';
import 'package:deardays/services/crash_reporting/crash_reporting_service.dart';

/// Data passed between RecordingScreen → ProcessingScreen → ReviewSaveScreen.
class ReviewData {
  final String rawText;
  final String? mood;
  final String? locationName;
  final String? attachedPhotoPath;
  final String? audioPath;
  final bool isVoice;
  final bool polishWithAI;

  /// When true, ProcessingScreen will send audio to OpenAI Whisper for
  /// transcription. Requires explicit user consent — audio leaves the device.
  /// Defaults to false: on-device STT transcript is used instead.
  final bool useWhisper;

  /// Focal alignment set by the user when picking/reframing the photo.
  /// Carried through the pipeline so ReviewSaveScreen can apply it to
  /// the banner image. Defaults to Alignment.center.
  final Alignment focalAlignment;

  // Pre-computed by ProcessingScreen so ReviewSaveScreen loads instantly
  final String? cleanedText;     // light polish: grammar/spelling fixed
  final String? polishedText;    // full AI literary narrative
  final String? generatedTitle;  // AI-extracted title

  /// When reopening an existing draft, pass its ID so the save overwrites
  /// the old entry instead of creating a duplicate.
  final String? existingDraftId;

  const ReviewData({
    required this.rawText,
    this.mood,
    this.locationName,
    this.attachedPhotoPath,
    this.audioPath,
    this.isVoice = false,
    this.polishWithAI = false,
    this.useWhisper = false,
    this.focalAlignment = Alignment.center,
    this.cleanedText,
    this.polishedText,
    this.generatedTitle,
    this.existingDraftId,
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

  // View toggle: 0 = Original, 1 = Polished, 2 = Story
  // Default to 1 so the user immediately sees the grammar/spelling-fixed text.
  // Display logic falls back to Original automatically if cleanedText is null.
  int _viewMode = 1;
  String? _selectedMood;
  bool _showMoodPicker = false;

  // Save state
  bool _isSaving = false;
  final bool _isUploadingPhoto = false;
  String? _attachedPhotoPath;
  String? _locationName;
  String? _saveError;
  final List<String> _tags = [];
  final _locationService = LocationService();
  final _tagController = TextEditingController();
  final _scrollController = ScrollController();

  // Shimmer animation
  late AnimationController _shimmerController;

  // Photo focal-point reframing
  Alignment _focalAlignment = Alignment.center;
  bool _showDragHint = true;

  /// Stable draft ID — reuses existing draft ID if opened from a saved draft,
  /// so leaving overwrites the old entry instead of creating a duplicate.
  late final String _draftId;
  bool _isNavigating = false; // prevents double-tap to PostSaveScreen

  @override
  void initState() {
    super.initState();
    _draftId = widget.data.existingDraftId ?? const Uuid().v4();
    _attachedPhotoPath = widget.data.attachedPhotoPath;
    _locationName = widget.data.locationName;
    _focalAlignment = widget.data.focalAlignment;
    _titleEditController = TextEditingController();
    // Pre-populate mood from the entry data, or fall back to today's saved mood
    _selectedMood = widget.data.mood ?? ref.read(todayMoodProvider);

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
    } else if (widget.data.polishWithAI) {
      _polishText();
    } else {
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
  Future<void> _saveReviewDraftAndPop() async {
    final draft = DraftEntry(
      id: _draftId,
      type: DraftType.review,
      rawText: widget.data.rawText,
      savedAt: DateTime.now(),
      entryDate: DateTime.now(),
      cleanedText: _cleanedText,
      polishedText: _polishedText,
      generatedTitle: _generatedTitle,
      mood: _selectedMood,
      locationName: _locationName,
      attachedPhotoPath: _attachedPhotoPath,
      isVoice: widget.data.isVoice,
    );
    await ref.read(draftSyncServiceProvider).saveDraft(draft);
    ref.invalidate(draftsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _generateTitleOnly() async {
    try {
      // Light polish only — title uses the instant fallback (tap to edit inline)
      final cleaned = await _aiService.lightPolish(widget.data.rawText);
      if (!mounted) return;
      // AppLocalizations.of(context) must be called after the first await so
      // it does not run synchronously inside initState (inheritFrom restriction).
      final l10n = AppLocalizations.of(context);
      final title = _generateFallbackTitle(l10n);
      setState(() {
        _cleanedText = cleaned;
        _generatedTitle = title;
        _titleEditController.text = title;
      });
    } catch (e) {
      debugPrint('[ReviewSave] Title generation failed, using fallback: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final title = _generateFallbackTitle(l10n);
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
      final aiStoryEnabled = ref.read(aiStoryEnabledProvider);

      // Step 1: Light polish — fix grammar/spelling (0% → 40%)
      _animateProgress(0.0, 0.4);
      final cleaned = await _aiService.lightPolish(widget.data.rawText);
      if (!mounted) return;
      // AppLocalizations.of(context) must be called after the first await.
      final l10n = AppLocalizations.of(context);
      setState(() => _cleanedText = cleaned);

      String? body;
      String aiTitle = '';

      if (aiStoryEnabled) {
        // Step 2: Literary polish + title generation in parallel (40% → 100%)
        _animateProgress(0.4, 0.85);
        final results = await Future.wait([
          _aiService.polishNarrative(cleaned, style: 'memoir'),
          _aiService.generateTitle(cleaned).catchError((_) => ''),
        ]);

        if (results.length < 2) throw Exception('Unexpected Future.wait result count: ${results.length}');
        String raw = results[0].trim();
        aiTitle = results[1];

        // Strip any leading markdown header from polished text
        final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.length > 1 && lines.first.startsWith('#')) {
          raw = lines.skip(1).join('\n\n').trim();
        }
        body = raw;
      } else {
        // AI Story disabled — skip narrative generation, use fallback title
        _animateProgress(0.4, 1.0);
      }

      final title = aiTitle.isNotEmpty ? aiTitle : _generateFallbackTitle(l10n);

      if (mounted) {
        _titleEditController.text = title;
        setState(() {
          _generatedTitle = title;
          _polishedText = body; // null when AI Story disabled
          _isPolishing = false;
          _polishProgress = 1.0;
        });
      }
    } catch (e, st) {
      debugPrint('[ReviewSave] AI polish failed: $e');
      // Log to crash reporting
      try {
        CrashReportingService().recordError(e, st, reason: 'ai_polish_failed');
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isPolishing = false;
          _polishError = 'AI polishing failed. You can save your original text.';
          _polishProgress = 0.0;
        });
      }
    }
  }

  void _animateProgress(double from, double to) async {
    if (!mounted) return;
    const steps = 5;
    final increment = (to - from) / steps;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && _isPolishing) {
        setState(() => _polishProgress = from + increment * i);
      }
    }
  }

  String _generateFallbackTitle([AppLocalizations? l10n]) {
    final now = DateTime.now();
    final month = DateFormat('MMM').format(now);
    final timeOfDay = now.hour < 12
        ? (l10n?.morning ?? 'Morning')
        : now.hour < 17
            ? (l10n?.afternoon ?? 'Afternoon')
            : (l10n?.evening ?? 'Evening');
    return '$timeOfDay, $month ${now.day}';
  }

  /// Validates the daily limit then hands off to PostSaveScreen which selects
  /// the chapter and does the actual DB write — keeping the draft alive until
  /// the save succeeds.
  Future<void> _saveEntry() async {
    if (_isNavigating) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    setState(() { _isSaving = true; _saveError = null; });

    try {
      // ── Daily memory limit check ──────────────────────────────────────────
      final db = ref.read(supabaseClientProvider);
      final userId = db.auth.currentUser?.id;
      if (userId != null && ConnectivityService().isOnline) {
        final configRow = await db
            .from('app_config')
            .select('value')
            .eq('key', 'daily_memory_limit')
            .maybeSingle();
        final dailyLimit = int.tryParse(configRow?['value'] as String? ?? '') ?? 10;
        final todayStart = DateTime.now().toUtc().copyWith(
          hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0,
        );
        final todayRows = await db
            .from('journal_entries')
            .select('id')
            .eq('user_id', userId)
            .gte('created_at', todayStart.toIso8601String());
        if ((todayRows as List).length >= dailyLimit) {
          setState(() {
            _isSaving = false;
            _saveError = l10n?.dailyLimitReached ??
                "You've reached today's memory limit. Come back tomorrow!";
          });
          return;
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      if (!mounted) return;
      _isNavigating = true;

      // Draft stays alive — PostSaveScreen deletes it after a successful save.
      context.go('/post-save', extra: PreSaveData(
        rawText: widget.data.rawText,
        cleanedText: _cleanedText,
        polishedText: _polishedText,
        generatedTitle: _generatedTitle,
        mood: _selectedMood,
        locationName: _locationName,
        attachedPhotoPath: _attachedPhotoPath,
        focalAlignment: _focalAlignment,
        isVoice: widget.data.isVoice,
        audioPath: widget.data.audioPath,
        draftId: _draftId,
        tags: List.unmodifiable(_tags),
      ));
    } catch (e, stack) {
      debugPrint('[ReviewSave] _saveEntry error: $e\n$stack');
      _isNavigating = false;
      if (mounted) {
        final msg = e.toString();
        setState(() => _saveError = msg.length > 100 ? '${msg.substring(0, 100)}…' : msg);
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

                  // Tags & location
                  _buildMetadataRow(colors),

                  // AI progress indicator
                  if (_isPolishing) ...[
                    _buildPolishProgress(),
                    const SizedBox(height: 16),
                    _buildShimmerPlaceholders(),
                  ],

                  // Content
                  if (!_isPolishing) ...[
                    if (_polishedText == null && _cleanedText == null && !widget.data.isVoice) ...[
                      const SizedBox(height: 8),
                      _buildAIPolishButton(),
                    ],
                    if (_polishError != null) ...[
                      const SizedBox(height: 8),
                      _buildErrorState(),
                    ],
                    // Voice audio player (always shown for voice entries)
                    if (widget.data.isVoice) ...[
                      const SizedBox(height: 8),
                      _buildAudioCard(colors),
                    ],
                    // View tabs: Original / Polished / Story
                    if (_cleanedText != null || _polishedText != null) ...[
                      const SizedBox(height: 12),
                      _buildViewTabs(colors),
                    ],
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _viewMode == 2 && _polishedText != null
                          ? _buildPolishedView()
                          : _viewMode == 1 && _cleanedText != null
                              ? _buildCleanedView()
                              : _buildOriginalView(),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
                onTap: _saveReviewDraftAndPop,
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
    final hasPhoto = _attachedPhotoPath != null;

    return GestureDetector(
      // Drag to reframe focal point (only when a photo is attached)
      onPanUpdate: hasPhoto
          ? (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final size = box.size;
              final dx = -details.delta.dx / size.width * 2.5;
              final dy = -details.delta.dy / size.height * 2.5;
              setState(() {
                _focalAlignment = Alignment(
                  (_focalAlignment.x + dx).clamp(-1.0, 1.0),
                  (_focalAlignment.y + dy).clamp(-1.0, 1.0),
                );
                _showDragHint = false;
              });
            }
          : null,
      child: ClipRRect(
        child: SizedBox(
          height: 260,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo or fallback gradient
              hasPhoto
                  ? Image.file(
                      File(_attachedPhotoPath!),
                      fit: BoxFit.cover,
                      alignment: _focalAlignment,
                      errorBuilder: (_, __, ___) => _fallbackBannerBg(colors),
                    )
                  : _fallbackBannerBg(colors),

              // Dark gradient scrim (bottom)
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

              // Drag-to-reframe hint (only when photo present and not yet dragged)
              if (hasPhoto && _showDragHint)
                Positioned(
                  bottom: 44,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(110),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_with_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            'Drag to reframe',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
                    child: const Icon(Icons.edit_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),

              // Upload progress overlay
              if (_isUploadingPhoto)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withAlpha(120),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Uploading photo...',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
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
      setState(() {
        _attachedPhotoPath = picked.path;
        _focalAlignment = Alignment.center;
        _showDragHint = true;
      });
      _showPhotoConfirmation(true);
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _takePhoto() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        setState(() {
          _attachedPhotoPath = picked.path;
          _focalAlignment = Alignment.center;
          _showDragHint = true;
        });
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
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not add photo. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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

  static const _moodOptions = [
    (value: 'great', label: 'Great', emoji: '😄', color: AppColors.moodGreat),
    (value: 'good',  label: 'Good',  emoji: '😊', color: AppColors.moodGood),
    (value: 'okay',  label: 'Okay',  emoji: '😐', color: AppColors.moodOkay),
    (value: 'low',   label: 'Low',   emoji: '😔', color: AppColors.moodLow),
    (value: 'tough', label: 'Tough', emoji: '😢', color: AppColors.moodTough),
  ];

  String _moodEmoji(String? mood) {
    return _moodOptions
        .where((m) => m.value == mood)
        .map((m) => m.emoji)
        .firstOrNull ?? '😊';
  }

  Widget _buildMetadataRow(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionPill(
                icon: Icons.sell_outlined,
                label: _tags.isNotEmpty ? '${_tags.length} tag${_tags.length == 1 ? '' : 's'}' : 'Add tags',
                isActive: _tags.isNotEmpty,
                onTap: _showTagsSheet,
              ),
              _actionPill(
                icon: Icons.location_on_outlined,
                label: _locationName ?? 'Add location',
                isActive: _locationName != null,
                onTap: _addLocation,
                maxLabelWidth: 160,
              ),
              _actionPill(
                icon: Icons.mood_rounded,
                label: _selectedMood != null
                    ? '${_moodEmoji(_selectedMood)} ${_selectedMood![0].toUpperCase()}${_selectedMood!.substring(1)}'
                    : 'Add mood',
                isActive: _selectedMood != null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showMoodPicker = !_showMoodPicker);
                },
              ),
            ],
          ),
          // Inline mood picker — expands when pill is tapped
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showMoodPicker
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _moodOptions.map((mood) {
                        final isSelected = _selectedMood == mood.value;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedMood = mood.value;
                              _showMoodPicker = false;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? mood.color.withAlpha(40)
                                      : colors.highlightFaint,
                                  border: Border.all(
                                    color: isSelected
                                        ? mood.color.withAlpha(150)
                                        : colors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(mood.emoji,
                                      style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mood.label,
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? mood.color
                                      : colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
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

  // ---------------------------------------------------------------------------
  // Mood Selector
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // View Tabs: Original | Polished | Story
  // ---------------------------------------------------------------------------

  Widget _buildViewTabs(AppPalette colors) {
    final tabs = <({int index, String label, IconData icon})>[
      (index: 0, label: 'ORIGINAL', icon: Icons.mic_rounded),
      if (_cleanedText != null) (index: 1, label: 'POLISHED', icon: Icons.auto_fix_high_rounded),
      if (_polishedText != null) (index: 2, label: 'STORY', icon: Icons.menu_book_rounded),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: tabs.map((tab) {
            final isActive = _viewMode == tab.index;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _viewMode = tab.index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        tab.icon,
                        key: ValueKey('${tab.index}_$isActive'),
                        size: 20,
                        color: isActive ? colors.accent : colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tab.label,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? colors.accent : colors.textMuted,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Sliding underline indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      height: 2,
                      decoration: BoxDecoration(
                        color: isActive ? colors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        Divider(height: 1, thickness: 1, color: colors.border),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Audio Card (inline, for voice entries)
  // ---------------------------------------------------------------------------

  Widget _buildAudioCard(AppPalette colors) {
    final hasAudio = widget.data.audioPath != null && widget.data.audioPath!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withAlpha(60),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Recording',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(20, (i) {
                    final h = 4.0 + (i % 5) * 3.0 + (i % 3) * 2.0;
                    return Expanded(
                      child: Container(
                        height: h.clamp(4.0, 18.0),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: colors.accent.withAlpha(120),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          if (!hasAudio) ...[
            const SizedBox(width: 8),
            Icon(Icons.info_outline, size: 16, color: colors.textMuted),
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
    } catch (e) {
      debugPrint('[ReviewSave] Location fetch failed: $e');
    }
  }

  Future<void> _addLocation() async {
    if (_locationName != null) {
      setState(() => _locationName = null);
      return;
    }

    // Show friendly pre-prompt before system dialog
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location access needed'),
          content: const Text(
            'DearDays uses your location to tag where memories happen. '
            'Enable location in Settings to use this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }

    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not get location. Try again.'),
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
    double? maxLabelWidth,
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
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth ?? double.infinity),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? AppColors.of(context).accent : AppColors.of(context).textSecondary,
                ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: GoogleFonts.manrope(fontSize: 12, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  // Edit Story button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.pop(),
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
                              'Edit',
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
                  // Save Memory button — direct save, no confirmation sheet
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
            ],
          ),
        ),
      ),
    );
  }
}
