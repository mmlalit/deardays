import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/story/data/models/life_story.dart';
import 'package:deardays/features/story/presentation/providers/story_provider.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const _totalPages = 5;

  @override
  void initState() {
    super.initState();
    // Start generation if not already done
    final state = ref.read(storyProvider);
    if (state.status == StoryStatus.ready || state.status == StoryStatus.error) {
      Future.microtask(() => ref.read(storyProvider.notifier).generateStory());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyState = ref.watch(storyProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: storyState.status == StoryStatus.generating
          ? _buildLoadingState(storyState, colors)
          : storyState.status == StoryStatus.available && storyState.story != null
              ? _buildStoryViewer(storyState.story!, colors)
              : _buildErrorState(storyState, colors),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoadingState(StoryState storyState, AppPalette colors) {
    final percent = (storyState.progress * 100).toInt();
    return SafeArea(
      child: Column(
        children: [
          _buildCloseButton(colors),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [colors.accent, colors.accent.withAlpha(150)],
                        ),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Creating your story...',
                      style: GoogleFonts.newsreader(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analyzing your memories',
                      style: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
                    ),
                    const SizedBox(height: 32),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: storyState.progress,
                        backgroundColor: colors.border,
                        color: colors.accent,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$percent%',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildErrorState(StoryState storyState, AppPalette colors) {
    return SafeArea(
      child: Column(
        children: [
          _buildCloseButton(colors),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: colors.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      storyState.errorMessage ?? 'Something went wrong',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(fontSize: 15, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.read(storyProvider.notifier).generateStory(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Try Again', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Story Viewer ───────────────────────────────────────────────────────────

  Widget _buildStoryViewer(LifeStory story, AppPalette colors) {
    return SafeArea(
      child: Column(
        children: [
          _buildCloseButton(colors),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildTitleCard(story, colors),
                _buildNarrativeCard(story, colors),
                _buildHighlightCard(story, colors),
                _buildInsightsCard(story, colors),
                _buildQuoteCard(story, colors),
              ],
            ),
          ),
          _buildPageDots(colors),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCloseButton(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.cardBg,
            ),
            child: Icon(Icons.close_rounded, size: 20, color: colors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildPageDots(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (i) {
          final isActive = i == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive ? colors.accent : colors.border,
            ),
          );
        }),
      ),
    );
  }

  // ── Card 1: Title ──────────────────────────────────────────────────────────

  Widget _buildTitleCard(LifeStory story, AppPalette colors) {
    final dateRange =
        '${DateFormat('MMM d').format(story.startDate)} – ${DateFormat('MMM d, yyyy').format(story.endDate)}';

    return _cardWrapper(
      colors: colors,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.accent.withAlpha(15), colors.bg],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colors.accent, colors.accent.withAlpha(180)],
              ),
              boxShadow: [
                BoxShadow(color: colors.accent.withAlpha(40), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            'Your Week With',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'DearDays',
            style: GoogleFonts.newsreader(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateRange,
            style: GoogleFonts.manrope(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: 36),
          // Stats row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('${story.totalEntries}', 'memories', colors),
                Container(width: 1, height: 30, color: colors.border),
                _statItem('${story.voiceEntries}', 'voice', colors),
                Container(width: 1, height: 30, color: colors.border),
                _statItem('${story.textEntries}', 'written', colors),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Swipe to explore',
                style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14, color: colors.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, AppPalette colors) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: colors.accent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
        ),
      ],
    );
  }

  // ── Card 2: Narrative ──────────────────────────────────────────────────────

  Widget _buildNarrativeCard(LifeStory story, AppPalette colors) {
    return _cardWrapper(
      colors: colors,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                'YOUR STORY',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(color: colors.textPrimary.withAlpha(6), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.format_quote_rounded, size: 28, color: colors.accent.withAlpha(60)),
                const SizedBox(height: 16),
                Text(
                  story.narrative,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: colors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 3: Highlight ──────────────────────────────────────────────────────

  Widget _buildHighlightCard(LifeStory story, AppPalette colors) {
    final dateStr = story.highlightDate != null
        ? DateFormat('EEEE, MMM d').format(story.highlightDate!)
        : '';

    return _cardWrapper(
      colors: colors,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.accent.withAlpha(10), colors.bg],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, size: 20, color: Colors.amber.shade600),
              const SizedBox(width: 8),
              Text(
                'HIGHLIGHT MOMENT',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accent, colors.accent.withAlpha(200)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: colors.accent.withAlpha(40), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 28, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  story.highlightTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your happiest moment this week',
            style: GoogleFonts.manrope(fontSize: 13, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Card 4: Insights ───────────────────────────────────────────────────────

  Widget _buildInsightsCard(LifeStory story, AppPalette colors) {
    return _cardWrapper(
      colors: colors,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insights_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                'LIFE INSIGHTS',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _insightTile(
                      icon: Icons.sentiment_satisfied_rounded,
                      label: 'Top Mood',
                      value: story.topMood,
                      color: _moodColor(story.topMood),
                      colors: colors,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _insightTile(
                      icon: Icons.tag_rounded,
                      label: 'Top Theme',
                      value: story.topTheme,
                      color: colors.accent,
                      colors: colors,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _insightTile(
                      icon: Icons.schedule_rounded,
                      label: 'Most Active',
                      value: story.mostActiveTime,
                      color: Colors.orange,
                      colors: colors,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _insightTile(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Streak',
                      value: '${story.writingStreak} day${story.writingStreak == 1 ? '' : 's'}',
                      color: Colors.redAccent,
                      colors: colors,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required AppPalette colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'great': return AppColors.moodGreat;
      case 'good': return AppColors.moodGood;
      case 'okay': return AppColors.moodOkay;
      case 'low': return AppColors.moodLow;
      case 'tough': return AppColors.moodTough;
      default: return AppColors.moodOkay;
    }
  }

  // ── Card 5: Quote + Share ──────────────────────────────────────────────────

  Widget _buildQuoteCard(LifeStory story, AppPalette colors) {
    return _cardWrapper(
      colors: colors,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.accent.withAlpha(20), colors.accent.withAlpha(6)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.format_quote_rounded, size: 40, color: colors.accent.withAlpha(80)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              story.quote,
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '— From your journal',
            style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 40),
          // Share button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share coming soon!')),
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 20, color: Colors.white),
                label: Text(
                  'Share Your Story',
                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: colors.accent.withAlpha(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Save image button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Save as image coming soon!')),
              );
            },
            child: Text(
              'Save as Image',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.accent,
                decoration: TextDecoration.underline,
                decorationColor: colors.accent.withAlpha(100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card Wrapper ───────────────────────────────────────────────────────────

  Widget _cardWrapper({
    required AppPalette colors,
    required Widget child,
    Gradient? gradient,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? colors.bg : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}
