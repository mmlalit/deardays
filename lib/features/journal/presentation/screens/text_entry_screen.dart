import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/location/location_service.dart';

class TextEntryScreen extends StatefulWidget {
  const TextEntryScreen({super.key});

  @override
  State<TextEntryScreen> createState() => _TextEntryScreenState();
}

class _TextEntryScreenState extends State<TextEntryScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  final _locationService = LocationService();
  bool _polishWithAI = false;
  String? _attachedPhotoPath;
  String? _locationName;
  int _promptIndex = 0;
  bool _promptVisible = true;
  String _salutation = 'Dear Diary,';

  static const _prompts = [
    'What made you smile today?',
    'What are you grateful for right now?',
    'Describe a moment that surprised you today.',
    'What\'s something you learned recently?',
    'How are you feeling in this very moment?',
    'What would you tell your future self?',
    'Describe the best part of your week so far.',
    'What\'s a small win you had today?',
    'Write about someone who made your day better.',
    'What\'s on your mind that you haven\'t said out loud?',
    'If today had a soundtrack, what song would it be?',
    'What does your ideal tomorrow look like?',
    'Write about a place that feels like home.',
    'What\'s a memory that always makes you happy?',
    'What challenged you today, and how did you handle it?',
  ];

  @override
  void initState() {
    super.initState();
    _promptIndex = Random().nextInt(_prompts.length);
    _textController.addListener(() => setState(() {}));
    _loadSalutation();
  }

  Future<void> _loadSalutation() async {
    final box = await Hive.openBox('settings');
    final saved = box.get('salutation') as String?;
    if (saved != null && mounted) {
      setState(() => _salutation = saved);
    }
  }

  Future<void> _editSalutation() async {
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: _salutation.replaceAll(',', '').trim());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Customize greeting',
          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.merriweather(fontSize: 16, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Dear Diary',
            hintStyle: GoogleFonts.merriweather(color: colors.textMuted),
            border: UnderlineInputBorder(borderSide: BorderSide(color: colors.accent)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.accent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.manrope(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: colors.accent)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final newSalutation = result.endsWith(',') ? result : '$result,';
      setState(() => _salutation = newSalutation);
      final box = await Hive.openBox('settings');
      await box.put('salutation', newSalutation);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _nextPrompt() {
    setState(() {
      _promptIndex = (_promptIndex + 1) % _prompts.length;
    });
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
      setState(() => _locationName = name ?? '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}');
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
      polishWithAI: _polishWithAI,
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
    final isKeyboardUp = MediaQuery.of(context).viewInsets.bottom > 100;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Top bar ────────────────────────────────────────────────────
          _buildTopBar(colors),

          // ── Scrollable writing area ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Date header — small, muted, editorial
                  Text(
                    DateFormat('EEEE, MMMM d · yyyy').format(DateTime.now()),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Salutation — tap to customize
                  GestureDetector(
                    onTap: _editSalutation,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _salutation,
                          style: GoogleFonts.merriweather(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_outlined, size: 14, color: colors.textMuted.withAlpha(150)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // AI prompt chip (inline, collapsible)
                  if (_promptVisible) _buildInlinePrompt(colors),

                  const SizedBox(height: 16),

                  // Text field — distraction-free, iA Writer inspired
                  TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: colors.accent,
                    cursorWidth: 2,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    style: GoogleFonts.merriweather(
                      fontSize: 17,
                      fontWeight: FontWeight.w300,
                      color: colors.textPrimary,
                      height: 1.85,
                      letterSpacing: 0.1,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start writing...',
                      hintStyle: GoogleFonts.merriweather(
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                        color: colors.textMuted,
                        height: 1.85,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom toolbar — moves up with keyboard automatically ───────
          _buildBottomBar(colors, isKeyboardUp),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(AppPalette colors) {
    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(color: colors.accent.withAlpha(20)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withAlpha(15),
                ),
                child: Icon(Icons.close, size: 18, color: colors.textPrimary),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'New Entry',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            // Word count — subtle, right-aligned
            AnimatedOpacity(
              opacity: _wordCount > 0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                '$_wordCount w',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Inline prompt chip ─────────────────────────────────────────────────────

  Widget _buildInlinePrompt(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withAlpha(30)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _prompts[_promptIndex],
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _nextPrompt,
            child: Icon(Icons.refresh_rounded, size: 16, color: colors.accent),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _promptVisible = false),
            child: Icon(Icons.close, size: 14, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Bottom toolbar ─────────────────────────────────────────────────────────

  Widget _buildBottomBar(AppPalette colors, bool isKeyboardUp) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: colors.accent.withAlpha(20)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 10, 16, isKeyboardUp ? 8 : 16),
        child: isKeyboardUp
            ? _buildCompactToolbar(colors)
            : _buildFullToolbar(colors),
      ),
    );
  }

  /// Compact toolbar shown when keyboard is visible — just the tool icons
  Widget _buildCompactToolbar(AppPalette colors) {
    return Row(
      children: [
        _toolButton(
          icon: _attachedPhotoPath != null ? Icons.image : Icons.image_outlined,
          label: 'Photo',
          isActive: _attachedPhotoPath != null,
          onTap: _attachPhoto,
          colors: colors,
        ),
        const SizedBox(width: 8),
        _toolButton(
          icon: _locationName != null ? Icons.location_on : Icons.location_on_outlined,
          label: _locationName ?? 'Location',
          isActive: _locationName != null,
          onTap: _addLocation,
          colors: colors,
        ),
        const Spacer(),
        // AI Polish toggle (compact)
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _polishWithAI = !_polishWithAI);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _polishWithAI ? colors.accent : colors.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.accent.withAlpha(40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_fix_high, size: 14,
                    color: _polishWithAI ? Colors.white : colors.accent),
                const SizedBox(width: 5),
                Text(
                  'AI Polish',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _polishWithAI ? Colors.white : colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Send / continue button
        GestureDetector(
          onTap: _goToReview,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF111111),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// Full toolbar shown when keyboard is hidden — includes Save to Book button
  Widget _buildFullToolbar(AppPalette colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tools row
        Row(
          children: [
            _toolButton(
              icon: _attachedPhotoPath != null ? Icons.image : Icons.image_outlined,
              label: 'Photo',
              isActive: _attachedPhotoPath != null,
              onTap: _attachPhoto,
              colors: colors,
            ),
            const SizedBox(width: 8),
            _toolButton(
              icon: _locationName != null ? Icons.location_on : Icons.location_on_outlined,
              label: _locationName ?? 'Location',
              isActive: _locationName != null,
              onTap: _addLocation,
              colors: colors,
            ),
            const Spacer(),
            // AI Polish toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _polishWithAI = !_polishWithAI);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _polishWithAI ? colors.accent : colors.accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.accent.withAlpha(40)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high, size: 16,
                        color: _polishWithAI ? Colors.white : colors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'AI Polish',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _polishWithAI ? Colors.white : colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Save to Book button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _goToReview,
            icon: const Icon(Icons.auto_stories, size: 18, color: Colors.white),
            label: Text(
              'Save to Book',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required AppPalette colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? colors.accent.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? colors.accent.withAlpha(60) : colors.accent.withAlpha(30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15,
                color: isActive ? colors.accent : colors.textMuted),
            const SizedBox(width: 5),
            Text(
              isActive && label != 'Photo' && label != 'Location'
                  ? label.length > 12 ? '${label.substring(0, 12)}…' : label
                  : label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? colors.accent : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
