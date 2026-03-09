import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/ai/ai_service.dart';

/// Processing screen shown after recording ends.
/// Runs transcription + AI polish while showing animated 3-step progress.
class ProcessingScreen extends StatefulWidget {
  final ReviewData data;
  const ProcessingScreen({super.key, required this.data});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  final _aiService = AiService();

  // 0 = transcribing, 1 = understanding, 2 = writing
  int _currentStep = 0;

  // Step progress bars (0.0 → 1.0)
  final List<double> _stepProgress = [0.0, 0.0, 0.0];

  // Step states: 'waiting' | 'active' | 'done'
  final List<String> _stepStates = ['active', 'waiting', 'waiting'];

  bool _failed = false;
  String? _errorMessage;

  // Ring rotation animation
  late AnimationController _ringController;

  // Step progress animation controllers
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _runProcessing();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _runProcessing() async {
    // ── Step 1: Transcribe voice ──────────────────────────────────────────
    _setStep(0, 'active');
    await _animateStepProgress(0, 0.0, 1.0, duration: const Duration(milliseconds: 500));

    String transcript = '';
    try {
      if (widget.data.audioPath != null && widget.data.audioPath!.isNotEmpty) {
        transcript = await _aiService.transcribeAudio(widget.data.audioPath!);
      } else if (widget.data.rawText.isNotEmpty) {
        transcript = widget.data.rawText;
      }
    } catch (e) {
      transcript = widget.data.rawText;
    }

    if (!mounted) return;
    _setStep(0, 'done');

    // ── Step 2: Understand story ──────────────────────────────────────────
    _setStep(1, 'active');
    await _animateStepProgress(1, 0.0, 0.7, duration: const Duration(milliseconds: 400));

    String cleanedText = transcript;
    try {
      cleanedText = await _aiService.lightPolish(transcript);
    } catch (_) {
      cleanedText = transcript;
    }

    if (!mounted) return;
    await _animateStepProgress(1, 0.7, 1.0, duration: const Duration(milliseconds: 200));
    _setStep(1, 'done');

    // ── Step 3: Write memory ──────────────────────────────────────────────
    _setStep(2, 'active');
    await _animateStepProgress(2, 0.0, 1.0, duration: const Duration(milliseconds: 600));

    if (!mounted) return;
    _setStep(2, 'done');

    // Small pause so user can see completion
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // Navigate to review screen with transcribed + cleaned text
    context.pushReplacement('/review', extra: ReviewData(
      rawText: cleanedText,
      isVoice: widget.data.isVoice,
      audioPath: widget.data.audioPath,
      attachedPhotoPath: widget.data.attachedPhotoPath,
      polishWithAI: true,
    ));
  }

  void _setStep(int index, String state) {
    if (mounted) {
      setState(() => _stepStates[index] = state);
    }
  }

  Future<void> _animateStepProgress(int index, double from, double to, {required Duration duration}) async {
    const steps = 10;
    final increment = (to - from) / steps;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      if (mounted) {
        setState(() => _stepProgress[index] = from + increment * i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top spacer + cancel link
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // ── Animated center illustration ──
            _buildCenterIllustration(colors),

            const SizedBox(height: 32),

            // ── Title ──
            Text(
              'Writing your memory',
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                letterSpacing: -0.5,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Polishing the details of your special moment.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 44),

            // ── Steps ──
            _buildStepsList(colors),

            const Spacer(flex: 3),

            // ── Info row ──
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: colors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'This usually takes about 10 seconds',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Center Illustration
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCenterIllustration(AppPalette colors) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating outer ring
          AnimatedBuilder(
            animation: _ringController,
            builder: (_, __) => Transform.rotate(
              angle: _ringController.value * 2 * 3.14159,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.accent,
                    width: 2,
                  ),
                ),
                child: CustomPaint(
                  painter: _DashedCirclePainter(color: colors.border),
                ),
              ),
            ),
          ),
          // Inner circle
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accentFaint,
            ),
          ),
          // Icon
          Icon(Icons.menu_book_rounded, size: 44, color: colors.accent),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Steps List
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStepsList(AppPalette colors) {
    final steps = [
      (Icons.volume_up_rounded, 'Transcribing voice'),
      (Icons.psychology_rounded, 'Understanding your story'),
      (Icons.auto_stories_rounded, 'Writing your memory'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: List.generate(steps.length, (i) {
          final state = _stepStates[i];
          final isDone = state == 'done';
          final isActive = state == 'active';
          final isWaiting = state == 'waiting';

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status icon
                  _buildStepIcon(colors, isDone: isDone, isActive: isActive, icon: steps[i].$1),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$2,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isWaiting ? colors.textMuted : colors.textPrimary,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: colors.textMuted,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _stepProgress[i],
                              backgroundColor: colors.border,
                              valueColor: AlwaysStoppedAnimation(colors.accent),
                              minHeight: 3,
                            ),
                          ),
                        ],
                        if (isDone)
                          Text(
                            'Done',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: colors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (isWaiting)
                          Text(
                            'Waiting',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: colors.textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Connector line
              if (i < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: 20,
                      color: colors.border,
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepIcon(AppPalette colors, {required bool isDone, required bool isActive, required IconData icon}) {
    if (isDone) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent),
        child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
      );
    }
    if (isActive) {
      return AnimatedBuilder(
        animation: _ringController,
        builder: (_, __) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accentFaint,
            border: Border.all(color: colors.accent, width: 2),
          ),
          child: Icon(icon, size: 18, color: colors.accent),
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: colors.border, width: 2),
      ),
      child: Icon(icon, size: 18, color: colors.textMuted),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter: Dashed Circle (outer ring decoration)
// ─────────────────────────────────────────────────────────────────────────────

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // The rotating border is handled by the Container border above.
    // This painter draws nothing extra — kept for extensibility.
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => false;
}
