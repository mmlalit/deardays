import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/onboarding_provider.dart';
import 'package:deardays/core/onboarding/sample_memory.dart';
import 'package:deardays/core/utils/photo_crop_helper.dart';
import 'package:deardays/core/widgets/app_avatar.dart';
import 'package:deardays/core/widgets/dd_logo.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/services/sync/sync_service.dart';
import 'package:deardays/services/memory_tagging/memory_tagging_service.dart';
import 'package:deardays/core/widgets/offline_banner.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  bool _prefetched = false;
  DateTime? _lastRefresh;

  /// Minimum gap between lifecycle-triggered refreshes.
  static const _refreshCooldown = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncService().onSyncComplete = _onSyncComplete;
    _prefetchData();
    Future.microtask(_scheduleEngagementNotifications);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final navigatorKey = GoRouter.of(context).routerDelegate.navigatorKey;
        NotificationService().setNavigatorKey(navigatorKey);
      }
    });
  }

  void _scheduleEngagementNotifications() {
    ref.listenManual<AsyncValue<List<dynamic>>>(
      onThisDayProvider,
      (_, next) {
        final entries = next.valueOrNull;
        if (entries == null || entries.isEmpty) return;
        final first = entries.first;
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

    ref.listenManual<AsyncValue<dynamic>>(
      todayEntryProvider,
      (_, next) {
        final entry = next.valueOrNull;
        if (entry != null) {
          NotificationService().cancelStreakReminder().ignore();
        } else if (next.hasValue) {
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
      final now = DateTime.now();
      if (_lastRefresh == null ||
          now.difference(_lastRefresh!) >= _refreshCooldown) {
        _invalidateAndRefresh();
        _lastRefresh = now;
      }
    }
  }

  void _onSyncComplete(List<String> syncedEntryIds) {
    if (!mounted) return;
    _invalidateAndRefresh();
    if (syncedEntryIds.isNotEmpty) {
      _tagSyncedEntries(syncedEntryIds);
    }
  }

  Future<void> _tagSyncedEntries(List<String> entryIds) async {
    if (!mounted || entryIds.isEmpty) return;
    try {
      // Fetch all synced entries in parallel instead of sequential N+1 queries.
      final repo = ref.read(journalRepositoryProvider);
      final entries = await Future.wait(
        entryIds.map((id) => repo.getEntry(id).catchError((Object e) {
          debugPrint('[AppShell] tagSync fetch error for $id: $e');
          return null;
        })),
      );
      for (final entry in entries) {
        if (!mounted) return;
        if (entry != null && !entry.tagsGenerated) {
          unawaited(MemoryTaggingService().tagEntry(
            entryId: entry.id,
            content: entry.content,
          ).catchError((Object e) {
            debugPrint('[AppShell] tagEntry error: $e');
          }));
        }
      }
    } catch (e) {
      debugPrint('[AppShell] tagSync error: $e');
    }
  }

  void _prefetchData() {
    if (_prefetched) return;
    _prefetched = true;

    Future.microtask(() async {
      if (!mounted) return;
      _triggerProviderFetch();
      _maybeSeedSampleMemory();
      _ensureDefaultChapters();
      if (kDebugMode) debugPrint('[AppShell] Pre-fetching data in background.');
    });
  }

  /// Seeds the 4 default chapters (Family, Career, Travel, Personal Growth)
  /// if the user has none, then invalidates chaptersProvider so the UI reloads.
  /// Gated behind onboarding state so we don't call on every mount.
  bool _chaptersSeeded = false;
  Future<void> _ensureDefaultChapters() async {
    if (_chaptersSeeded) return;
    _chaptersSeeded = true;
    try {
      await ref.read(profileRepositoryProvider).seedDefaultChapters();
      ref.invalidate(chaptersProvider);
    } catch (e) {
      _chaptersSeeded = false; // allow retry on next mount
      if (kDebugMode) debugPrint('[AppShell] seedDefaultChapters error: $e');
    }
  }

  Future<void> _maybeSeedSampleMemory() async {
    final onboarding = ref.read(onboardingProvider);
    if (onboarding.sampleMemorySeeded) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final entries = await ref.read(timelineEntriesProvider.future);
      final hasRealEntries = entries.any((e) => !isSampleEntry(e));
      if (hasRealEntries) {
        ref.read(onboardingProvider.notifier).markSampleMemorySeeded();
        return;
      }
      final sample = buildSampleMemory(userId: userId);
      await ref.read(journalRepositoryProvider).createEntry(sample);
      ref.read(onboardingProvider.notifier).markSampleMemorySeeded();
      ref.invalidate(timelineEntriesProvider);
    } catch (_) {}
  }

  void _invalidateAndRefresh() {
    if (!mounted) return;
    ref.invalidate(timelineEntriesProvider);
    ref.invalidate(todayEntryProvider);
    ref.invalidate(streakProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(onThisDayProvider);
    ref.invalidate(weeklyMoodsProvider);
    _triggerProviderFetch();
    if (kDebugMode) debugPrint('[AppShell] Refreshing cached data.');
  }

  void _triggerProviderFetch() {
    // ignore: unawaited_futures — fire-and-forget prefetch; errors are logged
    ref.read(timelineEntriesProvider.future).then<void>((_) {}).catchError((Object e, StackTrace st) { debugPrint('[AppShell] Prefetch failed (timeline): $e\n$st'); });
    ref.read(todayEntryProvider.future).then<void>((_) {}).catchError((Object e, StackTrace st) { debugPrint('[AppShell] Prefetch failed (today): $e\n$st'); });
    ref.read(streakProvider.future).then<void>((_) {}).catchError((Object e, StackTrace st) { debugPrint('[AppShell] Prefetch failed (streak): $e\n$st'); });
    ref.read(profileProvider.future).then<void>((_) {}).catchError((Object e, StackTrace st) { debugPrint('[AppShell] Prefetch failed (profile): $e\n$st'); });
    ref.read(booksProvider.future).then<void>((_) {}).catchError((Object e, StackTrace st) { debugPrint('[AppShell] Prefetch failed (books): $e\n$st'); });
    ref.read(chaptersProvider.future).then<void>((_) {}).catchError((Object e, StackTrace st) { debugPrint('[AppShell] Prefetch failed (chapters): $e\n$st'); });
    ref.read(weeklyMoodsProvider.future).then<void>((_) {}).catchError((Object e, StackTrace st) { debugPrint('[AppShell] Prefetch failed (moods): $e\n$st'); });
    ref.read(onThisDayProvider.future).then<void>((_) {}).catchError((Object e, StackTrace st) { debugPrint('[AppShell] Prefetch failed (onThisDay): $e\n$st'); });
  }

  Future<void> _openCameraDirectly() async {
    HapticFeedback.mediumImpact();

    // On mobile, request camera permission before opening the camera.
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to snap a photo.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final picker = ImagePicker();
    XFile? photo;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    }

    if (photo != null && mounted) {
      String finalPath = photo.path;
      try {
        final cropped = await cropPhoto(photo.path);
        finalPath = cropped ?? photo.path;
      } catch (e) {
        debugPrint('[AppShell] cropPhoto failed, using original: $e');
      }
      if (mounted) context.push('/photo-entry', extra: finalPath);
    }
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

    // Remove top padding so the glass header handles it instead of SafeArea in children.
    final childWithoutTopPad = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: widget.child,
    );

    return Scaffold(
      backgroundColor: colors.bg,
      extendBody: true, // content scrolls under glass bottom nav
      body: Column(
        children: [
          _GlassHeader(colors: colors),
          const OfflineBanner(),
          Expanded(child: childWithoutTopPad),
        ],
      ),
      floatingActionButton: _SnapFab(onTap: _openCameraDirectly),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _GlassBottomNav(currentIndex: index, colors: colors),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Header
// ─────────────────────────────────────────────────────────────────────────────

class _GlassHeader extends ConsumerWidget {
  final AppPalette colors;
  const _GlassHeader({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: colors.navBg,
            border: Border(
              bottom: BorderSide(color: const Color(0xFF6366F1).withAlpha(18), width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Logo + App name (HTML: menu icon + "The Chronicler")
                    const DdLogo(size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'DearDays',
                      style: GoogleFonts.newsreader(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    // Search
                    Semantics(
                      label: 'Search',
                      button: true,
                      child: GestureDetector(
                        onTap: () => context.push('/search'),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.search_rounded, size: 20, color: colors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Avatar (HTML: circular avatar with border)
                    GestureDetector(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6366F1).withAlpha(30),
                            width: 2,
                          ),
                        ),
                        child: const AppAvatar(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Snap FAB
// ─────────────────────────────────────────────────────────────────────────────

class _SnapFab extends StatelessWidget {
  final VoidCallback onTap;
  const _SnapFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x406366F1),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'shell-snap-fab',
        onPressed: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Bottom Nav
// ─────────────────────────────────────────────────────────────────────────────

class _GlassBottomNav extends ConsumerWidget {
  final int currentIndex;
  final AppPalette colors;

  const _GlassBottomNav({required this.currentIndex, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unvisited = ref.watch(onboardingProvider).unvisitedTabs;
    final notifier = ref.read(onboardingProvider.notifier);

    void goAndMark(String route, String tabKey) {
      if (unvisited.contains(tabKey)) notifier.markTabVisited(tabKey);
      context.go(route);
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: BottomAppBar(
          color: colors.navBg.withAlpha(204), // ~0.8 opacity glass
          elevation: 0,
          notchMargin: 8,
          shape: const CircularNotchedRectangle(),
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                // Left side: HOME + CHAPTERS
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                    isActive: currentIndex == 0,
                    showBadge: false,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.go('/home');
                    },
                    colors: colors,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.auto_stories_outlined,
                    activeIcon: Icons.auto_stories_rounded,
                    label: 'Chapters',
                    isActive: currentIndex == 1,
                    showBadge: unvisited.contains('chapters'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      goAndMark('/book', 'chapters');
                    },
                    colors: colors,
                  ),
                ),
                // Center gap for FAB
                const SizedBox(width: 72),
                // Right side: TIMELINE + EXPLORE
                Expanded(
                  child: _NavItem(
                    icon: Icons.timeline_outlined,
                    activeIcon: Icons.timeline_rounded,
                    label: 'Timeline',
                    isActive: currentIndex == 2,
                    showBadge: unvisited.contains('timeline'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      goAndMark('/timeline', 'timeline');
                    },
                    colors: colors,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore_rounded,
                    label: 'Explore',
                    isActive: currentIndex == 3,
                    showBadge: unvisited.contains('explore'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      goAndMark('/explore', 'explore');
                    },
                    colors: colors,
                  ),
                ),
              ],
            ),
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
  final bool showBadge;
  final VoidCallback onTap;
  final AppPalette colors;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.showBadge,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = colors.accent;
    final inactiveColor = colors.iconInactive;

    return Semantics(
      label: label,
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                if (showBadge && !isActive)
                  Positioned(
                    top: 2,
                    right: 8,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            ExcludeSemantics(
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 1.2,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
