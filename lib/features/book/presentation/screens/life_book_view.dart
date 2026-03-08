import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/book/presentation/providers/life_book_provider.dart';

class LifeBookView extends ConsumerWidget {
  const LifeBookView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lifeBookProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.chapters.isEmpty) {
      return _buildEmptyState(context);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCoverSection(context, state),
          const SizedBox(height: 32),
          _buildContentsSection(context, ref, state),
          const SizedBox(height: 28),
          if (state.activeEntry != null)
            _buildEntryDetail(context, ref, state),
          const SizedBox(height: 32),
          _buildDownloadButton(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 56,
              color: colors.accent.withAlpha(76),
            ),
            const SizedBox(height: 16),
            Text(
              'Your story is waiting',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start journaling from the home screen.\nYour conversations will appear here\nas beautifully written entries.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverSection(BuildContext context, LifeBookState state) {
    final colors = AppColors.of(context);
    final totalEntries =
        state.chapters.fold<int>(0, (sum, ch) => sum + ch.entryCount);
    final dateRange = _buildDateRange(state.chapters);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.readingBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.readingText.withAlpha(26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.accent.withAlpha(153),
                    colors.accent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.auto_stories,
                size: 34,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'My Life Book',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.readingText,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dateRange,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.readingText.withAlpha(128),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.accent.withAlpha(102)),
              ),
              child: Text(
                '$totalEntries ${totalEntries == 1 ? 'entry' : 'entries'}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentsSection(BuildContext context, WidgetRef ref, LifeBookState state) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Contents',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: colors.accent,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...state.chapters.asMap().entries.map((e) {
          final index = e.key;
          final chapter = e.value;
          final isActive = state.activeChapterIndex == index;
          return _buildChapterItem(
            context: context,
            ref: ref,
            title: chapter.title,
            subtitle:
                'CHAPTER ${index + 1} \u2022 ${chapter.entryCount} ${chapter.entryCount == 1 ? 'ENTRY' : 'ENTRIES'}',
            isActive: isActive,
            onTap: () =>
                ref.read(lifeBookProvider.notifier).selectChapter(index),
          );
        }),
      ],
    );
  }

  Widget _buildChapterItem({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:
              isActive ? colors.accent.withAlpha(13) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? colors.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.readingText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppColors.readingText.withAlpha(102),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isActive
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 20,
              color: isActive
                  ? colors.accent
                  : AppColors.readingText.withAlpha(76),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryDetail(BuildContext context, WidgetRef ref, LifeBookState state) {
    final colors = AppColors.of(context);
    final entry = state.activeEntry!;
    final chapterIdx = state.activeChapterIndex!;
    final chapter = state.chapters[chapterIdx];
    final entryIdx = state.activeEntryIndex!;
    final dateStr = DateFormat('MMMM d, yyyy').format(entry.date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.readingText.withAlpha(20)),

          // Entry picker if chapter has multiple entries
          if (chapter.entries.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chapter.entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final e = chapter.entries[index];
                  final isSelected = index == entryIdx;
                  return GestureDetector(
                    onTap: () => ref
                        .read(lifeBookProvider.notifier)
                        .selectEntry(chapterIdx, index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent
                            : colors.accent.withAlpha(13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        DateFormat('MMM d').format(e.date),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : colors.accent,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Entry header
          Row(
            children: [
              Text(
                dateStr,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.readingText.withAlpha(153),
                ),
              ),
              if (entry.mood != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.readingText.withAlpha(64),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _moodIcon(entry.mood!),
                  size: 14,
                  color: _moodColor(entry.mood!),
                ),
                const SizedBox(width: 4),
                Text(
                  entry.mood!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _moodColor(entry.mood!),
                  ),
                ),
              ],
              const Spacer(),
              // Re-polish button
              if (entry.hasPolished)
                GestureDetector(
                  onTap: () => ref
                      .read(lifeBookProvider.notifier)
                      .repolishEntry(chapterIdx, entryIdx),
                  child: Icon(
                    Icons.refresh,
                    size: 18,
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Entry body
          if (entry.isPolishing)
            _buildPolishingIndicator(context)
          else
            _buildEntryBody(entry.displayText),
        ],
      ),
    );
  }

  Widget _buildPolishingIndicator(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Crafting your story...',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryBody(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    // Split into paragraphs
    final paragraphs =
        text.split('\n').where((p) => p.trim().isNotEmpty).toList();

    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Builder(builder: (context) {
      final colors = AppColors.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First paragraph with drop cap
          _buildDropCapParagraph(context, paragraphs.first),
          // Remaining paragraphs
          ...paragraphs.skip(1).map((p) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  p,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.readingText,
                    height: 1.8,
                  ),
                ),
              )),
        ],
      );
    });
  }

  Widget _buildDropCapParagraph(BuildContext context, String text) {
    final colors = AppColors.of(context);
    if (text.length < 2) {
      return Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 16,
          color: AppColors.readingText,
          height: 1.8,
        ),
      );
    }

    final firstChar = text[0].toUpperCase();
    final restText = text.substring(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstChar,
          style: GoogleFonts.manrope(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: colors.accent,
            height: 0.85,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            restText,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.readingText,
              height: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/export'),
          icon: const Icon(Icons.download_rounded, size: 20),
          label: Text(
            'Download as PDF',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  // -- Helpers --

  String _buildDateRange(List<LifeBookChapter> chapters) {
    if (chapters.isEmpty) return '';
    final oldest = chapters.last;
    final newest = chapters.first;
    final start = DateFormat('MMM yyyy')
        .format(DateTime(oldest.year, oldest.month));
    final end = DateFormat('MMM yyyy')
        .format(DateTime(newest.year, newest.month));
    if (start == end) return start;
    return '$start \u2014 $end';
  }

  IconData _moodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return Icons.sentiment_very_satisfied;
      case 'good':
        return Icons.sentiment_satisfied;
      case 'okay':
        return Icons.sentiment_neutral;
      case 'low':
        return Icons.sentiment_dissatisfied;
      case 'tough':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return AppColors.moodGreat;
      case 'good':
        return AppColors.moodGood;
      case 'okay':
        return AppColors.moodOkay;
      case 'low':
        return AppColors.moodLow;
      case 'tough':
        return AppColors.moodTough;
      default:
        return AppColors.moodOkay;
    }
  }
}
