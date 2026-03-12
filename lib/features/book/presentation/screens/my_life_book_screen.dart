import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class MyLifeBookScreen extends StatefulWidget {
  const MyLifeBookScreen({super.key});

  @override
  State<MyLifeBookScreen> createState() => _MyLifeBookScreenState();
}

class _MyLifeBookScreenState extends State<MyLifeBookScreen>
    with TickerProviderStateMixin {
  int _activeChapterIndex = 0;
  final _scrollController = ScrollController();

  // ── Demo chapters (6 chapters, 45 memories total) ──────────────────────────

  static const _chapters = [
    _Chapter(
      number: '01',
      title: 'New Year Beginnings',
      subtitle: 'FRESH STARTS',
      monthYear: 'January 2026',
      entryCount: 9,
      mood: 'Hopeful',
      moodColor: Color(0xFF4ADE80),
      body:
          'It arrived quietly — January, carrying the clean smell of cold air and new resolve. I stood at the window with my coffee, watching frost trace patterns on the glass, and felt the peculiar lightness that comes with a blank calendar.\n\n'
          'Resolutions feel different this year. Less a list of improvements, more a gentle promise: to notice more, to hold things lightly, to let the days accumulate into something that matters.\n\n'
          'My mother called in the evening. We talked for an hour about nothing in particular — recipes, the neighbor\'s new dog, a film she had seen twice. When I hung up I realized I was smiling.',
      photoUrl:
          'https://images.unsplash.com/photo-1516912481808-3406841bd33c?w=800&fit=crop',
      photoCaption: 'January light through the kitchen window.',
    ),
    _Chapter(
      number: '02',
      title: 'Love & Connection',
      subtitle: 'HEARTS THAT HOLD US',
      monthYear: 'February 2026',
      entryCount: 6,
      mood: 'Warm',
      moodColor: Color(0xFFF472B6),
      body:
          'February has always felt like an invitation to slow down and look at the people around me. Not the grand declarations — though those have their place — but the small, everyday proofs of love that are too easy to rush past.\n\n'
          'This morning my partner left a cup of tea on my desk before I was even awake. The cup was exactly right: not too hot, the way I like it. That small act felt like a whole conversation.\n\n'
          'We walked through the botanical gardens in the afternoon, coats pulled tight against the wind. The rose bushes were bare and knotted, but somehow beautiful for it.',
      photoUrl: null,
      photoCaption: null,
    ),
    _Chapter(
      number: '03',
      title: 'Family Life',
      subtitle: 'THE EARLY FOUNDATIONS',
      monthYear: 'March 2026',
      entryCount: 12,
      mood: 'Serene',
      moodColor: Color(0xFF6B8CFF),
      body:
          'It began in a small house with a blue door. The smell of cedarwood and morning coffee is my earliest anchor to this world. My father used to say that a house isn\'t built of wood and stone, but of the echoes of the laughter that rings within its walls.\n\n'
          'I remember the sunlight streaming through the kitchen window, hitting the linoleum floor in perfect geometric shapes. I would sit there for hours, watching dust motes dance in the light, feeling the immense safety of a world that hadn\'t yet grown beyond our backyard fence.\n\n'
          'Mother was the quiet architect of our daily rituals. The way she folded the laundry, with a precision that seemed almost sacred, taught me my first lesson in mindfulness. Every crease was a silent testament to her care for us.',
      photoUrl:
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&fit=crop',
      photoCaption: 'Morning rituals and the scent of fresh coffee.',
    ),
    _Chapter(
      number: '04',
      title: 'Spring Blooms',
      subtitle: 'NEW BEGINNINGS',
      monthYear: 'April 2026',
      entryCount: 8,
      mood: 'Joyful',
      moodColor: Color(0xFFFBBF24),
      body:
          'April arrived like a quiet apology from winter. The cherry blossoms came first, carpeting the sidewalks in pale pink. I found myself walking slower these days, noticing things I had always overlooked — the particular shade of green in fresh leaves, the way early morning mist lingers over the park before the city wakes.\n\n'
          'There\'s something about spring that makes you want to start again. I decided to write more, to capture these small moments before they dissolve into the rhythm of ordinary days. The garden is coming back to life.',
      photoUrl:
          'https://images.unsplash.com/photo-1490750967868-88df5691cc51?w=800&fit=crop',
      photoCaption: 'Cherry blossoms on the walk to work.',
    ),
    _Chapter(
      number: '05',
      title: 'Growth & Change',
      subtitle: 'BECOMING',
      monthYear: 'May 2026',
      entryCount: 5,
      mood: 'Reflective',
      moodColor: Color(0xFFA78BFA),
      body:
          'May is the month I turned thirty-one. Unremarkable by most measures, and yet I spent the better part of a week thinking about growth — the kind that doesn\'t announce itself but shows up one day in the choices you make without having to think.\n\n'
          'I said no to something that would have taken six months and left me depleted. I said yes to an afternoon hike with no purpose beyond being outside. Both decisions felt right in a way that surprised me.',
      photoUrl: null,
      photoCaption: null,
    ),
    _Chapter(
      number: '06',
      title: 'Summer Adventures',
      subtitle: 'EXPLORING THE UNKNOWN',
      monthYear: 'June 2026',
      entryCount: 5,
      mood: 'Excited',
      moodColor: Color(0xFFFB923C),
      body:
          'The trip north was decided on a Thursday evening. By Saturday morning we were on the road, the city dissolving behind us into farmland and then forest. There is a particular kind of freedom in movement — the way the world reorganizes itself when you change your position in it.\n\n'
          'We stopped at a roadside diner where the pie was exceptional and the coffee was not. We didn\'t care. Everything tastes better when you\'re going somewhere.',
      photoUrl:
          'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800&fit=crop',
      photoCaption: 'The open road heading north, early morning.',
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Chapter selection with page-turn animation ──────────────────────────────

  void _selectChapter(int index) {
    if (index == _activeChapterIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _activeChapterIndex = index);
    // Scroll to content area after a short delay to let the animation start
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          // Scroll to approximately where chapter content starts
          _scrollController.position.maxScrollExtent * 0.35,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildHeader(context),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildCoverCard(context),
                    _buildContentsSection(context),
                    // Page-turn animation wraps only the chapter reading area
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 650),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: _pageTransitionBuilder,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topLeft,
                        children: [...previous, if (current != null) current],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_activeChapterIndex),
                        child: _buildChapterContent(
                            context, _chapters[_activeChapterIndex]),
                      ),
                    ),
                    _buildContinueHint(context),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          // Floating bottom nav
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: _buildFloatingNav(context),
          ),
        ],
      ),
    );
  }

  // ── Page-turn transition ────────────────────────────────────────────────────

  static Widget _pageTransitionBuilder(
      Widget child, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value; // incoming: 0→1 | outgoing: 1→0
        final isOutgoing = animation.status == AnimationStatus.reverse ||
            animation.status == AnimationStatus.dismissed;

        // Slide: outgoing goes left, incoming comes from right
        final dx = isOutgoing ? -(1.0 - t) : (1.0 - t);

        // 3-D tilt: slight Y rotation that straightens as page settles
        final angle = isOutgoing
            ? -(1.0 - t) * math.pi / 14 // outgoing tilts away
            : (1.0 - t) * math.pi / 14; // incoming arrives straight

        // Subtle shadow overlay on leading edge
        final shadowOpacity = isOutgoing ? (1.0 - t) * 0.18 : (1.0 - t) * 0.12;

        return ClipRect(
          child: FractionalTranslation(
            translation: Offset(dx, 0),
            child: Transform(
              alignment: isOutgoing
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective depth
                ..rotateY(angle),
              child: Stack(
                children: [
                  child!,
                  // Page-edge shadow
                  if (isOutgoing)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: 18,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(
                                  (shadowOpacity * 255).round()),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  SliverAppBar _buildHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xF2F8FAFC),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: const Color(0xFF0F172A),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'My Life Book',
        style: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF195DE6).withAlpha(22),
            child: const Icon(
              Icons.account_circle_rounded,
              color: Color(0xFF195DE6),
              size: 22,
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.black.withAlpha(15)),
      ),
    );
  }

  // ── Cover card ──────────────────────────────────────────────────────────────

  Widget _buildCoverCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 270,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl:
                    'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=900&fit=crop',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: const Color(0xFF1E293B)),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x330F172A), Color(0xF50F172A)],
                    stops: [0.0, 0.72],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _pill('VOLUME I'),
                    const SizedBox(height: 10),
                    Text(
                      'The Digital Autobiography',
                      style: GoogleFonts.newsreader(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A continuous journey of a life well lived',
                      style: GoogleFonts.newsreader(
                        fontSize: 13,
                        color: Colors.white.withAlpha(190),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'READING PROGRESS',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white.withAlpha(170),
                          ),
                        ),
                        Text(
                          '35%',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Colors.white.withAlpha(170),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.35,
                        backgroundColor: Colors.white.withAlpha(45),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF195DE6),
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${_chapters.length - 2} CHAPTERS REMAINING',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: Colors.white.withAlpha(110),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF195DE6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: Colors.white,
        ),
      ),
    );
  }

  // ── Contents ────────────────────────────────────────────────────────────────

  Widget _buildContentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
          child: Text(
            'Contents',
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF195DE6),
            ),
          ),
        ),
        ..._chapters.asMap().entries.map((e) {
          final i = e.key;
          final ch = e.value;
          final isActive = _activeChapterIndex == i;
          return GestureDetector(
            onTap: () => _selectChapter(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF195DE6).withAlpha(14)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isActive
                        ? const Color(0xFF195DE6)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      ch.number,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF195DE6)
                            .withAlpha(isActive ? 210 : 100),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ch.monthYear}: ${ch.title}',
                          style: GoogleFonts.newsreader(
                            fontSize: 15,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: const Color(0xFF0F172A),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'CHAPTER ${i + 1} • ${ch.entryCount} ENTRIES',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isActive ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_right_rounded,
                      size: 20,
                      color: isActive
                          ? const Color(0xFF195DE6)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Divider(color: Colors.black.withAlpha(12), height: 1),
        ),
      ],
    );
  }

  // ── Chapter reading content ─────────────────────────────────────────────────

  Widget _buildChapterContent(BuildContext context, _Chapter ch) {
    final chapterNum = _chapters.indexOf(ch) + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chapter heading block
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 1,
                color: const Color(0xFF195DE6).withAlpha(65),
              ),
              const SizedBox(height: 22),
              Text(
                'Chapter $chapterNum: ${ch.title}',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ch.subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: const Color(0xFF195DE6),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 48,
                height: 1,
                color: const Color(0xFF195DE6).withAlpha(65),
              ),
            ],
          ),
        ),

        // Date + mood meta
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Text(
                ch.monthYear.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'MOOD: ${ch.mood.toUpperCase()}',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: ch.moodColor,
                ),
              ),
            ],
          ),
        ),

        // Body text on warm reading background
        const SizedBox(height: 20),
        Container(
          color: AppColors.readingBg,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: _buildArticleBody(ch.body),
        ),

        // Inline photo
        if (ch.photoUrl != null) ...[
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: ch.photoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                if (ch.photoCaption != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    ch.photoCaption!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArticleBody(String text) {
    final paragraphs =
        text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropCapParagraph(paragraphs.first),
        ...paragraphs.skip(1).map(
              (p) => Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  p,
                  style: GoogleFonts.newsreader(
                    fontSize: 17,
                    height: 1.75,
                    color: AppColors.readingText,
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildDropCapParagraph(String text) {
    if (text.length < 2) {
      return Text(
        text,
        style: GoogleFonts.newsreader(
          fontSize: 17,
          height: 1.75,
          color: AppColors.readingText,
        ),
      );
    }
    final first = text[0].toUpperCase();
    final rest = text.substring(1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          first,
          style: GoogleFonts.newsreader(
            fontSize: 62,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF195DE6),
            height: 0.85,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            rest,
            style: GoogleFonts.newsreader(
              fontSize: 17,
              height: 1.75,
              color: AppColors.readingText,
            ),
          ),
        ),
      ],
    );
  }

  // ── Continue hint ───────────────────────────────────────────────────────────

  Widget _buildContinueHint(BuildContext context) {
    if (_activeChapterIndex >= _chapters.length - 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'You\'ve reached the end of your story so far.',
            style: GoogleFonts.newsreader(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: GestureDetector(
          onTap: () => _selectChapter(_activeChapterIndex + 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Continued in Chapter ${_activeChapterIndex + 2}',
                style: GoogleFonts.newsreader(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_downward_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Floating bottom nav ─────────────────────────────────────────────────────

  Widget _buildFloatingNav(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(225),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.black.withAlpha(15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(28),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navAction(Icons.bookmark_outline_rounded, 'SAVE', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Book saved to your library',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }),
              _navAction(Icons.share_outlined, 'SHARE', () {
                _showShareSheet(context);
              }),
              Transform.translate(
                offset: const Offset(0, -10),
                child: GestureDetector(
                  onTap: () => HapticFeedback.mediumImpact(),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF195DE6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF195DE6).withAlpha(100),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              _navAction(Icons.headphones_outlined, 'LISTEN', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Audio narration coming soon',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF64748B),
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }),
              _navAction(Icons.tune_rounded, 'DISPLAY', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Display settings coming soon',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF64748B),
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8).withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Share Your Story',
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF195DE6)),
                title: Text('Export as PDF', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Download a beautifully formatted book', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8))),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/export');
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded, color: Color(0xFF195DE6)),
                title: Text('Copy Link', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Share a read-only link to your book', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8))),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Link sharing coming soon', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF64748B),
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF64748B)),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _Chapter {
  final String number;
  final String title;
  final String subtitle;
  final String monthYear;
  final int entryCount;
  final String mood;
  final Color moodColor;
  final String body;
  final String? photoUrl;
  final String? photoCaption;

  const _Chapter({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.monthYear,
    required this.entryCount,
    required this.mood,
    required this.moodColor,
    required this.body,
    required this.photoUrl,
    required this.photoCaption,
  });
}
