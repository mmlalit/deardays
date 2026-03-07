import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

class TextEntryScreen extends StatefulWidget {
  const TextEntryScreen({super.key});

  @override
  State<TextEntryScreen> createState() => _TextEntryScreenState();
}

class _TextEntryScreenState extends State<TextEntryScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _polishWithAI = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'New Entry',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: handle save
            },
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
        color: AppColors.primary.withOpacity(0.05),
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
            'What made you smile today?',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              // TODO: fetch new prompt
            },
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
            color: Colors.black87,
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
            color: Colors.black87,
            height: 1.7,
          ),
          decoration: InputDecoration(
            hintText: 'Start writing your thoughts...',
            hintStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.black26,
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
        color: AppColors.bg,
        border: Border(
          top: BorderSide(
            color: Colors.black.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // TODO: attach photo
            },
            icon: Icon(
              Icons.photo_outlined,
              color: Colors.black54,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              // TODO: add location
            },
            icon: Icon(
              Icons.location_on_outlined,
              color: Colors.black54,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const Spacer(),
          Text(
            'Polish with AI',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
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
          onPressed: () {
            // TODO: save to book
          },
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
