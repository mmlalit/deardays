import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _moodFilter;
  String _searchQuery = '';

  static const _filterChips = [
    (null, 'All'),
    ('great', 'Joy'),
    ('good', 'Happy'),
    ('okay', 'Calm'),
    ('low', 'Sad'),
    ('tough', 'Tough'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _buildHeader(colors),
          Expanded(child: _buildBody(colors)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppPalette colors) {
    return Container(
      color: colors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + title + filter
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.accentFaint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_stories_rounded, size: 22, color: colors.accent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Timeline',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.accentFaint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(Icons.tune_rounded, size: 20, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: colors.accentFaint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: GoogleFonts.manrope(fontSize: 14, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search your life memories...',
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
                    prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category filter chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filterChips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (mood, label) = _filterChips[i];
                  final isActive = _moodFilter == mood;
                  return GestureDetector(
                    onTap: () => setState(() => _moodFilter = mood),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? colors.accent : colors.accentFaint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? colors.accent : colors.border),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : colors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: colors.border, height: 1),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody(AppPalette colors) {
    final entriesAsync = ref.watch(timelineEntriesProvider);
    return entriesAsync.when(
      data: (entries) {
        var filtered = entries;
        if (_moodFilter != null) {
          filtered = filtered.where((e) => e.mood == _moodFilter).toList();
        }
        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((e) =>
            e.content.toLowerCase().contains(_searchQuery) ||
            (e.locationName?.toLowerCase().contains(_searchQuery) ?? false),
          ).toList();
        }

        if (filtered.isEmpty) return _buildEmptyState(colors);

        // Group by year
        final grouped = <int, List<JournalEntry>>{};
        for (final e in filtered) {
          grouped.putIfAbsent(e.entryDate.year, () => []).add(e);
        }
        final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        // Build flat list
        final items = <_TimelineItem>[];
        for (final year in years) {
          items.add(_TimelineItem.year(year, grouped[year]!.length));
          for (final entry in grouped[year]!) {
            items.add(_TimelineItem.entry(entry));
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            if (item.isYearHeader) {
              return _buildYearHeader(item.year!, item.count!, colors);
            }
            return _buildTimelineCard(item.entry!, colors);
          },
        );
      },
      loading: () => _buildSkeleton(colors),
      error: (_, __) => _buildError(colors),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Year Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildYearHeader(int year, int count, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$year',
            style: GoogleFonts.manrope(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: colors.accent,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Container(height: 1, color: colors.border)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Timeline Card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTimelineCard(JournalEntry entry, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateStr = DateFormat('MMMM d').format(entry.entryDate).toUpperCase();
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final (tagLabel, tagColor) = _tagInfo(entry);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot
          _buildTimelineDot(colors),
          const SizedBox(width: 16),
          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/memory', extra: entry),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date + tag row
                          Row(
                            children: [
                              Text(
                                dateStr,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              if (tagLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tagColor.withAlpha(24),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tagLabel,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: tagColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Excerpt
                          Text(
                            excerpt,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: colors.textSecondary,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Photo or footer
                    if (photoMedia.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: _buildCardPhoto(photoMedia.first.storagePath, colors),
                      )
                    else
                      _buildCardFooter(entry, colors),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDot(AppPalette colors) {
    return SizedBox(
      width: 16,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
              border: Border.all(color: colors.accent.withAlpha(40), width: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPhoto(String storagePath, AppPalette colors) {
    final mediaService = ref.read(mediaServiceProvider);
    final url = mediaService.getPublicUrl(storagePath);
    return Image.network(
      url,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 100,
        color: colors.accentFaint,
        child: Icon(Icons.image_outlined, size: 36, color: colors.textMuted),
      ),
    );
  }

  Widget _buildCardFooter(JournalEntry entry, AppPalette colors) {
    final moodLabel = _moodLabel(entry.mood);
    final moodEmoji = _moodEmoji(entry.mood);
    final moodColor = _moodColor(entry.mood, colors);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          if (entry.locationName != null) ...[
            Icon(Icons.location_on_outlined, size: 13, color: colors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                entry.locationName!,
                style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
          if (moodLabel != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(moodEmoji ?? '', style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  moodLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: moodColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty / Error / Loading
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(AppPalette colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.accentFaint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_stories_outlined, size: 40, color: colors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              'Your story starts here',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Every entry becomes a part of your timeline.\nStart capturing your moments.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.push('/record'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Record First Memory',
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
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(AppPalette colors) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 80, height: 10, borderRadius: 5),
                    const SizedBox(height: 10),
                    SkeletonBox(width: 200, height: 14, borderRadius: 7),
                    const SizedBox(height: 8),
                    SkeletonBox(width: 160, height: 11, borderRadius: 5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Could not load timeline',
            style: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => ref.invalidate(timelineEntriesProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _extractTitle(JournalEntry entry) {
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return entry.content.length > 50 ? '${entry.content.substring(0, 50)}...' : entry.content;
  }

  String _extractExcerpt(JournalEntry entry) {
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final first = lines.first.trim();
    final isTitle = first.length < 80 && lines.length > 1;
    final body = isTitle ? lines.skip(1).join(' ') : entry.content;
    return body.length > 100 ? '${body.substring(0, 100)}...' : body;
  }

  (String?, Color) _tagInfo(JournalEntry entry) {
    final text = entry.content.toLowerCase();
    if (text.contains('travel') || text.contains('trip') || text.contains('vacation') || text.contains('flight')) {
      return ('Travel', const Color(0xFFF59E0B));
    }
    if (text.contains('work') || text.contains('job') || text.contains('career') || text.contains('promotion') || text.contains('office')) {
      return ('Career', const Color(0xFF195DE6));
    }
    if (text.contains('family') || text.contains('mom') || text.contains('dad') || text.contains('daughter') || text.contains('son') || text.contains('child')) {
      return ('Family', const Color(0xFFEC4899));
    }
    if (text.contains('friend') || text.contains('reunion')) {
      return ('Friends', const Color(0xFF8B5CF6));
    }
    switch (entry.mood) {
      case 'great': return ('Joy', const Color(0xFF10B981));
      case 'good': return ('Life', const Color(0xFF3B82F6));
      case 'low': return ('Personal', const Color(0xFF94A3B8));
      case 'tough': return ('Growth', const Color(0xFFF97316));
      default: return (null, Colors.transparent);
    }
  }

  String? _moodLabel(String? mood) {
    switch (mood) {
      case 'great': return 'Ecstatic';
      case 'good': return 'Grateful';
      case 'okay': return 'Calm';
      case 'low': return 'Reflective';
      case 'tough': return 'Proud';
      default: return null;
    }
  }

  String? _moodEmoji(String? mood) {
    switch (mood) {
      case 'great': return '😊';
      case 'good': return '🙂';
      case 'okay': return '😌';
      case 'low': return '😔';
      case 'tough': return '💙';
      default: return null;
    }
  }

  Color _moodColor(String? mood, AppPalette colors) {
    switch (mood) {
      case 'great': return const Color(0xFF10B981);
      case 'good': return const Color(0xFF3B82F6);
      case 'okay': return const Color(0xFF94A3B8);
      case 'low': return const Color(0xFF6366F1);
      case 'tough': return const Color(0xFFEC4899);
      default: return colors.textMuted;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline item model
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineItem {
  final bool isYearHeader;
  final int? year;
  final int? count;
  final JournalEntry? entry;

  const _TimelineItem._({
    required this.isYearHeader,
    this.year,
    this.count,
    this.entry,
  });

  factory _TimelineItem.year(int year, int count) =>
      _TimelineItem._(isYearHeader: true, year: year, count: count);

  factory _TimelineItem.entry(JournalEntry entry) =>
      _TimelineItem._(isYearHeader: false, entry: entry);
}
