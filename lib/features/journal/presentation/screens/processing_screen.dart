import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/ai/ai_credit_service.dart';
import 'package:deardays/services/ai/offline_ai_queue.dart';

/// Processing screen shown after recording or writing ends.
/// Runs transcription + AI polish while showing animated 3-step progress.
/// Uses green accent for voice entries and blue accent for text entries.
class ProcessingScreen extends StatefulWidget {
  final ReviewData data;
  const ProcessingScreen({super.key, required this.data});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  final _aiService = AiService();
  final _creditService = AiCreditService();
  final _offlineQueue = OfflineAiQueue();

  // Local analysis result (instant, free)
  LocalAnalysisResult? _localResult;

  // Step states: 'waiting' | 'active' | 'done'
  final List<String> _stepStates = ['active', 'waiting', 'waiting', 'waiting'];

  // Step progress 0.0 → 1.0 (used for overall % calculation)
  final List<double> _stepProgress = [0.0, 0.0, 0.0, 0.0];

  // Pulse animation for the concentric rings
  late AnimationController _pulseController;

  // Spin animation for the active step icon
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _runProcessing();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _runProcessing() async {
    // ── Step 1: Transcribe voice ──────────────────────────────────────────
    _setStep(0, 'active');
    await _animateProgress(0, 0.0, 0.3, duration: const Duration(milliseconds: 200));

    String transcript = '';
    try {
      if (widget.data.rawText.isNotEmpty) {
        // Use on-device live transcript when available (free)
        transcript = widget.data.rawText;
      } else if (widget.data.audioPath != null && widget.data.audioPath!.isNotEmpty) {
        // Fall back to cloud transcription — check credits first
        if (_creditService.canUse(AiOperation.transcription)) {
          _creditService.consume(AiOperation.transcription);
          transcript = await _aiService.transcribeAudio(widget.data.audioPath!);
        } else {
          transcript = widget.data.rawText;
        }
      }
    } catch (_) {
      transcript = widget.data.rawText;
    }

    // If no transcript was produced at all, show error and go back
    if (transcript.trim().isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No conversation recorded. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    if (!mounted) return;
    await _animateProgress(0, 0.3, 1.0, duration: const Duration(milliseconds: 300));
    _setStep(0, 'done');

    // ── Step 2: Local analysis (instant, free, no network) ────────────────
    _setStep(1, 'active');
    await _animateProgress(1, 0.0, 0.3, duration: const Duration(milliseconds: 150));

    // Run on-device mood detection, title extraction, highlight extraction
    _localResult = _offlineQueue.analyzeLocally(transcript);

    if (!mounted) return;
    await _animateProgress(1, 0.3, 1.0, duration: const Duration(milliseconds: 250));
    _setStep(1, 'done');

    // ── Step 3: Server AI polish — light polish (grammar/spelling) ────────
    _setStep(2, 'active');
    await _animateProgress(2, 0.0, 0.2, duration: const Duration(milliseconds: 150));

    String cleanedText = transcript;
    try {
      if (_creditService.canUse(AiOperation.polish)) {
        _creditService.consume(AiOperation.polish);
        cleanedText = await _aiService.lightPolish(transcript);
      }
    } catch (_) {
      _offlineQueue.enqueue(AiQueueItem(
        entryId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        text: transcript,
        operation: QueueOperation.lightPolish,
        createdAt: DateTime.now(),
      ));
      cleanedText = transcript;
    }

    if (!mounted) return;
    await _animateProgress(2, 0.2, 1.0, duration: const Duration(milliseconds: 300));
    _setStep(2, 'done');

    // ── Step 4: Full narrative polish + dedicated title generation ─────────
    _setStep(3, 'active');
    await _animateProgress(3, 0.0, 0.1, duration: const Duration(milliseconds: 100));

    String? polishedText;
    String? generatedTitle;
    try {
      // Run polish and title generation in parallel
      final results = await Future.wait([
        _aiService.polishNarrative(cleanedText, style: 'memoir'),
        _aiService.generateTitle(cleanedText).catchError((_) => ''),
      ]);

      polishedText = results[0].trim();
      generatedTitle = results[1].isNotEmpty ? results[1] : null;

      // Strip any leading markdown header from polished text
      final lines = polishedText.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length > 1 && lines.first.startsWith('#')) {
        polishedText = lines.skip(1).join('\n\n').trim();
      }
    } catch (_) {
      polishedText = null;
    }

    // Fallback title if AI title generation failed
    if (generatedTitle == null || generatedTitle.isEmpty) {
      final match = RegExp(r'^(.{5,40}[.!?])').firstMatch(cleanedText.trim());
      if (match != null) {
        generatedTitle = match.group(1)!.replaceAll(RegExp(r'[.!?]$'), '').trim();
      } else {
        final words = cleanedText.trim().split(RegExp(r'\s+'));
        generatedTitle = words.take(4).join(' ');
      }
    }

    if (!mounted) return;
    await _animateProgress(3, 0.1, 1.0, duration: const Duration(milliseconds: 400));
    _setStep(3, 'done');

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    context.pushReplacement('/review', extra: ReviewData(
      rawText: transcript,
      cleanedText: cleanedText,
      polishedText: polishedText,
      generatedTitle: generatedTitle,
      isVoice: widget.data.isVoice,
      audioPath: widget.data.audioPath,
      attachedPhotoPath: widget.data.attachedPhotoPath,
      polishWithAI: true,
      mood: _localResult?.mood,
    ));
  }

