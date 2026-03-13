import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';

class TextEntryScreen extends ConsumerStatefulWidget {
  const TextEntryScreen({super.key});

  @override
  ConsumerState<TextEntryScreen> createState() => _TextEntryScreenState();
}

class _TextEntryScreenState extends ConsumerState<TextEntryScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Distraction-free mode state
  bool _distractionFree = false;

  // Prompt shuffle state
  int _promptSeed = 0;

  static const _allPrompts = [
    'What made you smile today?',
    'Who did you spend time with?',
    'A challenge you faced',
    'Something new you learned',
    'Best part of your day',
    "What you're grateful for...",
    'A moment of calm today',
    'What surprised you?',
    'Something you accomplished',
    'A conversation that stuck with you',
    'What would you do differently?',
    'A small joy you noticed',
  ];

  List<String> get _visiblePrompts {
    final aiPrompt = ref.read(writingPromptProvider).valueOrNull;
    final rng = Random(_promptSeed);
    final shuffled = List<String>.from(_allPrompts)..shuffle(rng);
    final picked = shuffled.take(5).toList();
    if (aiPrompt != null) {
      picked.insert(0, aiPrompt);
    }
    return picked;
  }

  void _refreshPrompts() {
    HapticFeedback.selectionClick();
    setState(() => _promptSeed++);
    // Also try to fetch a new AI prompt
    ref.invalidate(writingPromptProvider);
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _distractionFree) {
      setState(() => _distractionFree = false);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goToReview() {
    HapticFeedback.lightImpact();
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      return;
    }
    context.push('/review', extra: ReviewData(
      rawText: text,
    ));
  }

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  void _exitDistractionFree() {
    setState(() => _distractionFree = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PopScope(
      canPop: !_distractionFree,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _distractionFree) {
          _exitDistractionFree();
        }
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        resizeToAvoidBottomInset: true,
        body: _distractionFree
            ? _buildDistractionFreeBody(colors)
            : _buildNormalBody(colors),
      ),
    );
  }

  // ── Distraction-free layout ───────────────────────────────────────────────

  Widget _buildDistractionFreeBody(AppPalette colors) {
    return Column(
      children: [
        _buildMinimalTopBar(colors),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: colors.accent,
              cursorWidth: 2,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: colors.textPrimary,
                height: 1.75,
              ),
              decoration: InputDecoration(
                hintText: 'Write about your day...',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: colors.textMuted,
                  height: 1.75,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        _buildBottomBar(colors),
      ],
    );
  }

  Widget _buildMinimalTopBar(AppPalette colors) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: _exitDistractionFree,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.cardBg,
                ),
                child: Icon(Icons.arrow_back_rounded, size: 18, color: colors.textSecondary),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _distractionFree = false);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withAlpha(20),
                ),
                child: Icon(Icons.fullscreen_exit_rounded, size: 18, color: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Normal layout ─────────────────────────────────────────────────────────

  Widget _buildNormalBody(AppPalette colors) {
    return Column(
      children: [
        _buildTopBar(colors),
        // Prompts section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: _buildPromptsSection(colors),
        ),
        // Expanded writing area fills remaining space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _buildWritingArea(colors),
          ),
        ),
        _buildBottomBar(colors),
      ],
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(AppPalette colors) {
    return SafeArea(
      bottom: false,
      child: Padding(
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
                'Write Memory',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            // Focus toggle icon
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (_wordCount > 0) {
                  setState(() => _distractionFree = true);
                  _focusNode.requestFocus();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.cardBg,
                ),
                child: Icon(
                  Icons.fullscreen_rounded,
                  size: 20,
                  color: _wordCount > 0 ? colors.textSecondary : colors.textMuted.withAlpha(80),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Prompts Section ───────────────────────────────────────────────────────

  Widget _buildPromptsSection(AppPalette colors) {
    final prompts = _visiblePrompts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_rounded, size: 16, color: colors.accent),
            const SizedBox(width: 6),
            Text(
              'NEED A PROMPT?',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.textMuted,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            // Refresh button
            GestureDetector(
              onTap: _refreshPrompts,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withAlpha(15),
                ),
                child: Icon(Icons.refresh_rounded, size: 16, color: colors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () {
                  final current = _textController.text;
                  final prompt = prompts[i];
                  _textController.text = current.isEmpty
                      ? prompt
                      : '$current\n$prompt';
                  _textController.selection = TextSelection.collapsed(
                    offset: _textController.text.length,
                  );
                  _focusNode.requestFocus();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.textPrimary.withAlpha(8),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      prompts[i],
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Writing Area ──────────────────────────────────────────────────────────

  Widget _buildWritingArea(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: colors.accent,
        cursorWidth: 2,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
          height: 1.75,
        ),
        decoration: InputDecoration(
          hintText: 'Write about your day...',
          hintStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: colors.textMuted,
            height: 1.75,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  // ── Bottom Bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(AppPalette colors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.highlightFaint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_wordCount word${_wordCount == 1 ? '' : 's'}',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _goToReview,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                label: Text(
                  'Continue',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: colors.accent.withAlpha(60),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
