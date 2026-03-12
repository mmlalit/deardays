import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';

/// Dedicated edit screen for memory content, tags, people, location.
/// Receives the [ReviewData] and returns updated data on save via GoRouter.
class EditMemoryScreen extends StatefulWidget {
  final ReviewData data;
  const EditMemoryScreen({super.key, required this.data});

  @override
  State<EditMemoryScreen> createState() => _EditMemoryScreenState();
}

class _EditMemoryScreenState extends State<EditMemoryScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _storyController;
  final _imagePicker = ImagePicker();
  String? _attachedPhotoPath;

  final List<String> _tags = [];
  final _tagController = TextEditingController();
  final _focusTag = FocusNode();

  static const List<String> _suggestedTags = [
    'Family', 'Travel', 'Work', 'Friends', 'Nature',
    'Food', 'Health', 'Gratitude', 'Achievement', 'Funny',
  ];

  @override
  void initState() {
    super.initState();

    // Extract title from rawText first line if it looks like a title
    final lines = widget.data.rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final firstLine = lines.isNotEmpty ? lines.first : '';
    final bodyText = lines.length > 1 ? lines.skip(1).join('\n').trim() : widget.data.rawText;

    _attachedPhotoPath = widget.data.attachedPhotoPath;

    _titleController = TextEditingController(
      text: (firstLine.length < 80 && lines.length > 1) ? firstLine : '',
    );
    _storyController = TextEditingController(
      text: (firstLine.length < 80 && lines.length > 1) ? bodyText : widget.data.rawText,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    _tagController.dispose();
    _focusTag.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() => _tags.add(trimmed));
    }
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _showPhotoOptions(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
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
                color: colors.textMuted.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: colors.accent),
              title: Text(
                'Upload Photo',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Choose from your gallery',
                style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: colors.accent),
              title: Text(
                'Take Photo',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Use your camera',
                style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        setState(() => _attachedPhotoPath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access photo gallery.')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        setState(() => _attachedPhotoPath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera.')),
        );
      }
    }
  }

  void _saveChanges() {
    HapticFeedback.mediumImpact();
    final title = _titleController.text.trim();
    final body = _storyController.text.trim();
    final combined = title.isNotEmpty ? '$title\n\n$body' : body;

    // Pop back to review screen with updated data
    context.pop(ReviewData(
      rawText: combined,
      isVoice: widget.data.isVoice,
      audioPath: widget.data.audioPath,
      attachedPhotoPath: _attachedPhotoPath,
      mood: widget.data.mood,
      locationName: widget.data.locationName,
      polishWithAI: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _buildTopBar(colors),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo section
                  _buildPhotoSection(colors),
                  const SizedBox(height: 24),

                  // Title field
                  _buildFieldLabel('Title', colors),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _titleController,
                    hint: 'Give your memory a title',
                    maxLines: 1,
                    colors: colors,
                  ),
                  const SizedBox(height: 20),

                  // Story field
                  _buildFieldLabel('Story', colors),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _storyController,
                    hint: 'Write your memory here...',
                    maxLines: 8,
                    colors: colors,
                  ),
                  const SizedBox(height: 24),

                  // Metadata row
                  _buildMetadataRow(colors),
                  const SizedBox(height: 24),

                  // Tags
                  _buildFieldLabel('Tags', colors),
                  const SizedBox(height: 12),
                  _buildTagsSection(colors),
                ],
              ),
            ),
          ),

          // Bottom bar
          _buildBottomBar(colors),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accentFaint,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: colors.textPrimary),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Edit Memory',
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _saveChanges,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent,
                  ),
                  child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Photo Section
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPhotoSection(AppPalette colors) {
    return GestureDetector(
      onTap: () => _showPhotoOptions(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            if (_attachedPhotoPath != null)
              Image.asset(
                _attachedPhotoPath!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 180,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.accent, colors.accentLight],
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.image_outlined, size: 48, color: Colors.white.withAlpha(120)),
                  ),
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.accent, colors.accentLight],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.white.withAlpha(180)),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add a photo',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: colors.border),
                ),
                child: Icon(Icons.camera_alt_outlined, size: 18, color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Field Label
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label, AppPalette colors) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Text Field
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
    required AppPalette colors,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: maxLines == 1 ? 1 : 4,
        style: GoogleFonts.manrope(
          fontSize: 15,
          color: colors.textPrimary,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
            fontSize: 15,
            color: colors.textMuted,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          filled: false,
        ),
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Metadata Row (People | Location | Date)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMetadataRow(AppPalette colors) {
    final items = [
      (Icons.person_add_alt_rounded, 'PEOPLE'),
      (Icons.location_on_outlined, 'LOCATION'),
      (Icons.calendar_today_outlined, 'DATE'),
    ];

    return Row(
      children: items.map((item) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colors.accentFaint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  Icon(item.$1, size: 20, color: colors.accent),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tags Section
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTagsSection(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active tags
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) => _buildTagChip(tag, isActive: true, colors: colors)).toList()
              ..add(_buildAddTagChip(colors)),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAddTagChip(colors),
              ..._suggestedTags.take(5).map((t) => _buildTagChip(t, isActive: false, colors: colors)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTagChip(String tag, {required bool isActive, required AppPalette colors}) {
    return GestureDetector(
      onTap: isActive ? () => _removeTag(tag) : () => _addTag(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : colors.accentFaint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? colors.accent : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : colors.textPrimary,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 14, color: Colors.white.withAlpha(200)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddTagChip(AppPalette colors) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: colors.bg,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _tagController,
                  focusNode: _focusTag,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Type a tag...',
                    hintStyle: GoogleFonts.manrope(color: colors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.check_rounded, color: colors.accent),
                      onPressed: () {
                        _addTag(_tagController.text);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  onSubmitted: (v) {
                    _addTag(v);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestedTags.map((t) => GestureDetector(
                    onTap: () {
                      _addTag(t);
                      Navigator.pop(context);
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
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'ADD TAG',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBottomBar(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.pop(),
                child: Text(
                  'Discard Changes',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textSecondary,
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
