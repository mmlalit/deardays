import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// A horizontally-scrollable "On This Day" section that surfaces
/// memories from exactly N years ago.  Each card has a subtle sepia
/// tint over any photo and a "N years ago" circular badge.
class OnThisDaySection extends StatelessWidget {
  const OnThisDaySection({
    super.key,
    required this.entries,
    required this.colors,
    required this.onEntryTap,
    this.photoUrlBuilder,
  });

  final List<JournalEntry> entries;
  final AppPalette colors;
  final void Function(JournalEntry entry) onEntryTap;
  final String Function(String storagePath)? photoUrlBuilder;

  int _yearsAgo(JournalEntry e) {
    return DateTime.now().year - e.entryDate.year;
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orange.withAlpha(20),
                ),
                child: const Icon(Icons.history_rounded, size: 18, color: AppColors.orange),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On This Day',
                    style: GoogleFonts.newsreader(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Memories from years past',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Horizontal scroll of memory cards
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _buildMemoryCard(entries[i]),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMemoryCard(JournalEntry entry) {
    final yearsAgo = _yearsAgo(entry);
    final dateStr = DateFormat('MMM dd, yyyy').format(entry.entryDate);
    final excerpt = _extractExcerpt(entry);
    final photos = entry.media.where((m) => m.mediaType == 'photo').toList();
    final hasPhoto = photos.isNotEmpty;

    return GestureDetector(
      onTap: () => onEntryTap(entry),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo area (sepia-tinted) or decorative fallback
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPhoto)
                    _buildSepiaPhoto(photos.first.storagePath)
                  else
                    _buildDecorativeFallback(),

                  // "N years ago" badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$yearsAgo',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          Text(
                            yearsAgo == 1 ? 'year' : 'years',
                            style: GoogleFonts.manrope(
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    Text(
                      dateStr,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Excerpt
                    Expanded(
                      child: Text(
                        excerpt,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSepiaPhoto(String storagePath) {
    final url = photoUrlBuilder?.call(storagePath);
    final child = (url != null && url.isNotEmpty)
        ? Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildDecorativeFallback(),
          )
        : _buildDecorativeFallback();

    // Apply sepia-like warm tint
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.39, 0.35, 0.17, 0, 20,
        0.35, 0.31, 0.14, 0, 15,
        0.27, 0.24, 0.11, 0, 10,
        0,    0,    0,    1,  0,
      ]),
      child: child,
    );
  }

  Widget _buildDecorativeFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.orange.withAlpha(25),
            AppColors.orangeBg,
          ],
        ),
      ),
      child: Center(
        child: Text(
          '\u201C',
          style: GoogleFonts.newsreader(
            fontSize: 72,
            fontWeight: FontWeight.w700,
            color: AppColors.orange.withAlpha(40),
            height: 1,
          ),
        ),
      ),
    );
  }

  String _extractExcerpt(JournalEntry e) {
    final lines = e.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final first = lines.first.trim();
    final isTitle = first.length < 80 && lines.length > 1;
    final body = isTitle ? lines.skip(1).join(' ') : e.content;
    return body.length > 100 ? '${body.substring(0, 100)}...' : body;
  }
}
