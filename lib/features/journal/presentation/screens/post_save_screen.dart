import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
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
  int _currentStep = 0; // 0 = chapter, 1 = confirmation
  String? _selectedChapterId;

  void _next() {
    if (_currentStep == 0 && _selectedChapterId != null) {
      setState(() => _currentStep = 1);
    }
  }

  void _finish() {
    HapticFeedback.lightImpact();
    ref.read(postSaveDataProvider.notifier).state = null;
    // Re-invalidate so home screen fetches fresh data
    ref.invalidate(timelineEntriesProvider);
    ref.invalidate(todayEntryProvider);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _currentStep == 0
            ? _buildChapterScreen(colors)
            : _buildConfirmationScreen(colors),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Add to Chapter
  // ---------------------------------------------------------------------------

  Widget _buildChapterScreen(AppPalette colors) {
    final chaptersAsync = ref.watch(chaptersProvider);

    return Column(
      key: const ValueKey('chapter'),
      children: [
        // Header
        Container(
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
                      'Add to Chapter',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _finish,
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
        ),

        // Chapter list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a chapter to organize this memory.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),

                const SizedBox(height: 20),

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

                // Create new chapter
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
          ),
        ),

        // Bottom bar with Next button
        _buildBottomBar(colors),
      ],
    );
  }

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

  Widget _buildChapterCard(String id, String title, int entryCount, AppPalette colors) {
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
                    'Continue',
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

  // ---------------------------------------------------------------------------
  // Step 1 — Confirmation
  // ---------------------------------------------------------------------------

  Widget _buildConfirmationScreen(AppPalette colors) {
    return Container(
      key: const ValueKey('confirmation'),
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
              const SizedBox(height: 40),

              _buildPhotoCardSection(colors),

              const SizedBox(height: 36),

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

              // View Memory
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

              // Secondary buttons
              Row(
                children: [
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
              child: Icon(Icons.favorite_rounded, size: 18, color: colors.accent),
            ),
          ),
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
              child: Icon(Icons.auto_awesome_rounded, size: 16, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
