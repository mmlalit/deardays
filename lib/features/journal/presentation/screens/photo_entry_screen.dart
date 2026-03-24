import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';

class PhotoEntryScreen extends ConsumerStatefulWidget {
  final String photoPath;

  const PhotoEntryScreen({super.key, required this.photoPath});

  @override
  ConsumerState<PhotoEntryScreen> createState() => _PhotoEntryScreenState();
}

class _PhotoEntryScreenState extends ConsumerState<PhotoEntryScreen>
    with TickerProviderStateMixin {
  late String _photoPath;
  Alignment _focalAlignment = Alignment.center;
  bool _showDragHint = true;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  bool _hasEnoughText = false;
  bool _photoLoadError = false;

  // ── Voice recording state ────────────────────────────────────────────────
  bool _isRecordingVoice = false;
  bool _isVoiceMode = false; // true after a voice recording has been completed
  String? _audioPath;
  String _liveTranscript = '';
  String _currentWords = '';
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const _minChars = 10;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  String get _formattedTime {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _photoPath = widget.photoPath;
    _textController.addListener(_onTextChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _speech.stop();
    try {
      _audioRecorder.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _onTextChanged() {
    final enough = _textController.text.trim().length >= _minChars;
    if (enough != _hasEnoughText) setState(() => _hasEnoughText = enough);
  }

  // ── Voice recording ───────────────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Voice recording requires the mobile or desktop app.')),
      );
      return;
    }
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required.')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/photo_entry_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: path,
      );

      _speechAvailable = await _speech.initialize(
        onError: (_) {},
        onStatus: (status) {
          if (status == 'notListening' && _isRecordingVoice && mounted) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_isRecordingVoice && mounted) _startListening();
            });
          }
        },
      );
      if (_speechAvailable) _startListening();

      if (mounted) {
        setState(() {
          _isRecordingVoice = true;
          _isVoiceMode = false;
          _recordingSeconds = 0;
          _liveTranscript = '';
          _currentWords = '';
        });
        _recordingTimer =
            Timer.periodic(const Duration(seconds: 1), (_) {
          if (_isRecordingVoice && mounted) {
            setState(() => _recordingSeconds++);
          }
        });
        _pulseController.repeat(reverse: true);
        // Dismiss keyboard so the photo preview stays full-height
        _focusNode.unfocus();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Recording unavailable: ${msg.substring(0, msg.length.clamp(0, 60))}'),
          ),
        );
      }
    }
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _pulseController
      ..stop()
      ..reset();

    if (_speechAvailable) await _speech.stop();

    final transcript = _currentWords.isNotEmpty
        ? '$_liveTranscript $_currentWords'.trim()
        : _liveTranscript.trim();

    try {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _isVoiceMode = true;
          _audioPath = path;
          _textController.text = transcript;
        });
        _onTextChanged();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _isVoiceMode = transcript.isNotEmpty;
          _textController.text = transcript;
        });
        _onTextChanged();
      }
    }
  }

  void _startListening() {
    _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _currentWords = result.recognizedWords;
          if (result.finalResult) {
            _liveTranscript = _liveTranscript.isEmpty
                ? result.recognizedWords
                : '$_liveTranscript ${result.recognizedWords}';
            _currentWords = '';
          }
        });
        final combined = _currentWords.isNotEmpty
            ? '$_liveTranscript $_currentWords'.trim()
            : _liveTranscript.trim();
        if (combined != _textController.text) {
          _textController.text = combined;
          _onTextChanged();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  // ── Photo handling ────────────────────────────────────────────────────────

  Future<String?> _cropPhoto(String sourcePath) async {
    if (_isDesktop) return sourcePath;
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
    if (_isDesktop) {
      photo = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
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

  // ── Navigation ────────────────────────────────────────────────────────────

  void _onContinue() {
    final text = _textController.text.trim();
    if (text.length < _minChars) return;
    HapticFeedback.mediumImpact();
    if (_isVoiceMode && _audioPath != null) {
      // Voice path: route through ProcessingScreen for AI polish + title gen
      context.push(
        '/processing',
        extra: ReviewData(
          rawText: text,
          attachedPhotoPath: _photoPath,
          audioPath: _audioPath,
          isVoice: true,
          focalAlignment: _focalAlignment,
        ),
      );
    } else {
      context.push(
        '/review',
        extra: ReviewData(
          rawText: text,
          attachedPhotoPath: _photoPath,
          isVoice: false,
          focalAlignment: _focalAlignment,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          onPressed: () => Navigator.of(context).maybePop(),
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
                // Photo collapses to thumbnail when keyboard is open
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
          _photoLoadError
              ? Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.white54),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(File(_photoPath)),
                      fit: BoxFit.cover,
                      alignment: _focalAlignment,
                      onError: (_, __) {
                        if (mounted) setState(() => _photoLoadError = true);
                      },
                    ),
                  ),
                ),

          // Drag-to-reframe hint
          if (!compact && _showDragHint)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(110),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_with_rounded,
                          size: 12, color: Colors.white),
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
                if (!_isDesktop && !compact)
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.crop_rounded,
                              size: 13, color: Colors.white),
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
                if (!_isDesktop && !compact) const SizedBox(width: 8),
                GestureDetector(
                  onTap: _changePhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded,
                            size: 13, color: Colors.white),
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
          // Label row: "Tell the story *" + optional voice badge + mic/stop button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // "Voice" badge shown after recording completes
              if (_isVoiceMode && !_isRecordingVoice) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.accent.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded, size: 10, color: colors.accent),
                      const SizedBox(width: 3),
                      Text(
                        'Voice',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Mic / Stop toggle button
              GestureDetector(
                key: const Key('voice_toggle_button'),
                onTap: _isRecordingVoice
                    ? _stopVoiceRecording
                    : _startVoiceRecording,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecordingVoice
                        ? Colors.red.withAlpha(20)
                        : colors.accent.withAlpha(18),
                  ),
                  child: Icon(
                    _isRecordingVoice
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                    size: 18,
                    color: _isRecordingVoice ? Colors.red : colors.accent,
                  ),
                ),
              ),
            ],
          ),

          // Pulsing recording indicator shown while actively recording
          if (_isRecordingVoice) ...[
            const SizedBox(height: 8),
            _buildRecordingIndicator(colors),
          ],

          const SizedBox(height: 10),

          // Text field — read-only while recording (transcript streams in)
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: null,
              expands: true,
              readOnly: _isRecordingVoice,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.manrope(
                fontSize: 15,
                color: colors.textPrimary,
                height: 1.65,
              ),
              decoration: InputDecoration(
                hintText: _isRecordingVoice
                    ? 'Listening… speak your memory'
                    : 'What happened here? What does this moment mean to you?',
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

          // Nudge when text is too short (hidden while recording)
          AnimatedOpacity(
            opacity: _textController.text.isNotEmpty &&
                    !_hasEnoughText &&
                    !_isRecordingVoice
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

  Widget _buildRecordingIndicator(AppPalette colors) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) => Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withAlpha((_pulseAnim.value * 220).round()),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Listening…',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formattedTime,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.red.withAlpha(180),
            ),
          ),
          const Spacer(),
          Text(
            'Tap ■ to stop',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: colors.textSecondary.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(AppPalette colors) {
    final canContinue = _hasEnoughText && !_isRecordingVoice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: AnimatedOpacity(
        opacity: canContinue ? 1.0 : 0.38,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: canContinue ? _onContinue : null,
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
              _isRecordingVoice ? 'Recording… tap ■ to stop' : 'Continue →',
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