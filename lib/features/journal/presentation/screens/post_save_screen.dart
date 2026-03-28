import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/onboarding/sample_memory.dart';
import 'package:deardays/core/providers/onboarding_provider.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';
import 'package:deardays/services/connectivity/connectivity_service.dart';
import 'package:deardays/services/media/media_service.dart';
import 'package:deardays/services/memory_tagging/memory_tagging_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/media/pending_photo_uploads.dart';
import 'package:deardays/services/sync/sync_queue.dart';
import 'package:deardays/services/sync/sync_operation.dart';

/// All data needed to create the journal entry.
/// Passed from ReviewSaveScreen so the chapter can be selected BEFORE
/// the entry is written to the database.
class PreSaveData {
  final String rawText;
  final String? cleanedText;
  final String? polishedText;
  final String? generatedTitle;
  final String? mood;
  final String? locationName;
  final String? attachedPhotoPath;
  final Alignment focalAlignment;
  final bool isVoice;
  final String? audioPath;
  final String draftId;
  final List<String> tags;

  const PreSaveData({
    required this.rawText,
    this.cleanedText,
    this.polishedText,
    this.generatedTitle,
    this.mood,
    this.locationName,
    this.attachedPhotoPath,
    this.focalAlignment = Alignment.center,
    this.isVoice = false,
    this.audioPath,
    required this.draftId,
    this.tags = const [],
  });
}

/// Lightweight data object used after a successful save (confirmation screen).
class PostSaveData {
  final String entryId;
  final String title;
  final String content;
  final String? attachedPhotoPath;
  final bool savedOffline;

  const PostSaveData({
    required this.entryId,
    required this.title,
    required this.content,
    this.attachedPhotoPath,
    this.savedOffline = false,
  });
}

class PostSaveScreen extends ConsumerStatefulWidget {
  /// Pre-save payload: chapter is selected here, then the entry is saved.
  final PreSaveData? preSaveData;

  /// Legacy post-save payload: entry already saved, screen shows confirmation.
  final PostSaveData? data;

  const PostSaveScreen({super.key, this.preSaveData, this.data});

  @override
  ConsumerState<PostSaveScreen> createState() => _PostSaveScreenState();
}

class _PostSaveScreenState extends ConsumerState<PostSaveScreen> {
  int _currentStep = 0; // 0 = chapter, 1 = confirmation
  String? _selectedChapterId;
  bool _isSaving = false;
  String? _saveError;

  // Filled after a successful save so the confirmation screen can display it.
  PostSaveData? _confirmedData;

  late final JournalRepository _repository = JournalRepository(
    client: Supabase.instance.client,
  );
  late final MediaService _mediaService = MediaService(
    client: Supabase.instance.client,
  );

