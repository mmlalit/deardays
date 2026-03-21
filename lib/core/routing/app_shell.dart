import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/services/sync/sync_service.dart';
import 'package:deardays/services/memory_tagging/memory_tagging_service.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  bool _prefetched = false;
  DateTime? _lastRefresh;

  /// Minimum gap between lifecycle-triggered refreshes. Prevents rapid
  /// invalidation if the user toggles between apps quickly.
  static const _refreshCooldown = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncService().onSyncComplete = _onSyncComplete;
    _prefetchData();
    Future.microtask(_scheduleEngagementNotifications);
  }

  /// Wires smart engagement notifications:
  ///   • On This Day — shows once per day when past entries exist.
  ///   • Streak at Risk — schedules 9 PM reminder if no entry today and streak > 0;
  ///     cancels it immediately when the user writes.
  void _scheduleEngagementNotifications() {
    // On This Day — fires when onThisDayProvider resolves with entries.
    ref.listenManual<AsyncValue<List<dynamic>>>(
      onThisDayProvider,
      (_, next) {
        final entries = next.valueOrNull;
        if (entries == null || entries.isEmpty) return;
        final first = entries.first;
        // Compute years ago from the entry date.
        final entryDate = (first.entryDate as DateTime?) ?? DateTime.now();
        final yearsAgo = DateTime.now().year - entryDate.year;
        if (yearsAgo <= 0) return;
        final excerpt = (first.polishedContent as String?)?.trim().isNotEmpty == true
            ? first.polishedContent as String
            : first.content as String;
        NotificationService().maybeShowOnThisDay(
          entryExcerpt: excerpt,
          yearsAgo: yearsAgo,
        ).ignore();
      },
      fireImmediately: true,
    );

    // Streak at Risk — cancel reminder when user has written today,
    // schedule it when they haven't (and have an active streak).
    ref.listenManual<AsyncValue<dynamic>>(
      todayEntryProvider,
      (_, next) {
        final entry = next.valueOrNull;
        if (entry != null) {
          // User wrote today — cancel any pending reminder.
          NotificationService().cancelStreakReminder().ignore();
        } else if (next.hasValue) {
          // Provider resolved with null: no entry today.
          // Schedule the reminder using the current streak from streakProvider.
          final streak = ref.read(streakProvider).valueOrNull;
          final current = streak?.currentStreak ?? 0;
          if (current > 0) {
            NotificationService()
                .scheduleStreakReminder(currentStreak: current)
                .ignore();
          }
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    SyncService().onSyncComplete = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh only if enough time has passed since the last refresh.
      final now = DateTime.now();
      if (_lastRefresh == null ||
          now.difference(_lastRefresh!) >= _refreshCooldown) {
        _invalidateAndRefresh();
        _lastRefresh = now;
      }
    }
  }

  /// Called by SyncService after pending operations sync to Supabase.
  /// Refreshes providers and triggers semantic tagging for newly synced entries.
  void _onSyncComplete(List<String> syncedEntryIds) {
    if (!mounted) return;
    _invalidateAndRefresh();
    if (syncedEntryIds.isNotEmpty) {
      _tagSyncedEntries(syncedEntryIds);
    }
  }

  Future<void> _tagSyncedEntries(List<String> entryIds) async {
    for (final id in entryIds) {
      if (!mounted) return;
      try {
        final entry = await ref.read(journalRepositoryProvider).getEntry(id);
        if (entry != null && !entry.tagsGenerated) {
          unawaited(MemoryTaggingService().tagEntry(
            entryId: id,
            content: entry.content,
          ));
        }
      } catch (_) {}
    }
  }

  /// Eagerly fetch and cache entries so screens display instantly.
  /// Runs once when the authenticated shell mounts.
  void _prefetchData() {
    if (_prefetched) return;
    _prefetched = true;

    Future.microtask(() {
      if (!mounted) return;

      _triggerProviderFetch();

      if (kDebugMode) {
        debugPrint('[AppShell] Pre-fetching data in background.');
      }
    });
  }

  /// Invalidate stale providers and re-fetch fresh data from network.
  void _invalidateAndRefresh() {
    if (!mounted) return;

    ref.invalidate(timelineEntriesProvider);
    ref.invalidate(todayEntryProvider);
    ref.invalidate(streakProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(onThisDayProvider);
    ref.invalidate(weeklyMoodsProvider);

    _triggerProviderFetch();

    if (kDebugMode) {
      debugPrint('[AppShell] Refreshing cached data.');
    }
  }

  /// Touch providers so they start fetching in the background.
  void _triggerProviderFetch() {
    ref.read(timelineEntriesProvider.future).ignore();
    ref.read(todayEntryProvider.future).ignore();
    ref.read(streakProvider.future).ignore();
    ref.read(profileProvider.future).ignore();
    ref.read(booksProvider.future).ignore();
    ref.read(chaptersProvider.future).ignore();
    ref.read(weeklyMoodsProvider.future).ignore();
    ref.read(onThisDayProvider.future).ignore();
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/book')) return 1;
    if (location.startsWith('/timeline')) return 2;
    if (location.startsWith('/explore')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final colors = AppColors.of(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _BottomNav(currentIndex: index, colors: colors),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final AppPalette colors;

  const _BottomNav({required this.currentIndex, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.navBg,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // Home
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isActive: currentIndex == 0,
                  onTap: () => context.go('/home'),
                  colors: colors,
                ),
              ),
              // Chapters
              Expanded(
                child: _NavItem(
                  icon: Icons.auto_stories_outlined,
                  activeIcon: Icons.auto_stories_rounded,
                  label: 'Chapters',
                  isActive: currentIndex == 1,
                  onTap: () => context.go('/book'),
                  colors: colors,
                ),
              ),
              // Timeline
              Expanded(
                child: _NavItem(
                  icon: Icons.timeline_outlined,
                  activeIcon: Icons.timeline_rounded,
                  label: 'Timeline',
                  isActive: currentIndex == 2,
                  onTap: () => context.go('/timeline'),
                  colors: colors,
                ),
              ),
              // Explore
              Expanded(
                child: _NavItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  label: 'Explore',
                  isActive: currentIndex == 3,
                  onTap: () => context.go('/explore'),
                  colors: colors,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final AppPalette colors;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = colors.accent;
    final inactiveColor = colors.iconInactive;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withAlpha(20) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : inactiveColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.2,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
