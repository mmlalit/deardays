import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/ai/ai_service.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _showBottomSheet = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _recordingPath;

  // Transcription state
  bool _isTranscribing = false;
  String? _transcribedText;

  // AI Polish state
  bool _isPolishing = false;
  String? _polishedText;

  // Photo
  String? _attachedPhotoPath;
  final _imagePicker = ImagePicker();

  final _aiService = AiService();
  final AudioRecorder _audioRecorder = AudioRecorder();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Waveform bar heights — 9 bars
  final List<double> _barHeights = List.generate(
    9,
    (i) => 0.3 + (sin(i * 1.2) * 0.4 + 0.3).clamp(0.1, 1.0),
  );

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    try {
      _audioRecorder.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice recording is not supported on web. Please use the mobile app.')),
        );
        Navigator.of(context).maybePop();
      }
      return;
    }

    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _elapsedSeconds = 0;
        });

        _startTimer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required.')),
          );
          Navigator.of(context).maybePop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording not available: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}')),
        );
        Navigator.of(context).maybePop();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRecording) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        _timer?.cancel();
        setState(() {
          _isRecording = false;
          _recordingPath = path;
          _pulseController.stop();
          _showBottomSheet = true;
          _isTranscribing = true;
        });
        // Transcribe the audio
        await _transcribeAudio(path);
      } else {
        setState(() {
          _showBottomSheet = false;
          _transcribedText = null;
          _polishedText = null;
          _attachedPhotoPath = null;
        });
        await _startRecording();
        _pulseController.repeat(reverse: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}')),
        );
      }
    }
  }

  Future<void> _transcribeAudio(String? path) async {
    if (path == null) {
      if (mounted) setState(() => _isTranscribing = false);
      return;
    }
    try {
      final text = await _aiService.transcribeAudio(path);
      if (mounted) {
        setState(() {
          _transcribedText = text;
          _isTranscribing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          // Fallback: show duration text so user can still proceed
          _transcribedText = null;
        });
      }
    }
  }

  Future<void> _polishTranscription() async {
    final text = _transcribedText;
    if (text == null || text.isEmpty) return;
    setState(() => _isPolishing = true);
    try {
      final polished = await _aiService.lightPolish(text);
      if (mounted) {
        setState(() {
          _polishedText = polished;
          _isPolishing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPolishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Polish failed. Your original text is preserved.')),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _attachedPhotoPath = picked.path);
    }
  }

  void _goToReview() {
    final finalText = _polishedText ?? _transcribedText ?? 'Voice journal entry ($_minutes:$_seconds)';
    context.push('/review', extra: ReviewData(
      rawText: finalText,
      isVoice: true,
      attachedPhotoPath: _attachedPhotoPath,
    ));
  }

  String get _minutes =>
      (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');

  String get _seconds =>
      (_elapsedSeconds % 60).toString().padLeft(2, '0');

  String get _formattedDate =>
      DateFormat('MMM d').format(DateTime.now()).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dark backdrop
          Container(
            color: Theme.of(context).scaffoldBackgroundColor.withAlpha(242),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(flex: 2),
                _buildTimer(),
                const SizedBox(height: 48),
                _buildWaveform(),
                const SizedBox(height: 56),
                _buildMicButton(),
                const SizedBox(height: 24),
                _buildStatusText(),
                const Spacer(flex: 3),
              ],
            ),
          ),

          // Bottom sheet
          if (_showBottomSheet) _buildEntrySheet(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Top bar
  // ──────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(26),
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
            ),
          ),
          const Spacer(),
          Text(
            'DearDays Recording',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Timer with MIN / SEC labels
  // ──────────────────────────────────────────────

  Widget _buildTimer() {
    final colors = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timerBox(_minutes, 'MIN'),
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20),
          child: Text(
            ':',
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: colors.accent,
            ),
          ),
        ),
        _timerBox(_seconds, 'SEC'),
      ],
    );
  }

  Widget _timerBox(String value, String label) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(26)),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: colors.accent,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colors.accent.withAlpha(178),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Waveform
  // ──────────────────────────────────────────────

  Widget _buildWaveform() {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barHeights.length, (index) {
          final opacity = 0.4 + (_barHeights[index] * 0.6);
          final height = 16 + (_barHeights[index] * 80);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 4,
            height: _isRecording ? height : 10,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(
                ((_isRecording ? opacity : 0.3) * 255).round(),
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Mic button
  // ──────────────────────────────────────────────

  Widget _buildMicButton() {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = _isRecording ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: colors.accent.withAlpha(64),
                          blurRadius: 48,
                          spreadRadius: 20,
                        ),
                        BoxShadow(
                          color: colors.accent.withAlpha(102),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: colors.accent.withAlpha(76),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.stop,
                size: 44,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Status text
  // ──────────────────────────────────────────────

  Widget _buildStatusText() {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text(
          _isRecording ? 'Recording your thoughts...' : 'Recording stopped',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRecording ? 'Tap to stop' : 'Review your entry below',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: colors.accent.withAlpha(178),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Bottom entry sheet
  // ──────────────────────────────────────────────

  Widget _buildEntrySheet() {
    final colors = AppColors.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        offset: _showBottomSheet ? Offset.zero : const Offset(0, 1),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white.withAlpha(13))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(76),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withAlpha(76),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'JOURNAL ENTRY \u2022 $_formattedDate',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      // Add Photo button
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _attachedPhotoPath != null
                                ? colors.accent.withAlpha(25)
                                : colors.accent.withAlpha(13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colors.accent.withAlpha(
                                _attachedPhotoPath != null ? 60 : 30,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _attachedPhotoPath != null
                                    ? Icons.check_circle_outline
                                    : Icons.camera_alt_outlined,
                                size: 15,
                                color: colors.accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _attachedPhotoPath != null ? 'Photo added' : 'Add photo',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Content area
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildTranscriptContent(colors),
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      // AI Polish button — only show if transcription done and not yet polished
                      if (!_isTranscribing && _transcribedText != null && _polishedText == null)
                        _buildAIPolishButton(colors),
                      if (!_isTranscribing && _transcribedText != null && _polishedText == null)
                        const SizedBox(height: 10),

                      // Add to Book button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: (_isTranscribing || _isPolishing) ? null : _goToReview,
                          icon: const Icon(Icons.auto_stories, size: 20, color: Colors.white),
                          label: Text(
                            'Add to Book',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111111),
                            disabledBackgroundColor: colors.accent.withAlpha(100),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptContent(AppPalette colors) {
    // Transcribing state
    if (_isTranscribing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Transcribing your recording...',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This may take a few seconds',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    // Polish in progress
    if (_isPolishing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.accent),
            ),
            const SizedBox(height: 14),
            Text(
              'AI is polishing your words...',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Transcription failed
    if (_transcribedText == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(Icons.mic_off_outlined, size: 32, color: colors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Transcription unavailable',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your recording ($_minutes:$_seconds) is saved.\nYou can still add it to your book.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Show polished or transcribed text
    final displayText = _polishedText ?? _transcribedText!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_polishedText != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_fix_high, size: 13, color: colors.accent),
                const SizedBox(width: 5),
                Text(
                  'AI Polished',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
        Text(
          displayText,
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: colors.textPrimary,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildAIPolishButton(AppPalette colors) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _polishTranscription,
        icon: Icon(Icons.auto_fix_high, size: 18, color: colors.accent),
        label: Text(
          'AI Polish — Fix grammar & improve readability',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.accent.withAlpha(60)),
          backgroundColor: colors.accent.withAlpha(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
