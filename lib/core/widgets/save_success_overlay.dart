import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/theme/app_colors.dart';

/// Full-screen "Memory saved successfully" confirmation.
///
/// Shown as a full-screen overlay after saving a memory.
class SaveSuccessOverlay {
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDismiss,
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
          onDismiss?.call();
        },
        onRecordAnother: () {
          entry.remove();
          context.pushReplacement('/record');
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
  late Animation<double> _checkScale;

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

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
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
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onFinished,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accentFaint,
                            border: Border.all(color: colors.border),
                          ),
                          child: Icon(Icons.close_rounded, size: 18, color: colors.textPrimary),
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
                      const SizedBox(width: 38),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Memory card with heart + sparkles overlays
                ScaleTransition(
                  scale: _checkScale,
                  child: _buildMemoryCard(colors),
                ),

                const SizedBox(height: 36),

                // Title
                Text(
                  'Memory saved',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'successfully.',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Aura has safely tucked your memory away in the stars. It\'s ready whenever you wish to revisit it.',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 3),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: widget.onViewMemory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
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

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onRecordAnother,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: colors.accentFaint,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: colors.border),
                            ),
                            child: Center(
                              child: Text(
                                'Record Another',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
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
                            height: 52,
                            decoration: BoxDecoration(
                              color: colors.accentFaint,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: colors.border),
                            ),
                            child: Center(
                              child: Text(
                                'Go to Timeline',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryCard(AppPalette colors) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card image/gradient
          Center(
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withAlpha(40),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.accent, colors.accentLight],
                  ),
                ),
                child: Icon(Icons.auto_stories_rounded, size: 60, color: Colors.white.withAlpha(200)),
              ),
            ),
          ),

          // Heart badge (top-right)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.favorite_rounded, size: 22, color: colors.accent),
            ),
          ),

          // Sparkles badge (bottom-left)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 22, color: Color(0xFFF59E0B)),
            ),
          ),
        ],
      ),
    );
  }
}
