import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category definition
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final List<String> keywords;

  const _Category({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    required this.keywords,
  });
}

const _categories = [
  _Category(
    id: 'family',
    label: 'Family',
    emoji: '👨‍👩‍👧',
    color: Color(0xFFEC4899),
    keywords: ['family', 'mom', 'dad', 'mother', 'father', 'daughter', 'son', 'brother', 'sister', 'parent', 'child', 'baby'],
  ),
  _Category(
    id: 'travel',
    label: 'Travel',
    emoji: '✈️',
    color: Color(0xFFF59E0B),
    keywords: ['travel', 'trip', 'vacation', 'flight', 'hotel', 'beach', 'mountain', 'journey', 'explore', 'visited', 'airport'],
  ),
  _Category(
    id: 'career',
    label: 'Career',
    emoji: '💼',
    color: Color(0xFF195DE6),
    keywords: ['work', 'job', 'career', 'promotion', 'office', 'meeting', 'project', 'client', 'boss', 'colleague', 'salary', 'startup'],
  ),
  _Category(
    id: 'friends',
    label: 'Friends',
    emoji: '🤝',
    color: Color(0xFF8B5CF6),
    keywords: ['friend', 'friends', 'reunion', 'hangout', 'college', 'school', 'party', 'met', 'gathering'],
  ),
  _Category(
    id: 'growth',
    label: 'Growth',
    emoji: '💡',
    color: Color(0xFF10B981),
    keywords: ['lesson', 'learned', 'growth', 'reflection', 'realized', 'grateful', 'mindful', 'overcome', 'challenge', 'goal'],
  ),
  _Category(
    id: 'health',
    label: 'Health',
    emoji: '🏃',
    color: Color(0xFF06B6D4),
    keywords: ['health', 'workout', 'gym', 'run', 'yoga', 'meditation', 'doctor', 'sleep', 'diet', 'exercise', 'fitness'],
  ),
];

