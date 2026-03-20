import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/widgets/dd_logo.dart';

// ── Warm cream background ─────────────────────────────────────────────────────
const _kPaper = Color(0xFFF9F7F3);
const _kTextDark = Color(0xFF111C2D);
const _kTextMuted = Color(0xFF64748B);
const _kDotInactive = Color(0xFFCBD5E1);

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _bgController;
  late final Animation<double> _bgAnimation;

  static const _pages = [
    _PageData(
      photo: 'assets/images/onboarding/ob1_speak.jpg',
      gradientColors: [Color(0xFFFF9A6C), Color(0xFFFF6B9D)],
      icon: Icons.mic_rounded,
      title: 'Speak your day',
      subtitle: 'Just talk. DearDays turns your words into beautiful, lasting stories.',
    ),
    _PageData(
      photo: 'assets/images/onboarding/ob2_journal.jpg',
      gradientColors: [Color(0xFF2DD4BF), Color(0xFF3B82F6)],
      icon: Icons.menu_book_rounded,
      title: 'Your life, one page at a time',
      subtitle: 'Every entry becomes a chapter in your own personal book.',
    ),
    _PageData(
      photo: 'assets/images/onboarding/ob3_private.jpg',
      gradientColors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
      icon: Icons.lock_rounded,
      title: 'Private by design',
      subtitle: 'End-to-end encrypted. Your story belongs to you and no one else.',
    ),
    _PageData(
      photo: 'assets/images/onboarding/ob4_memory.jpg',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      icon: Icons.auto_awesome_rounded,
      title: 'Record your first memory',
      subtitle: 'It takes 30 seconds. Speak and watch your story come to life.',
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgAnimation = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_isLastPage) {
      widget.onComplete();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kPaper,
      body: Stack(
        children: [
          // ── Main content column ──────────────────────────────────────────
          Column(
            children: [
              // ── Photo hero — takes top 58% ──────────────────────────────
              Expanded(
                flex: 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Photo — animates between pages via AnimatedSwitcher
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Image.asset(
                        page.photo,
                        key: ValueKey(page.photo),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),

                    // Dark gradient overlay — bottom of photo for legibility
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.4, 1.0],
                          colors: [Colors.transparent, Color(0xCC000000)],
                        ),
                      ),
                    ),

                    // Decorative orbs (subtle, over photo)
                    AnimatedBuilder(
                      animation: _bgAnimation,
                      builder: (_, __) => CustomPaint(
                        painter: _OrbsPainter(
                          t: _bgAnimation.value,
                          colors: page.gradientColors,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // Page icon — bottom center of hero
                    Positioned(
                      bottom: 28,
                      left: 0,
                      right: 0,
                      child: _HeroIcon(page: page),
                    ),
                  ],
                ),
              ),

              // ── Cream card — flush against photo ─────────────────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _kPaper,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  28, 28, 28, math.max(24.0, bottomPadding + 12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title + subtitle
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _BottomText(
                        key: ValueKey(_currentPage),
                        page: _pages[_currentPage],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer: Skip · Dots · Next
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Skip — bottom left
                        TextButton(
                          onPressed: widget.onComplete,
                          style: TextButton.styleFrom(
                            foregroundColor: _kTextMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kTextMuted,
                            ),
                          ),
                        ),

                        // Progress dots — center
                        Row(
                          children: List.generate(_pages.length, (i) {
                            final active = i == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: active
                                    ? LinearGradient(colors: page.gradientColors)
                                    : null,
                                color: active ? null : _kDotInactive,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),

                        // Next / Get Started — circular button
                        _NextButton(
                          isLast: _isLastPage,
                          gradientColors: page.gradientColors,
                          onTap: _onNext,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Centered brand header (over photo) ───────────────────────────
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 60,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(40),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const DdLogoWhite(size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero icon (bottom of photo) ───────────────────────────────────────────────

class _HeroIcon extends StatefulWidget {
  final _PageData page;
  const _HeroIcon({required this.page});

  @override
  State<_HeroIcon> createState() => _HeroIconState();
}

class _HeroIconState extends State<_HeroIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.page.gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.page.gradientColors.last.withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(widget.page.icon, size: 34, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── Bottom text block ─────────────────────────────────────────────────────────

class _BottomText extends StatelessWidget {
  final _PageData page;
  const _BottomText({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: _kTextDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          page.subtitle,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _kTextMuted,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

// ── Next / Start button (circular) ───────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final bool isLast;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  const _NextButton({
    required this.isLast,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isLast ? 140.0 : 56.0,
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: isLast ? 20 : 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLast
              ? Text(
                  'Get Started',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

// ── Decorative floating orbs (subtle tint over photo) ────────────────────────

class _OrbsPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  _OrbsPainter({required this.t, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.82 + math.sin(t * math.pi) * 0.06),
        size.height * (0.15 + math.cos(t * math.pi) * 0.05),
      ),
      radius: size.width * 0.38,
      color: colors.first.withAlpha(22),
    );
    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.1 + math.cos(t * math.pi) * 0.04),
        size.height * (0.65 + math.sin(t * math.pi) * 0.06),
      ),
      radius: size.width * 0.26,
      color: colors.last.withAlpha(18),
    );
  }

  void _drawOrb(Canvas canvas, {required Offset center, required double radius, required Color color}) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withAlpha(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_OrbsPainter old) => old.t != t || old.colors != colors;
}

// ── Data model ────────────────────────────────────────────────────────────────

class _PageData {
  final String photo;
  final List<Color> gradientColors;
  final IconData icon;
  final String title;
  final String subtitle;

  const _PageData({
    required this.photo,
    required this.gradientColors,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
