import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/core/domain/repositories/journal_repository_interface.dart';
import 'package:deardays/core/domain/services/media_service_interface.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/services/location/location_service.dart';

// ---------------------------------------------------------------------------
// Entry point — accepts a saved JournalEntry from timeline / detail screen.
// ---------------------------------------------------------------------------

class EditMemoryScreen extends ConsumerStatefulWidget {
  final JournalEntry entry;

  const EditMemoryScreen({super.key, required this.entry});

  @override
  ConsumerState<EditMemoryScreen> createState() => _EditMemoryScreenState();
}

class _EditMemoryScreenState extends ConsumerState<EditMemoryScreen> {
  // ── repository / services — injected via Riverpod providers ─────────────
  // (resolved lazily on first use so ref is available after initState)
  IJournalRepository get _repository => ref.read(journalRepositoryProvider);
  IMediaService get _mediaService => ref.read(mediaServiceProvider);
  LocationService get _locationService => ref.read(locationServiceProvider);
  final _imagePicker = ImagePicker();

  // ── story controllers ─────────────────────────────────────────────────────
  late final TextEditingController _titleController;
  late final TextEditingController _storyController;
  late final TextEditingController _originalController;

  // ── edit-original mode ────────────────────────────────────────────────────
  bool _editingOriginal = false;

  // ── metadata state ────────────────────────────────────────────────────────
  String? _selectedMood;
  String? _locationName;
  late DateTime _entryDate;
  TimeOfDay? _entryTime;

  // ── tags ──────────────────────────────────────────────────────────────────
  late List<String> _tags;
  final _tagController = TextEditingController();

  // ── photo ─────────────────────────────────────────────────────────────────
  /// Local file path if user picked a new photo this session.
  String? _newPhotoPath;

  /// Resolved URL of the existing remote photo (lazy-loaded once).
  String? _existingPhotoUrl;
  bool _removePhoto = false;

  /// Focal alignment for drag-to-reframe; resets to center on photo change.
  Alignment _focalAlignment = Alignment.center;
  bool _showDragHint = true;

  // ── save state ────────────────────────────────────────────────────────────
  bool _isSaving = false;

  // ── mood options ──────────────────────────────────────────────────────────
  static const _moods = [
    ('great', '😄', 'Great'),
    ('good', '🙂', 'Good'),
    ('okay', '😐', 'Okay'),
    ('low', '😔', 'Low'),
    ('tough', '😢', 'Tough'),
  ];

