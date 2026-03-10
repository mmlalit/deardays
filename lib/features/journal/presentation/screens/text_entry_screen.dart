import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/location/location_service.dart';

class TextEntryScreen extends ConsumerStatefulWidget {
  const TextEntryScreen({super.key});

  @override
  ConsumerState<TextEntryScreen> createState() => _TextEntryScreenState();
}

class _TextEntryScreenState extends ConsumerState<TextEntryScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  final _locationService = LocationService();
  String? _attachedPhotoPath;
  String? _locationName;
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  static const _suggestedTags = [
    'Family', 'Travel', 'Work', 'Friends', 'Nature',
    'Food', 'Health', 'Gratitude', 'Achievement', 'Funny',
  ];

  static const _fallbackPrompts = [
    'What made you smile?',
    'Who did you meet?',
    'A challenge faced',
    'Something new learned',
    'Best part of today',
    'Grateful for...',
  ];

  List<String> get _prompts {
    final aiPrompt = ref.read(writingPromptProvider).valueOrNull;
    if (aiPrompt != null) {
      return [aiPrompt, ..._fallbackPrompts];
    }
    return _fallbackPrompts;
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _attachPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _attachedPhotoPath = picked.path);
    }
  }

  Future<void> _addLocation() async {
    if (_locationName != null) {
      setState(() => _locationName = null);
      return;
    }
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not get location. Check permissions.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    final name = await _locationService.getLocationName(
      position.latitude,
      position.longitude,
    );
    if (mounted) {
      setState(() => _locationName = name ??
          '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}');
    }
  }

  void _showTagsSheet() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Tags', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 12),
              TextField(
                controller: _tagController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Type a tag...',
                  hintStyle: GoogleFonts.manrope(color: colors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.check_rounded, color: colors.accent),
                    onPressed: () {
                      final tag = _tagController.text.trim();
                      if (tag.isNotEmpty && !_tags.contains(tag)) {
                        setState(() => _tags.add(tag));
                        setSheet(() {});
                      }
                      _tagController.clear();
                    },
                  ),
                ),
                onSubmitted: (v) {
                  final tag = v.trim();
                  if (tag.isNotEmpty && !_tags.contains(tag)) {
                    setState(() => _tags.add(tag));
                    setSheet(() {});
                  }
                  _tagController.clear();
                },
              ),
              const SizedBox(height: 16),
              if (_tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) => GestureDetector(
                    onTap: () {
                      setState(() => _tags.remove(tag));
                      setSheet(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tag, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(width: 4),
                          Icon(Icons.close_rounded, size: 14, color: Colors.white.withAlpha(200)),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Text('Suggestions', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedTags.where((t) => !_tags.contains(t)).map((t) => GestureDetector(
                  onTap: () {
                    setState(() => _tags.add(t));
                    setSheet(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: colors.accentFaint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(t, style: GoogleFonts.manrope(fontSize: 13, color: colors.textPrimary)),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
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
      locationName: _locationName,
      attachedPhotoPath: _attachedPhotoPath,
    ));
  }

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildTopBar(colors),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildPromptsSection(colors),
                  const SizedBox(height: 20),
                  _buildWritingArea(colors),
                  const SizedBox(height: 32),
                  _buildMetaSection(colors),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _buildSaveButton(colors),
        ],
      ),
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
            SizedBox(
              width: 40,
              child: AnimatedOpacity(
                opacity: _wordCount > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '$_wordCount w',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
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
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _prompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () {
                  final current = _textController.text;
                  final prompt = _prompts[i];
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
                      _prompts[i],
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
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      maxLines: null,
      minLines: 12,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: colors.accent,
      cursorWidth: 2,
      scrollPadding: const EdgeInsets.only(bottom: 120),
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
    );
  }

  // ── Meta Section ──────────────────────────────────────────────────────────

  Widget _buildMetaSection(AppPalette colors) {
    return Column(
      children: [
        Divider(color: colors.border, height: 1),
        const SizedBox(height: 4),
        _buildMetaRow(
          icon: Icons.sell_rounded,
          title: 'Tags',
          subtitle: _tags.isEmpty ? 'Categorize your memory' : _tags.join(', '),
          isActive: _tags.isNotEmpty,
          onTap: _showTagsSheet,
          colors: colors,
        ),
        _buildMetaRow(
          icon: Icons.image_rounded,
          title: 'Photo',
          subtitle: _attachedPhotoPath != null ? 'Photo attached' : 'Add a photo to this memory',
          isActive: _attachedPhotoPath != null,
          onTap: _attachPhoto,
          colors: colors,
        ),
        _buildMetaRow(
          icon: Icons.location_on_rounded,
          title: 'Location',
          subtitle: _locationName ?? 'Where did this happen?',
          isActive: _locationName != null,
          onTap: _addLocation,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    required AppPalette colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: colors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: isActive ? colors.accent : colors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.check_rounded : Icons.add_rounded,
                    size: 13,
                    color: isActive ? colors.accent : colors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isActive ? 'ADDED' : 'ADD',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isActive ? colors.accent : colors.textMuted,
                      letterSpacing: 0.5,
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

  // ── Save Button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton(AppPalette colors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _goToReview,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
            label: Text(
              'Save Memory',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: colors.accent.withAlpha(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
