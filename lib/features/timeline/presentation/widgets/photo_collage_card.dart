import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';

/// A card that displays a grid photo collage when an entry has 2+ photos.
/// Layout adapts based on photo count:
///   2 photos → side-by-side
///   3 photos → 1 large left + 2 stacked right
///   4+ photos → 2×2 grid with "+N" overlay on 4th if > 4
class PhotoCollageCard extends StatelessWidget {
  const PhotoCollageCard({
    super.key,
    required this.entry,
    required this.colors,
    required this.onTap,
    this.photoUrlBuilder,
  });

  final JournalEntry entry;
  final AppPalette colors;
  final VoidCallback onTap;
  final Future<String> Function(String storagePath)? photoUrlBuilder;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM dd').format(entry.entryDate).toUpperCase();
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final photos =
        entry.media.where((m) => m.mediaType == 'photo').toList();
    final tags = _entryTags(entry);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo collage bleeds to card edges at top — same structure as single-photo card
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: _buildCollage(photos),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + tags row
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      ...tags.take(2).map((t) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _buildTagChip(t.$1, t.$2),
                          )),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Excerpt
                  Text(
                    excerpt,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.6,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Voice indicator
                  if (entry.hasVoice) ...[
                    const SizedBox(height: 10),
                    _buildVoiceIndicator(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollage(List<EntryMedia> photos) {
    if (photos.length == 2) return _buildTwoPhotos(photos);
    if (photos.length == 3) return _buildThreePhotos(photos);
    return _buildFourPhotos(photos);
  }

  // ── 2 photos: side-by-side ──
  Widget _buildTwoPhotos(List<EntryMedia> photos) {
    return SizedBox(
      height: 140,
      child: Row(
        children: [
          Expanded(child: _photoTile(photos[0].storagePath)),
          const SizedBox(width: 2),
          Expanded(child: _photoTile(photos[1].storagePath)),
        ],
      ),
    );
  }

  // ── 3 photos: 1 large left + 2 stacked right ──
  Widget _buildThreePhotos(List<EntryMedia> photos) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(flex: 3, child: _photoTile(photos[0].storagePath)),
          const SizedBox(width: 2),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: _photoTile(photos[1].storagePath)),
                const SizedBox(height: 2),
                Expanded(child: _photoTile(photos[2].storagePath)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4+ photos: 2×2 grid, "+N" on last if > 4 ──
  Widget _buildFourPhotos(List<EntryMedia> photos) {
    final extra = photos.length - 4;
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _photoTile(photos[0].storagePath)),
                const SizedBox(width: 2),
                Expanded(child: _photoTile(photos[1].storagePath)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _photoTile(photos[2].storagePath)),
                const SizedBox(width: 2),
                Expanded(
                  child: extra > 0
                      ? _photoTileWithOverlay(
                          photos[3].storagePath, '+$extra')
                      : _photoTile(photos[3].storagePath),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(String storagePath) {
    final future = photoUrlBuilder?.call(storagePath);
    if (future == null) return _photoPlaceholder();
    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.hasError || url == null || url.isEmpty) {
          return snapshot.connectionState == ConnectionState.waiting
              ? _photoShimmer()
              : _photoPlaceholder();
        }
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 600,
          memCacheHeight: 600,
          placeholder: (_, __) => _photoShimmer(),
          errorWidget: (_, __, ___) => _photoPlaceholder(),
        );
      },
    );
  }

  Widget _photoTileWithOverlay(String storagePath, String label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _photoTile(storagePath),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoShimmer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accentFaint,
            colors.accentFaint.withAlpha(60),
            colors.accentFaint,
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accentFaint,
            colors.accentFaint.withAlpha(80),
          ],
        ),
      ),
      child: Icon(Icons.image_outlined, size: 28, color: colors.textMuted.withAlpha(120)),
    );
  }

  Widget _buildVoiceIndicator() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.accentFaint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          ...List.generate(7, (i) {
            const heights = [4.0, 8.0, 12.0, 8.0, 4.0, 8.0, 12.0];
            const alphas = [100, 160, 255, 160, 100, 160, 255];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 2.5,
                height: heights[i],
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(alphas[i]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
          const Spacer(),
          Text(
            'Voice',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  List<(String, Color)> _entryTags(JournalEntry e) {
    final tags = <(String, Color)>[];
    switch (e.mood) {
      case 'great':
        tags.add(('Joy', AppColors.moodOkay));
      case 'good':
        tags.add(('Happy', AppColors.moodGood));
      case 'okay':
        tags.add(('Serene', AppColors.moodGood));
      case 'low':
        tags.add(('Sad', AppColors.indigo));
      case 'tough':
        tags.add(('Growth', AppColors.orange));
    }
    final text = e.content.toLowerCase();
    if (text.contains('travel') || text.contains('trip') || text.contains('vacation')) {
      tags.add(('Travel', AppColors.blue));
    } else if (text.contains('work') || text.contains('job') || text.contains('career')) {
      tags.add(('Career', AppColors.blue));
    } else if (text.contains('family') || text.contains('mom') || text.contains('dad')) {
      tags.add(('Family', AppColors.blue));
    }
    return tags.take(2).toList();
  }

  String _extractTitle(JournalEntry e) {
    final lines = e.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return e.content.length > 50 ? '${e.content.substring(0, 50)}...' : e.content;
  }

  String _extractExcerpt(JournalEntry e) {
    final lines = e.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final first = lines.first.trim();
    final isTitle = first.length < 80 && lines.length > 1;
    final body = isTitle ? lines.skip(1).join(' ') : e.content;
    return body.length > 120 ? '${body.substring(0, 120)}...' : body;
  }
}
