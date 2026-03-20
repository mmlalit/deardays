import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Section type enum
// ─────────────────────────────────────────────────────────────────────────────

enum SeeAllSection { happiest, family, travel, mood }

// ─────────────────────────────────────────────────────────────────────────────
// See All Timeline Screen
// ─────────────────────────────────────────────────────────────────────────────

class SeeAllTimelineScreen extends ConsumerStatefulWidget {
  final SeeAllSection section;
  /// Pre-selects a mood filter tab (e.g. 'Great', 'Good') on open.
  final String? initialMoodFilter;

  const SeeAllTimelineScreen({super.key, required this.section, this.initialMoodFilter});

  @override
  ConsumerState<SeeAllTimelineScreen> createState() => _SeeAllTimelineScreenState();
}

class _SeeAllTimelineScreenState extends ConsumerState<SeeAllTimelineScreen> {
  late String _activeFilter;

  @override
  void initState() {
    super.initState();
    // Capitalise to match filter chip labels: 'great' → 'Great'
    final mood = widget.initialMoodFilter;
    _activeFilter = mood != null
        ? '${mood[0].toUpperCase()}${mood.substring(1)}'
        : 'All';
  }

  List<String> get _filters {
    switch (widget.section) {
      case SeeAllSection.happiest:
        return ['All', 'Great', 'Good'];
      case SeeAllSection.family:
        return ['All', 'Milestones', 'Travel', 'Holidays'];
      case SeeAllSection.travel:
        return ['All', 'Trips', 'Adventures', 'Walks'];
      case SeeAllSection.mood:
        return ['All', 'Great', 'Good', 'Okay', 'Low', 'Tough'];
    }
  }

  String get _title {
    switch (widget.section) {
      case SeeAllSection.happiest:
        return 'Happiest Memories';
      case SeeAllSection.family:
        return 'Family Journey';
      case SeeAllSection.travel:
        return 'Travel Adventures';
      case SeeAllSection.mood:
        final m = widget.initialMoodFilter ?? '';
        final label = m.isEmpty ? '' : '${m[0].toUpperCase()}${m.substring(1)}';
        return '$label Memories';
    }
  }

  String get _subtitle {
    switch (widget.section) {
      case SeeAllSection.happiest:
        return 'Reliving your peak moments';
      case SeeAllSection.family:
        return 'Our shared history';
      case SeeAllSection.travel:
        return 'Exploring the world';
      case SeeAllSection.mood:
        return 'All memories with this mood';
    }
  }

  Color get _accentColor {
    switch (widget.section) {
      case SeeAllSection.happiest:
        return const Color(0xFF10B981);
      case SeeAllSection.family:
        return const Color(0xFFEC4899);
      case SeeAllSection.travel:
        return const Color(0xFFF59E0B);
      case SeeAllSection.mood:
        switch (widget.initialMoodFilter) {
          case 'great': return const Color(0xFF10B981);
          case 'good':  return const Color(0xFF34D399);
          case 'okay':  return const Color(0xFFF59E0B);
          case 'low':   return const Color(0xFFF97316);
          case 'tough': return const Color(0xFFEF4444);
          default:      return const Color(0xFF6366F1);
        }
    }
  }

