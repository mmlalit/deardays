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

import 'package:uuid/uuid.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';
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
  // _showDragHint removed — Edit pill handles reframe UX
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  bool _hasEnoughText = false;
  bool _photoLoadError = false;
  final String _draftId = const Uuid().v4();
  bool _submitted = false;

  // ── Photo adjustment state ────────────────────────────────────────────────
  double _brightness = 0.0;  // -1.0 to 1.0
  double _warmth = 0.0;      // -1.0 to 1.0
  double _contrast = 0.0;    // -1.0 to 1.0

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

  /// Builds a 5×4 color matrix combining brightness, warmth and contrast.
  ColorFilter _buildColorFilter() {
    final b = _brightness * 0.3;       // brightness offset
    final w = _warmth * 0.15;          // warmth: warm R+, cool B+
    final c = 1.0 + _contrast * 0.5;  // contrast scale
    final t = (1.0 - c) / 2.0;        // translate to keep midpoint
    return ColorFilter.matrix([
      c,   0,   0,   0,  (t + b + w) * 255,
      0,   c,   0,   0,  (t + b)     * 255,
      0,   0,   c,   0,  (t + b - w) * 255,
      0,   0,   0,   1,  0,
    ]);
  }

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

  // ── Draft saving ──────────────────────────────────────────────────────────

  Future<void> _saveDraftIfNeeded() async {
    if (_submitted) return;
    final text = _textController.text.trim();
    if (text.length < _minChars) return;
    final draft = DraftEntry(
      id: _draftId,
      type: DraftType.text,
      rawText: text,
      savedAt: DateTime.now(),
      entryDate: DateTime.now(),
      attachedPhotoPath: _photoPath,
    );
    await ref.read(draftSyncServiceProvider).saveDraft(draft);
    ref.invalidate(draftsProvider);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _onBack() async {
    await _saveDraftIfNeeded();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _onContinue() {
    final text = _textController.text.trim();
    if (text.length < _minChars) return;
    _submitted = true;
    HapticFeedback.mediumImpact();
    if (_isVoiceMode && _audioPath != null) {
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
        '/processing',
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
    return PopScope(
      onPopInvokedWithResult: (_, __) => _saveDraftIfNeeded(),
      child: Scaffold(
        backgroundColor: colors.bg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: _onBack,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withAlpha(90),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildPhotoHero(colors),
              Expanded(child: _buildTextArea(colors)),
              if (_isRecordingVoice)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _buildRecordingIndicator(colors),
                ),
              _buildBottomActions(colors),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photo hero (full-width, 4:5 aspect — taller, immersive) ──────────────

  Widget _buildPhotoHero(AppPalette colors) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: GestureDetector(
        onPanUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final size = box.size;
          final dx = -details.delta.dx / size.width * 3.0;
          final dy = -details.delta.dy / size.height * 3.0;
          setState(() {
            _focalAlignment = Alignment(
              (_focalAlignment.x + dx).clamp(-1.0, 1.0),
              (_focalAlignment.y + dy).clamp(-1.0, 1.0),
            );
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
                : ColorFiltered(
                    colorFilter: _buildColorFilter(),
                    child: Image.file(
                      File(_photoPath),
                      fit: BoxFit.cover,
                      alignment: _focalAlignment,
                      errorBuilder: (_, __, ___) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _photoLoadError = true);
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
            // Bottom gradient
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(120)],
                  ),
                ),
              ),
            ),
            // Bottom pills: Edit (crop/adjust) + Change photo + Drag hint
            Positioned(
              bottom: 10, left: 16, right: 16,
              child: Row(
                children: [
                  // Edit pencil — opens crop + brightness/warmth/contrast sheet
                  GestureDetector(
                    onTap: () => _showReframeSheet(AppColors.of(context)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('Edit',
                              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Change photo — pick a different photo
                  GestureDetector(
                    onTap: _changePhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('Change',
                              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Borderless text area ──────────────────────────────────────────────────

  Widget _buildTextArea(AppPalette colors) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isVoiceMode && !_isRecordingVoice)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                      Text('Voice transcription',
                          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: colors.accent)),
                    ],
                  ),
                ),
              ),
            TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              minLines: 3,
              maxLines: 12,
              readOnly: _isRecordingVoice,
              style: GoogleFonts.newsreader(fontSize: 17, color: colors.textPrimary, height: 1.7),
              decoration: InputDecoration(
                hintText: _isRecordingVoice
                    ? 'Listening… speak your memory'
                    : 'What happened here?\nTell the story of this moment…',
                hintStyle: GoogleFonts.newsreader(
                    fontSize: 17, color: colors.textSecondary.withAlpha(100), height: 1.7),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            AnimatedOpacity(
              opacity: _textController.text.isNotEmpty && !_hasEnoughText && !_isRecordingVoice ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Write a little more to continue…',
                    style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary.withAlpha(140))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom action bar: Record (outline) + Continue (filled) ───────────────

  Widget _buildBottomActions(AppPalette colors) {
    final canContinue = _hasEnoughText && !_isRecordingVoice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          // Record / Stop button (outline)
          Expanded(
            flex: 4,
            child: GestureDetector(
              key: const Key('voice_toggle_button'),
              onTap: _isRecordingVoice ? _stopVoiceRecording : _startVoiceRecording,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isRecordingVoice ? Colors.red.withAlpha(160) : colors.border,
                    width: _isRecordingVoice ? 1.5 : 1,
                  ),
                  color: _isRecordingVoice ? Colors.red.withAlpha(15) : Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRecordingVoice ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 18,
                      color: _isRecordingVoice ? Colors.red : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isRecordingVoice ? 'Stop' : 'Record',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isRecordingVoice ? Colors.red : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Continue button (filled)
          Expanded(
            flex: 6,
            child: AnimatedOpacity(
              opacity: canContinue ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: canContinue ? _onContinue : null,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Continue →',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a bottom sheet for drag-to-reframe + photo adjustments.
  void _showReframeSheet(AppPalette colors) {
    Alignment tempAlignment = _focalAlignment;
    double tempBrightness = _brightness;
    double tempWarmth = _warmth;
    double tempContrast = _contrast;

    ColorFilter buildFilter() {
      final b = tempBrightness * 0.3;
      final w = tempWarmth * 0.15;
      final c = 1.0 + tempContrast * 0.5;
      final t = (1.0 - c) / 2.0;
      return ColorFilter.matrix([
        c, 0, 0, 0, (t + b + w) * 255,
        0, c, 0, 0, (t + b)     * 255,
        0, 0, c, 0, (t + b - w) * 255,
        0, 0, 0, 1, 0,
      ]);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          'Edit Photo',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        if (!_isDesktop)
                          GestureDetector(
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final cropped = await _cropPhoto(_photoPath);
                              if (cropped != null && mounted) {
                                setState(() {
                                  _photoPath = cropped;
                                  _focalAlignment = Alignment.center;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.crop_rounded, size: 13, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('Crop', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _focalAlignment = tempAlignment;
                              _brightness = tempBrightness;
                              _warmth = tempWarmth;
                              _contrast = tempContrast;
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Done', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Photo drag area
                  Expanded(
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final box = ctx.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final size = box.size;
                        final dx = -details.delta.dx / size.width * 2.5;
                        final dy = -details.delta.dy / size.height * 2.5;
                        setSheetState(() {
                          tempAlignment = Alignment(
                            (tempAlignment.x + dx).clamp(-1.0, 1.0),
                            (tempAlignment.y + dy).clamp(-1.0, 1.0),
                          );
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                        child: _photoLoadError
                            ? const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54))
                            : ColorFiltered(
                                colorFilter: buildFilter(),
                                child: Image.file(
                                  File(_photoPath),
                                  fit: BoxFit.cover,
                                  alignment: tempAlignment,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                      ),
                    ),
                  ),
                  // ── Adjustment sliders ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      children: [
                        _AdjustSlider(
                          label: 'Brightness',
                          icon: Icons.wb_sunny_outlined,
                          value: tempBrightness,
                          onChanged: (v) => setSheetState(() => tempBrightness = v),
                        ),
                        const SizedBox(height: 8),
                        _AdjustSlider(
                          label: 'Warmth',
                          icon: Icons.thermostat_outlined,
                          value: tempWarmth,
                          onChanged: (v) => setSheetState(() => tempWarmth = v),
                        ),
                        const SizedBox(height: 8),
                        _AdjustSlider(
                          label: 'Contrast',
                          icon: Icons.contrast_outlined,
                          value: tempContrast,
                          onChanged: (v) => setSheetState(() => tempContrast = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
          GestureDetector(
            onTap: _stopVoiceRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_rounded, size: 13, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Stop',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Adjustment slider row ─────────────────────────────────────────────────────

class _AdjustSlider extends StatelessWidget {
  const _AdjustSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 2,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: value,
              min: -1.0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value == 0 ? '0' : value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: GoogleFonts.manrope(
              fontSize: 10,
              color: Colors.white54,
            ),
          ),
        ),
      ],
    );
  }
}