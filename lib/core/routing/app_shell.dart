import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  bool _fabOpen = false;
  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnim;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/book')) return 1;
    if (location.startsWith('/timeline')) return 2;
    if (location.startsWith('/explore')) return 3;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotationAnim = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    HapticFeedback.mediumImpact();
    setState(() => _fabOpen = !_fabOpen);
    if (_fabOpen) {
      _rotationController.forward();
    } else {
      _rotationController.reverse();
    }
  }

  void _closeFab() {
    if (!_fabOpen) return;
    setState(() => _fabOpen = false);
    _rotationController.reverse();
  }

  void _navigate(String route) {
    HapticFeedback.lightImpact();
    _closeFab();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final colors = AppColors.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // nav bar: 60px fixed height + safe area + 16px gap above FAB
    final fabBottomOffset = 60.0 + bottomPadding + 16.0;

    return Scaffold(
      body: Stack(
        children: [
          // ── Routed screen ──────────────────────────────────────────────────
          widget.child,

          // ── Scrim ──────────────────────────────────────────────────────────
          if (_fabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFab,
                child: AnimatedOpacity(
                  opacity: _fabOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: Colors.black.withAlpha(80)),
                ),
              ),
            ),

          // ── FAB + mini menu ────────────────────────────────────────────────
          Positioned(
            bottom: fabBottomOffset,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Mini menu items (shown when open)
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _fabOpen
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _MiniButton(
                                icon: Icons.smart_toy_outlined,
                                label: 'Chat AI',
                                colors: colors,
                                onTap: () => _navigate('/checkin'),
                              ),
                              const SizedBox(height: 12),
                              _MiniButton(
                                icon: Icons.mic_rounded,
                                label: 'Speak',
                                colors: colors,
                                onTap: () => _navigate('/record'),
                              ),
                              const SizedBox(height: 12),
                              _MiniButton(
                                icon: Icons.edit_note_rounded,
                                label: 'Write',
                                colors: colors,
                                onTap: () => _navigate('/write'),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Main FAB
                GestureDetector(
                  onTap: _toggleFab,
                  child: AnimatedBuilder(
                    animation: _rotationAnim,
                    builder: (_, child) => Transform.rotate(
                      angle: _rotationAnim.value * 2 * 3.14159265,
                      child: child,
                    ),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withAlpha(80),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(currentIndex: index, colors: colors),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini FAB option button
// ─────────────────────────────────────────────────────────────────────────────

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette colors;
  final VoidCallback onTap;

  const _MiniButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.textPrimary.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: colors.accent),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
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
