import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/utils/entry_categories.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/services/sync/sync_queue.dart';

/// Full-width memory card matching the Timeline tab card design.
/// Shows photo/mood-band, date, tags, title, excerpt, voice indicator,
/// and an optional share icon.
/// Used by TimelineScreen and ChapterDetailScreen.
class MemoryCard extends ConsumerWidget {
  const MemoryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onLongPress,
    this.onShare,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onShare;

  // ── Static helpers (reusable from outside) ────────────────────────────────

  static String extractTitle(JournalEntry entry) {
    final lines =
        entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return entry.content.length > 50
        ? '${entry.content.substring(0, 50)}...'
        : entry.content;
  }

  static String extractExcerpt(JournalEntry entry) {
    final lines =
        entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final first = lines.first.trim();
    final isTitle = first.length < 80 && lines.length > 1;
    final body = isTitle ? lines.skip(1).join(' ') : entry.content;
    return body.length > 120 ? '${body.substring(0, 120)}...' : body;
  }

  static List<(String, Color)> entryTags(JournalEntry entry) =>
      EntryCategories.tagChips(entry);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors   = AppColors.of(context);
    final title    = extractTitle(entry);
    final excerpt  = extractExcerpt(entry);
    final timeStr  = entry.entryTime != null
        ? '${entry.entryTime!.hour.toString().padLeft(2, '0')}:${entry.entryTime!.minute.toString().padLeft(2, '0')}'
        : DateFormat('HH:mm').format(entry.createdAt);
    final dateStr  = '${DateFormat('MMM dd').format(entry.entryDate).toUpperCase()} • $timeStr';
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final tags     = entryTags(entry);
    final hasPhoto = photoMedia.isNotEmpty;
    final isPendingSync = SyncQueue().isPending(entry.id);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
            // Photo bleeds to card edges, or mood-colour band as visual anchor
            if (hasPhoto)
              Stack(
                children: [
                  MemoryCardPhoto(
                    storagePath: photoMedia.first.storagePath,
                    colors: colors,
                  ),
                  if (onShare != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _FrostedShareButton(onTap: onShare!),
                    ),
                ],
              )
            else if (entry.mood != null)
              _MoodBand(mood: entry.mood!, colors: colors),

            Padding(
              padding: EdgeInsets.fromLTRB(16, hasPhoto ? 14 : 18, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + sync indicator + tag chips
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          dateStr,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors.textMuted,
                            letterSpacing: 1.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPendingSync) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 12,
                          color: colors.textMuted.withAlpha(150),
                        ),
                      ],
                      const Spacer(),
                      ...tags.take(2).map((t) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _TagChip(label: t.$1, color: t.$2),
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
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (entry.hasVoice) ...[
                    const SizedBox(height: 10),
                    _VoiceIndicator(colors: colors),
                  ],
                  // Share on text-only cards (no photo to overlay)
                  if (onShare != null && !hasPhoto) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _FrostedShareButton(onTap: onShare!, muted: true, colors: colors),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

// ── Frosted glass share button ───────────────────────────────────────────────

class _FrostedShareButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool muted;
  final AppPalette? colors;

  const _FrostedShareButton({
    required this.onTap,
    this.muted = false,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Share memory',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: muted
            ? Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (colors?.border ?? Colors.grey).withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.share_rounded,
                  size: 16,
                  color: colors?.textMuted ?? Colors.grey,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(180),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      size: 15,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
}

// ── Mood band ─────────────────────────────────────────────────────────────────

class _MoodBand extends StatelessWidget {
  const _MoodBand({required this.mood, required this.colors});

  final String mood;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    final moodColor = switch (mood) {
      'great' => AppColors.moodGreat,
      'good'  => AppColors.moodGood,
      'okay'  => AppColors.moodOkay,
      'low'   => AppColors.moodLow,
      'tough' => AppColors.moodTough,
      _       => colors.accent,
    };
    final moodEmoji = switch (mood) {
      'great' => '🌟',
      'good'  => '😊',
      'okay'  => '😌',
      'low'   => '😔',
      'tough' => '💪',
      _       => '✨',
    };
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            moodColor.withAlpha(38),
            moodColor.withAlpha(18),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(width: 3, color: moodColor),
          const SizedBox(width: 12),
          Text(moodEmoji, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

// ── Voice indicator ───────────────────────────────────────────────────────────

class _VoiceIndicator extends StatelessWidget {
  const _VoiceIndicator({required this.colors});

  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.accentFaint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          ...List.generate(7, (i) {
            const heights = [4.0, 8.0, 12.0, 8.0, 4.0, 8.0, 12.0];
            const alphas  = [100, 160, 255, 160, 100, 160, 255];
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
          const SizedBox(width: 8),
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
}

// ── Photo widget (public so other screens can reuse it) ───────────────────────

class MemoryCardPhoto extends ConsumerStatefulWidget {
  const MemoryCardPhoto({
    super.key,
    required this.storagePath,
    required this.colors,
    this.height = 140,
  });

  final String storagePath;
  final AppPalette colors;
  final double height;

  @override
  ConsumerState<MemoryCardPhoto> createState() => _MemoryCardPhotoState();
}

class _MemoryCardPhotoState extends ConsumerState<MemoryCardPhoto> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _fetchUrl();
  }

  @override
  void didUpdateWidget(MemoryCardPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) {
      _urlFuture = _fetchUrl();
    }
  }

  Future<String> _fetchUrl() async {
    if (widget.storagePath.startsWith('http')) return widget.storagePath;
    try {
      return await ref
          .read(mediaServiceProvider)
          .getSignedUrl(widget.storagePath);
    } catch (e) {
      debugPrint('[MemoryCard] getSignedUrl failed: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final child = FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.accentFaint,
                  colors.accentFaint.withAlpha(50),
                  colors.accentFaint,
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.hasError || snapshot.data!.isEmpty) {
          return Container(
            color: colors.accentFaint,
            child: Icon(
              Icons.image_outlined,
              size: 32,
              color: colors.textMuted.withAlpha(120),
            ),
          );
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          width: double.infinity,
          fit: BoxFit.cover,
          memCacheWidth: 600,
          memCacheHeight: 338,
          errorWidget: (_, __, ___) => Container(
            color: colors.accentFaint,
            child: Icon(
              Icons.image_outlined,
              size: 32,
              color: colors.textMuted.withAlpha(120),
            ),
          ),
        );
      },
    );
    // 16:9 landscape — cinematic header, lets text show below the fold
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: child,
    );
  }
}
