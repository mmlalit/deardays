import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/location/location_service.dart';

class TextEntryScreen extends StatefulWidget {
  const TextEntryScreen({super.key});

  @override
  State<TextEntryScreen> createState() => _TextEntryScreenState();
}

class _TextEntryScreenState extends State<TextEntryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  final _locationService = LocationService();
  String? _attachedPhotoPath;
  String? _locationName;

  static const _prompts = [
    'What made you smile?',
    'Who did you meet?',
    'A challenge faced',
    'Something new learned',
    'Best part of today',
    'Grateful for...',
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _focusNode.dispose();
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
            backgroundColor: Colors.red.shade700,
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
                  _buildTitleInput(colors),
                  const SizedBox(height: 24),
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

  // ── Title Input ───────────────────────────────────────────────────────────

  Widget _buildTitleInput(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: colors.accent,
          style: GoogleFonts.merriweather(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: 'Untitled Moment',
            hintStyle: GoogleFonts.merriweather(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: colors.textMuted.withAlpha(120),
              height: 1.2,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 48,
          height: 1,
          color: colors.accent.withAlpha(80),
        ),
      ],
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
                        color: Colors.black.withAlpha(8),
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
          subtitle: 'Categorize your memory',
          isActive: false,
          onTap: () {},
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