  @override
  void initState() {
    super.initState();
    // Force fresh chapter data every time this screen opens so the list is
    // never stale (e.g. after a new user's default chapters were just seeded).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(chaptersProvider);
    });
  }

  /// Called when the user taps Continue after selecting a chapter.
  /// If [PreSaveData] was supplied, this is where the DB write happens.
  Future<void> _next() async {
    if (_selectedChapterId == null || _isSaving) return;
    setState(() { _isSaving = true; _saveError = null; });

    try {
      if (widget.preSaveData != null) {
        // ── New flow: save entry WITH chapterId already set ──────────────────
        await _saveNewEntry(widget.preSaveData!, _selectedChapterId!);
      } else {
        // ── Legacy flow: entry already saved, just update chapter ────────────
        final resolvedData = widget.data ?? ref.read(postSaveDataProvider);
        final entryId = resolvedData?.entryId;
        if (entryId != null) {
          if (ConnectivityService().isOnline) {
            await _repository.updateEntryChapter(entryId, _selectedChapterId!);
            ref.invalidate(chaptersProvider);
            ref.invalidate(chapterEntriesProvider(_selectedChapterId!));
          } else {
            final userId = ref.read(supabaseClientProvider).auth.currentUser?.id ?? '';
            await SyncQueue().enqueue(SyncOperation.create(
              id: entryId,
              type: SyncOperationType.update,
              tableName: 'journal_entries',
              payload: {'chapter_id': _selectedChapterId!, 'user_id': userId},
            ));
          }
        }
        if (mounted) setState(() => _currentStep = 1);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        setState(() => _saveError = msg.length > 120 ? '${msg.substring(0, 120)}…' : msg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveNewEntry(PreSaveData pre, String chapterId) async {
    final now     = DateTime.now().toUtc();
    final content = pre.cleanedText ?? pre.rawText;
    final polishedContent = pre.polishedText != null
        ? '${pre.generatedTitle ?? ''}\n\n${pre.polishedText}'
        : null;
    final isOnline = ConnectivityService().isOnline;

    final entry = JournalEntry(
      id: const Uuid().v4(),
      userId: ref.read(supabaseClientProvider).auth.currentUser!.id,
      content: content,
      rawContent: pre.rawText,
      polishedContent: polishedContent,
      mood: pre.mood,
      entryDate: now,
      entryTime: TimeOfDay.fromDateTime(now),
      isAiPolished: pre.polishedText != null,
      locationName: pre.locationName,
      hasPhoto: false,
      hasVoice: pre.isVoice,
      wordCount: content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      chapterId: chapterId,
      tags: pre.tags,
      createdAt: now,
      updatedAt: now,
    );

    bool savedOffline = false;
    JournalEntry saved;

    if (!isOnline) {
      await LocalStorageService().cacheEntry(entry);
      if (!mounted) return;
      try {
        await SyncQueue().enqueue(SyncOperation.create(
          id: entry.id,
          type: SyncOperationType.create,
          tableName: 'journal_entries',
          payload: entry.toSupabaseMap(),
        ));
      } catch (e) {
        debugPrint('[PostSave] Queue failed: $e');
      }
      saved = entry;
      savedOffline = true;
    } else {
      saved = await _repository.createEntry(entry);

      // Fire-and-forget tagging
      if (!saved.tagsGenerated) {
        unawaited(MemoryTaggingService().tagEntry(
          entryId: saved.id,
          content: content,
        ));
      }

      // Ensure default book exists
      try {
        final profile = await ref.read(profileProvider.future);
        final organization = profile?.bookOrganization ?? 'yearly';
        await ref.read(bookRepositoryProvider).ensureDefaultBook(organization);
      } catch (e) {
        debugPrint('[PostSave] ensureDefaultBook error: $e');
      }

      // Photo upload
      if (pre.attachedPhotoPath != null) {
        try {
          await _mediaService.uploadPhoto(
            entryId: saved.id,
            filePath: pre.attachedPhotoPath!,
            focalAlignment: pre.focalAlignment,
          );
          saved = saved.copyWith(hasPhoto: true);
        } catch (e) {
          debugPrint('[PostSave] Photo upload failed: $e');
          // Queue for automatic retry when connectivity is restored.
          await PendingPhotoUploads().add(
            entryId: saved.id,
            filePath: pre.attachedPhotoPath!,
            focalAlignment: pre.focalAlignment,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Photo will upload automatically when you\u2019re back online.'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      }

      // Streak notification
      try {
        final profileRepo = ProfileRepository(client: Supabase.instance.client);
        final streak = await profileRepo.getStreak();
        if (streak != null) {
          if (NotificationService.isStreakMilestone(streak.currentStreak)) {
            final box = await Hive.openBox('settings');
            final milestonesEnabled = box.get('streak_milestones_enabled') as bool? ?? true;
            if (milestonesEnabled) {
              await NotificationService().showStreakNotification(streak.currentStreak);
            }
          }
          NotificationService().cancelStreakReminder().catchError((e) {
            debugPrint('[PostSave] Cancel streak reminder failed: $e');
          });
          final profile = await profileRepo.getProfile();
          if (profile?.reminderTime != null) {
            final parts = profile!.reminderTime!.split(':');
            if (parts.length >= 2) {
              await NotificationService().scheduleDailyReminder(
                TimeOfDay(
                  hour: int.tryParse(parts[0]) ?? 9,
                  minute: int.tryParse(parts[1]) ?? 0,
                ),
                streak: streak.currentStreak,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[PostSave] Streak/notification error: $e');
      }
    }

    // Audio file cleanup
    if (pre.audioPath != null) {
      try {
        final audioFile = File(pre.audioPath!);
        if (await audioFile.exists()) await audioFile.delete();
      } catch (e) {
        debugPrint('[PostSave] Audio cleanup failed: $e');
      }
    }

    // Auto-delete sample memory on first real save
    try {
      final entries = await ref.read(timelineEntriesProvider.future);
      final realEntries = entries.where((e) => !isSampleEntry(e)).toList();
      if (realEntries.isEmpty) {
        final sampleExists = entries.any((e) => isSampleEntry(e));
        if (sampleExists) {
          await ref.read(journalRepositoryProvider).deleteEntry('sample-onboarding-001');
          ref.read(onboardingProvider.notifier).markSampleMemorySeeded();
        }
      }
    } catch (e) {
      debugPrint('[PostSave] Sample cleanup failed: $e');
    }

    if (!mounted) return;

    // Delete the draft now that the entry is fully saved
    try {
      await LocalStorageService.instance.deleteDraft(pre.draftId);
      ref.invalidate(draftsProvider);
    } catch (e) {
      debugPrint('[PostSave] Draft deletion failed: $e');
    }

    ref.invalidate(todayEntryProvider);
    ref.invalidate(timelineEntriesProvider);
    ref.invalidate(booksProvider);
    ref.invalidate(chaptersProvider);
    ref.invalidate(chapterEntriesProvider(chapterId));

    _confirmedData = PostSaveData(
      entryId: saved.id,
      title: pre.generatedTitle ?? saved.content.split('\n').first,
      content: content,
      attachedPhotoPath: pre.attachedPhotoPath,
      savedOffline: savedOffline,
    );

    if (mounted) setState(() => _currentStep = 1);
  }

  void _finish() {
    HapticFeedback.lightImpact();
    ref.read(postSaveDataProvider.notifier).state = null;
    ref.invalidate(timelineEntriesProvider);
    ref.invalidate(todayEntryProvider);
    context.go('/home');
  }

  Future<void> _showCreateChapterDialog() async {
    final controller = TextEditingController();
    final colors = AppColors.of(context);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'New Chapter',
          style: GoogleFonts.newsreader(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.manrope(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Chapter name',
            hintStyle: GoogleFonts.manrope(color: colors.textMuted),
            filled: true,
            fillColor: colors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.manrope(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: Text('Create', style: GoogleFonts.manrope(color: colors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final newChapter = await ref
            .read(profileRepositoryProvider)
            .createChapter(result);
        ref.invalidate(chaptersProvider);
        if (mounted) {
          setState(() => _selectedChapterId = newChapter.id);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create chapter. Try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _currentStep == 0
            ? _buildChapterScreen(colors)
            : _buildConfirmationScreen(colors),
      ),
    );
  }

  Widget _buildSaveError(AppPalette colors) {
    if (_saveError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Add to Chapter
  // ---------------------------------------------------------------------------

  Widget _buildChapterScreen(AppPalette colors) {
    final chaptersAsync = ref.watch(chaptersProvider);

    return Column(
      key: const ValueKey('chapter'),
      children: [
        // Header
        Container(
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
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (Navigator.of(context).canPop()) {
                        context.pop();
                      } else {
                        _finish();
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent.withAlpha(15),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(Icons.arrow_back_rounded, size: 20, color: colors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Add to Chapter',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ),

        // Chapter list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which chapter does this memory belong to?',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),

                const SizedBox(height: 20),

                chaptersAsync.when(
                  skipLoadingOnRefresh: true,
                  skipError: true,
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      'Could not load chapters.',
                      style: GoogleFonts.manrope(color: colors.textMuted),
                    ),
                  ),
                  data: (chapters) => Column(
                    children: chapters
                        .map((c) => _buildChapterCard(c.id, c.title, c.entryCount, colors))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // Create new chapter
                GestureDetector(
                  onTap: _showCreateChapterDialog,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.accent.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 20, color: colors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Create New Chapter',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
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

        _buildBottomBar(colors),
      ],
    );
  }

  Widget _buildChapterCard(String id, String title, int entryCount, AppPalette colors) {
    final isSelected = _selectedChapterId == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedChapterId = isSelected ? null : id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentFaint : colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? colors.accent : colors.accentFaint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bookmark_rounded,
                size: 20,
                color: isSelected ? Colors.white : colors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$entryCount ${entryCount == 1 ? 'memory' : 'memories'}',
                    style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 22, color: colors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppPalette colors) {
    final hasSelection = _selectedChapterId != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSaveError(colors),
              if (!hasSelection)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Select a chapter to continue',
                    style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
                  ),
                ),
              GestureDetector(
                onTap: hasSelection && !_isSaving ? _next : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: hasSelection ? colors.accent : colors.accent.withAlpha(60),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasSelection
                        ? [BoxShadow(color: colors.accent.withAlpha(50), blurRadius: 12, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: _isSaving
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                      : Text(
                          'Continue',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: hasSelection ? Colors.white : Colors.white.withAlpha(120),
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

  // ---------------------------------------------------------------------------
  // Step 1 — Confirmation
  // ---------------------------------------------------------------------------

  Widget _buildConfirmationScreen(AppPalette colors) {
    final resolvedData = _confirmedData ?? widget.data ?? ref.read(postSaveDataProvider);
    final photoPath = resolvedData?.attachedPhotoPath;
    return Container(
      key: const ValueKey('confirmation'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.accentFaint, colors.bg],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              _buildPhotoCardSection(colors, photoPath: photoPath),

              const SizedBox(height: 36),

              Text(
                'Memory saved\nsuccessfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Your memory has been preserved and added to its chapter. Revisit it anytime.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: colors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),

              if (resolvedData?.savedOffline == true) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.accent.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: colors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saved locally — will sync when back online.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // View Memory
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(postSaveDataProvider.notifier).state = null;
                  context.go('/timeline');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: colors.accent.withAlpha(50), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    'View on Timeline',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(postSaveDataProvider.notifier).state = null;
                        context.go('/home');
                        Future.microtask(() {
                          if (mounted) context.push('/write');
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Add Another',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _finish,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Go Home',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCardSection(AppPalette colors, {String? photoPath}) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform.rotate(
            angle: -5 * math.pi / 180,
            child: Container(
              width: 200,
              height: 160,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border, width: 4),
                boxShadow: [
                  BoxShadow(color: colors.textPrimary.withAlpha(20), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photoPath != null
                    ? Image.file(
                        File(photoPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: colors.accentFaint,
                          child: Center(
                            child: Icon(Icons.landscape_rounded, size: 48, color: colors.accent.withAlpha(120)),
                          ),
                        ),
                      )
                    : Container(
                        color: colors.accentFaint,
                        child: Center(
                          child: Icon(Icons.landscape_rounded, size: 48, color: colors.accent.withAlpha(120)),
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.card,
                border: Border.all(color: colors.border),
                boxShadow: [BoxShadow(color: colors.textPrimary.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(Icons.favorite_rounded, size: 18, color: colors.accent),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 40,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.card,
                border: Border.all(color: colors.border),
                boxShadow: [BoxShadow(color: colors.textPrimary.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 16, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
