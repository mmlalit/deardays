import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// A visually prominent card for life milestones — birthdays, promotions,
/// graduations, etc.  Features a hero photo area with gradient overlay,
/// accent left border, and a milestone type badge.
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({
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

  // Milestone type → icon mapping
  static const _milestoneIcons = <String, IconData>{
    'birthday': Icons.cake_rounded,
    'graduation': Icons.school_rounded,
    'wedding': Icons.favorite_rounded,
    'promotion': Icons.trending_up_rounded,
    'newborn': Icons.child_care_rounded,
    'anniversary': Icons.celebration_rounded,
    'travel': Icons.flight_takeoff_rounded,
    'achievement': Icons.emoji_events_rounded,
    'other': Icons.star_rounded,
  };

  String _milestoneLabel(String? type) {
    if (type == null) return 'Milestone';
    return type[0].toUpperCase() + type.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM dd').format(entry.entryDate).toUpperCase();
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final icon = _milestoneIcons[entry.milestoneType] ?? Icons.star_rounded;
    final photoMedia =
        entry.media.where((m) => m.mediaType == 'photo').toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.accent.withAlpha(18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Accent left border
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: colors.accent),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero photo area
                if (photoMedia.isNotEmpty) _buildHeroPhoto(photoMedia.first.storagePath),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge row: date + milestone badge
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
                          _buildMilestoneBadge(icon),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title — slightly larger for milestones
                      Text(
                        title,
                        style: GoogleFonts.newsreader(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Excerpt
                      Text(
                        excerpt,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: colors.textSecondary,
                          height: 1.6,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPhoto(String storagePath) {
    final future = photoUrlBuilder?.call(storagePath);

    return Stack(
      children: [
        // Photo
        if (future != null)
          FutureBuilder<String>(
            future: future,
            builder: (context, snapshot) {
              final url = snapshot.data;
              if (snapshot.hasError || url == null || url.isEmpty) {
                return _buildPhotoPlaceholder();
              }
              return CachedNetworkImage(
                imageUrl: url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                memCacheHeight: 360,
                errorWidget: (_, __, ___) => _buildPhotoPlaceholder(),
              );
            },
          )
        else
          _buildPhotoPlaceholder(),

        // Gradient overlay
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.cardBg.withAlpha(0),
                  colors.cardBg,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withAlpha(30),
            colors.accentFaint,
          ],
        ),
      ),
      child: Icon(Icons.photo_rounded, size: 48, color: colors.accent.withAlpha(60)),
    );
  }

  Widget _buildMilestoneBadge(IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withAlpha(50),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            _milestoneLabel(entry.milestoneType).toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _extractTitle(JournalEntry e) {
    final lines =
        e.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return e.content.length > 50
        ? '${e.content.substring(0, 50)}...'
        : e.content;
  }

  String _extractExcerpt(JournalEntry e) {
    final lines =
        e.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final first = lines.first.trim();
    final isTitle = first.length < 80 && lines.length > 1;
    final body = isTitle ? lines.skip(1).join(' ') : e.content;
    return body.length > 120 ? '${body.substring(0, 120)}...' : body;
  }
}
