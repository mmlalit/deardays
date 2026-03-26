import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/core/widgets/memory_card.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/timeline/presentation/widgets/milestone_card.dart';
import 'package:deardays/features/timeline/presentation/widgets/photo_collage_card.dart';

/// A visual timeline list (dot + vertical line + year headers) rendered as a
/// [Column] — suitable for embedding inside a [SingleChildScrollView].
///
/// Used by [ChapterDetailScreen] (and any other screen that already has its
/// own scroll view) so that the full timeline visual is identical to the
/// Timeline tab.
class TimelineList extends StatelessWidget {
  const TimelineList({
    super.key,
    required this.entries,
    required this.colors,
    required this.onEntryTap,
    this.accentColor,
    this.onShare,
    this.onLongPress,
    this.photoUrlBuilder,
    this.horizontalPadding = 20,
  });

  final List<JournalEntry> entries;
  final AppPalette colors;

  /// Accent color used for year-badge and dot highlight.
  /// Defaults to [AppPalette.accent] when null.
  final Color? accentColor;

  final void Function(JournalEntry entry, List<JournalEntry> all, int index) onEntryTap;
  final void Function(JournalEntry)? onShare;
  final void Function(JournalEntry)? onLongPress;

  /// Used to resolve a storage path to a displayable URL.
  /// If null, only HTTP URLs in media are shown.
  final Future<String> Function(String storagePath)? photoUrlBuilder;

  final double horizontalPadding;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? colors.accent;

    // Group by year, newest first.
    final grouped = <int, List<JournalEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.entryDate.year, () => []).add(e);
    }
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final mostRecentYear = years.isNotEmpty ? years.first : DateTime.now().year;

    final children = <Widget>[];
    for (final year in years) {
      final yearEntries = grouped[year]!;
      children.add(_YearHeaderRow(
        year: year,
        isCurrentYear: year == mostRecentYear,
        accentColor: accent,
        colors: colors,
      ));
      for (int i = 0; i < yearEntries.length; i++) {
        final entry = yearEntries[i];
        final isLast = (year == years.last) && (i == yearEntries.length - 1);
        children.add(_CardRow(
          entry: entry,
          isLast: isLast,
          colors: colors,
          card: _cardForType(
            entry: entry,
            allEntries: entries,
            colors: colors,
            photoUrlBuilder: photoUrlBuilder,
            onTap: () => onEntryTap(entry, entries, entries.indexOf(entry)),
            onShare: onShare != null ? () => onShare!(entry) : null,
            onLongPress: onLongPress != null ? () => onLongPress!(entry) : null,
          ),
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ── Card type picker ──────────────────────────────────────────────────────

  static Widget _cardForType({
    required JournalEntry entry,
    required List<JournalEntry> allEntries,
    required AppPalette colors,
    required VoidCallback onTap,
    VoidCallback? onShare,
    VoidCallback? onLongPress,
    Future<String> Function(String)? photoUrlBuilder,
  }) {
    final photoCount = entry.media.where((m) => m.mediaType == 'photo').length;

    Future<String> resolveUrl(String path) async {
      if (path.startsWith('http')) return path;
      return photoUrlBuilder != null ? await photoUrlBuilder(path) : '';
    }

    if (entry.isMilestone) {
      return MilestoneCard(
        entry: entry,
        colors: colors,
        onTap: onTap,
        photoUrlBuilder: resolveUrl,
      );
    }

    if (photoCount >= 2) {
      return PhotoCollageCard(
        entry: entry,
        colors: colors,
        onTap: onTap,
        photoUrlBuilder: resolveUrl,
      );
    }

    return MemoryCard(
      entry: entry,
      onTap: onTap,
      onShare: onShare,
      onLongPress: onLongPress,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Year header row: circle badge + horizontal rule
// ─────────────────────────────────────────────────────────────────────────────

class _YearHeaderRow extends StatelessWidget {
  const _YearHeaderRow({
    required this.year,
    required this.isCurrentYear,
    required this.accentColor,
    required this.colors,
  });

  final int year;
  final bool isCurrentYear;
  final Color accentColor;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vertical line through center
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 19,
                    child: Container(width: 2, color: colors.border),
                  ),
                  // Year badge on top
                  ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrentYear ? accentColor : colors.border,
                        boxShadow: isCurrentYear
                            ? [
                                BoxShadow(
                                  color: accentColor.withAlpha(60),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$year',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isCurrentYear
                                ? Colors.white
                                : const Color(0xFF4A4540),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Container(height: 1, color: colors.border)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card row: dot + vertical line + card widget
// ─────────────────────────────────────────────────────────────────────────────

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.entry,
    required this.isLast,
    required this.colors,
    required this.card,
  });

  final JournalEntry entry;
  final bool isLast;
  final AppPalette colors;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final dotColor = ChapterVisual.forTitle(MemoryCard.extractTitle(entry)).primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column: vertical line + dot
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical line
                if (!isLast)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 19,
                    child: Container(width: 2, color: colors.border),
                  )
                else
                  Positioned(
                    top: 0,
                    bottom: 24,
                    left: 19,
                    child: Container(width: 2, color: colors.border),
                  ),
                // Dot at ~22px from top
                Positioned(
                  top: 22,
                  left: 14,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      border: Border.all(color: colors.bg, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly-grouped view — used by ChapterDetailScreen's "Monthly" toggle
// ─────────────────────────────────────────────────────────────────────────────

class TimelineMonthlyList extends StatelessWidget {
  const TimelineMonthlyList({
    super.key,
    required this.entries,
    required this.colors,
    required this.accentColor,
    required this.onEntryTap,
    this.onShare,
    this.onLongPress,
    this.photoUrlBuilder,
    this.horizontalPadding = 20,
  });

  final List<JournalEntry> entries;
  final AppPalette colors;
  final Color accentColor;
  final void Function(JournalEntry, List<JournalEntry>, int) onEntryTap;
  final void Function(JournalEntry)? onShare;
  final void Function(JournalEntry)? onLongPress;
  final Future<String> Function(String)? photoUrlBuilder;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<JournalEntry>>{};
    for (final e in entries) {
      final key =
          '${e.entryDate.year}-${e.entryDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final key in keys) ...[
            _buildMonthHeader(key, grouped[key]!.length),
            for (final entry in grouped[key]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TimelineList._cardForType(
                  entry: entry,
                  allEntries: grouped[key]!,
                  colors: colors,
                  photoUrlBuilder: photoUrlBuilder,
                  onTap: () => onEntryTap(
                    entry,
                    grouped[key]!,
                    grouped[key]!.indexOf(entry),
                  ),
                  onShare: onShare != null ? () => onShare!(entry) : null,
                  onLongPress:
                      onLongPress != null ? () => onLongPress!(entry) : null,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String key, int count) {
    final parts = key.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(date),
            style: GoogleFonts.newsreader(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
