import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  final AudioRecorder _audioRecorder = AudioRecorder();

  // On-device speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  String _liveTranscript = '';
  String _currentWords = '';

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

  // Fallback prompts when AI is unavailable
  static const List<String> _fallbackPrompts = [
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
    _currentPrompt = _fallbackPrompts[today.hour % _fallbackPrompts.length];

    // M-28: use ref.listen so the prompt updates reactively if the provider changes
    ref.listenManual(writingPromptProvider, (_, next) {
      if (next != null && mounted) {
        setState(() => _currentPrompt = next);
      }
    }, fireImmediately: true);

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
    _speech.stop();
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
        // Use temp directory so recordings are auto-cleaned by the OS and
        // don't persist unencrypted in the user's documents folder.
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,     // 64kbps — sufficient for voice, ~50% smaller
            sampleRate: 22050,  // 22kHz — adequate for speech (vs default 44.1kHz)
          ),
          path: path,
        );

        // Start on-device speech recognition in parallel
        _speechAvailable = await _speech.initialize(
          onError: (_) {},
          onStatus: (status) {
            // Restart listening when it stops (speech_to_text auto-stops on silence)
            if (status == 'notListening' && _isRecording && !_isPaused && mounted) {
              _restartListening();
            }
          },
        );
        if (_speechAvailable) {
          _startListening();
        }

        if (mounted) {
          setState(() {
            _isRecording = true;
            _isPaused = false;
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
          SnackBar(content: Text(() { final msg = e.toString(); return 'Recording unavailable: ${msg.substring(0, msg.length.clamp(0, 60))}'; }())),
        );
        Navigator.of(context).maybePop();
      }
    }
  }

  void _startListening() {
    _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _currentWords = result.recognizedWords;
            if (result.finalResult) {
              if (_liveTranscript.isNotEmpty) {
                _liveTranscript += ' ${result.recognizedWords}';
              } else {
                _liveTranscript = result.recognizedWords;
              }
              _currentWords = '';
            }
          });
        }
      },
      listenMode: stt.ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  void _restartListening() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_isRecording && !_isPaused && mounted && _speechAvailable) {
        _startListening();
      }
    });
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
        if (_speechAvailable) _startListening();
        setState(() => _isPaused = false);
        _startWaveAnimation();
      } else {
        await _audioRecorder.pause();
        if (_speechAvailable) _speech.stop();
        setState(() => _isPaused = true);
        _waveTimer?.cancel();
      }
    } catch (e) {
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

    // Capture final transcript before stopping speech
    if (_speechAvailable) {
      await _speech.stop();
    }
    final transcript = _currentWords.isNotEmpty
        ? '$_liveTranscript $_currentWords'.trim()
        : _liveTranscript.trim();

    try {
      final path = await _audioRecorder.stop();

      // Validate: if no transcript was captured and recording was very short,
      // show an error instead of navigating forward.
      if (transcript.isEmpty && _elapsedSeconds < 3) {
        if (mounted) {
          setState(() => _isRecording = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No conversation recorded. Please try again.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _startRecording();
          });
        }
        return;
      }

      // If on-device STT captured nothing (but recording was long enough),
      // ask the user before sending audio to an external AI service.
      if (transcript.isEmpty && path != null && mounted) {
        setState(() => _isRecording = false);
        _showWhisperConsentDialog(path);
        return;
      }

      if (mounted) {
        setState(() => _isRecording = false);
        context.pushReplacement('/processing', extra: ReviewData(
          rawText: transcript,
          isVoice: true,
          attachedPhotoPath: null,
          audioPath: path,
          // useWhisper defaults to false — on-device transcript is used.
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

  /// Shows a consent dialog when on-device STT captured nothing.
  /// User must explicitly choose to send audio to OpenAI Whisper.
  void _showWhisperConsentDialog(String audioPath) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Voice not captured',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your device could not transcribe the audio automatically.\n\n'
          'Would you like to use AI transcription? Your audio will be sent '
          'to OpenAI to convert your speech to text, then deleted.',
          style: GoogleFonts.manrope(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Discard audio, let user type manually
              context.pushReplacement('/write');
            },
            child: Text(
              'Type instead',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pushReplacement('/processing', extra: ReviewData(
                rawText: '',
                isVoice: true,
                attachedPhotoPath: null,
                audioPath: audioPath,
                useWhisper: true,
              ));
            },
            child: Text(
              'Use AI Transcription',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
                  const SizedBox(height: 20),
                  _buildPromptSection(colors),
                  const Spacer(flex: 2),
                  _buildWaveform(colors),
                  const SizedBox(height: 32),
                  _buildMicButton(colors),
                  const SizedBox(height: 28),
                  _buildTimer(colors),
                  if (_liveTranscript.isNotEmpty || _currentWords.isNotEmpty)
                    _buildLiveTranscript(colors),
                  const Spacer(flex: 1),
                ],
              ),
            ),
            _buildActionButtons(colors),
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
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Text(
        _currentPrompt,
        textAlign: TextAlign.center,
        style: GoogleFonts.newsreader(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          height: 1.3,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Live Transcript Preview
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLiveTranscript(AppPalette colors) {
    final display = _currentWords.isNotEmpty
        ? '$_liveTranscript $_currentWords'.trim()
        : _liveTranscript.trim();
    // Show last ~120 chars to keep it compact
    final preview = display.length > 120
        ? '...${display.substring(display.length - 120)}'
        : display;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.accent.withAlpha(13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.accent.withAlpha(30)),
        ),
        child: Text(
          preview,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
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
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barHeights.length, (i) {
          final isActive = _isRecording && !_isPaused;
          final height = isActive ? 10.0 + _barHeights[i] * 60.0 : 10.0;
          final opacity = isActive ? (0.4 + _barHeights[i] * 0.6) : 0.15;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 3.5,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 3),
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
                  width: 116,
                  height: 116,
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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
