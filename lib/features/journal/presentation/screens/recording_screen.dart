import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _recordingPath;

  final AudioRecorder _audioRecorder = AudioRecorder();

  // Waveform animation
  late AnimationController _waveController;
  final List<double> _barHeights = List.generate(
    13,
    (i) => 0.3 + (sin(i * 1.1 + 0.5) * 0.35 + 0.35).clamp(0.15, 1.0),
  );
  Timer? _waveTimer;

  // Pulse animation for the mic button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Prompt rotation
  static const List<String> _prompts = [
    'What made today special?',
    'Who did you spend time with?',
    'What are you grateful for today?',
    'What challenged you today?',
    'Describe one moment from today.',
  ];
  late String _currentPrompt;

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    _currentPrompt = _prompts[today.hour % _prompts.length];

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveTimer?.cancel();
    _waveController.dispose();
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
          const SnackBar(content: Text('Voice recording requires the mobile app.')),
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

        if (mounted) {
          setState(() {
            _isRecording = true;
            _isPaused = false;
            _recordingPath = path;
            _elapsedSeconds = 0;
          });
          _startTimer();
          _startWaveAnimation();
        }
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
          SnackBar(content: Text('Recording unavailable: ${e.toString().substring(0, e.toString().length.clamp(0, 60))}')),
        );
        Navigator.of(context).maybePop();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRecording && !_isPaused && mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _startWaveAnimation() {
    final rng = Random();
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (_isRecording && !_isPaused && mounted) {
        setState(() {
          for (int i = 0; i < _barHeights.length; i++) {
            _barHeights[i] = 0.15 + rng.nextDouble() * 0.85;
          }
        });
      }
    });
  }

  Future<void> _togglePause() async {
    HapticFeedback.lightImpact();
    try {
      if (_isPaused) {
        await _audioRecorder.resume();
        setState(() => _isPaused = false);
        _startWaveAnimation();
      } else {
        await _audioRecorder.pause();
        setState(() => _isPaused = true);
        _waveTimer?.cancel();
      }
    } catch (e) {
      // Some platforms don't support pause — just show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pause not supported on this device.')),
        );
      }
    }
  }

  Future<void> _finishRecording() async {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _waveTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = path;
        });
        // Navigate to processing screen
        context.pushReplacement('/processing', extra: ReviewData(
          rawText: '',
          isVoice: true,
          attachedPhotoPath: null,
          audioPath: path,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save recording.')),
        );
      }
    }
  }

  String get _formattedTime {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(colors),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  _buildPromptSection(colors),
                  const Spacer(),
                  _buildWaveform(colors),
                  const Spacer(),
                  _buildMicButton(colors),
                  const SizedBox(height: 24),
                  _buildTimer(colors),
                  const Spacer(),
                ],
              ),
            ),
            _buildActionButtons(colors),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              child: Icon(Icons.close_rounded, size: 22, color: colors.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              'Recording Memory',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Prompt Section
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPromptSection(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            'CURRENT PROMPT',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.accent,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _currentPrompt,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Timer
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTimer(AppPalette colors) {
    return Column(
      children: [
        Text(
          _formattedTime,
          style: GoogleFonts.manrope(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isPaused ? 'Paused' : (_isRecording ? 'Recording in progress' : 'Ready'),
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Waveform
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWaveform(AppPalette colors) {
    return SizedBox(
      height: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barHeights.length, (i) {
          final isActive = _isRecording && !_isPaused;
          final height = isActive ? 20.0 + _barHeights[i] * 140.0 : 16.0;
          final opacity = isActive ? (0.5 + _barHeights[i] * 0.5) : 0.15;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 4,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha((opacity * 255).round()),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mic Button
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMicButton(AppPalette colors) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = (_isRecording && !_isPaused) ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              if (_isRecording && !_isPaused)
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withAlpha(20),
                  ),
                ),
              // Main button
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPaused ? colors.textMuted : colors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: (_isPaused ? colors.textMuted : colors.accent).withAlpha(80),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _isPaused ? Icons.mic_off_rounded : Icons.mic_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pause / Finish Buttons
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActionButtons(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          // Pause button
          Expanded(
            child: GestureDetector(
              onTap: _togglePause,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.accent.withAlpha(80),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 20,
                      color: colors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPaused ? 'Resume' : 'Pause',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Finish button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _elapsedSeconds >= 2 ? _finishRecording : null,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: _elapsedSeconds >= 2 ? colors.accent : colors.accent.withAlpha(80),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _elapsedSeconds >= 2
                      ? [
                          BoxShadow(
                            color: colors.accent.withAlpha(70),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Finish Recording',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
