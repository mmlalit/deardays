import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/storage/local_storage_service.dart';

void showDraftHistorySheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DraftHistorySheet(ref: ref),
  );
}

class _DraftHistorySheet extends ConsumerWidget {
  final WidgetRef ref;
  const _DraftHistorySheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef watchRef) {
    final colors = AppColors.of(context);
    final draftsAsync = watchRef.watch(draftsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row — no hard divider, bottom padding creates separation
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Drafts',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  draftsAsync.when(
                    data: (drafts) => drafts.isEmpty
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.accent.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${drafts.length}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.accent,
                              ),
                            ),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  // Proper 44×44 tap target for close
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(Icons.close_rounded,
                            size: 20, color: colors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: draftsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Could not load drafts',
                      style: GoogleFonts.manrope(color: colors.textMuted)),
                ),
                data: (drafts) => drafts.isEmpty
                    ? _EmptyState(colors: colors)
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: drafts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) => _DraftCard(
                          draft: drafts[i],
                          colors: colors,
                          onTap: () => _openDraft(context, watchRef, drafts[i]),
                          onDelete: () =>
                              _deleteDraft(context, watchRef, drafts[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDraft(BuildContext context, WidgetRef ref, DraftEntry draft) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    if (draft.type == DraftType.text) {
      context.push('/write', extra: draft);
    } else {
      context.push(
        '/review',
        extra: ReviewData(
          rawText: draft.rawText,
          cleanedText: draft.cleanedText,
          polishedText: draft.polishedText,
          generatedTitle: draft.generatedTitle,
          mood: draft.mood,
          locationName: draft.locationName,
          attachedPhotoPath: draft.attachedPhotoPath,
          isVoice: draft.isVoice,
          polishWithAI: false,
          existingDraftId: draft.id,
        ),
      );
    }
  }

  Future<void> _deleteDraft(
      BuildContext context, WidgetRef ref, DraftEntry draft) async {
    HapticFeedback.lightImpact();
    await LocalStorageService.instance.deleteDraft(draft.id);
    ref.invalidate(draftsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draft deleted',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draft card
// ─────────────────────────────────────────────────────────────────────────────

class _DraftCard extends StatelessWidget {
  final DraftEntry draft;
  final AppPalette colors;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.colors,
    required this.onTap,
    required this.onDelete,
  });

  String get _dateLabel {
    final now = DateTime.now();
    final d = draft.savedAt;
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(d)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('h:mm a').format(d)}';
    }
    return DateFormat('MMM d, h:mm a').format(d);
  }

  String get _wordCountLabel {
    final n = draft.wordCount;
    return '$n word${n == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final isReview = draft.type == DraftType.review;
    return Dismissible(
      key: ValueKey(draft.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.red, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: date + type badge
              Row(
                children: [
                  Text(
                    _dateLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  if (isReview)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.accent.withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'AI polished',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Preview text — 14px, generous line height
              Text(
                draft.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: colors.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              // Footer: word count + metadata pills + chevron
              Row(
                children: [
                  Text(
                    _wordCountLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (draft.attachedPhotoPath != null &&
                      File(draft.attachedPhotoPath!).existsSync()) ...[
                    const SizedBox(width: 8),
                    _Pill(
                        icon: Icons.image_rounded,
                        label: 'photo',
                        colors: colors),
                  ],
                  if (draft.isVoice) ...[
                    const SizedBox(width: 8),
                    _Pill(
                        icon: Icons.mic_rounded,
                        label: 'voice',
                        colors: colors),
                  ],
                  if (draft.mood != null) ...[
                    const SizedBox(width: 8),
                    _Pill(
                        icon: Icons.mood_rounded,
                        label: draft.mood!,
                        colors: colors),
                  ],
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: colors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill — metadata tag with subtle background
// ─────────────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette colors;

  const _Pill(
      {required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.border.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppPalette colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 48, color: colors.textMuted.withAlpha(80)),
          const SizedBox(height: 16),
          Text(
            'No drafts yet',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Entries you leave without saving\nwill appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textMuted.withAlpha(160),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
