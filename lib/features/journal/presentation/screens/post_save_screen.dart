import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';

/// Lightweight data object passed from ReviewSaveScreen -> PostSaveScreen.
class PostSaveData {
  final String entryId;
  final String title;
  final String content;

  const PostSaveData({
    required this.entryId,
    required this.title,
    required this.content,
  });
}

class PostSaveScreen extends ConsumerStatefulWidget {
  final PostSaveData? data;

  const PostSaveScreen({super.key, this.data});

  @override
  ConsumerState<PostSaveScreen> createState() => _PostSaveScreenState();
}

class _PostSaveScreenState extends ConsumerState<PostSaveScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0 = chapter, 1 = confirmation

  // Chapter
  String? _selectedChapterId;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _next() {
    if (_currentStep == 0 && _selectedChapterId != null) {
      _goToStep(1); // Go to confirmation
    }
    // Do nothing if no chapter selected
  }

  void _skipAll() {
    _finish();
  }

  void _finish() {
    HapticFeedback.lightImpact();
    ref.read(postSaveDataProvider.notifier).state = null;
    context.go('/home');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          // Header only on chapter step
          if (_currentStep == 0) _buildHeader(colors),
          if (_currentStep == 0) _buildProgressIndicator(colors),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildChapterStep(colors),
                _buildConfirmationStep(colors),
              ],
            ),
          ),
          // Bottom bar only on chapter step
          if (_currentStep == 0) _buildBottomBar(colors),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header (chapter step only)
  // ---------------------------------------------------------------------------

  Widget _buildHeader(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (Navigator.of(context).canPop()) {
                    context.pop();
                  } else {
                    _finish();
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withAlpha(15),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.arrow_back_rounded, size: 20, color: colors.textPrimary),
                ),
              ),
              Expanded(
                child: Text(
                  'Organize Memory',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _skipAll,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.close_rounded, size: 22, color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress indicator (only for chapter step)
  // ---------------------------------------------------------------------------

  Widget _buildProgressIndicator(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: colors.accent,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Chapters (required selection)
  // ---------------------------------------------------------------------------

  Widget _buildChapterStep(AppPalette colors) {
    final chaptersAsync = ref.watch(chaptersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add to a chapter',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Select a chapter to organize this memory.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          chaptersAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => _buildMockChapters(colors),
            data: (chapters) {
              if (chapters.isEmpty) return _buildMockChapters(colors);
              return Column(
                children: chapters
                    .map((c) => _buildChapterCard(c.id, c.title, c.entryCount, colors))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 12),

          // Create new chapter option
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Create chapter coming soon',
                    style: GoogleFonts.manrope(fontSize: 13),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.accent.withAlpha(80),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20, color: colors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Create New Chapter',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback mock chapters when no real data is available.
  Widget _buildMockChapters(AppPalette colors) {
    final mockChapters = [
      ('ch-travel', 'Travel & Adventures', 12),
      ('ch-family', 'Family Moments', 8),
      ('ch-growth', 'Personal Growth', 5),
      ('ch-career', 'Career Milestones', 6),
    ];

    return Column(
      children: mockChapters
          .map((c) => _buildChapterCard(c.$1, c.$2, c.$3, colors))
          .toList(),
    );
  }

  Widget _buildChapterCard(
    String id,
    String title,
    int entryCount,
    AppPalette colors,
  ) {
    final isSelected = _selectedChapterId == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedChapterId = isSelected ? null : id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentFaint : colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? colors.accent : colors.accentFaint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bookmark_rounded,
                size: 20,
                color: isSelected ? Colors.white : colors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$entryCount ${entryCount == 1 ? 'memory' : 'memories'}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 22, color: colors.accent),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Confirmation (full-screen, no header/bottom bar)
  // ---------------------------------------------------------------------------

  Widget _buildConfirmationStep(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.accentFaint,
            colors.bg,
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Tilted photo card with floating decorations
              _buildPhotoCardSection(colors),

              const SizedBox(height: 36),

              // Heading
              Text(
                'Memory saved\nsuccessfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 14),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Your memory has been safely preserved. It\'s ready whenever you wish to revisit it.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: colors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Primary button: View Memory
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(postSaveDataProvider.notifier).state = null;
                  context.go('/timeline');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withAlpha(50),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'View Memory',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Secondary buttons row
              Row(
                children: [
                  // Record Another
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(postSaveDataProvider.notifier).state = null;
                        context.go('/home');
                        Future.microtask(() {
                          if (mounted) context.push('/write');
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Record Another',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Go to Timeline
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(postSaveDataProvider.notifier).state = null;
                        context.go('/timeline');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Go to Timeline',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tilted photo card with floating decorations
  // ---------------------------------------------------------------------------

  Widget _buildPhotoCardSection(AppPalette colors) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Tilted photo card
          Transform.rotate(
            angle: -5 * math.pi / 180,
            child: Container(
              width: 200,
              height: 160,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withAlpha(20),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: colors.accentFaint,
                  child: Center(
                    child: Icon(
                      Icons.landscape_rounded,
                      size: 48,
                      color: colors.accent.withAlpha(120),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating heart — top right
          Positioned(
            top: 0,
            right: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.card,
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: 18,
                color: colors.accent,
              ),
            ),
          ),

          // Floating sparkle — bottom left
          Positioned(
            bottom: 4,
            left: 40,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.card,
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar (chapter step only)
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(AppPalette colors) {
    final hasSelection = _selectedChapterId != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasSelection)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Select a chapter to continue',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              // Full-width Next button
              GestureDetector(
                onTap: hasSelection ? _next : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: hasSelection ? colors.accent : colors.accent.withAlpha(60),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasSelection
                        ? [
                            BoxShadow(
                              color: colors.accent.withAlpha(50),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    'Next',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: hasSelection ? Colors.white : Colors.white.withAlpha(120),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