  IconData get _dotIcon {
    switch (widget.section) {
      case SeeAllSection.happiest:
        return Icons.favorite_rounded;
      case SeeAllSection.family:
        return Icons.family_restroom_rounded;
      case SeeAllSection.travel:
        return Icons.location_on_rounded;
      case SeeAllSection.mood:
        return Icons.mood_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _buildHeader(colors),
          _buildFilterChips(colors),
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                final filtered = _filterEntries(entries);
                if (filtered.isEmpty) return _buildEmpty(colors);
                return _buildTimeline(filtered, colors);
              },
              loading: () => _buildSkeleton(colors),
              error: (_, __) => Center(
                child: Text('Could not load', style: GoogleFonts.manrope(color: colors.textMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bg.withAlpha(200),
        border: Border(bottom: BorderSide(color: colors.accent.withAlpha(25))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.pop();
                },
                icon: Icon(Icons.arrow_back_rounded, color: colors.accent),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: GoogleFonts.newsreader(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      _subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Stats for travel section
              if (widget.section == SeeAllSection.travel)
                GestureDetector(
                  onTap: () => HapticFeedback.selectionClick(),
                  child: Icon(Icons.share_outlined, size: 22, color: colors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter chips (horizontal scroll)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFilterChips(AppPalette colors) {
    return Container(
      color: colors.bg,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Row(
          children: _filters.map((filter) {
            final isActive = _activeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeFilter = filter);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? colors.accent : colors.highlightFaint,
                    borderRadius: BorderRadius.circular(20),
                    border: isActive ? null : Border.all(color: colors.border),
                  ),
                  child: Text(
                    filter,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? Colors.white : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats row (travel only)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(List<JournalEntry> entries, AppPalette colors) {
    final locationCount = entries
        .where((e) => e.locationName != null && e.locationName!.isNotEmpty)
        .map((e) => e.locationName)
        .toSet()
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.route_rounded,
              label: 'MEMORIES',
              value: '${entries.length}',
              colors: colors,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.public_rounded,
              label: 'PLACES',
              value: '$locationCount',
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required AppPalette colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.accent, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Timeline list
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTimeline(List<JournalEntry> entries, AppPalette colors) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: (widget.section == SeeAllSection.travel ? 1 : 0) + entries.length,
      itemBuilder: (context, index) {
        // Stats row for travel
        if (widget.section == SeeAllSection.travel && index == 0) {
          return _buildStatsRow(entries, colors);
        }
        final entryIndex = widget.section == SeeAllSection.travel ? index - 1 : index;
        final entry = entries[entryIndex];
        final isLast = entryIndex == entries.length - 1;
        return _buildTimelineCard(entry, isLast, colors);
      },
    );
  }

  Widget _buildTimelineCard(JournalEntry entry, bool isLast, AppPalette colors) {
    final dateStr = DateFormat('MMMM d, yyyy').format(entry.entryDate);
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 150
        ? '${entry.content.substring(0, 150)}...'
        : entry.content;
    final hasPhoto = entry.media.where((m) => m.mediaType == 'photo').isNotEmpty;
    final yearLabel = '${entry.entryDate.year}';
    final moodBadge = _moodBadgeText(entry);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline rail
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Dot
                  Container(
                    width: widget.section == SeeAllSection.travel ? 40 : 20,
                    height: widget.section == SeeAllSection.travel ? 40 : 20,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.bg, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withAlpha(30),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: widget.section == SeeAllSection.travel
                        ? Icon(_dotIcon, size: 16, color: Colors.white)
                        : null,
                  ),
                  // Vertical line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: _accentColor.withAlpha(40),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/memory', extra: entry);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year + type label
                      Text(
                        '$yearLabel${moodBadge.isNotEmpty ? ' · $moodBadge' : ''}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: _accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Card body
                      Container(
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border.withAlpha(120)),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textPrimary.withAlpha(8),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Photo
                            if (hasPhoto)
                              SizedBox(
                                height: widget.section == SeeAllSection.happiest ? 128 : 192,
                                child: _buildEntryPhoto(entry, colors),
                              ),
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: GoogleFonts.newsreader(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (moodBadge.isNotEmpty && widget.section == SeeAllSection.happiest)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _accentColor.withAlpha(25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            moodBadge.toUpperCase(),
                                            style: GoogleFonts.manrope(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                              color: _accentColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Date
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Excerpt
                                  Text(
                                    excerpt,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                      height: 1.6,
                                    ),
                                  ),
                                  // Tags
                                  const SizedBox(height: 12),
                                  _buildTags(entry, colors),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tags row
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTags(JournalEntry entry, AppPalette colors) {
    final tags = <String>[];

    // Add section-specific tag
    switch (widget.section) {
      case SeeAllSection.happiest:
        tags.add('#${_moodLabel(entry.mood)}');
        break;
      case SeeAllSection.family:
        tags.add('#Family');
        break;
      case SeeAllSection.travel:
        tags.add('#Travel');
        break;
      case SeeAllSection.mood:
        tags.add('#${_moodLabel(entry.mood)}');
        break;
    }

    // Add location tag for travel
    if (entry.locationName != null && entry.locationName!.isNotEmpty) {
      tags.add('#${entry.locationName!.split(',').first.trim()}');
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((tag) {
        final isPrimary = tag.startsWith('#Family') || tag.startsWith('#Travel') || tag.startsWith('#Great') || tag.startsWith('#Good');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPrimary ? _accentColor.withAlpha(20) : colors.highlightFaint,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tag,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              color: isPrimary ? _accentColor : colors.textMuted,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter logic
  // ─────────────────────────────────────────────────────────────────────────

  static const _familyKeywords = [
    'family', 'mom', 'dad', 'mother', 'father', 'daughter', 'son',
    'brother', 'sister', 'parent', 'child', 'baby', 'husband', 'wife',
  ];

  static const _travelKeywords = [
    'travel', 'trip', 'vacation', 'flight', 'hotel', 'beach', 'mountain',
    'journey', 'explore', 'visited', 'airport', 'road trip', 'hike',
  ];

  List<JournalEntry> _filterEntries(List<JournalEntry> entries) {
    List<JournalEntry> base;

    switch (widget.section) {
      case SeeAllSection.happiest:
        base = entries.where((e) => e.mood == 'great' || e.mood == 'good').toList();
        break;
      case SeeAllSection.family:
        base = entries.where((e) {
          final text = e.content.toLowerCase();
          return _familyKeywords.any((kw) => text.contains(kw));
        }).toList();
        break;
      case SeeAllSection.travel:
        base = entries.where((e) {
          final text = e.content.toLowerCase();
          return _travelKeywords.any((kw) => text.contains(kw));
        }).toList();
        break;
      case SeeAllSection.mood:
        base = entries.toList(); // filter applied below via _activeFilter
        break;
    }

    // Apply sub-filter
    if (_activeFilter == 'All') return base;

    switch (widget.section) {
      case SeeAllSection.happiest:
        if (_activeFilter == 'Great') return base.where((e) => e.mood == 'great').toList();
        if (_activeFilter == 'Good') return base.where((e) => e.mood == 'good').toList();
        break;
      case SeeAllSection.mood:
        // Filter by mood label
        return base.where((e) => e.mood?.toLowerCase() == _activeFilter.toLowerCase()).toList();
      case SeeAllSection.family:
        if (_activeFilter == 'Milestones') return base.where((e) => e.isMilestone).toList();
        if (_activeFilter == 'Travel') {
          return base.where((e) {
            final text = e.content.toLowerCase();
            return _travelKeywords.any((kw) => text.contains(kw));
          }).toList();
        }
        if (_activeFilter == 'Holidays') {
          return base.where((e) {
            final text = e.content.toLowerCase();
            return ['holiday', 'christmas', 'thanksgiving', 'birthday', 'celebration', 'festival', 'diwali', 'easter']
                .any((kw) => text.contains(kw));
          }).toList();
        }
        break;
      case SeeAllSection.travel:
        if (_activeFilter == 'Trips') {
          return base.where((e) {
            final text = e.content.toLowerCase();
            return ['trip', 'vacation', 'flight', 'hotel'].any((kw) => text.contains(kw));
          }).toList();
        }
        if (_activeFilter == 'Adventures') {
          return base.where((e) {
            final text = e.content.toLowerCase();
            return ['adventure', 'hike', 'mountain', 'explore', 'trek'].any((kw) => text.contains(kw));
          }).toList();
        }
        if (_activeFilter == 'Walks') {
          return base.where((e) {
            final text = e.content.toLowerCase();
            return ['walk', 'stroll', 'park', 'garden', 'trail'].any((kw) => text.contains(kw));
          }).toList();
        }
        break;
    }
    return base;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEntryPhoto(JournalEntry entry, AppPalette colors) {
    final photo = entry.media.where((m) => m.mediaType == 'photo').firstOrNull;
    if (photo == null) return const SizedBox.shrink();

    if (photo.storagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: photo.storagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        memCacheWidth: 400,
        errorWidget: (_, __, ___) => Container(color: colors.highlightFaint),
      );
    }

    return FutureBuilder<String>(
      future: ref.read(mediaServiceProvider).getSignedUrl(photo.storagePath).catchError((_) => ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return Container(color: colors.highlightFaint);
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          memCacheWidth: 400,
          errorWidget: (_, __, ___) => Container(color: colors.highlightFaint),
        );
      },
    );
  }

  String _entryTitle(JournalEntry entry) {
    final text = entry.content;
    final firstSentence = RegExp(r'^[^.!?\n]+[.!?]?').firstMatch(text)?.group(0);
    if (firstSentence != null && firstSentence.length <= 60) return firstSentence;
    if (text.length <= 40) return text;
    return '${text.substring(0, 40)}...';
  }

  String _moodBadgeText(JournalEntry entry) {
    switch (entry.mood) {
      case 'great':
        return 'High Joy';
      case 'good':
        return 'Good';
      default:
        return '';
    }
  }

  String _moodLabel(String? mood) {
    switch (mood) {
      case 'great':
        return 'Great';
      case 'good':
        return 'Good';
      case 'okay':
        return 'Okay';
      case 'low':
        return 'Low';
      case 'tough':
        return 'Tough';
      default:
        return 'Memory';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty + Skeleton
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmpty(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timeline_rounded, size: 48, color: colors.textMuted.withAlpha(80)),
          const SizedBox(height: 12),
          Text(
            'No memories in this category yet',
            style: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(AppPalette colors) {
    Widget shimmer({double width = double.infinity, double height = 16, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.highlightFaint,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        for (int i = 0; i < 3; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shimmer(width: 20, height: 20, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shimmer(width: 100, height: 12),
                    const SizedBox(height: 8),
                    shimmer(height: 200, radius: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