  static const _suggestedTags = [
    'Family', 'Travel', 'Work', 'Friends', 'Nature',
    'Food', 'Health', 'Gratitude', 'Achievement', 'Funny',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Init / Dispose
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final e = widget.entry;

    // Parse polished content: stored as "title\n\nbody"
    final pc = e.polishedContent ?? '';
    final pcLines = pc.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final hasTitle = pcLines.length > 1;
    final parsedTitle = hasTitle ? pcLines.first : '';
    final parsedBody = hasTitle
        ? pcLines.skip(1).join('\n\n').trim()
        : pc.trim();

    _titleController = TextEditingController(text: parsedTitle);
    _storyController = TextEditingController(
      text: parsedBody.isNotEmpty
          ? parsedBody
          : (e.polishedContent != null && e.polishedContent!.isNotEmpty
              ? e.polishedContent!
              : e.content),
    );
    _originalController = TextEditingController(text: e.rawContent ?? e.content);

    _selectedMood = e.mood;
    _locationName = e.locationName;
    _entryDate = e.entryDate;
    _entryTime = e.entryTime;
    _tags = List.from(e.tags);

    // Load photo URL if entry has media
    _loadExistingPhoto();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    _originalController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPhoto() async {
    final photo = widget.entry.media
        .where((m) => m.mediaType == 'photo')
        .firstOrNull;
    if (photo == null) return;
    try {
      final url = photo.storagePath.startsWith('http')
          ? photo.storagePath
          : await _mediaService.getSignedUrl(photo.storagePath);
      if (mounted) setState(() => _existingPhotoUrl = url);
    } catch (e, st) {
      debugPrint('[EditMemory] Photo load error: $e\n$st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();
      final body = _storyController.text.trim();

      // Rebuild polishedContent: "title\n\nbody" (same format as ProcessingScreen)
      String? polishedContent;
      if (title.isNotEmpty || body.isNotEmpty) {
        polishedContent = title.isNotEmpty ? '$title\n\n$body' : body;
      }

      // Rebuild word count from the currently edited text
      final editedText = _storyController.text.trim();
      final wordCount = editedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

      // C-08 FIX: Upload new photo FIRST. Only update DB after upload succeeds.
      // This ensures the DB is never written with a storage path that doesn't exist.
      String? newEntryMediaUploaded; // non-null means upload succeeded
      if (_newPhotoPath != null) {
        try {
          await _mediaService.uploadPhoto(
            entryId: widget.entry.id,
            filePath: _newPhotoPath!,
            focalAlignment: _focalAlignment,
          );
          newEntryMediaUploaded = _newPhotoPath;
        } catch (uploadError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo upload failed. Changes not saved — please try again.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return; // Abort: do NOT update DB if photo upload failed
        }
      }

      final updated = widget.entry.copyWith(
        polishedContent: polishedContent,
        rawContent: _editingOriginal ? _originalController.text.trim() : widget.entry.rawContent,
        mood: _selectedMood,
        locationName: _locationName,
        entryDate: _entryDate,
        entryTime: _entryTime,
        wordCount: wordCount,
        tags: _tags,
        hasPhoto: newEntryMediaUploaded != null ||
            (!_removePhoto && widget.entry.hasPhoto),
        updatedAt: DateTime.now().toUtc(),
      );

      // Step 2: Update DB only after photo upload has already succeeded (or was not needed)
      final saved = await _repository.updateEntry(updated);

      // Step 3: Delete OLD photo ONLY after DB is updated (compensating action — non-critical)
      if (newEntryMediaUploaded != null) {
        final oldPhotos = widget.entry.media.where((m) => m.mediaType == 'photo').toList();
        for (final old in oldPhotos) {
          try {
            await _mediaService.deleteMedia(old);
          } catch (e) {
            debugPrint('[EditMemory] Old photo cleanup failed (non-critical): $e');
          }
        }
        _mediaService.clearCachedUrls(
          widget.entry.media.map((m) => m.storagePath).toList(),
        );
      }

      if (mounted) {
        ref.invalidate(timelineEntriesProvider);
        ref.invalidate(todayEntryProvider);
        ref.invalidate(onThisDayProvider);
        context.pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Re-process (Edit Original path)
  // ─────────────────────────────────────────────────────────────────────────

  void _confirmReprocess() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Regenerate Story?',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'Saving your edited original text will create a new AI-polished story. Your current story will be replaced.',
          style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.manrope(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _goToReprocess();
            },
            child: Text('Re-process',
                style: GoogleFonts.manrope(
                    color: colors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _goToReprocess() {
    final newText = _originalController.text.trim();
    if (newText.isEmpty) return;
    context.push('/processing',
        extra: ReviewData(
          rawText: newText,
          isVoice: widget.entry.hasVoice,
          mood: _selectedMood,
          locationName: _locationName,
          attachedPhotoPath: _newPhotoPath,
        ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Photo actions
  // ─────────────────────────────────────────────────────────────────────────

  void _showPhotoOptions() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: colors.accent),
              title: Text('Choose from gallery',
                  style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary)),
              onTap: () { Navigator.pop(ctx); _pickFromGallery(); },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: colors.accent),
              title: Text('Take a photo',
                  style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary)),
              onTap: () { Navigator.pop(ctx); _takePhoto(); },
            ),
            if (_newPhotoPath != null ||
                (_existingPhotoUrl != null && !_removePhoto))
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text('Remove photo',
                    style: GoogleFonts.manrope(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (await _confirmPhotoRemove(context)) {
                    setState(() {
                      _newPhotoPath = null;
                      _removePhoto = true;
                    });
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmPhotoRemove(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove photo?'),
            content: const Text(
                'This photo will be permanently removed from your memory.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(
          source: ImageSource.gallery, maxWidth: 1920, imageQuality: 75);
      if (picked != null && mounted) {
        setState(() {
          _newPhotoPath = picked.path;
          _removePhoto = false;
          _focalAlignment = Alignment.center;
          _showDragHint = true;
        });
      }
    } catch (e) { debugPrint('[EditMemory] Error: $e'); }
  }

  Future<void> _takePhoto() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    try {
      final picked = await _imagePicker.pickImage(
          source: ImageSource.camera, maxWidth: 1920, imageQuality: 75);
      if (picked != null && mounted) {
        setState(() {
          _newPhotoPath = picked.path;
          _removePhoto = false;
          _focalAlignment = Alignment.center;
          _showDragHint = true;
        });
      }
    } catch (e) { debugPrint('[EditMemory] Error: $e'); }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Location
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _editLocation() async {
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: _locationName ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location',
                style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.manrope(
                  fontSize: 15, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter location name...',
                hintStyle:
                    GoogleFonts.manrope(color: colors.textMuted),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: colors.accent, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final loc =
                          await _locationService.getCurrentLocation();
                      if (loc?.locationName != null && mounted) {
                        setState(
                            () => _locationName = loc!.locationName);
                      }
                    } catch (e) { debugPrint('[EditMemory] Error: $e'); }
                  },
                  icon: Icon(Icons.my_location_rounded,
                      size: 16, color: colors.accent),
                  label: Text('Use current location',
                      style: GoogleFonts.manrope(
                          fontSize: 13, color: colors.accent)),
                ),
                const Spacer(),
                if (_locationName != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _locationName = null);
                      Navigator.pop(ctx);
                    },
                    child: Text('Clear',
                        style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: colors.textSecondary)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final v = controller.text.trim();
                    setState(
                        () => _locationName = v.isEmpty ? null : v);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Save',
                      style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Date / Time
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
              primary: AppColors.of(context).accent),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _entryDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _entryTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
              primary: AppColors.of(context).accent),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _entryTime = picked);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tags
  // ─────────────────────────────────────────────────────────────────────────

  void _showTagSheet() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tags',
                  style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 12),
              TextField(
                controller: _tagController,
                autofocus: false,
                style: GoogleFonts.manrope(
                    fontSize: 15, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a tag and press enter...',
                  hintStyle:
                      GoogleFonts.manrope(color: colors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.check_rounded,
                        color: colors.accent),
                    onPressed: () {
                      final t = _tagController.text.trim();
                      if (t.isNotEmpty && !_tags.contains(t)) {
                        setState(() => _tags.add(t));
                        setSheet(() {});
                      }
                      _tagController.clear();
                    },
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: colors.accent, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty && !_tags.contains(t)) {
                    setState(() => _tags.add(t));
                    setSheet(() {});
                  }
                  _tagController.clear();
                },
              ),
              const SizedBox(height: 16),
              Text('Suggestions',
                  style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedTags.map((t) {
                  final active = _tags.contains(t);
                  return GestureDetector(
                    onTap: () {
                      if (active) {
                        setState(() => _tags.remove(t));
                      } else {
                        setState(() => _tags.add(t));
                      }
                      setSheet(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? colors.accent
                            : colors.accentFaint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active
                                ? colors.accent
                                : colors.border),
                      ),
                      child: Text(t,
                          style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : colors.textPrimary)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _buildTopBar(colors),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  _buildPhotoBanner(colors),

                  const SizedBox(height: 24),

                  // ── STORY section ──────────────────────────────────────
                  _sectionLabel('STORY', colors),
                  const SizedBox(height: 12),
                  _buildTitleField(colors),
                  const SizedBox(height: 12),
                  _editingOriginal
                      ? _buildOriginalEditor(colors)
                      : _buildStoryEditor(colors),
                  const SizedBox(height: 12),
                  _buildEditOriginalButton(colors),

                  const SizedBox(height: 28),
                  Divider(color: colors.border, indent: 20, endIndent: 20),
                  const SizedBox(height: 20),

                  // ── MOOD section ───────────────────────────────────────
                  _sectionLabel('MOOD', colors),
                  const SizedBox(height: 12),
                  _buildMoodSelector(colors),

                  const SizedBox(height: 24),
                  Divider(color: colors.border, indent: 20, endIndent: 20),
                  const SizedBox(height: 20),

                  // ── DETAILS section ────────────────────────────────────
                  _sectionLabel('DETAILS', colors),
                  const SizedBox(height: 12),
                  _buildDetailRow(colors),

                  const SizedBox(height: 24),
                  Divider(color: colors.border, indent: 20, endIndent: 20),
                  const SizedBox(height: 20),

                  // ── TAGS section ───────────────────────────────────────
                  _sectionLabel('TAGS', colors),
                  const SizedBox(height: 12),
                  _buildTagsRow(colors),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.cardBg,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: colors.textPrimary),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Edit Memory',
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isSaving ? null : _saveChanges,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSaving
                        ? colors.accent.withAlpha(100)
                        : colors.accent,
                  ),
                  child: _isSaving
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded,
                          size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Photo Banner
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPhotoBanner(AppPalette colors) {
    final hasPhoto = _newPhotoPath != null ||
        (_existingPhotoUrl != null && !_removePhoto);

    return GestureDetector(
      // Drag reframes the focal point; tap opens photo options
      onPanUpdate: hasPhoto
          ? (details) {
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
            }
          : null,
      onTap: _showPhotoOptions,
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background photo or placeholder
            if (_newPhotoPath != null)
              Image.file(
                File(_newPhotoPath!),
                fit: BoxFit.cover,
                alignment: _focalAlignment,
                errorBuilder: (_, __, ___) => _photoBg(colors),
              )
            else if (_existingPhotoUrl != null && !_removePhoto)
              CachedNetworkImage(
                imageUrl: _existingPhotoUrl!,
                fit: BoxFit.cover,
                alignment: _focalAlignment,
                placeholder: (_, __) => _photoBg(colors),
                errorWidget: (_, __, ___) => _photoBg(colors),
              )
            else
              _photoBg(colors),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(120),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Drag-to-reframe hint
            if (hasPhoto && _showDragHint)
              Positioned(
                bottom: 44,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
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

            // Change/Add photo badge (bottom-right)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(120),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPhoto
                          ? Icons.edit_rounded
                          : Icons.add_a_photo_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasPhoto ? 'Change photo' : 'Add photo',
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
    );
  }

  Widget _photoBg(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withAlpha(60),
            colors.accentLight.withAlpha(40)
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.add_a_photo_rounded,
            size: 40, color: colors.textMuted),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Story Section
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTitleField(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _titleController,
        maxLines: 1,
        style: GoogleFonts.newsreader(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Title',
          hintStyle: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textMuted),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildStoryEditor(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: TextField(
          controller: _storyController,
          maxLines: null,
          minLines: 6,
          style: GoogleFonts.newsreader(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: colors.textPrimary,
            height: 1.75,
          ),
          decoration: InputDecoration(
            hintText: 'Your polished story...',
            hintStyle: GoogleFonts.newsreader(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: colors.textMuted),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
    );
  }

  Widget _buildOriginalEditor(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: colors.accent.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 15, color: colors.accent),
                const SizedBox(width: 6),
                Text(
                  'Editing original text — save to re-process with AI',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      setState(() => _editingOriginal = false),
                  child: Icon(Icons.close_rounded,
                      size: 15, color: colors.accent),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12)),
              border: Border.all(color: colors.accent.withAlpha(40)),
            ),
            child: TextField(
              controller: _originalController,
              maxLines: null,
              minLines: 6,
              style: GoogleFonts.manrope(
                fontSize: 15,
                color: colors.textPrimary,
                height: 1.65,
              ),
              decoration: InputDecoration(
                hintText: 'Your original words...',
                hintStyle: GoogleFonts.manrope(
                    fontSize: 15, color: colors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmReprocess,
              icon: const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Colors.white),
              label: Text(
                'Save & Re-generate Story',
                style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditOriginalButton(AppPalette colors) {
    if (_editingOriginal) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => setState(() => _editingOriginal = true),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded,
                  size: 14, color: colors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Edit original text',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: colors.textMuted.withAlpha(150)),
              const SizedBox(width: 4),
              Text(
                'replaces story',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mood Selector
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMoodSelector(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _moods.map((mood) {
          final isSelected = _selectedMood == mood.$1;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(
                  () => _selectedMood = isSelected ? null : mood.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accent.withAlpha(20)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected ? colors.accent : colors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(mood.$2,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    mood.$3,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colors.accent
                          : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Details Row (location, date, time)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDetailRow(AppPalette colors) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr =
        '${months[_entryDate.month - 1]} ${_entryDate.day}, ${_entryDate.year}';
    final timeStr = _entryTime != null
        ? _entryTime!.format(context)
        : 'Set time';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _detailTile(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: _locationName ?? 'Add location',
            hasValue: _locationName != null,
            colors: colors,
            onTap: _editLocation,
          ),
          const SizedBox(height: 8),
          _detailTile(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: dateStr,
            hasValue: true,
            colors: colors,
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          _detailTile(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: timeStr,
            hasValue: _entryTime != null,
            colors: colors,
            onTap: _pickTime,
          ),
        ],
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
    required bool hasValue,
    required AppPalette colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color:
                    hasValue ? colors.accent : colors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                        letterSpacing: 0.4,
                      )),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: hasValue
                            ? colors.textPrimary
                            : colors.textMuted,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tags Row
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTagsRow(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Existing tags
          ..._tags.map((t) => GestureDetector(
                onTap: () => setState(() => _tags.remove(t)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t,
                          style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(width: 4),
                      Icon(Icons.close_rounded,
                          size: 13,
                          color: Colors.white.withAlpha(200)),
                    ],
                  ),
                ),
              )),
          // Add button
          GestureDetector(
            onTap: _showTagSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded,
                      size: 14, color: colors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Add tag',
                      style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section Label
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.textMuted,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
