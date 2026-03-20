import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/widgets/dd_logo.dart';

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
      gradientColors: [Color(0xFFFF9A6C), Color(0xFFFF6B9D)],
      icon: Icons.mic_rounded,
      title: 'Speak your day',
      subtitle: 'Just talk. DearDays turns your words into beautiful, lasting stories.',
    ),
    _PageData(
      gradientColors: [Color(0xFF2DD4BF), Color(0xFF3B82F6)],
      icon: Icons.menu_book_rounded,
      title: 'Your life, one page at a time',
      subtitle: 'Every entry becomes a chapter in your own personal book.',
    ),
    _PageData(
      gradientColors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
      icon: Icons.lock_rounded,
      title: 'Private by design',
      subtitle: 'End-to-end encrypted. Your story belongs to you and no one else.',
    ),
    _PageData(
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
    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.58;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Full-bleed gradient hero ─────────────────────────────────────
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (_, __) => Positioned(
              top: 0, left: 0, right: 0,
              height: heroHeight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: page.gradientColors,
                  ),
                ),
                child: _DecorativeOrbs(animation: _bgAnimation, colors: page.gradientColors),
              ),
            ),
          ),

          // ── Skip button (white, on gradient) ────────────────────────────
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 20),
                child: TextButton(
                  onPressed: widget.onComplete,
                  style: TextButton.styleFrom(foregroundColor: Colors.white.withAlpha(200)),
                  child: Text('Skip', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),

          // ── Main content column ──────────────────────────────────────────
          Column(
            children: [
              // Hero emoji section — swipeable
              Expanded(
                flex: 10,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _HeroContent(page: _pages[i], isFirst: i == 0),
                ),
              ),

              // ── White card — overlaps gradient by 28px ───────────────────
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(14),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
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

                      const SizedBox(height: 20),

                      // Dots + Next button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: List.generate(_pages.length, (i) {
                              final active = i == _currentPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(right: 6),
                                width: active ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: active
                                      ? LinearGradient(colors: _pages[_currentPage].gradientColors)
                                      : null,
                                  color: active ? null : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          _NextButton(
                            isLast: _isLastPage,
                            gradientColors: page.gradientColors,
                            onTap: _onNext,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Hero content (emoji + optional logo) ─────────────────────────────────────

class _HeroContent extends StatefulWidget {
  final _PageData page;
  final bool isFirst;
  const _HeroContent({required this.page, required this.isFirst});

  @override
  State<_HeroContent> createState() => _HeroContentState();
}

class _HeroContentState extends State<_HeroContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isFirst) ...[
              const DdLogoWhite(size: 56),
              const SizedBox(height: 18),
            ],
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(35),
                border: Border.all(color: Colors.white.withAlpha(90), width: 2),
              ),
              child: Icon(widget.page.icon, size: 46, color: Colors.white),
            ),
          ],
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
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
            height: 1.25,
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
            color: const Color(0xFF64748B),
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

// ── Next / Start button ───────────────────────────────────────────────────────

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
        height: 52,
        padding: EdgeInsets.symmetric(horizontal: isLast ? 24 : 0),
        width: isLast ? 148.0 : 52.0,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withAlpha(70),
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
              : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── Decorative floating orbs in hero ─────────────────────────────────────────

class _DecorativeOrbs extends StatelessWidget {
  final Animation<double> animation;
  final List<Color> colors;
  const _DecorativeOrbs({required this.animation, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        return CustomPaint(
          painter: _OrbsPainter(t: t, colors: colors),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _OrbsPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  _OrbsPainter({required this.t, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    // Large soft orb — top right, drifts slowly
    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.78 + math.sin(t * math.pi) * 0.06),
        size.height * (0.18 + math.cos(t * math.pi) * 0.05),
      ),
      radius: size.width * 0.44,
      color: Colors.white.withAlpha(28),
    );

    // Small orb — bottom left
    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.12 + math.cos(t * math.pi) * 0.04),
        size.height * (0.72 + math.sin(t * math.pi) * 0.06),
      ),
      radius: size.width * 0.28,
      color: Colors.white.withAlpha(20),
    );

    // Tiny accent orb — top left
    _drawOrb(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.14),
      radius: size.width * 0.14,
      color: Colors.white.withAlpha(15),
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
  final List<Color> gradientColors;
  final IconData icon;
  final String title;
  final String subtitle;

  const _PageData({
    required this.gradientColors,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
