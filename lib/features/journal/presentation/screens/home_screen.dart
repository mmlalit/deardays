import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/core/widgets/milestone_overlay.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart'
    show showMemoryContextMenu;
import 'package:deardays/core/widgets/force_update_dialog.dart';
import 'package:deardays/l10n/app_localizations.dart';
import 'package:deardays/core/providers/onboarding_provider.dart';
import 'package:deardays/core/onboarding/checklist_card.dart';

String _cleanFirstName(String name) {
  final first = name.split(' ').first;
  // If it looks like a username (no spaces, has digits), strip digits/symbols
  if (!name.contains(' ') && first.contains(RegExp(r'[0-9_.]'))) {
    final clean = first.replaceAll(RegExp(r'[0-9_.]'), '');
    if (clean.isNotEmpty) {
      return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
    }
  }
  return first[0].toUpperCase() + first.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final profileAsync = ref.watch(profileProvider);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    // ── Force-update check (runs once per app session) ───────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) ForceUpdateDialog.showIfNeeded(context);
    });

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
            ).catchError((_) {
              // NotificationService may not be initialized (e.g. in tests).
            });
      }
    });

    // ── Checklist task auto-completion ───────────────────────────────────────
    ref.listen<AsyncValue<List<JournalEntry>>>(timelineEntriesProvider,
        (_, next) {
      final entries = next.valueOrNull;
      if (entries == null) return;
      final notifier = ref.read(onboardingProvider.notifier);
      final tasks = ref.read(onboardingProvider).checklistTasks;

      final realEntries = entries.where((e) => !e.tags.contains('__sample__')).toList();
      if (realEntries.isNotEmpty) {
        if (!tasks.any((t) => t.id == 'first_memory' && t.isCompleted)) {
          notifier.completeTask('first_memory');
        }
      }
      if (entries.any((e) => e.hasPhoto)) {
        if (!tasks.any((t) => t.id == 'add_photo' && t.isCompleted)) {
          notifier.completeTask('add_photo');
        }
      }
    });

    ref.listen<AsyncValue<List<dynamic>>>(chaptersProvider, (_, next) {
      final chapters = next.valueOrNull;
      if (chapters != null && chapters.isNotEmpty) {
        final tasks = ref.read(onboardingProvider).checklistTasks;
        if (!tasks.any((t) => t.id == 'create_chapter' && t.isCompleted)) {
          ref.read(onboardingProvider.notifier).completeTask('create_chapter');
        }
      }
    });

    User? user;
    try {
      user = Supabase.instance.client.auth.currentUser;
    } catch (_) {
      // Supabase not initialized (e.g. in tests).
    }
    final displayName = profileAsync.valueOrNull?.displayName ??
        user?.userMetadata?['display_name'] as String? ??
        user?.email?.split('@').first ??
        'there';
    final firstName = _cleanFirstName(displayName);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // 1. Greeting
                    _buildGreeting(firstName, colors),
                    const SizedBox(height: 16),

                    // Mood check-in
                    _buildMoodRow(colors),
                    const SizedBox(height: 16),

                    // 2. Capture grid (2x2)
                    _buildCaptureHero(context, colors),
                    const SizedBox(height: 16),

                    // 3. Getting Started checklist (new users only)
                    _buildChecklistSection(),

                    // 4. Journal Activity
                    _buildJournalActivityCard(colors),
                    const SizedBox(height: 16),

                    // 6. Recent Memories header
                    _buildSectionHeader(context, colors),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Recent Memory cards (mixed layout) ───────────────────────────
            entriesAsync.when(
              data: (data) {
                final entries = data;
                if (entries.isEmpty) {
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverToBoxAdapter(
                      child: _EmptyHomeState(colors: colors),
                    ),
                  );
                }
                return _buildMixedMemoryCards(context, entries, colors);
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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
              height: 110,
              width: double.infinity,
              child: photoMedia.isNotEmpty
                  ? _NetworkImage(
                      storagePath: photoMedia.first.storagePath)
                  : _GradientBanner(colors: colors, mood: entry.mood),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
  // Getting Started checklist (Layer 3A)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildChecklistSection() {
    final onboarding = ref.watch(onboardingProvider);
    if (onboarding.checklistDismissed || onboarding.allTasksComplete) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: const ChecklistCard(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Greeting + prompt
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGreeting(String firstName, AppPalette colors) {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context);

    final greeting = hour < 12
        ? (l10n?.goodMorning ?? 'Good Morning')
        : hour < 17
            ? (l10n?.goodAfternoon ?? 'Good Afternoon')
            : (l10n?.goodEvening ?? 'Good Evening');

    final tagline = hour >= 5 && hour < 12
        ? 'Start your day with a memory ☀️'
        : hour < 17
            ? 'Capture a moment from today'
            : hour < 21
                ? 'Ready to reflect on your day? 🌙'
                : 'Perfect time to journal ✨';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $firstName',
          style: GoogleFonts.newsreader(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tagline,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mood check-in row
  // ─────────────────────────────────────────────────────────────────────────

  static const _moodData = [
    {'emoji': '🤩', 'label': 'GREAT', 'color': Color(0xFFF59E0B)},
    {'emoji': '😊', 'label': 'GOOD', 'color': Color(0xFF10B981)},
    {'emoji': '😐', 'label': 'OKAY', 'color': Color(0xFF94A3B8)},
    {'emoji': '😔', 'label': 'LOW', 'color': Color(0xFF8B5CF6)},
    {'emoji': '😣', 'label': 'TOUGH', 'color': Color(0xFFEF4444)},
  ];

  Widget _buildMoodRow(AppPalette colors) {
    final selectedMood = ref.watch(todayMoodProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling?',
            style: GoogleFonts.newsreader(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _moodData.map((m) {
              final label = m['label'] as String;
              final color = m['color'] as Color;
              final emoji = m['emoji'] as String;
              final isSelected = selectedMood == label;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(todayMoodProvider.notifier).setMood(label);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withAlpha(30) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isSelected ? color : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Capture grid (2x2)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCaptureHero(BuildContext context, AppPalette colors) {
    return Row(
      children: [
        Expanded(child: _buildGlassButton(
          icon: Icons.mic_rounded,
          label: 'Speak it',
          subtitle: 'Voice memory',
          color: const Color(0xFF6366F1),
          colors: colors,
          onTap: () { HapticFeedback.mediumImpact(); context.push('/record'); },
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildGlassButton(
          icon: Icons.edit_note_rounded,
          label: 'Write',
          subtitle: 'Text entry',
          color: const Color(0xFFEC4899),
          colors: colors,
          onTap: () { HapticFeedback.mediumImpact(); context.push('/write'); },
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildGlassButton(
          icon: Icons.forum_rounded,
          label: 'Check In',
          subtitle: 'AI mood',
          color: const Color(0xFFF97316),
          colors: colors,
          onTap: () { HapticFeedback.mediumImpact(); context.push('/checkin'); },
        )),
      ],
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
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
              height: 76,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withAlpha(45), width: 1),
              ),
              child: Center(
                child: Icon(icon, size: 28, color: color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            Text(
              subtitle,
              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w500, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Journal Activity
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildJournalActivityCard(AppPalette colors) {
    final streakAsync = ref.watch(streakProvider);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    final streak = streakAsync.valueOrNull;
    final entries = entriesAsync.valueOrNull ?? [];
    final streakCount = streak?.currentStreak ?? 0;

    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final entryDays = entries.map((e) {
      final d = e.entryDate;
      return DateTime(d.year, d.month, d.day);
    }).toSet();
    final todayNorm = DateTime(today.year, today.month, today.day);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: colors.textPrimary.withAlpha(8), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Journal Activity', style: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            streakCount > 0 ? '🔥 CURRENT STREAK: $streakCount DAYS' : 'START YOUR STREAK TODAY',
            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFF97316), letterSpacing: 0.8),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = days[i];
              final isToday = day == todayNorm;
              final isDone = entryDays.contains(day);
              final isFuture = day.isAfter(todayNorm);
              final dayName = dayNames[day.weekday - 1];
              // Recent = within last 3 days (not today); older done days get tinted style
              final isRecentDone = isDone && !isToday && day.isAfter(todayNorm.subtract(const Duration(days: 3)));

              return Column(
                children: [
                  Text(
                    dayName,
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday ? colors.accent : colors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  isDone && !isToday
                      ? Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isRecentDone ? colors.accent : colors.accentFaint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: isRecentDone ? Colors.white : colors.accent,
                          ),
                        )
                      : isToday
                          ? _DashedBorderBox(
                              size: 34,
                              radius: 8,
                              color: colors.accent,
                              child: Center(
                                child: isDone
                                    ? Icon(Icons.check_rounded, size: 16, color: colors.accent)
                                    : Text(
                                        '${day.day}',
                                        style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: colors.accent),
                                      ),
                              ),
                            )
                          : Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isFuture ? colors.border.withAlpha(80) : colors.border.withAlpha(40),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isFuture ? colors.textMuted.withAlpha(80) : colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go('/timeline'),
            child: Row(
              children: [
                Text('FULL CALENDAR', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: colors.accent, letterSpacing: 1.0)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14, color: colors.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Recent Memories section header
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
                  height: 200,
                  width: double.infinity,
                  child: photoMedia.isNotEmpty
                      ? _NetworkImage(
                          storagePath: photoMedia.first.storagePath)
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
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    excerpt,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
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

  String _relativeDate(DateTime date) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff =
        now.difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return l10n?.today ?? 'Today';
    if (diff == 1) return l10n?.yesterday ?? 'Yesterday';
    if (diff < 7) return l10n?.daysAgo(diff) ?? '$diff days ago';
    if (diff < 14) return l10n?.weekAgo ?? '1 week ago';
    if (diff < 365) {
      final months = (diff / 30).round();
      return l10n?.monthsAgo(months) ?? '$months months ago';
    }
    final years = (diff / 365).round();
    return l10n?.yearsAgo(years) ?? '$years years ago';
  }

  String _dateLabel(DateTime date) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff =
        now.difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return l10n?.today ?? 'Today';
    if (diff == 1) return l10n?.yesterday ?? 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkImage extends ConsumerWidget {
  final String storagePath;
  const _NetworkImage({required this.storagePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    // If already an HTTP URL (demo data), use directly
    if (storagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: storagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 600,
        memCacheHeight: 400,
        errorWidget: (_, __, ___) => _GradientBanner(colors: colors),
      );
    }
    // Use signed URL for private bucket storage (cached via MediaService)
    return FutureBuilder<String>(
      future: ref.read(mediaServiceProvider).getSignedUrl(storagePath).catchError((_) => ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: colors.accentFaint,
            child: Center(
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: colors.textMuted,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.hasError || snapshot.data!.isEmpty) {
          return _GradientBanner(colors: colors);
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 600,
          memCacheHeight: 400,
          errorWidget: (_, __, ___) => _GradientBanner(colors: colors),
        );
      },
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


// ─────────────────────────────────────────────────────────────────────────────
// Dashed border box — used for today's day cell in Journal Activity
// ─────────────────────────────────────────────────────────────────────────────

class _DashedBorderBox extends StatelessWidget {
  final double size;
  final double radius;
  final Color color;
  final Widget child;

  const _DashedBorderBox({
    required this.size,
    required this.radius,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedRectPainter(color: color, radius: radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRoundedRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
        Radius.circular(radius),
      ));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedRectPainter old) =>
      old.color != color || old.radius != radius;
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty home state — shown when user has no memories yet
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHomeState extends StatelessWidget {
  final AppPalette colors;
  const _EmptyHomeState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 30, color: colors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'Your story starts here',
            style: GoogleFonts.newsreader(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Speak, snap, or write your first memory above. It takes less than a minute.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar bottom sheet — monthly view with entry markers
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarSheet extends StatefulWidget {
  final AppPalette colors;
  final List<JournalEntry> entries;

  const _CalendarSheet({required this.colors, required this.entries});

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late DateTime _viewMonth; // first day of the displayed month

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month, 1);
  }

  Set<DateTime> get _entryDays => widget.entries.map((e) {
        final d = e.entryDate;
        return DateTime(d.year, d.month, d.day);
      }).toSet();

  void _prevMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    // Don't go past current month
    if (nextMonth.isBefore(DateTime(now.year, now.month + 1, 1))) {
      setState(() => _viewMonth = nextMonth);
    }
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _viewMonth.year < now.year ||
        (_viewMonth.year == now.year && _viewMonth.month < now.month);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final entryDays = _entryDays;

    // Calendar grid data
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final firstWeekday = _viewMonth.weekday; // 1 = Mon
    final totalCells = firstWeekday - 1 + daysInMonth;
    final rows = (totalCells / 7).ceil();

    // Count entries this month
    final monthEntryCount = entryDays
        .where((d) =>
            d.year == _viewMonth.year && d.month == _viewMonth.month)
        .length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textMuted.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Month nav header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _prevMonth,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(Icons.chevron_left_rounded,
                        size: 20, color: colors.textPrimary),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(_viewMonth),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (monthEntryCount > 0)
                        Text(
                          '$monthEntryCount ${monthEntryCount == 1 ? 'entry' : 'entries'}',
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
                  onTap: _canGoNext ? _nextMonth : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 20,
                        color: _canGoNext
                            ? colors.textPrimary
                            : colors.textMuted.withAlpha(60)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Day-of-week header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Calendar grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: List.generate(rows, (row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: List.generate(7, (col) {
                      final cellIndex = row * 7 + col;
                      final dayNum = cellIndex - (firstWeekday - 1) + 1;

                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return const Expanded(child: SizedBox(height: 40));
                      }

                      final cellDate = DateTime(
                          _viewMonth.year, _viewMonth.month, dayNum);
                      final isToday = cellDate == todayNorm;
                      final hasEntry = entryDays.contains(cellDate);

                      return Expanded(
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: hasEntry
                                    ? colors.accent
                                    : isToday
                                        ? colors.accent.withAlpha(20)
                                        : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isToday && !hasEntry
                                    ? Border.all(
                                        color: colors.accent, width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '$dayNum',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: hasEntry || isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: hasEntry
                                        ? Colors.white
                                        : isToday
                                            ? colors.accent
                                            : colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
