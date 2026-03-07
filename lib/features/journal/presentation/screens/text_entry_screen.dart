import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/services/encryption/encryption_service.dart';
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
  bool _isSaving = false;
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

  late final JournalRepository _repository = JournalRepository(
    client: Supabase.instance.client,
    encryption: EncryptionService(),
  );

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Future<void> _saveEntry({bool addToBook = false}) async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toUtc();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        userId: Supabase.instance.client.auth.currentUser!.id,
        content: text,
        rawContent: text,
        entryDate: now,
        entryTime: TimeOfDay.fromDateTime(now),
        isAiPolished: _polishWithAI,
        locationName: _locationName,
        hasPhoto: _attachedPhotoPath != null,
        wordCount: text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.createEntry(entry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(addToBook ? 'Saved to your book!' : 'Entry saved!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: DearDaysHeader.appBar(
        context: context,
        title: 'New Entry',
        mode: HeaderMode.modal,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _saveEntry(),
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildAISuggestionCard(),
                  const SizedBox(height: 24),
                  _buildTextArea(),
                ],
              ),
            ),
          ),
          _buildBottomToolbar(),
          _buildSaveToBookButton(),
        ],
      ),
    );
  }

  Widget _buildAISuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI SUGGESTION',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _prompts[_promptIndex],
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _nextPrompt,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'New Prompt',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dear Diary,',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          maxLines: null,
          minLines: 12,
          keyboardType: TextInputType.multiline,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
            height: 1.7,
          ),
          decoration: InputDecoration(
            hintText: 'Start writing your thoughts...',
            hintStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
              height: 1.7,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        border: Border(
          top: BorderSide(
            color: Colors.black.withAlpha(15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _attachPhoto,
            icon: Icon(
              _attachedPhotoPath != null
                  ? Icons.photo
                  : Icons.photo_outlined,
              color: _attachedPhotoPath != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _addLocation,
            icon: Icon(
              _locationName != null
                  ? Icons.location_on
                  : Icons.location_on_outlined,
              color: _locationName != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          if (_locationName != null) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _locationName!,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            'Polish with AI',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _polishWithAI,
            onChanged: (value) {
              setState(() {
                _polishWithAI = value;
              });
            },
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.black12,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveToBookButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : () => _saveEntry(addToBook: true),
          icon: const Icon(Icons.book_outlined, size: 20),
          label: Text(
            'Save to Book',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