const _emotionFilters = [
  (null, 'All', '✨'),
  ('great', 'Joy', '😊'),
  ('good', 'Happy', '🙂'),
  ('okay', 'Calm', '😌'),
  ('low', 'Sad', '😔'),
  ('tough', 'Tough', '💙'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Explore Screen
// ─────────────────────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedMood;
  String? _selectedCategoryId;
  bool _isSearchFocused = false;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _isSearchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasFilter => _selectedMood != null || _selectedCategoryId != null || _searchQuery.isNotEmpty;

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
          children: [
            // Title row
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
                    child: Icon(Icons.explore_rounded, size: 22, color: colors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore',
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
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
                  focusNode: _searchFocus,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: GoogleFonts.manrope(fontSize: 14, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search memories...',
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
                    prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
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
        if (_hasFilter) return _buildFilteredView(entries, colors);
        return _buildOverview(entries, colors);
      },
      loading: () => _buildSkeleton(colors),
      error: (_, __) => Center(
        child: Text('Could not load', style: GoogleFonts.manrope(color: colors.textMuted)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Overview (no filter)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverview(List<JournalEntry> entries, AppPalette colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        // AI Insights
        _buildAiInsightsCard(entries, colors),
        const SizedBox(height: 28),

        // Emotions section
        _buildSectionTitle('Explore by Emotion', Icons.favorite_rounded, colors),
        const SizedBox(height: 12),
        _buildEmotionRow(entries, colors),
        const SizedBox(height: 28),

        // Themes section
        _buildSectionTitle('Explore by Theme', Icons.category_outlined, colors),
        const SizedBox(height: 12),
        _buildCategoryGrid(entries, colors),
        const SizedBox(height: 28),

        // Recent highlights
        if (entries.isNotEmpty) ...[
          _buildSectionTitle('Recent Highlights', Icons.star_rounded, colors),
          const SizedBox(height: 12),
          ...entries.take(3).map((e) => _buildMemoryCard(e, colors)),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI Insights Card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAiInsightsCard(List<JournalEntry> entries, AppPalette colors) {
    final happiest = entries.where((e) => e.mood == 'great').toList();
    final happiestEntry = happiest.isNotEmpty ? happiest.first : null;
    final happiestTitle = happiestEntry != null ? _extractTitle(happiestEntry) : null;

    // Find most frequent category
    final categoryCounts = <String, int>{};
    for (final entry in entries) {
      final cat = _detectCategory(entry);
      if (cat != null) categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }
    String? topCategory;
    int topCount = 0;
    categoryCounts.forEach((k, v) {
      if (v > topCount) { topCount = v; topCategory = k; }
    });
    final topCategoryDef = topCategory != null
        ? _categories.where((c) => c.id == topCategory).firstOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, colors.accentLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'AI INSIGHTS',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Insight 1: Happiest moment
              if (happiestTitle != null) ...[
                Text(
                  '😊 Happiest Moment',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  happiestTitle,
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
              ],

              // Insight 2: Top theme
              if (topCategoryDef != null) ...[
                Text(
                  '${topCategoryDef.emoji} Most Recorded Theme',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${topCategoryDef.label} — $topCount ${topCount == 1 ? 'memory' : 'memories'}',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Total memories
              Text(
                '📖 ${entries.length} memories recorded',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: Colors.white.withAlpha(220),
                ),
              ),
            ],
          ),
          // Watermark
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.insights_rounded,
              size: 80,
              color: Colors.white.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section title
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon, AppPalette colors) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Emotion row
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmotionRow(List<JournalEntry> entries, AppPalette colors) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _emotionFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (mood, label, emoji) = _emotionFilters[i];
          final count = mood == null
              ? entries.length
              : entries.where((e) => e.mood == mood).length;
          final isActive = _selectedMood == mood && mood != null;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedMood = mood;
                _selectedCategoryId = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 70,
              decoration: BoxDecoration(
                color: isActive ? colors.accent : colors.accentFaint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? colors.accent : colors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : colors.textSecondary,
                    ),
                  ),
                  Text(
                    '$count',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: isActive ? Colors.white.withAlpha(200) : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Category grid
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCategoryGrid(List<JournalEntry> entries, AppPalette colors) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final cat = _detectCategory(entry);
      if (cat != null) counts[cat] = (counts[cat] ?? 0) + 1;
    }

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _categories.map((cat) {
        final count = counts[cat.id] ?? 0;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedCategoryId = cat.id;
              _selectedMood = null;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cat.color.withAlpha(14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cat.color.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cat.color.withAlpha(24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cat.color,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.label,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'memory' : 'memories'}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filtered view
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFilteredView(List<JournalEntry> all, AppPalette colors) {
    // Determine active filter label
    String filterLabel;
    List<JournalEntry> filtered;

    if (_searchQuery.isNotEmpty) {
      filterLabel = 'Search: "$_searchQuery"';
      filtered = all.where((e) =>
        e.content.toLowerCase().contains(_searchQuery) ||
        (e.locationName?.toLowerCase().contains(_searchQuery) ?? false),
      ).toList();
    } else if (_selectedCategoryId != null) {
      final cat = _categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
      filterLabel = cat != null ? '${cat.emoji} ${cat.label} Memories' : 'Filtered';
      filtered = all.where((e) => _detectCategory(e) == _selectedCategoryId).toList();
    } else {
      final (mood, label, emoji) = _emotionFilters.where((f) => f.$1 == _selectedMood).first;
      filterLabel = '$emoji $label Memories';
      filtered = mood == null ? all : all.where((e) => e.mood == mood).toList();
    }

    return Column(
      children: [
        // Filter bar
        Container(
          color: colors.bg,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  filterLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedMood = null;
                    _selectedCategoryId = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.accentFaint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: colors.border, height: 1),

        // Results
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyFilter(filterLabel, colors)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildMemoryCard(filtered[i], colors),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyFilter(String label, AppPalette colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.accentFaint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 32, color: colors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'No memories found',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search or filter.',
              style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Memory card (compact)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMemoryCard(JournalEntry entry, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateStr = DateFormat('MMM d, yyyy').format(entry.entryDate);
    final (tagLabel, tagColor) = _tagInfo(entry);
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('/memory', extra: entry),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Photo thumbnail or color strip
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: photoMedia.isNotEmpty
                    ? _buildThumbnail(photoMedia.first.storagePath, colors)
                    : _buildColorStrip(entry, colors),
              ),

              // Text content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateStr,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: colors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (tagLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tagColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tagLabel,
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: tagColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        excerpt,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right_rounded, size: 20, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String storagePath, AppPalette colors) {
    final mediaService = ref.read(mediaServiceProvider);
    final url = mediaService.getPublicUrl(storagePath);
    return Image.network(
      url,
      width: 80,
      height: 90,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 80,
        height: 90,
        color: colors.accentFaint,
        child: Icon(Icons.image_outlined, size: 24, color: colors.textMuted),
      ),
    );
  }

  Widget _buildColorStrip(JournalEntry entry, AppPalette colors) {
    final (_, tagColor) = _tagInfo(entry);
    return Container(
      width: 6,
      height: 90,
      decoration: BoxDecoration(
        color: tagColor == Colors.transparent ? colors.accent : tagColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Skeleton
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSkeleton(AppPalette colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        // Insights card skeleton
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 28),
        // Category grid skeleton
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(6, (_) => Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
          )),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String? _detectCategory(JournalEntry entry) {
    final text = entry.content.toLowerCase();
    for (final cat in _categories) {
      if (cat.keywords.any((kw) => text.contains(kw))) return cat.id;
    }
    return null;
  }

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
    return body.length > 80 ? '${body.substring(0, 80)}...' : body;
  }

  (String?, Color) _tagInfo(JournalEntry entry) {
    final cat = _detectCategory(entry);
    if (cat != null) {
      final def = _categories.where((c) => c.id == cat).firstOrNull;
      if (def != null) return (def.label, def.color);
    }
    switch (entry.mood) {
      case 'great': return ('Joy', const Color(0xFF10B981));
      case 'good': return ('Life', const Color(0xFF3B82F6));
      case 'low': return ('Personal', const Color(0xFF94A3B8));
      case 'tough': return ('Growth', const Color(0xFFF97316));
      default: return (null, Colors.transparent);
    }
  }
}
