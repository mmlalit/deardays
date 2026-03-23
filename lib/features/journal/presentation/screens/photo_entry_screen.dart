import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';

class PhotoEntryScreen extends ConsumerStatefulWidget {
  final String photoPath;

  const PhotoEntryScreen({super.key, required this.photoPath});

  @override
  ConsumerState<PhotoEntryScreen> createState() => _PhotoEntryScreenState();
}

class _PhotoEntryScreenState extends ConsumerState<PhotoEntryScreen> {
  late String _photoPath;
  Alignment _focalAlignment = Alignment.center;
  bool _showDragHint = true;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  bool _hasEnoughText = false;

  static const _minChars = 10;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.photoPath;
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final enough = _textController.text.trim().length >= _minChars;
    if (enough != _hasEnoughText) setState(() => _hasEnoughText = enough);
  }

  /// Opens the platform crop UI after picking. Returns original path on desktop.
  Future<String?> _cropPhoto(String sourcePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return sourcePath;
    }
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          doneButtonTitle: 'Done',
          cancelButtonTitle: 'Cancel',
          aspectRatioPickerButtonHidden: false,
        ),
      ],
    );
    return cropped?.path;
  }

  Future<void> _changePhoto() async {
    final XFile? photo;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (photo != null && mounted) {
        setState(() {
          _photoPath = photo!.path;
          _focalAlignment = Alignment.center;
        });
      }
      return;
    }
    photo = await _showMobilePhotoSheet();
    if (photo != null) {
      final cropped = await _cropPhoto(photo.path);
      if (cropped != null && mounted) {
        setState(() {
          _photoPath = cropped;
          _focalAlignment = Alignment.center;
          _showDragHint = true;
        });
      }
    }
  }

  Future<XFile?> _showMobilePhotoSheet() async {
    final colors = AppColors.of(context);
    return showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _sheetOption(
                ctx,
                icon: Icons.camera_alt_rounded,
                label: 'Take a photo',
                colors: colors,
                onTap: () async {
                  final f = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, f);
                },
              ),
              const SizedBox(height: 12),
              _sheetOption(
                ctx,
                icon: Icons.photo_library_rounded,
                label: 'Upload from gallery',
                colors: colors,
                onTap: () async {
                  final f = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, f);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required AppPalette colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.accent),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onContinue() {
    final text = _textController.text.trim();
    if (text.length < _minChars) return;
    HapticFeedback.mediumImpact();
    context.push(
      '/review',
      extra: ReviewData(
        rawText: text,
        attachedPhotoPath: _photoPath,
        isVoice: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add a Memory',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final keyboardOpen = keyboardHeight > 100;
            return Column(
              children: [
                // Photo collapses to thumbnail when keyboard is open (Instagram-style)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  height: keyboardOpen ? 100 : 260,
                  child: _buildPhotoPreview(colors, compact: keyboardOpen),
                ),
                Expanded(child: _buildTextArea(colors)),
                // Continue button sticks above keyboard
                Padding(
                  padding: EdgeInsets.only(bottom: keyboardHeight),
                  child: _buildContinueButton(colors),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(AppPalette colors, {bool compact = false}) {
    return GestureDetector(
      // Drag to reframe focal point (full-size view only)
      onPanUpdate: compact
          ? null
          : (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final size = box.size;
              final dx = -details.delta.dx / size.width * 2.5;
              final dy = -details.delta.dy / size.height * 2.5;
              setState(() {
                _focalAlignment = Alignment(
                  (_focalAlignment.x + dx).clamp(-1.0, 1.0),
                  (_focalAlignment.y + dy).clamp(-1.0, 1.0),
                );
                _showDragHint = false;
              });
            },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo with focal-point alignment
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(File(_photoPath)),
                fit: BoxFit.cover,
                alignment: _focalAlignment,
                onError: (_, __) {},
              ),
            ),
          ),

          // Drag-to-reframe hint (fades after first drag)
          if (!compact && _showDragHint)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(110),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_with_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'Drag to reframe',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Top-right action pills: Crop + Change
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Crop button — mobile only
                if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS && !compact)
                  GestureDetector(
                    onTap: () async {
                      final cropped = await _cropPhoto(_photoPath);
                      if (cropped != null && mounted) {
                        setState(() {
                          _photoPath = cropped;
                          _focalAlignment = Alignment.center;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.crop_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Crop',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS && !compact)
                  const SizedBox(width: 8),
                // Change button
                GestureDetector(
                  onTap: _changePhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          'Change',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Text(
                'Tell the story',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.manrope(
                fontSize: 15,
                color: colors.textPrimary,
                height: 1.65,
              ),
              decoration: InputDecoration(
                hintText:
                    'What happened here? What does this moment mean to you?',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 15,
                  color: colors.textSecondary.withAlpha(110),
                  height: 1.65,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Nudge when text started but too short
          AnimatedOpacity(
            opacity: _textController.text.isNotEmpty && !_hasEnoughText
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Write a little more to continue…',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: colors.textSecondary.withAlpha(140),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: AnimatedOpacity(
        opacity: _hasEnoughText ? 1.0 : 0.38,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _hasEnoughText ? _onContinue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              disabledBackgroundColor: colors.accent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Continue →',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
