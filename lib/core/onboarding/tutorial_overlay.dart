import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/onboarding_provider.dart';
import 'spotlight_painter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tutorial step definitions for Phase 2 (Chapter discovery)
// ─────────────────────────────────────────────────────────────────────────────

class _TutorialStepDef {
  final String title;
  final String body;
  final String? keyName;

  const _TutorialStepDef({
    required this.title,
    required this.body,
    this.keyName,
  });
}

const _phase2Steps = [
  _TutorialStepDef(
    title: 'Chapters are albums',
    body: 'Group memories by theme, season, or whatever feels right.',
    keyName: 'tutorialChaptersTab',
  ),
  _TutorialStepDef(
    title: 'Read your life as a book',
    body: 'Tap By Chapter to see your memories laid out like a real book.',
    keyName: 'tutorialHeroButtons',
  ),
  _TutorialStepDef(
    title: 'Your memory landed here',
    body: 'Every memory you assign to a chapter shows up in this grid.',
    keyName: 'tutorialChapterGrid',
  ),
  _TutorialStepDef(
    title: 'Your memory lives here',
    body: 'Tap any card to open the full memory.',
    keyName: 'tutorialFirstEntry',
  ),
  _TutorialStepDef(
    title: 'Add more anytime',
    body: 'Tap + to record, write, or snap a photo directly into this chapter.',
    keyName: 'tutorialChapterFab',
  ),
  _TutorialStepDef(
    title: 'AI rewrote your story',
    body: 'Tap STORY to read a beautifully written version of your entries.',
    keyName: 'tutorialStoryToggle',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Global key registry for tutorial spotlight targets
// ─────────────────────────────────────────────────────────────────────────────

/// Attach these keys to target widgets so TutorialOverlay can spotlight them.
class TutorialKeys {
  TutorialKeys._();

  static final chaptersTab = GlobalKey(debugLabel: 'tutorialChaptersTab');
  static final heroButtons = GlobalKey(debugLabel: 'tutorialHeroButtons');
  static final chapterGrid = GlobalKey(debugLabel: 'tutorialChapterGrid');
  static final firstEntry = GlobalKey(debugLabel: 'tutorialFirstEntry');
  static final chapterFab = GlobalKey(debugLabel: 'tutorialChapterFab');
  static final storyToggle = GlobalKey(debugLabel: 'tutorialStoryToggle');

  static GlobalKey? forName(String name) {
    switch (name) {
      case 'tutorialChaptersTab':
        return chaptersTab;
      case 'tutorialHeroButtons':
        return heroButtons;
      case 'tutorialChapterGrid':
        return chapterGrid;
      case 'tutorialFirstEntry':
        return firstEntry;
      case 'tutorialChapterFab':
        return chapterFab;
      case 'tutorialStoryToggle':
        return storyToggle;
      default:
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tutorial Overlay Widget
// ─────────────────────────────────────────────────────────────────────────────

/// Stack child in AppShell. Renders nothing when phase2Step is null or
/// phase2 is already completed.
class TutorialOverlay extends ConsumerWidget {
  const TutorialOverlay({super.key});

  Rect? _getTargetRect(String? keyName) {
    if (keyName == null) return null;
    final key = TutorialKeys.forName(keyName);
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final step = state.phase2Step;

    if (step == null || state.phase2Completed) return const SizedBox.shrink();
    if (step >= _phase2Steps.length) return const SizedBox.shrink();

    final def = _phase2Steps[step];
    final targetRect = _getTargetRect(def.keyName);
    final colors = AppColors.of(context);
    final isLast = step == _phase2Steps.length - 1;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: SpotlightPainter(targetRect: targetRect),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(40), blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    _phase2Steps.length,
                    (i) => Container(
                      margin: const EdgeInsets.only(right: 5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == step ? colors.accent : colors.border,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  def.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  def.body,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: notifier.skipPhase2,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.manrope(
                            fontSize: 14, color: colors.textMuted),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isLast
                          ? notifier.skipPhase2
                          : notifier.advancePhase2,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isLast ? 'Done' : 'Next →',
                        style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
