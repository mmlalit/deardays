import 'dart:math';
import 'dart:ui';

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
  final TextEditingController _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _locationService = LocationService();
  bool _polishWithAI = false;
  String? _attachedPhotoPath;
  String? _locationName;
  int _promptIndex = 0;

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
  }

  @override
  void dispose() {
    _textController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Photo attached'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Scrollable content
          Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _buildAISuggestionCard(),
                      _buildWritingArea(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating bottom bar with gradient
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingBottom(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Top bar — X close, "New Entry" center, "Post" right
  // ──────────────────────────────────────────────

  Widget _buildTopBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgLight.withAlpha(204),
            border: Border(
              bottom: BorderSide(
                color: AppColors.primary.withAlpha(26),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Close button
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close, size: 24),
                      color: AppColors.textPrimary,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  // Title
                  Expanded(
                    child: Center(
                      child: Text(
                        'New Entry',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Post button
                  GestureDetector(
                    onTap: _goToReview,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'Post',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // AI Suggestion Card — white, border, serif italic
  // ──────────────────────────────────────────────

  Widget _buildAISuggestionCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withAlpha(51),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "AI SUGGESTION" label
            Text(
              'AI SUGGESTION',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            // Prompt text — serif italic
            Text(
              _prompts[_promptIndex],
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // "New Prompt" pill button
            GestureDetector(
              onTap: _nextPrompt,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Prompt',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Writing area — "Dear Diary," + paper-lined text
  // ──────────────────────────────────────────────

  Widget _buildWritingArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // "Dear Diary," heading
          Text(
            'Dear Diary,',
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Text field with paper lines
          Stack(
            children: [
              // Paper lines background
              Positioned.fill(
                child: CustomPaint(
                  painter: _PaperLinesPainter(
                    lineColor: const Color(0xFFE8E1D9),
                    lineHeight: 40.0,
                  ),
                ),
              ),
              // Actual text field
              TextField(
                controller: _textController,
                maxLines: null,
                minLines: 14,
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary.withAlpha(204),
                  height: 2.0, // matches 40px line height at 20px font
                ),
                decoration: InputDecoration(
                  hintText: 'Start writing your thoughts...',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                    height: 2.0,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Floating bottom — gradient fade, tools, save
  // ──────────────────────────────────────────────

  Widget _buildFloatingBottom() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgLight.withAlpha(0),
            AppColors.bgLight,
            AppColors.bgLight,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick tools row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Image button
                    _toolCircleButton(
                      icon: Icons.image,
                      isActive: _attachedPhotoPath != null,
                      onTap: _attachPhoto,
                    ),
                    const SizedBox(width: 8),
                    // Location button
                    _toolCircleButton(
                      icon: Icons.location_on,
                      isActive: _locationName != null,
                      onTap: _addLocation,
                    ),
                    const Spacer(),
                    // Polish with AI pill
                    _buildPolishToggle(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Save to Book button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _goToReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.primary.withAlpha(76),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_stories,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Save to Book',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Widget _toolCircleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: AppColors.primary.withAlpha(51),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildPolishToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: AppColors.primary.withAlpha(51),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_fix_high,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Text(
            'AI Polish',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          // Custom toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _polishWithAI = !_polishWithAI);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _polishWithAI
                    ? AppColors.primary
                    : const Color(0xFFCBD5E1),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _polishWithAI
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(38),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Paper lines painter
// ──────────────────────────────────────────────

class _PaperLinesPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;

  _PaperLinesPainter({
    required this.lineColor,
    required this.lineHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    double y = lineHeight;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperLinesPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.lineHeight != lineHeight;
}