  void _setStep(int index, String state) {
    if (mounted) setState(() => _stepStates[index] = state);
  }

  Future<void> _animateProgress(int index, double from, double to, {required Duration duration}) async {
    const steps = 10;
    final increment = (to - from) / steps;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      if (mounted) setState(() => _stepProgress[index] = from + increment * i);
    }
  }

  double get _overallProgress {
    final total = _stepProgress[0] + _stepProgress[1] + _stepProgress[2] + _stepProgress[3];
    return (total / 4).clamp(0.0, 1.0);
  }

  /// Whether this is a text entry (not voice recording).
  bool get _isTextEntry => !widget.data.isVoice;

  /// Blue accent for text entries, default accent for voice.
  Color _accentColor(AppPalette colors) =>
      _isTextEntry ? const Color(0xFF3B82F6) : colors.accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final overall = _overallProgress;
    final pct = (overall * 100).round();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIllustration(colors),
                    const SizedBox(height: 32),
                    _buildTitle(colors),
                    const SizedBox(height: 40),
                    _buildProgressBar(colors, overall, pct),
                    const SizedBox(height: 32),
                    _buildStepsTimeline(colors),
                  ],
                ),
              ),
            ),
            _buildFooter(colors),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.cardBg,
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: colors.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              'Aura',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Concentric Rings Illustration ──────────────────────────────────────

  Widget _buildIllustration(AppPalette colors) {
    final accent = _accentColor(colors);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final outerAlpha = (15 + (_pulseController.value * 10).round()).clamp(15, 25);
        return SizedBox(
          width: 192,
          height: 192,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withAlpha(outerAlpha),
                ),
              ),
              // Middle ring
              Container(
                width: 152,
                height: 152,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withAlpha(35),
                ),
              ),
              // Inner ring
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withAlpha(55),
                ),
              ),
              // Center circle with icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withAlpha(100),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  _isTextEntry ? Icons.edit_note_rounded : Icons.psychology_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Title + Subtitle ─────────────────────────────────────────────────────

  Widget _buildTitle(AppPalette colors) {
    return Column(
      children: [
        Text(
          'Processing your memory',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Aura is weaving your story together...',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Overall Progress Bar ──────────────────────────────────────────────────

  Widget _buildProgressBar(AppPalette colors, double progress, int pct) {
    final accent = _accentColor(colors);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall Progress',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            Text(
              '$pct%',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: accent.withAlpha(25),
            valueColor: AlwaysStoppedAnimation(accent),
            minHeight: 12,
          ),
        ),
      ],
    );
  }

  // ── Steps Timeline ────────────────────────────────────────────────────────

  Widget _buildStepsTimeline(AppPalette colors) {
    final accent = _accentColor(colors);
    final steps = _isTextEntry
        ? ['Reading your words', 'Understanding story', 'Polishing grammar', 'Crafting your narrative']
        : ['Transcribing voice', 'Understanding story', 'Polishing grammar', 'Crafting your narrative'];

    return Column(
      children: List.generate(steps.length, (i) {
        final state = _stepStates[i];
        final isDone = state == 'done';
        final isActive = state == 'active';
        final isWaiting = state == 'waiting';
        final isLast = i == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: step circle + connector line
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    _buildStepCircle(colors, isDone: isDone, isActive: isActive),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isDone ? accent : colors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right column: title + status
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 36, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i],
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isWaiting ? colors.textMuted : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isDone ? 'Done' : isActive ? 'In progress...' : 'Waiting',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isWaiting ? colors.textMuted : accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepCircle(AppPalette colors, {required bool isDone, required bool isActive}) {
    final accent = _accentColor(colors);
    if (isDone) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      );
    }
    if (isActive) {
      return RotationTransition(
        turns: _spinController,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(color: accent, width: 2),
          ),
          child: Icon(Icons.refresh_rounded, size: 16, color: accent),
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: colors.border, width: 2),
      ),
      child: Icon(Icons.more_horiz_rounded, size: 16, color: colors.textMuted),
    );
  }

  // ── Footer Info Card ──────────────────────────────────────────────────────

  Widget _buildFooter(AppPalette colors) {
    final accent = _accentColor(colors);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: accent.withAlpha(13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withAlpha(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_rounded, size: 20, color: accent),
            const SizedBox(width: 8),
            Text(
              'This usually takes about 10 seconds.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
