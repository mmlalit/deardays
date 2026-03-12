import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/core/widgets/milestone_overlay.dart';
import 'package:deardays/core/demo/demo_data.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart'
    show showMemoryContextMenu;

// ─────────────────────────────────────────────────────────────────────────────
// Mock recent conversations (for demo mode)
// ─────────────────────────────────────────────────────────────────────────────

const _mockConversations = [
  {'date': 'Today', 'preview': 'Had a great lunch with Sarah at the new Italian place...', 'mood': '\u{1F60A}'},
  {'date': 'Today', 'preview': 'Work meeting went well, got approval for the project...', 'mood': '\u{1F4AA}'},
  {'date': 'Yesterday', 'preview': 'Took a long walk in the park, beautiful sunset...', 'mood': '\u{1F305}'},
  {'date': 'Yesterday', 'preview': 'Called mom, she shared her pasta recipe...', 'mood': '\u{2764}\u{FE0F}'},
];

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final profileAsync = ref.watch(profileProvider);
    final entriesAsync = ref.watch(timelineEntriesProvider);
    // ── Milestone celebration overlay ────────────────────────────────────────
    ref.listen<AsyncValue<Streak?>>(streakProvider, (previous, next) {
      final streak = next.valueOrNull;
      if (streak != null) {
        const milestones = [7, 30, 100, 365];
        if (milestones.contains(streak.currentStreak)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              MilestoneOverlay.show(
                context,
                days: streak.currentStreak,
                longestStreak: streak.longestStreak,
              );
            }
          });
        }
      }
    });

    // ── Weekly recap notification trigger ────────────────────────────────────
    ref.listen<AsyncValue<List<Map<String, String>>>>(weeklyMoodsProvider,
        (prev, next) {
      final moods = next.valueOrNull;
      if (moods != null && moods.isNotEmpty) {
        final moodCounts = <String, int>{};
        for (final m in moods) {
          final mood = m['mood'] ?? 'okay';
          moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
        }
        final topMood = moodCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        ref.read(notificationServiceProvider).scheduleWeeklyRecap(
              weekSummary: 'You had a $topMood week',
              memoriesCount: moods.length,
              topMood: topMood,
            );
      }
    });

    final user = Supabase.instance.client.auth.currentUser;
    final displayName = profileAsync.valueOrNull?.displayName ??
        user?.userMetadata?['display_name'] as String? ??
        user?.email?.split('@').first ??
        'there';
    final firstName = displayName.split(' ').first;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    _buildHeader(context, displayName, colors),
                    const SizedBox(height: 8),

                    // 1. Greeting
                    _buildGreeting(firstName, colors),
                    const SizedBox(height: 28),

                    // 2. Large Mic Button
                    _buildMicButton(context, colors),
                    const SizedBox(height: 16),

                    // 3. Write & Chat icons
                    _buildWriteChatRow(context, colors),
                    const SizedBox(height: 28),

                    // 4. Streak Strip
                    _buildStreakStrip(colors),
                    const SizedBox(height: 24),

                    // 5. On This Day
                    _buildOnThisDaySection(context, colors),

                    // 6. Recent Conversations
                    _buildRecentConversations(context, colors),
                    const SizedBox(height: 24),

                    // 7. Recent Memories header
                    _buildSectionHeader(context, colors),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Recent Memory cards (mixed layout) ───────────────────────────
            entriesAsync.when(
              data: (data) {
                final entries = data.isEmpty ? DemoData.entries : data;
                if (entries.isEmpty) {
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'No memories yet. Start capturing your day!',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                return _buildMixedMemoryCards(context, entries, colors);
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                      child: _buildCardSkeleton(i == 0, colors),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
              error: (_, __) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 32, color: colors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'You\'re offline. Your memories will appear when you reconnect.',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
  // Mixed memory card layout builder
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMixedMemoryCards(
      BuildContext context, List<JournalEntry> entries, AppPalette colors) {
    // Build a list of widgets cycling: large → 2 compact → milestone (if any)
    final widgets = <Widget>[];
    int idx = 0;
    final maxEntries = entries.length.clamp(0, 10);

    while (idx < maxEntries) {
      // Large card (hero style)
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 16),
          child: _buildHeroCard(context, entries[idx], entries, colors),
        ),
      );
      idx++;

      // Two compact cards side by side
      if (idx < maxEntries) {
        final first = entries[idx];
        idx++;
        final second = idx < maxEntries ? entries[idx] : null;
        if (second != null) idx++;

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCompactGridCard(context, first, entries, colors),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: second != null
                      ? _buildCompactGridCard(
                          context, second, entries, colors)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }

      // Milestone card — find next milestone entry if any
      if (idx < maxEntries && entries[idx].isMilestone) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child:
                _buildMilestoneCard(context, entries[idx], entries, colors),
          ),
        );
        idx++;
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => i == 0 ? widgets[i] : Padding(
            padding: const EdgeInsets.only(top: 0),
            child: widgets[i],
          ),
          childCount: widgets.length,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Compact grid card (for two-column layout)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCompactGridCard(BuildContext context, JournalEntry entry,
      List<JournalEntry> allEntries, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateStr = _relativeDate(entry.entryDate);
    final photoMedia =
        entry.media.where((m) => m.mediaType == 'photo').toList();

    return GestureDetector(
      onTap: () => context.push(
        '/memory',
        extra: MemoryDetailArgs(
          entry: entry,
          allEntries: allEntries,
          initialIndex: allEntries.indexOf(entry),
        ),
      ),
      onLongPress: () => showMemoryContextMenu(context, entry, colors),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
                color: colors.textPrimary.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 90,
              width: double.infinity,
              child: photoMedia.isNotEmpty
                  ? _NetworkImage(
                      url: _getPhotoUrl(
                          context, photoMedia.first.storagePath))
                  : _GradientBanner(colors: colors, mood: entry.mood),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: colors.accent,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    excerpt,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: colors.textSecondary,
                      height: 1.5,
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
  // Milestone card (special border and badge)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMilestoneCard(BuildContext context, JournalEntry entry,
      List<JournalEntry> allEntries, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateStr = _relativeDate(entry.entryDate);

    return GestureDetector(
      onTap: () => context.push(
        '/memory',
        extra: MemoryDetailArgs(
          entry: entry,
          allEntries: allEntries,
          initialIndex: allEntries.indexOf(entry),
        ),
      ),
      onLongPress: () => showMemoryContextMenu(context, entry, colors),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.accent.withAlpha(100),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.accent.withAlpha(15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'MILESTONE',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: colors.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: colors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    excerpt,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.5,
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
  // Header (app name + profile avatar)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(
      BuildContext context, String displayName, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(
            'Aura',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.accent,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Semantics(
            label: 'Settings',
            button: true,
            child: GestureDetector(
              onTap: () => context.push('/settings'),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(Icons.settings_outlined, size: 22, color: colors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Greeting + prompt
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGreeting(String firstName, AppPalette colors) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $firstName',
          style: GoogleFonts.newsreader(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'What happened today?',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Large Mic Button
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMicButton(BuildContext context, AppPalette colors) {
    return Center(
      child: Semantics(
        label: 'Record a memory',
        button: true,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/record');
          },
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withAlpha(80),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Write & Chat row
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWriteChatRow(BuildContext context, AppPalette colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSmallAction(
          context,
          icon: Icons.edit_rounded,
          label: 'Write',
          colors: colors,
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/write');
          },
        ),
        const SizedBox(width: 40),
        _buildSmallAction(
          context,
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Chat',
          colors: colors,
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/write');
          },
        ),
      ],
    );
  }

  Widget _buildSmallAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required AppPalette colors,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 24, color: colors.accent),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Streak Strip
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStreakStrip(AppPalette colors) {
    final streakAsync = ref.watch(streakProvider);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    final streak = streakAsync.valueOrNull;
    final entries = entriesAsync.valueOrNull ?? [];

    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final entryDays = entries.map((e) {
      final d = e.entryDate;
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    final todayNorm = DateTime(today.year, today.month, today.day);
    final streakCount = streak?.currentStreak ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
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
          Row(
            children: List.generate(7, (i) {
              final day = days[i];
              final isToday = day == todayNorm;
              final hasEntry = entryDays.contains(day);
              final letterIndex = (day.weekday - 1) % 7;

              Color bgColor;
              Color textColor;
              Border? border;

              if (hasEntry) {
                bgColor = colors.accent;
                textColor = Colors.white;
                border = null;
              } else if (isToday) {
                bgColor = colors.accent.withAlpha(40);
                textColor = colors.accent;
                border = Border.all(
                    color: colors.accent.withAlpha(80), width: 1.5);
              } else {
                bgColor = colors.card;
                textColor = colors.textPrimary;
                border = Border.all(color: colors.border, width: 1);
              }

              return ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dayLetters[letterIndex],
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 16),
          if (streakCount > 0)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ExcludeSemantics(
                        child: Text('\u{1F525}',
                            style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streakCount',
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'day streak',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Text(
                'Start your streak!',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. On This Day
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOnThisDaySection(BuildContext context, AppPalette colors) {
    final onThisDayAsync = ref.watch(onThisDayProvider);
    final entries = onThisDayAsync.valueOrNull ?? [];

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.orange.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On This Day',
                    style: GoogleFonts.newsreader(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Memories from years past',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/on-this-day');
              },
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Center(
                    child: Text(
                      'See All',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final entry = entries[i];
              final excerpt = _extractExcerpt(entry);
              final relDate = _relativeDate(entry.entryDate);
              final photoMedia =
                  entry.media.where((m) => m.mediaType == 'photo').toList();

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(
                    '/memory',
                    extra: MemoryDetailArgs(
                      entry: entry,
                      allEntries: entries,
                      initialIndex: i,
                    ),
                  );
                },
                onLongPress: () =>
                    showMemoryContextMenu(context, entry, colors),
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.textPrimary.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 100,
                        width: double.infinity,
                        child: photoMedia.isNotEmpty
                            ? _NetworkImage(
                                url: _getPhotoUrl(
                                    context, photoMedia.first.storagePath))
                            : _GradientBanner(colors: colors, mood: entry.mood),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              relDate.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: colors.accent,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              excerpt,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: colors.textSecondary,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Recent Conversations
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRecentConversations(BuildContext context, AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                size: 18,
                color: Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recent Conversations',
                style: GoogleFonts.newsreader(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.go('/timeline');
              },
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Center(
                    child: Text(
                      'See All',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _mockConversations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final convo = _mockConversations[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/write');
                },
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.textPrimary.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (convo['date'] ?? '').toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: colors.accent,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(convo['mood'] ?? '',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          convo['preview'] ?? '',
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
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 7. Recent Memories section header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, AppPalette colors) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.photo_library_rounded,
            size: 18,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Recent Memories',
            style: GoogleFonts.newsreader(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => context.go('/timeline'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'View All',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hero card (first entry — large full-width)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeroCard(BuildContext context, JournalEntry entry,
      List<JournalEntry> allEntries, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateLabel = _dateLabel(entry.entryDate);
    final photoMedia =
        entry.media.where((m) => m.mediaType == 'photo').toList();

    return GestureDetector(
      onTap: () => context.push(
        '/memory',
        extra: MemoryDetailArgs(
          entry: entry,
          allEntries: allEntries,
          initialIndex: allEntries.indexOf(entry),
        ),
      ),
      onLongPress: () => showMemoryContextMenu(context, entry, colors),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
                color: colors.textPrimary.withAlpha(12),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: photoMedia.isNotEmpty
                      ? _NetworkImage(
                          url: _getPhotoUrl(
                              context, photoMedia.first.storagePath))
                      : _GradientBanner(colors: colors, mood: entry.mood),
                ),
                if (entry.isAiPolished)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_fix_high_rounded,
                              size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('AI',
                              style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Skeleton loaders
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCardSkeleton(bool isHero, AppPalette colors) {
    if (isHero) {
      return Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(
                width: double.infinity, height: 160, borderRadius: 0),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 200, height: 14, borderRadius: 7),
                  SizedBox(height: 8),
                  SkeletonBox(width: 280, height: 12, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 110, height: 110, borderRadius: 0),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160, height: 12, borderRadius: 6),
                  SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 11, borderRadius: 5),
                ],
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

  String _getPhotoUrl(BuildContext context, String storagePath) {
    if (storagePath.startsWith('http')) return storagePath;
    return Supabase.instance.client.storage
        .from('media')
        .getPublicUrl(storagePath);
  }

  String _extractTitle(JournalEntry entry) {
    final lines =
        entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return entry.content.length > 50
        ? '${entry.content.substring(0, 50)}...'
        : entry.content;
  }

  String _extractExcerpt(JournalEntry entry) {
    final lines =
        entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final first = lines.first.trim();
    final isTitle = first.length < 80 && lines.length > 1;
    final body = isTitle ? lines.skip(1).join(' ') : entry.content;
    return body.length > 100 ? '${body.substring(0, 100)}...' : body;
  }

  static String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff =
        now.difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 14) return '1 week ago';
    if (diff < 365) return '${(diff / 30).round()} months ago';
    final years = (diff / 365).round();
    return years == 1 ? '1 year ago' : '$years years ago';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final diff =
        now.difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkImage extends StatelessWidget {
  final String url;
  const _NetworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _GradientBanner(colors: colors),
    );
  }
}

class _GradientBanner extends StatelessWidget {
  final AppPalette colors;
  final String? mood;

  const _GradientBanner({required this.colors, this.mood});

  Color _moodColor1(String? mood) {
    switch (mood) {
      case 'great':
        return const Color(0xFF10B981);
      case 'good':
        return const Color(0xFF3B82F6);
      case 'okay':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFFF97316);
      case 'tough':
        return const Color(0xFFEF4444);
      default:
        return colors.accent;
    }
  }

  Color _moodColor2(String? mood) {
    switch (mood) {
      case 'great':
        return const Color(0xFF34D399);
      case 'good':
        return const Color(0xFF60A5FA);
      case 'okay':
        return const Color(0xFFFBBF24);
      case 'low':
        return const Color(0xFFFB923C);
      case 'tough':
        return const Color(0xFFF87171);
      default:
        return colors.accentLight;
    }
  }

  String _moodEmoji(String? mood) {
    switch (mood) {
      case 'great':
        return '\u{1F929}';
      case 'good':
        return '\u{1F60A}';
      case 'okay':
        return '\u{1F610}';
      case 'low':
        return '\u{1F614}';
      case 'tough':
        return '\u{1F622}';
      default:
        return '\u{1F4D6}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_moodColor1(mood), _moodColor2(mood)],
            ),
          ),
        ),
        Center(
          child: Text(
            _moodEmoji(mood),
            style: TextStyle(
              fontSize: 32,
              color: Colors.white.withAlpha(180),
            ),
          ),
        ),
      ],
    );
  }
}

