import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Full-screen "Memory saved successfully" confirmation screen.
///
/// Shown as a full-screen overlay after saving a memory.
class SaveSuccessOverlay {
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDismiss,
    JournalEntry? savedEntry,
    Duration displayDuration = const Duration(milliseconds: 2200),
  }) async {
    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _SaveSuccessScreen(
        onFinished: () {
          entry.remove();
          onDismiss?.call();
        },
        onViewMemory: () {
          entry.remove();
          if (savedEntry != null) {
            context.go('/timeline');
            context.push('/memory', extra: savedEntry);
          } else {
            onDismiss?.call();
          }
        },
        onRecordAnother: () {
          entry.remove();
          context.go('/home');
          context.push('/write');
        },
        onGoToTimeline: () {
          entry.remove();
          context.go('/timeline');
        },
        displayDuration: displayDuration,
      ),
    );

    overlayState.insert(entry);
  }
}

class _SaveSuccessScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback onViewMemory;
  final VoidCallback onRecordAnother;
  final VoidCallback onGoToTimeline;
  final Duration displayDuration;

  const _SaveSuccessScreen({
    required this.onFinished,
    required this.onViewMemory,
    required this.onRecordAnother,
    required this.onGoToTimeline,
    required this.displayDuration,
  });

  @override
  State<_SaveSuccessScreen> createState() => _SaveSuccessScreenState();
}

class _SaveSuccessScreenState extends State<_SaveSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _cardScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slideUp = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _cardScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.65, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return FadeTransition(
      opacity: _fadeIn,
      child: Material(
        color: colors.bg,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _slideUp.value),
              child: child,
            ),
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onFinished,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.cardBg,
                          ),
                          child: Icon(Icons.close_rounded, size: 20, color: colors.textPrimary),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Confirmation',
                            style: GoogleFonts.manrope(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // ── Celebration visual ──────────────────────────────────────
                ScaleTransition(
                  scale: _cardScale,
                  child: _buildCelebrationCard(colors),
                ),

                const SizedBox(height: 40),

                // ── Title ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Memory saved successfully.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'DearDays has safely tucked your memory away in the stars. It\'s ready whenever you wish to revisit it.',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 3),

                // ── Action buttons ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: GestureDetector(
                    onTap: widget.onViewMemory,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withAlpha(70),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'View Memory',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onRecordAnother,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: colors.accent.withAlpha(25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.accent.withAlpha(51)),
                            ),
                            child: Center(
                              child: Text(
                                'Record Another',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onGoToTimeline,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: colors.accent.withAlpha(25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.accent.withAlpha(51)),
                            ),
                            child: Center(
                              child: Text(
                                'Go to Timeline',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Rotated memory card with radial glow + floating heart & sparkles badges.
  Widget _buildCelebrationCard(AppPalette colors) {
    // 256px outer container to leave room for floating badges
    return SizedBox(
      width: 256,
      height: 256,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Radial glow behind the card (bg-primary/20 blur-3xl)
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.accent.withAlpha(60),
                  colors.accent.withAlpha(0),
                ],
              ),
            ),
          ),

          // Rotated memory card (~3°)
          Transform.rotate(
            angle: 3 * pi / 180,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withAlpha(45),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: colors.accent.withAlpha(50),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent, colors.accentLight],
                ),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 70,
                color: Colors.white.withAlpha(200),
              ),
            ),
          ),

          // Heart badge — top-right, outside the card (-top-4 -right-4 = ~ -16px)
          Positioned(
            top: 14,
            right: 14,
            child: Transform.rotate(
              angle: 12 * pi / 180, // rotate-12
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: colors.textPrimary.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.favorite_rounded, size: 22, color: colors.accent),
              ),
            ),
          ),

          // Sparkles badge — bottom-left, outside the card (-bottom-6 -left-6 = ~-24px)
          Positioned(
            bottom: 6,
            left: 6,
            child: Transform.rotate(
              angle: -12 * pi / 180, // -rotate-12
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: colors.textPrimary.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 22,
                  color: AppColors.moodOkay,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
