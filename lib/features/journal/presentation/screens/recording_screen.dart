import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = true;
  bool _showBottomSheet = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Waveform bar heights — simulated
  final List<double> _barHeights = List.generate(
    30,
    (i) => 0.2 + (sin(i * 0.7) * 0.3 + 0.3).clamp(0.1, 1.0),
  );

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRecording) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _isRecording = false;
        _pulseController.stop();
        _showBottomSheet = true;
      } else {
        _isRecording = true;
        _showBottomSheet = false;
        _pulseController.repeat(reverse: true);
      }
    });
  }

  String get _minutes =>
      (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');

  String get _seconds =>
      (_elapsedSeconds % 60).toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dark backdrop
          Container(
            color: AppColors.bgDark.withOpacity(0.95),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(flex: 2),
                _buildTimer(),
                const SizedBox(height: 40),
                _buildWaveform(),
                const SizedBox(height: 48),
                _buildMicButton(),
                const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
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
          // Invisible spacer to balance the row
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Timer
  // ──────────────────────────────────────────────

  Widget _buildTimer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timerBox(_minutes),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            ':',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        _timerBox(_seconds),
      ],
    );
  }

  Widget _timerBox(String value) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
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
    );
  }

  // ──────────────────────────────────────────────
  // Waveform
  // ──────────────────────────────────────────────

  Widget _buildWaveform() {
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barHeights.length, (index) {
          // Vary opacity across bars
          final opacity = 0.3 + (_barHeights[index] * 0.7);
          final height = 12 + (_barHeights[index] * 52);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 3,
            height: _isRecording ? height : 8,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(
                _isRecording ? opacity : 0.25,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Mic button with pulse / glow
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 16,
                        ),
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.stop,
                size: 40,
                color: Colors.white,
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
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRecording ? 'Tap to stop' : 'Review your entry below',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.primary.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Bottom entry sheet
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
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
                        color: AppColors.textMuted.withOpacity(0.3),
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
                          'JOURNAL ENTRY \u2022 NOV 14',
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

                  // Narrative text
                  Text(
                    'The autumn light filtered through the kitchen window as '
                    'I made my morning coffee. There\'s something about this '
                    'time of year that makes ordinary moments feel like small '
                    'gifts \u2014 the way the steam curls upward, the warmth of '
                    'the cup in my hands...',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Save to Book',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.1),
      ),
      child: Icon(
        icon,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }
}
