import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/book/presentation/providers/life_book_provider.dart';
import 'package:deardays/features/story/data/models/story_node.dart';
import 'package:deardays/features/story/presentation/providers/story_provider.dart';

class MyStoryScreen extends ConsumerStatefulWidget {
  final String bookId;

  const MyStoryScreen({super.key, required this.bookId});

  @override
  ConsumerState<MyStoryScreen> createState() => _MyStoryScreenState();
}

class _MyStoryScreenState extends ConsumerState<MyStoryScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  String _writingStyle = 'Memoir';
  bool _isFullscreen = false;
  bool _showOriginalInBook = false;

  /// null = Daily (existing page book), non-null = hierarchical level
  StoryLevelType? _hierarchyLevel;

  static const _styles = ['Memoir', 'Diary', 'Letter', 'Poetic'];

  static const _levelLabels = {
    null: 'Daily',
    StoryLevelType.weekly: 'Weekly',
    StoryLevelType.monthly: 'Monthly',
    StoryLevelType.yearly: 'Yearly',
    StoryLevelType.lifetime: 'Lifetime',
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);

    return booksAsync.when(
      data: (books) {
        final book = books.where((b) => b.id == widget.bookId).firstOrNull;
        if (book == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Book not found', style: GoogleFonts.manrope(color: AppColors.of(context).textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => context.go('/book'), child: const Text('Back to Library')),
                ],
              ),
            ),
          );
        }
        return _buildScreen(context, book);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        body: Center(child: TextButton(onPressed: () => context.go('/book'), child: const Text('Back to Library'))),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, Book book) {
    final state = ref.watch(lifeBookProvider);
    final colors = AppColors.of(context);

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
          ),
        ),
      );
    }

    // Build flat list of all entries across chapters
    final allEntries = <LifeBookEntry>[];
    for (final ch in state.chapters) {
      allEntries.addAll(ch.entries);
    }

    // Empty book — show mic/write CTA
    if (allEntries.isEmpty) {
      return _buildEmptyBookState(context, book);
    }

    final totalPages = 1 + allEntries.length; // cover + entries

    // Fullscreen mode — just the page view + tap to exit
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: GestureDetector(
          onTap: _toggleFullscreen,
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              if (index > 0) _ensureEntryPolished(state, index - 1);
            },
            itemBuilder: (context, index) {
              if (index == 0) return _buildCoverPage(book, state, fullscreen: true);
              final entryIndex = index - 1;
              if (entryIndex < allEntries.length) {
                return _buildEntryPage(allEntries[entryIndex], pageNumber: index, totalPages: totalPages - 1, fullscreen: true);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildTopNav(context, book),
          _buildLevelSelector(),
          // ── Hierarchical view ──────────────────────────────────────────
          if (_hierarchyLevel != null) ...[
            Expanded(child: _buildHierarchicalView(context)),
          ] else ...[
          // ── Original daily page book ───────────────────────────────────
          // Page counter with arrows
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _currentPage > 0
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  child: Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: _currentPage > 0 ? colors.textPrimary : colors.textMuted.withAlpha(76),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _currentPage == 0 ? 'Cover' : 'Page $_currentPage of ${totalPages - 1}',
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w500, color: colors.textSecondary),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _currentPage < totalPages - 1
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: _currentPage < totalPages - 1 ? colors.textPrimary : colors.textMuted.withAlpha(76),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: totalPages > 1 ? _currentPage / (totalPages - 1) : 0,
                backgroundColor: colors.accent.withAlpha(26),
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                minHeight: 3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Swipeable page view
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalPages,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                if (index > 0) {
                  _ensureEntryPolished(state, index - 1);
                }
              },
              itemBuilder: (context, index) {
                if (index == 0) return _buildCoverPage(book, state);
                final entryIndex = index - 1;
                if (entryIndex < allEntries.length) {
                  return _buildEntryPage(allEntries[entryIndex], pageNumber: index, totalPages: totalPages - 1);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          // Bottom bar
          _buildBottomBar(context, state),
          ], // end else (daily view)
        ],
      ),
    );
  }

  void _ensureEntryPolished(LifeBookState state, int flatIndex) {
    int count = 0;
    for (int c = 0; c < state.chapters.length; c++) {
      for (int e = 0; e < state.chapters[c].entries.length; e++) {
        if (count == flatIndex) {
          final entry = state.chapters[c].entries[e];
          if (!entry.hasPolished && !entry.isPolishing) {
            ref.read(lifeBookProvider.notifier).selectEntry(c, e);
          }
          return;
        }
        count++;
      }
    }
  }

  // ──────────────────────────────────────────────
  // Level selector
  // ──────────────────────────────────────────────

  Widget _buildLevelSelector() {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.accent.withAlpha(20))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _levelLabels.entries.map((entry) {
            final isActive = _hierarchyLevel == entry.key;
            return GestureDetector(
              onTap: () => setState(() => _hierarchyLevel = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? colors.accent : colors.accent.withAlpha(13),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  entry.value,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : colors.accent,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Hierarchical view (Weekly / Monthly / Yearly / Lifetime)
  // ──────────────────────────────────────────────

  Widget _buildHierarchicalView(BuildContext context) {
    final level = _hierarchyLevel!;
    final hState = ref.watch(hierarchicalBookProvider);
    final colors = AppColors.of(context); // AppPalette

    if (level == StoryLevelType.lifetime) {
      return _buildLifetimeView(context, hState);
    }

    final nodes = hState.nodesForLevel(level);

    // Derive available periods from LifeBook chapters as scaffold
    final lifeBookState = ref.watch(lifeBookProvider);
    final periods = _periodsForLevel(level, lifeBookState);

    if (periods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Add some check-ins or entries first.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (hState.error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(hState.error!,
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.red)),
                ),
                GestureDetector(
                  onTap: () => ref.read(hierarchicalBookProvider.notifier).clearError(),
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: periods.length,
            itemBuilder: (context, index) {
              final period = periods[index];
              final nodeId = _nodeIdForPeriod(level, period);
              final node = nodes.where((n) => n.id == nodeId).firstOrNull;
              final isGenerating = hState.generatingId == nodeId;
              return _buildPeriodCard(
                context,
                level: level,
                period: period,
                node: node,
                isGenerating: isGenerating,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodCard(
    BuildContext context, {
    required StoryLevelType level,
    required _StoryPeriod period,
    required StoryNode? node,
    required bool isGenerating,
  }) {
    final colors = AppColors.of(context);
    final isGenerated = node?.isGenerated ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withAlpha(isGenerated ? 30 : 15)),
        boxShadow: [
          BoxShadow(color: colors.textPrimary.withAlpha(6), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period.label,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (node?.theme != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.accent.withAlpha(20),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            node!.theme!,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isGenerating)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    ),
                  )
                else if (isGenerated)
                  GestureDetector(
                    onTap: () => _regeneratePeriod(level, period),
                    child: Icon(Icons.refresh_rounded, size: 18, color: colors.textSecondary),
                  )
                else
                  GestureDetector(
                    onTap: () => _generatePeriod(level, period),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        'Generate',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Story preview / body
          if (isGenerated && node?.generatedStory != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                node!.generatedStory!,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: colors.textPrimary.withAlpha(204),
                  height: 1.65,
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Read more button
            GestureDetector(
              onTap: () => _showFullStory(context, period.label, node.generatedStory!, node.theme),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.accent.withAlpha(20))),
                ),
                child: Text(
                  'Read full story',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          ] else if (!isGenerating) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Text(
                'Tap Generate to create this story.',
                style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Text(
                'Writing your story…',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLifetimeView(BuildContext context, HierarchicalBookState hState) {
    final colors = AppColors.of(context);
    final node = hState.lifetimeNode;
    final isGenerating = hState.generatingId == StoryNode.lifetimeKey;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hState.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(hState.error!,
                        style: GoogleFonts.manrope(fontSize: 12, color: Colors.red)),
                  ),
                  GestureDetector(
                    onTap: () => ref.read(hierarchicalBookProvider.notifier).clearError(),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ],
              ),
            ),
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Life Story',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (node?.generatedAt != null)
                      Text(
                        'Updated ${DateFormat('MMM d, yyyy').format(node!.generatedAt!)}',
                        style: GoogleFonts.manrope(fontSize: 11, color: colors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (node?.isGenerated == true && !isGenerating)
                GestureDetector(
                  onTap: () => ref.read(hierarchicalBookProvider.notifier).regenerateLifetime(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.accent.withAlpha(60)),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      'Regenerate',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Story card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: colors.accent.withAlpha(80), width: 3)),
              boxShadow: [
                BoxShadow(color: colors.textPrimary.withAlpha(8), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: isGenerating
                ? Column(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Writing your life story…\nThis may take a moment.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  )
                : node?.isGenerated == true
                    ? Text(
                        node!.generatedStory!,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          color: colors.textPrimary.withAlpha(220),
                          height: 1.75,
                        ),
                      )
                    : Column(
                        children: [
                          Icon(Icons.auto_stories_rounded, size: 40, color: colors.accent.withAlpha(60)),
                          const SizedBox(height: 16),
                          Text(
                            'Your lifetime story synthesises all your yearly stories into one continuous narrative.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: colors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generate yearly stories first, then tap below.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => ref.read(hierarchicalBookProvider.notifier).generateLifetime(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: BorderRadius.circular(9999),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accent.withAlpha(60),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Generate Lifetime Story',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _showFullStory(BuildContext context, String title, String story, String? theme) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.manrope(
                                fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                        if (theme != null)
                          Text(theme,
                              style: GoogleFonts.manrope(
                                  fontSize: 12, color: colors.accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Text(
                  story,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: colors.textPrimary.withAlpha(220),
                    height: 1.75,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Period helpers ──────────────────────────────────────────────────────

  List<_StoryPeriod> _periodsForLevel(StoryLevelType level, LifeBookState lifeBookState) {
    if (lifeBookState.chapters.isEmpty) return [];

    final allDates = lifeBookState.chapters
        .expand((ch) => ch.entries.map((e) => e.date))
        .toList()
      ..sort();
    if (allDates.isEmpty) return [];

    final earliest = allDates.first;
    final latest = allDates.last;
    final periods = <_StoryPeriod>[];

    if (level == StoryLevelType.weekly) {
      var week = StoryNode.weekStart(earliest);
      final lastWeek = StoryNode.weekStart(latest);
      while (!week.isAfter(lastWeek)) {
        final end = week.add(const Duration(days: 6));
        final label = 'Week of ${DateFormat('MMM d, yyyy').format(week)}';
        periods.add(_StoryPeriod(weekDate: week, label: label, start: week, end: end));
        week = week.add(const Duration(days: 7));
      }
    } else if (level == StoryLevelType.monthly) {
      var month = DateTime(earliest.year, earliest.month);
      final lastMonth = DateTime(latest.year, latest.month);
      while (!month.isAfter(lastMonth)) {
        final label = DateFormat('MMMM yyyy').format(month);
        final end = DateTime(month.year, month.month + 1, 0);
        periods.add(_StoryPeriod(year: month.year, month: month.month, label: label, start: month, end: end));
        month = DateTime(month.year, month.month + 1);
      }
    } else if (level == StoryLevelType.yearly) {
      for (var year = earliest.year; year <= latest.year; year++) {
        periods.add(_StoryPeriod(year: year, label: '$year', start: DateTime(year, 1, 1), end: DateTime(year, 12, 31)));
      }
    }

    return periods.reversed.toList(); // newest first
  }

  String _nodeIdForPeriod(StoryLevelType level, _StoryPeriod period) {
    return switch (level) {
      StoryLevelType.weekly =>
        StoryNode.weekKey(period.weekDate!.year, StoryNode.isoWeekNumber(period.weekDate!)),
      StoryLevelType.monthly => StoryNode.monthKey(period.year!, period.month!),
      StoryLevelType.yearly => StoryNode.yearKey(period.year!),
      _ => '',
    };
  }

  void _generatePeriod(StoryLevelType level, _StoryPeriod period) {
    final notifier = ref.read(hierarchicalBookProvider.notifier);
    switch (level) {
      case StoryLevelType.weekly:
        notifier.generateWeekly(period.weekDate!);
      case StoryLevelType.monthly:
        notifier.generateMonthly(period.year!, period.month!);
      case StoryLevelType.yearly:
        notifier.generateYearly(period.year!);
      default:
        break;
    }
  }

  void _regeneratePeriod(StoryLevelType level, _StoryPeriod period) {
    final notifier = ref.read(hierarchicalBookProvider.notifier);
    switch (level) {
      case StoryLevelType.weekly:
        notifier.regenerateWeekly(period.weekDate!);
      case StoryLevelType.monthly:
        notifier.regenerateMonthly(period.year!, period.month!);
      case StoryLevelType.yearly:
        notifier.regenerateYearly(period.year!);
      default:
        break;
    }
  }

  // ──────────────────────────────────────────────
  // Empty book state — mic/write CTA
  // ──────────────────────────────────────────────

  Widget _buildEmptyBookState(BuildContext context, Book book) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.textPrimary),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      book.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            // Empty state
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.accent.withAlpha(25),
                              colors.accentFaint,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 48,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'This book is empty',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first entry by recording\nyour voice or writing it down.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Mic + Write buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Record button
                          GestureDetector(
                            onTap: () => context.push('/record'),
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accent.withAlpha(60),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Record',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Write button
                          GestureDetector(
                            onTap: () => context.push('/write'),
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colors.accent.withAlpha(40)),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.textPrimary.withAlpha(8),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.edit_note_rounded, color: colors.accent, size: 28),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Write',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  // ──────────────────────────────────────────────
  // Top nav — back, DEARDAYS, download + style pill
  // ──────────────────────────────────────────────

  Widget _buildTopNav(BuildContext context, Book book) {
    final colors = AppColors.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: colors.bg.withAlpha(204),
            border: Border(bottom: BorderSide(color: colors.accent.withAlpha(26))),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/book'),
                    child: Icon(Icons.arrow_back_ios, size: 20, color: colors.textPrimary.withAlpha(178)),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'DEARDAYS',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Download PDF icon
                  GestureDetector(
                    onTap: () => context.push('/export'),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.download_rounded, size: 22, color: colors.accent),
                    ),
                  ),
                  _buildStyleSelector(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyleSelector() {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: _showStylePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: colors.accent.withAlpha(76)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _writingStyle,
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: colors.accent),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 16, color: colors.accent),
          ],
        ),
      ),
    );
  }

  void _showStylePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Writing Style', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ..._styles.map((style) => ListTile(
                    onTap: () {
                      setState(() => _writingStyle = style);
                      Navigator.pop(ctx);
                    },
                    title: Text(style, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w500)),
                    trailing: _writingStyle == style ? Icon(Icons.check_circle, color: AppColors.of(context).accent, size: 20) : null,
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Stacked pages wrapper — gives the "pushed up" feel
  // ──────────────────────────────────────────────

  Widget _buildStackedPage({required Widget child, bool fullscreen = false}) {
    final horizontalPad = fullscreen ? 8.0 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, fullscreen ? 8 : 16),
      child: Stack(
        children: [
          // Bottom page (3rd layer) — offset down and in
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).highlightFaint,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: AppColors.of(context).textPrimary.withAlpha(6), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
            ),
          ),
          // Middle page (2nd layer) — offset slightly
          Positioned(
            left: 6,
            right: 6,
            top: 6,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).highlight,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: AppColors.of(context).textPrimary.withAlpha(8), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
            ),
          ),
          // Top page (main content)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: child,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Cover page
  // ──────────────────────────────────────────────

  Widget _buildCoverPage(Book book, LifeBookState state, {bool fullscreen = false}) {
    final colors = AppColors.of(context);
    final dateRange = _buildDateRange(state.chapters);

    return _buildStackedPage(
      fullscreen: fullscreen,
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: colors.accent.withAlpha(51), width: 4)),
            boxShadow: [
              BoxShadow(color: colors.textPrimary.withAlpha(10), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image area with gradient overlay
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.accent.withAlpha(13)),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(child: Icon(Icons.auto_stories, size: 64, color: colors.accent.withAlpha(51))),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, colors.textPrimary.withAlpha(153)],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dateRange.toUpperCase(),
                                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withAlpha(204), letterSpacing: 3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Contents heading
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.accent.withAlpha(26)))),
                  child: Text(
                    'Contents',
                    style: GoogleFonts.manrope(fontSize: 18, fontStyle: FontStyle.italic, color: colors.textPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                // Chapter list
                ...state.chapters.asMap().entries.map((e) {
                  final index = e.key;
                  final chapter = e.value;
                  int pageIndex = 1;
                  for (int i = 0; i < index; i++) {
                    pageIndex += state.chapters[i].entryCount;
                  }

                  return GestureDetector(
                    onTap: () => _pageController.animateToPage(pageIndex, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              (index + 1).toString().padLeft(2, '0'),
                              style: GoogleFonts.manrope(fontSize: 14, fontStyle: FontStyle.italic, color: colors.accent.withAlpha(102)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(chapter.title, style: GoogleFonts.manrope(fontSize: 16, color: colors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                  'CHAPTER ${index + 1} \u2022 ${chapter.entryCount} ${chapter.entryCount == 1 ? "ENTRY" : "ENTRIES"}',
                                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w500, color: colors.textPrimary.withAlpha(102), letterSpacing: 0.8),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward, size: 14, color: colors.accent.withAlpha(76)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Entry page — book-style rendering
  // ──────────────────────────────────────────────

  Widget _buildEntryPage(LifeBookEntry entry, {required int pageNumber, required int totalPages, bool fullscreen = false}) {
    final colors = AppColors.of(context);
    final dateStr = DateFormat('MMMM d, yyyy').format(entry.date).toUpperCase();
    final moodLabel = entry.mood != null ? 'Mood: ${entry.mood![0].toUpperCase()}${entry.mood!.substring(1)}' : null;

    return _buildStackedPage(
      fullscreen: fullscreen,
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: colors.textPrimary.withAlpha(10), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(32, 32, 32, fullscreen ? 32 : 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page header
                    Container(
                      padding: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.accent.withAlpha(13)))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(dateStr, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: colors.textSecondary)),
                                if (moodLabel != null) ...[
                                  Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent.withAlpha(76)),
                                  ),
                                  Text(moodLabel, style: GoogleFonts.manrope(fontSize: 10, fontStyle: FontStyle.italic, color: colors.textPrimary.withAlpha(128))),
                                ],
                              ],
                            ),
                          ),
                          // Fullscreen toggle
                          GestureDetector(
                            onTap: _toggleFullscreen,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                size: 18,
                                color: colors.accent.withAlpha(128),
                              ),
                            ),
                          ),
                          Text('Page $pageNumber', style: GoogleFonts.manrope(fontSize: 10, fontStyle: FontStyle.italic, color: colors.textSecondary.withAlpha(102))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Story / Original toggle
                    if (entry.hasPolished)
                      _buildContentToggle(),
                    const SizedBox(height: 24),
                    // Body
                    if (entry.isPolishing)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(colors.accent)),
                              ),
                              const SizedBox(height: 12),
                              Text('Crafting your story...', style: GoogleFonts.manrope(fontSize: 14, fontStyle: FontStyle.italic, color: colors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    else if (_showOriginalInBook)
                      _buildOriginalBody(entry.rawText)
                    else
                      _buildEntryBody(entry.displayText),
                  ],
                ),
              ),
              // Page fold corner
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(48, 48),
                  painter: _PageFoldPainter(color: colors.accent.withAlpha(26)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryBody(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropCapParagraph(paragraphs.first),
        ...paragraphs.skip(1).map((p) => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                p,
                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w400, color: AppColors.of(context).textPrimary.withAlpha(230), height: 1.7),
              ),
            )),
      ],
    );
  }

  Widget _buildDropCapParagraph(String text) {
    final colors = AppColors.of(context);

    if (text.length < 2) {
      return Text(text, style: GoogleFonts.manrope(fontSize: 18, color: colors.textPrimary.withAlpha(230), height: 1.7));
    }

    final firstChar = text[0].toUpperCase();
    final restText = text.substring(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 4),
          child: Text(
            firstChar,
            style: GoogleFonts.manrope(fontSize: 52, fontWeight: FontWeight.w700, color: colors.textPrimary, height: 0.85),
          ),
        ),
        Expanded(
          child: Text(
            restText,
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w400, color: colors.textPrimary.withAlpha(230), height: 1.7),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Story / Original toggle pill
  // ──────────────────────────────────────────────

  Widget _buildContentToggle() {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _contentToggleTab('Story', !_showOriginalInBook, () => setState(() => _showOriginalInBook = false)),
          _contentToggleTab('Original', _showOriginalInBook, () => setState(() => _showOriginalInBook = true)),
        ],
      ),
    );
  }

  Widget _contentToggleTab(String label, bool isActive, VoidCallback onTap) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [BoxShadow(color: colors.textPrimary.withAlpha(8), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? colors.accent : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Original text body — Inter sans-serif, no drop cap
  // ──────────────────────────────────────────────

  Widget _buildOriginalBody(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          p,
          style: GoogleFonts.manrope(
            fontSize: 16,
            color: AppColors.of(context).textPrimary.withAlpha(204),
            height: 1.7,
          ),
        ),
      )).toList(),
    );
  }

  // ──────────────────────────────────────────────
  // Bottom bar — chapter name only (PDF moved to header)
  // ──────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, LifeBookState state) {
    final colors = AppColors.of(context);
    String chapterName = '';
    if (_currentPage > 0 && state.chapters.isNotEmpty) {
      int count = 0;
      for (final ch in state.chapters) {
        count += ch.entryCount;
        if (_currentPage <= count) {
          chapterName = ch.title;
          break;
        }
      }
    }

    if (chapterName.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: GestureDetector(
          onTap: () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories, size: 14, color: colors.accent.withAlpha(128)),
              const SizedBox(width: 8),
              Text(
                chapterName,
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildDateRange(List<LifeBookChapter> chapters) {
    if (chapters.isEmpty) return '';
    final oldest = chapters.last;
    return '${oldest.year} \u2014 Present';
  }
}

class _PageFoldPainter extends CustomPainter {
  final Color color;
  _PageFoldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.transparent, color, color.withAlpha(51)],
        stops: const [0.5, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PageFoldPainter oldDelegate) => oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: represents a time period in the hierarchical view
// ─────────────────────────────────────────────────────────────────────────────

class _StoryPeriod {
  final String label;
  final DateTime start;
  final DateTime end;

  /// Set for weekly periods (the Monday of the ISO week).
  final DateTime? weekDate;

  /// Set for monthly and yearly periods.
  final int? year;

  /// Set for monthly periods.
  final int? month;

  const _StoryPeriod({
    required this.label,
    required this.start,
    required this.end,
    this.weekDate,
    this.year,
    this.month,
  });
}
