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
// Category definitions
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
  String? _selectedCategoryId;
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasFilter => _selectedCategoryId != null || _searchQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _buildHeader(colors),
          _buildSearchBar(colors),
          Expanded(child: _buildBody(colors)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header — "Aura" branding row
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppPalette colors) {
    return Container(
      color: colors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Row(
            children: [
              // Aura icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bubble_chart_rounded, color: colors.accent, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Aura',
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              // Notifications bell
              GestureDetector(
                onTap: () => HapticFeedback.selectionClick(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.notifications_outlined, size: 20, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              // Avatar circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.accent, colors.accentLight],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Search bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSearchBar(AppPalette colors) {
    return Container(
      color: colors.bg,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colors.highlightFaint,
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody(AppPalette colors) {
    final entriesAsync = ref.watch(timelineEntriesProvider);
    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty && !_hasFilter) return _buildSampleExplore(colors);
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
  // Overview (no filter active)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverview(List<JournalEntry> entries, AppPalette colors) {
    final happiest = entries.where((e) => e.mood == 'great' || e.mood == 'good').take(8).toList();
    final familyEntries = entries.where((e) => _detectCategory(e) == 'family').take(3).toList();
    final travelEntries = entries.where((e) => _detectCategory(e) == 'travel').take(4).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // AI Insights
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: _buildAiInsightsCard(entries, colors),
        ),

        // Happiest Memories
        if (happiest.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildSectionHeader('Happiest Memories', colors),
          ),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: happiest.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(happiest[i], colors),
            ),
          ),
          const SizedBox(height: 28),
        ],

        // Family Moments
        if (familyEntries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildSectionHeader('Family Moments', colors),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildFamilyGrid(familyEntries, colors),
          ),
          const SizedBox(height: 28),
        ],

        // Travel Stories
        if (travelEntries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildSectionHeader('Travel Stories', colors),
          ),
          ...travelEntries.map((e) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildTravelRow(e, colors),
          )),
          const SizedBox(height: 8),
        ],

        // Fallback: category grid when no curated sections
        if (happiest.isEmpty && familyEntries.isEmpty && travelEntries.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildSectionHeader('Explore by Theme', colors),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildCategoryGrid(entries, colors),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sample explore (first-time user)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSampleExplore(AppPalette colors) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // CTA banner
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: GestureDetector(
            onTap: () => context.push('/record'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.accent.withAlpha(30)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.explore, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Explore your memories', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('Start journaling to unlock AI insights and themes.', style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),

        // Example label
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: colors.accent.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                child: Text('EXAMPLES', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: colors.accent, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Text('Discover patterns in your journal', style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted)),
            ],
          ),
        ),

        // Sample AI Insights card
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Opacity(
            opacity: 0.8,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.accentFaint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.accent.withAlpha(25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology, size: 20, color: colors.accent),
                          const SizedBox(width: 8),
                          Text('AI Insights', style: GoogleFonts.newsreader(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your week has been centered around family and personal growth. You mentioned gratitude 4 times — a pattern that correlates with your happiest days.',
                        style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: colors.textPrimary.withAlpha(120), borderRadius: BorderRadius.circular(4)),
                    child: Text('EXAMPLE', style: GoogleFonts.manrope(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sample "Happiest Memories" section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Happiest Memories', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _buildSampleHappyCard(i, colors),
          ),
        ),
        const SizedBox(height: 28),

        // Sample category grid
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Explore by Theme', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSampleCategoryGrid(colors),
        ),
      ],
    );
  }

  Widget _buildSampleHappyCard(int index, AppPalette colors) {
    const samples = [
      ('Sunday dinner at Mom\'s', 'Family', Color(0xFFFF8A65), Color(0xFFFF5722), Icons.family_restroom),
      ('Beach day with friends', 'Travel', Color(0xFF4DD0E1), Color(0xFF00897B), Icons.flight_takeoff),
      ('Promotion at work!', 'Career', Color(0xFF7986CB), Color(0xFF3949AB), Icons.work_outline),
    ];
    final (title, tag, c1, c2, icon) = samples[index];

    return Opacity(
      opacity: 0.8,
      child: Stack(
        children: [
          Container(
            width: 160,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
              boxShadow: [BoxShadow(color: colors.textPrimary.withAlpha(10), blurRadius: 12, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2])),
                  child: Center(child: Icon(icon, size: 36, color: Colors.white.withAlpha(160))),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: colors.accent.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                        child: Text(tag, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: colors.accent)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black.withAlpha(100), borderRadius: BorderRadius.circular(4)),
              child: Text('EXAMPLE', style: GoogleFonts.manrope(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCategoryGrid(AppPalette colors) {
    const sampleCategories = [
      ('Family', Icons.family_restroom, Color(0xFFEC4899), 12),
      ('Travel', Icons.flight_takeoff, Color(0xFFF59E0B), 8),
      ('Career', Icons.work_outline, Color(0xFF195DE6), 15),
      ('Wellness', Icons.spa, Color(0xFF10B981), 6),
      ('Friends', Icons.people_outline, Color(0xFF8B5CF6), 9),
      ('Creative', Icons.palette, Color(0xFFE91E63), 4),
    ];

    return Opacity(
      opacity: 0.8,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
        ),
        itemCount: sampleCategories.length,
        itemBuilder: (_, i) {
          final (label, icon, color, count) = sampleCategories[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                      Text('$count memories', style: GoogleFonts.manrope(fontSize: 11, color: colors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section header row (title + "See all" link)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, AppPalette colors, {VoidCallback? onSeeAll}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See all',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI Insights card — white card, mood label, gradient square
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAiInsightsCard(List<JournalEntry> entries, AppPalette colors) {
    // Determine dominant mood
    final moodCounts = <String, int>{};
    for (final e in entries) {
      if (e.mood != null && e.mood!.isNotEmpty) {
        moodCounts[e.mood!] = (moodCounts[e.mood!] ?? 0) + 1;
      }
    }
    String topMood = 'okay';
    int topCount = 0;
    moodCounts.forEach((k, v) {
      if (v > topCount) { topCount = v; topMood = k; }
    });

    // Fallback mood descriptions
    final fallbackMoodData = {
      'great': ('Joyful', 'Your recent entries radiate happiness and positive energy. You\'re in a great place!'),
      'good':  ('Content', 'Things are going well. Your entries reflect a steady, positive mindset.'),
      'okay':  ('Reflective', 'Your recent entries show a thoughtful and introspective mood.'),
      'low':   ('Introspective', 'You\'ve been reflecting deeply. Remember, every feeling is valid and worth recording.'),
      'tough': ('Resilient', 'You\'re working through challenges. Your courage in recording these moments is admirable.'),
    };
    final (fallbackLabel, fallbackDesc) = fallbackMoodData[topMood] ?? ('Reflective', 'Your recent entries show a thoughtful and introspective mood.');

    // Use AI-generated weekly summary when available
    final aiSummary = ref.watch(weeklySummaryProvider).valueOrNull;
    final moodLabel = fallbackLabel;
    final moodDesc = aiSummary ?? fallbackDesc;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "AI INSIGHTS" badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 12, color: colors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'AI INSIGHTS',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$moodLabel Mood',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  moodDesc,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Gradient square
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accent, colors.accentLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withAlpha(60),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Happiest Memories — horizontal scroll card (220px tall)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHappyCard(JournalEntry entry, AppPalette colors) {
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final dateStr = DateFormat('MMM d, yyyy').format(entry.entryDate);
    final title = _extractTitle(entry);
    final mediaService = ref.read(mediaServiceProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colors.accent,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: photo or gradient
            if (photoMedia.isNotEmpty)
              Image.network(
                mediaService.getPublicUrl(photoMedia.first.storagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.accent, colors.accentLight],
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.accent,
                      colors.accentLight,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 48,
                  color: Colors.white.withAlpha(60),
                ),
              ),

            // Dark gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Bottom-left: date + title
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Family Moments — 1 large featured + 2 small cards
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFamilyGrid(List<JournalEntry> entries, AppPalette colors) {
    return Column(
      children: [
        // Featured large card
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/memory', extra: entries[0]);
          },
          child: _buildPhotoCard(
            entry: entries[0],
            height: 160,
            colors: colors,
            showFeaturedBadge: true,
          ),
        ),
        if (entries.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/memory', extra: entries[1]);
                  },
                  child: _buildPhotoCard(
                    entry: entries[1],
                    height: 110,
                    colors: colors,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/memory', extra: entries.length > 2 ? entries[2] : entries[1]);
                  },
                  child: _buildPhotoCard(
                    entry: entries.length > 2 ? entries[2] : entries[1],
                    height: 110,
                    colors: colors,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoCard({
    required JournalEntry entry,
    required double height,
    required AppPalette colors,
    bool showFeaturedBadge = false,
  }) {
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final title = _extractTitle(entry);
    final mediaService = ref.read(mediaServiceProvider);
    final cat = _detectCategory(entry);
    final catDef = cat != null ? _categories.where((c) => c.id == cat).firstOrNull : null;
    final cardColor = catDef?.color ?? colors.accent;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          if (photoMedia.isNotEmpty)
            Image.network(
              mediaService.getPublicUrl(photoMedia.first.storagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildCardGradient(cardColor),
            )
          else
            _buildCardGradient(cardColor),

          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xB3000000), Colors.transparent],
              ),
            ),
          ),

          // Title at bottom
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Featured badge
          if (showFeaturedBadge)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Featured',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cardColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardGradient(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withAlpha(180)],
        ),
      ),
      child: Icon(
        Icons.auto_stories_rounded,
        size: 36,
        color: Colors.white.withAlpha(50),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Travel Stories — list row with 80x80 thumbnail
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTravelRow(JournalEntry entry, AppPalette colors) {
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final location = entry.locationName;
    final photoCount = photoMedia.length;
    final mediaService = ref.read(mediaServiceProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photoMedia.isNotEmpty
                  ? Image.network(
                      mediaService.getPublicUrl(photoMedia.first.storagePath),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildTravelPlaceholder(colors),
                    )
                  : _buildTravelPlaceholder(colors),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta row: location + photo count
                  Row(
                    children: [
                      if (location != null && location.isNotEmpty) ...[
                        Icon(Icons.place_outlined, size: 12, color: colors.textMuted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            location,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: colors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (photoCount > 0) ...[
                        Icon(Icons.photo_outlined, size: 12, color: colors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          '$photoCount photo${photoCount != 1 ? 's' : ''}',
                          style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.3,
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
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelPlaceholder(AppPalette colors) {
    return Container(
      width: 80,
      height: 80,
      color: const Color(0xFFF59E0B).withAlpha(25),
      child: const Icon(Icons.flight_rounded, size: 28, color: Color(0xFFF59E0B)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Category grid (fallback)
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
            setState(() => _selectedCategoryId = cat.id);
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
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: cat.color),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    Text('$count ${count == 1 ? 'memory' : 'memories'}', style: GoogleFonts.manrope(fontSize: 11, color: colors.textSecondary)),
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
    String filterLabel;
    List<JournalEntry> filtered;

    if (_searchQuery.isNotEmpty) {
      filterLabel = 'Search: "$_searchQuery"';
      filtered = all.where((e) =>
        e.content.toLowerCase().contains(_searchQuery) ||
        (e.locationName?.toLowerCase().contains(_searchQuery) ?? false),
      ).toList();
    } else {
      final cat = _categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
      filterLabel = cat != null ? '${cat.emoji} ${cat.label} Memories' : 'Filtered';
      filtered = all.where((e) => _detectCategory(e) == _selectedCategoryId).toList();
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
                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
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
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
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
                  itemBuilder: (_, i) => _buildMemoryRow(filtered[i], colors),
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
              decoration: BoxDecoration(color: colors.accentFaint, shape: BoxShape.circle),
              child: Icon(Icons.search_off_rounded, size: 32, color: colors.accent),
            ),
            const SizedBox(height: 16),
            Text('No memories found', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 8),
            Text('Try a different search or filter.', style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Compact memory row (filtered results)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMemoryRow(JournalEntry entry, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateStr = DateFormat('MMM d, yyyy').format(entry.entryDate);
    final (tagLabel, tagColor) = _tagInfo(entry);
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final mediaService = ref.read(mediaServiceProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/memory', extra: entry);
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(color: colors.textPrimary.withAlpha(8), blurRadius: 10, offset: const Offset(0, 3)),
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
                    ? Image.network(
                        mediaService.getPublicUrl(photoMedia.first.storagePath),
                        width: 80,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 90,
                          color: colors.accentFaint,
                          child: Icon(Icons.image_outlined, size: 24, color: colors.textMuted),
                        ),
                      )
                    : Container(
                        width: 6,
                        height: 90,
                        color: tagColor == Colors.transparent ? colors.accent : tagColor,
                      ),
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
                              style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w500),
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
                                style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: tagColor),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        excerpt,
                        style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary, height: 1.4),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Skeleton loading
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSkeleton(AppPalette colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        // AI Insights skeleton
        Container(height: 110, decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 28),
        // Horizontal scroll skeleton
        SizedBox(
          height: 220,
          child: Row(
            children: List.generate(4, (_) => Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
            )),
          ),
        ),
        const SizedBox(height: 28),
        // Grid skeleton
        Column(
          children: [
            Container(height: 160, decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Container(height: 110, decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)))),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 110, decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)))),
            ]),
          ],
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
