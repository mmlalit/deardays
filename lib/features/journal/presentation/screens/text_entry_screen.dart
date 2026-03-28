import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
// LocalStorageService import removed — drafts go through draftSyncServiceProvider

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
  final _picker = ImagePicker();
  bool _distractionFree = false;
  bool _promptsExpanded = true;
  int _promptSeed = 0;
  final List<String> _attachedPhotoPaths = [];

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

  int _lastWordCount = 0;

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  /// Only calls setState when the word count actually changes, avoiding
  /// unnecessary rebuilds on every keystroke.
  void _onTextChanged() {
    final current = _wordCount;
    if (current != _lastWordCount) {
      _lastWordCount = current;
      setState(() {});
    }
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
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _promptsExpanded) {
        setState(() => _promptsExpanded = false);
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
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
    await ref.read(draftSyncServiceProvider).saveDraft(draft);
    ref.invalidate(draftsProvider);
  }

  Future<void> _deleteDraft() async {
    await ref.read(draftSyncServiceProvider).deleteDraft(_draftId);
    ref.invalidate(draftsProvider);
  }

  Future<void> _onBack() async {
    if (_distractionFree) {
      _exitDistractionFree();
      return;
    }
    await _saveDraftIfNeeded();
    if (mounted) context.pop();
  }

  void _refreshPrompts() {
    HapticFeedback.selectionClick();
    setState(() => _promptSeed++);
    ref.invalidate(writingPromptProvider);
  }

  Future<void> _pickPhoto() async {
    if (_attachedPhotoPaths.length >= 5) {
      // M-11: notify user instead of silently doing nothing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 photos per entry'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    HapticFeedback.selectionClick();
    final XFile? picked;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      picked = await showModalBottomSheet<XFile?>(
        context: context,
        backgroundColor: AppColors.of(context).card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.of(context).border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.camera_alt_rounded, color: AppColors.of(context).accent),
                  title: Text('Take a photo', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (ctx.mounted) Navigator.pop(ctx, f);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_rounded, color: AppColors.of(context).accent),
                  title: Text('Choose from gallery', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (ctx.mounted) Navigator.pop(ctx, f);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (picked != null && mounted) {
      setState(() => _attachedPhotoPaths.add(picked!.path));
    }
  }

  Future<void> _goToReview() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    _submitted = true;
    await _deleteDraft();
    if (mounted) {
      FocusScope.of(context).unfocus();
      context.push('/processing', extra: ReviewData(
        rawText: text,
        attachedPhotoPath: _attachedPhotoPaths.isNotEmpty ? _attachedPhotoPaths.first : null,
      ));
    }
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Photo thumbnail strip (shown when photos are attached)
        if (_attachedPhotoPaths.isNotEmpty)
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _attachedPhotoPaths.length + (_attachedPhotoPaths.length < 5 ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _attachedPhotoPaths.length) {
                  return GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 44, height: 44,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(Icons.add_photo_alternate_outlined, size: 18, color: colors.accent),
                    ),
                  );
                }
                return Stack(
                  children: [
                    Container(
                      width: 44, height: 44,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(_attachedPhotoPaths[i])),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _attachedPhotoPaths.removeAt(i)),
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        // Main action bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: colors.bg,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              // Word count pill
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
              const SizedBox(width: 10),
              // Camera icon button
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _attachedPhotoPaths.isNotEmpty
                        ? colors.accent.withAlpha(20)
                        : colors.card,
                    border: Border.all(color: colors.border),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                          color: _attachedPhotoPaths.isNotEmpty ? colors.accent : colors.textSecondary,
                        ),
                      ),
                      if (_attachedPhotoPaths.isNotEmpty)
                        Positioned(
                          top: 2, right: 2,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                '${_attachedPhotoPaths.length}',
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Continue button
              GestureDetector(
                onTap: enabled
                    ? _goToReview
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Write at least 5 words to continue.'),
                            duration: Duration(seconds: 2),
                          ),
                        ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: enabled ? colors.accent : colors.accent.withAlpha(60),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: enabled
                        ? [BoxShadow(color: colors.accent.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Continue',
                          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
