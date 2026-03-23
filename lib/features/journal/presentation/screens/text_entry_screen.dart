import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/storage/local_storage_service.dart';

class TextEntryScreen extends ConsumerStatefulWidget {
  /// When resuming from draft history, the draft to pre-fill.
  final DraftEntry? initialDraft;

  const TextEntryScreen({super.key, this.initialDraft});

  @override
  ConsumerState<TextEntryScreen> createState() => _TextEntryScreenState();
}

class _TextEntryScreenState extends ConsumerState<TextEntryScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _distractionFree = false;
  bool _promptsExpanded = true;
  int _promptSeed = 0;

  /// ID of the in-progress draft for this session. Stable so repeated saves
  /// upsert rather than create new entries.
  late String _draftId;

  /// True once the user taps Continue — suppresses draft save on dispose.
  bool _submitted = false;

  static const _allPrompts = [
    (Icons.sentiment_satisfied_rounded, 'What made you smile today?'),
    (Icons.group_rounded, 'Who were you with today?'),
    (Icons.psychology_rounded, 'Something new you learned'),
    (Icons.emoji_events_rounded, 'A challenge you faced'),
    (Icons.favorite_rounded, 'What are you grateful for?'),
    (Icons.wb_sunny_rounded, 'Best part of today'),
    (Icons.restaurant_rounded, 'A meal you enjoyed'),
    (Icons.local_florist_rounded, 'Something beautiful you saw'),
    (Icons.lightbulb_rounded, 'An idea that excited you'),
    (Icons.chat_bubble_rounded, 'A memorable conversation'),
    (Icons.star_rounded, 'Something you accomplished'),
    (Icons.bedtime_rounded, 'A calm moment today'),
  ];

  List<(IconData, String)> get _visiblePrompts {
    final rng = Random(_promptSeed);
    final shuffled = List<(IconData, String)>.from(_allPrompts)..shuffle(rng);
    return shuffled.take(3).toList();
  }

  String get _formattedDate {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft != null) {
      _draftId = draft.id;
      _textController.text = draft.rawText;
    } else {
      _draftId = const Uuid().v4();
    }
    _textController.addListener(() => setState(() {}));
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _promptsExpanded) {
        setState(() => _promptsExpanded = false);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveDraftIfNeeded() async {
    if (_submitted) return;
    final text = _textController.text.trim();
    if (text.length < 10) return;
    final draft = DraftEntry(
      id: _draftId,
      type: DraftType.text,
      rawText: text,
      savedAt: DateTime.now(),
      entryDate: DateTime.now(),
    );
    await LocalStorageService.instance.saveDraft(draft);
    ref.invalidate(draftsProvider);
  }

  Future<void> _deleteDraft() async {
    await LocalStorageService.instance.deleteDraft(_draftId);
    ref.invalidate(draftsProvider);
  }

  Future<void> _onBack() async {
    if (_distractionFree) {
      _exitDistractionFree();
      return;
    }
    await _saveDraftIfNeeded();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _refreshPrompts() {
    HapticFeedback.selectionClick();
    setState(() => _promptSeed++);
    ref.invalidate(writingPromptProvider);
  }

  Future<void> _goToReview() async {
    HapticFeedback.lightImpact();
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      return;
    }
    _submitted = true;
    await _deleteDraft();
    if (mounted) context.push('/processing', extra: ReviewData(rawText: text));
  }

  void _toggleDistractionFree() {
    HapticFeedback.selectionClick();
    if (_wordCount > 0) {
      setState(() => _distractionFree = true);
      _focusNode.requestFocus();
    }
  }

  void _exitDistractionFree() {
    setState(() => _distractionFree = false);
    _focusNode.unfocus();
  }

  Widget _iconBtn(IconData icon, AppPalette colors, VoidCallback onTap,
      {Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.card,
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? colors.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBack();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: _distractionFree
              ? _buildDistractionFreeBody(colors)
              : _buildNormalBody(colors),
        ),
      ),
    );
  }

  // ── Normal body ───────────────────────────────────────────────────────────

  Widget _buildNormalBody(AppPalette colors) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Column(
      children: [
        _buildTopBar(colors),
        _buildPromptsArea(colors),
        Expanded(child: _buildWritingArea(colors)),
        Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: _buildBottomBar(colors),
        ),
      ],
    );
  }

  Widget _buildTopBar(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          _iconBtn(Icons.arrow_back_rounded, colors, _onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Write',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  _formattedDate,
                  style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
          ),
          _iconBtn(
            Icons.fullscreen_rounded,
            colors,
            _toggleDistractionFree,
            iconColor: _wordCount > 0
                ? colors.textSecondary
                : colors.textMuted.withAlpha(60),
          ),
          const SizedBox(width: 8),
          _iconBtn(Icons.more_horiz_rounded, colors, _showOptionsMenu),
        ],
      ),
    );
  }

  // ── Prompts area ──────────────────────────────────────────────────────────

  Widget _buildPromptsArea(AppPalette colors) {
    if (!_promptsExpanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _promptsExpanded = true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_rounded, size: 13, color: colors.accent),
                  const SizedBox(width: 5),
                  Text(
                    'Prompts',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14,
                      color: colors.accent),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final prompts = _visiblePrompts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 14, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                'Need a spark?',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _refreshPrompts,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 12, color: colors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Shuffle',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _promptsExpanded = false);
                },
                child: Icon(Icons.keyboard_arrow_up_rounded, size: 18,
                    color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...prompts.map((prompt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    final current = _textController.text;
                    _textController.text = current.isEmpty
                        ? prompt.$2
                        : '$current\n${prompt.$2}';
                    _textController.selection = TextSelection.collapsed(
                        offset: _textController.text.length);
                    _focusNode.requestFocus();
                    setState(() => _promptsExpanded = false);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: colors.accent.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(prompt.$1, size: 15, color: colors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            prompt.$2,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12,
                            color: colors.textMuted),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ── Writing area ──────────────────────────────────────────────────────────

  Widget _buildWritingArea(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        autofocus: true,
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
          hintText: 'Start writing...',
          hintStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: colors.textMuted.withAlpha(120),
            height: 1.75,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 4),
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(AppPalette colors) {
    final enabled = _wordCount >= 5;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_wordCount word${_wordCount == 1 ? '' : 's'}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: enabled ? _goToReview : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: enabled ? colors.accent : colors.accent.withAlpha(60),
                borderRadius: BorderRadius.circular(14),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: colors.accent.withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 17, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Distraction-free body ─────────────────────────────────────────────────

  Widget _buildDistractionFreeBody(AppPalette colors) {
    return Column(
      children: [
        _buildDistractionFreeTopBar(colors),
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
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        _buildDistractionFreeBottomBar(colors),
      ],
    );
  }

  Widget _buildDistractionFreeTopBar(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _iconBtn(Icons.arrow_back_rounded, colors, _exitDistractionFree),
          const Spacer(),
          Text(
            '$_wordCount word${_wordCount == 1 ? '' : 's'}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          _iconBtn(
            Icons.fullscreen_exit_rounded,
            colors,
            () {
              HapticFeedback.selectionClick();
              setState(() => _distractionFree = false);
            },
            iconColor: colors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildDistractionFreeBottomBar(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border.withAlpha(60))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _goToReview,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 17, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Options menu ──────────────────────────────────────────────────────────

  void _showOptionsMenu() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: colors.textSecondary),
              title: Text(
                'Clear text',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                if (_textController.text.isNotEmpty) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Clear text?'),
                      content: const Text(
                          "This will erase everything you've written."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            _textController.clear();
                            setState(() => _promptsExpanded = true);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
