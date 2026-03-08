import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';

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

  final AudioRecorder _audioRecorder = AudioRecorder();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Waveform bar heights — 9 bars to match mockup
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
        });
      } else {
        setState(() {
          _showBottomSheet = false;
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

  void _goToReview() {
    // For voice entries, the raw text is a placeholder until transcription is added
    final durationText = '$_minutes:$_seconds';
    context.push('/review', extra: ReviewData(
      rawText: 'Voice journal entry ($durationText)',
      isVoice: true,
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
            color: AppColors.bgDark.withAlpha(242),
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
            style: GoogleFonts.inter(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timerBox(_minutes, 'MIN'),
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20),
          child: Text(
            ':',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        _timerBox(_seconds, 'SEC'),
      ],
    );
  }

  Widget _timerBox(String value, String label) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withAlpha(26),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.primary.withAlpha(178),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Waveform — 9 bars, 4px wide, gold
  // ──────────────────────────────────────────────

  Widget _buildWaveform() {
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
              color: AppColors.primary.withAlpha(
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
  // Mic button — 112px, dark icon on gold bg
  // ──────────────────────────────────────────────

  Widget _buildMicButton() {
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
                color: AppColors.primary,
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(64),
                          blurRadius: 48,
                          spreadRadius: 20,
                        ),
                        BoxShadow(
                          color: AppColors.primary.withAlpha(102),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(76),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.stop,
                size: 44,
                color: AppColors.bgDark,
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
    return Column(
      children: [
        Text(
          _isRecording ? 'Recording your thoughts...' : 'Recording stopped',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRecording ? 'Tap to stop' : 'Review your entry below',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.primary.withAlpha(178),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Bottom entry sheet — 40px radius, strong shadow
  // ──────────────────────────────────────────────

  Widget _buildEntrySheet() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        offset: _showBottomSheet ? Offset.zero : const Offset(0, 1),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withAlpha(13),
              ),
            ),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withAlpha(76),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'JOURNAL ENTRY \u2022 $_formattedDate',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      _sheetActionButton(Icons.camera_alt_outlined),
                      const SizedBox(width: 10),
                      _sheetActionButton(Icons.location_on_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Recording summary
                  Text(
                    'You recorded $_minutes:$_seconds of audio. '
                    'Your voice entry will be transcribed and polished by AI '
                    'into a beautiful story.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save button — gold bg, dark text, with icon
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _goToReview,
                      icon: const Icon(
                        Icons.auto_stories,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Save to book',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  Widget _sheetActionButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.primary.withAlpha(26),
      ),
      child: Icon(
        icon,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }
}
