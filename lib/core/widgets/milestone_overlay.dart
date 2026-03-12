import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';

/// Full-screen celebration overlay shown when the user hits a streak milestone.
///
/// Usage:
///   MilestoneOverlay.show(context, days: 7, longestStreak: 14);
class MilestoneOverlay {
  static Future<void> show(
    BuildContext context, {
    required int days,
    int longestStreak = 0,
  }) async {
    HapticFeedback.heavyImpact();

    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _MilestoneWidget(
        days: days,
        longestStreak: longestStreak,
        onClose: () => entry.remove(),
      ),
    );

    overlayState.insert(entry);
  }
}

class _MilestoneWidget extends StatefulWidget {
  final int days;
  final int longestStreak;
  final VoidCallback onClose;

  const _MilestoneWidget({
    required this.days,
    required this.longestStreak,
    required this.onClose,
  });

  @override
  State<_MilestoneWidget> createState() => _MilestoneWidgetState();
}

class _MilestoneWidgetState extends State<_MilestoneWidget>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _bounceController;
  late AnimationController _countdownController;
  late AnimationController _confettiController;

  late Animation<double> _cardScale;
  late Animation<double> _bgFade;
  late Animation<double> _bounceAnim;

  static const _autoDismissDuration = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();

    // Entrance animation (card scales in)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _cardScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Emoji bounce animation (looping)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _bounceAnim = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Countdown bar (linear, 8 seconds)
    _countdownController = AnimationController(
      vsync: this,
      duration: _autoDismissDuration,
    );

    // Confetti scatter animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Start animations
    _entranceController.forward();
    _bounceController.repeat(reverse: true);
    _countdownController.forward().then((_) {
      if (mounted) widget.onClose();
    });
    _confettiController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _bounceController.dispose();
    _countdownController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _headline() {
    switch (widget.days) {
      case 7:
        return '7 Day Streak!';
      case 30:
        return '30 Days!';
      case 100:
        return '100 Days!';
      case 365:
        return 'One Year!';
      default:
        return '${widget.days} Day Streak!';
    }
  }

  String _subtitle() {
    switch (widget.days) {
      case 7:
        return 'A week of memories. You\'re building something beautiful.';
      case 30:
        return '30 days of showing up for yourself. That\'s incredible.';
      case 100:
        return '100 days! Your story is a masterpiece in the making.';
      case 365:
        return 'One full year. Your journal is a treasure.';
      default:
        return 'Every day you write, your story grows richer.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: _bgFade,
      builder: (context, child) => Material(
        color: Colors.black.withAlpha((_bgFade.value * 180).round()),
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onClose,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Center(
            child: GestureDetector(
              // Prevent tap-inside from closing the overlay
              onTap: () {},
              child: ScaleTransition(
                scale: _cardScale,
                child: _buildCard(colors),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AppPalette colors) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Confetti dots ────────────────────────────────────────────────
          _buildConfettiRow(),
          const SizedBox(height: 20),

          // ── Emoji with bounce ────────────────────────────────────────────
          AnimatedBuilder(
            animation: _bounceAnim,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _bounceAnim.value),
              child: child,
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 72)),
          ),
          const SizedBox(height: 20),

          // ── Headline ─────────────────────────────────────────────────────
          Text(
            _headline(),
            style: GoogleFonts.newsreader(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.of(context).textPrimary,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // ── Subtitle ─────────────────────────────────────────────────────
          Text(
            _subtitle(),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.of(context).textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ── Longest streak stat ──────────────────────────────────────────
          if (widget.longestStreak > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.of(context).accentFaint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Longest streak: ${widget.longestStreak} days',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(context).accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 24),

          // ── Buttons ──────────────────────────────────────────────────────
          Row(
            children: [
              // Primary: Keep Writing
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onClose();
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Keep Writing →',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Secondary: Share
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onClose();
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text('Share your streak from Settings > Export'),
                      ),
                    );
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.of(context).border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Share',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(context).textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Countdown bar ────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _countdownController,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1.0 - _countdownController.value,
                    minHeight: 3,
                    backgroundColor: AppColors.of(context).border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.of(context).accent.withAlpha(120),
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

  Widget _buildConfettiRow() {
    // 6 colored dots from the mood palette — scatter via animation
    final dotColors = [
      AppColors.moodGreat,
      AppColors.moodGood,
      AppColors.moodOkay,
      AppColors.moodLow,
      AppColors.rose,
      AppColors.purple,
    ];

    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, _) {
        return SizedBox(
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(dotColors.length, (i) {
              // Each dot has a slightly different scatter curve
              final t = (_confettiController.value - i * 0.05).clamp(0.0, 1.0);
              final offset = Curves.easeOutBack.transform(t);
              final yOffset = -12.0 * offset * ((i % 2 == 0) ? 1.0 : 0.6);
              return Transform.translate(
                offset: Offset(0, yOffset),
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: dotColors[i],
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
