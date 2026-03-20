import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/app_avatar.dart';
import 'package:deardays/core/widgets/dd_logo.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/core/widgets/milestone_overlay.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart'
    show showMemoryContextMenu;
import 'package:deardays/core/widgets/force_update_dialog.dart';
import 'package:deardays/l10n/app_localizations.dart';

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

                    // 2. Large Mic Button + 3. Write/Photo/Chat grouped
                    _buildMicButton(context, colors),
                    const SizedBox(height: 12),
                    _buildWriteChatRow(context, colors),
                    const SizedBox(height: 24),

                    // 4. Streak Strip
                    _buildStreakStrip(colors),
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
                      storagePath: photoMedia.first.storagePath)
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
          const DdLogo(size: 28),
          const Spacer(),
          Semantics(
            label: 'Search',
            button: true,
            child: GestureDetector(
              onTap: () => context.push('/search'),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(Icons.search_rounded, size: 22, color: colors.textSecondary),
                ),
              ),
            ),
          ),
          const AppAvatar(),
        ],
      ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.accent, colors.accent.withAlpha(200)],
                  ),
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
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Record a memory',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Write / Photo / Chat row
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openPhotoFlow(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    XFile? photo;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: camera not supported — go straight to file picker.
      photo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } else {
      // Mobile: show Camera vs Gallery choice sheet.
      final source = await _showPhotoSourceSheet(context);
      if (source == null) return;
      photo = await picker.pickImage(source: source, imageQuality: 85);
    }

    if (photo != null && context.mounted) {
      context.push('/photo-entry', extra: photo.path);
    }
  }

  Future<ImageSource?> _showPhotoSourceSheet(BuildContext context) {
    final colors = AppColors.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _PhotoSourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo',
                subtitle: 'Open camera',
                colors: colors,
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _PhotoSourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Library',
                subtitle: 'Browse your gallery',
                colors: colors,
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWriteChatRow(BuildContext context, AppPalette colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSmallAction(
          context,
          icon: Icons.edit_rounded,
          label: 'Write',
          iconColor: const Color(0xFF6366F1), // indigo
          colors: colors,
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/write');
          },
        ),
        const SizedBox(width: 24),
        _buildSmallAction(
          context,
          icon: Icons.camera_alt_rounded,
          label: 'Photo',
          iconColor: const Color(0xFF10B981), // emerald
          colors: colors,
          onTap: () => _openPhotoFlow(context),
        ),
        const SizedBox(width: 24),
        _buildSmallAction(
          context,
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Chat',
          iconColor: const Color(0xFFF97316), // orange
          colors: colors,
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/checkin');
          },
        ),
      ],
    );
  }

  Widget _buildSmallAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
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
                color: iconColor.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: iconColor.withAlpha(40)),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 24, color: iconColor),
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
    final streakCount = streak?.currentStreak ?? 0;

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final entryDays = entries.map((e) {
      final d = e.entryDate;
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
      child: Column(
        children: [
          // Header: streak info + calendar button
          Row(
            children: [
              if (streakCount > 0) ...[
                const ExcludeSemantics(
                  child: Text('\u{1F525}', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 4),
                Text(
                  '$streakCount day streak',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                  ),
                ),
              ] else
                Text(
                  'Journal Activity',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showCalendarSheet(context, colors, entries),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 7-day row
          Row(
            children: List.generate(7, (i) {
              final day = days[i];
              final isToday = day == todayNorm;
              final hasEntry = entryDays.contains(day);
              final dayName = dayNames[(day.weekday - 1) % 7];

              return Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Text(
                        dayName,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isToday ? colors.accent : colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${day.day}',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isToday ? colors.accent : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: hasEntry
                              ? colors.accent
                              : isToday
                                  ? colors.accent.withAlpha(20)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !hasEntry
                              ? Border.all(color: colors.accent.withAlpha(100), width: 1.5)
                              : !hasEntry
                                  ? Border.all(color: colors.border, width: 1.5)
                                  : null,
                        ),
                        child: hasEntry
                            ? const Center(
                                child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Opens a bottom sheet with a monthly calendar view that shows
  /// which days had journal entries. Users can navigate months.
  void _showCalendarSheet(
    BuildContext context,
    AppPalette colors,
    List<JournalEntry> entries,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _CalendarSheet(
        colors: colors,
        entries: entries,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
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
                  height: 160,
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
// Photo source choice tile (Camera / Gallery)
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final AppPalette colors;
  final VoidCallback onTap;

  const _PhotoSourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: colors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  Text(subtitle, style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textMuted),
          ],
        ),
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
