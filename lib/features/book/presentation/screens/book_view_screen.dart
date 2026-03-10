import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

class BookViewScreen extends StatefulWidget {
  const BookViewScreen({super.key});

  @override
  State<BookViewScreen> createState() => _BookViewScreenState();
}

class _BookViewScreenState extends State<BookViewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildCoverSection(),
              const SizedBox(height: 32),
              _buildContentsSection(),
              const SizedBox(height: 28),
              _buildEntryDetail(),
              const SizedBox(height: 32),
              _buildDownloadButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'DEARDAYS',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: AppColors.readingText,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.of(context).accent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Memoir',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.of(context).accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.of(context).accent.withAlpha(153),
                  AppColors.of(context).accent,
                ],
              ),
            ),
            child: Icon(
              Icons.person,
              size: 40,
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'The Story of Sarah',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.readingText,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '2026 \u2014 Present',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.readingText.withAlpha(128),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Contents',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: AppColors.of(context).textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildChapterItem(
          title: 'March 2026: The Beginning',
          subtitle: 'CHAPTER 1 \u2022 12 ENTRIES',
          isActive: true,
        ),
        _buildChapterItem(
          title: 'February 2026: Winter Reflections',
          subtitle: 'CHAPTER 2 \u2022 9 ENTRIES',
          isActive: false,
        ),
        _buildChapterItem(
          title: 'January 2026: A Fresh Start',
          subtitle: 'CHAPTER 3 \u2022 15 ENTRIES',
          isActive: false,
        ),
      ],
    );
  }

  Widget _buildChapterItem({
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isActive ? AppColors.of(context).accent.withAlpha(13) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isActive ? AppColors.of(context).accent : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: AppColors.readingText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.readingText.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryDetail() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.readingText.withAlpha(20)),
          const SizedBox(height: 20),
          _buildEntryHeader(),
          const SizedBox(height: 24),
          _buildDropCapParagraph(),
          const SizedBox(height: 20),
          _buildPhotoPlaceholder(),
          const SizedBox(height: 20),
          _buildContinuationParagraph(),
          const SizedBox(height: 12),
          _buildContinuationParagraph2(),
        ],
      ),
    );
  }

  Widget _buildEntryHeader() {
    return Row(
      children: [
        Text(
          'March 7, 2026',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.readingText.withAlpha(153),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.readingText.withAlpha(64),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '\u263A Grateful',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.of(context).textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.readingText.withAlpha(64),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.readingText.withAlpha(102),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  'Home',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.readingText.withAlpha(102),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropCapParagraph() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'T',
          style: GoogleFonts.manrope(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: AppColors.of(context).textPrimary,
            height: 0.85,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'he morning light crept through the curtains in that gentle way it does '
            'when spring is just beginning to remember itself. I sat by the window '
            'with my coffee, watching the world slowly wake up. There is something '
            'profoundly beautiful about these quiet moments before the day demands '
            'anything of you.',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.readingText,
              height: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.of(context).accent.withAlpha(38),
            AppColors.of(context).accent.withAlpha(20),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_outlined,
            size: 36,
            color: AppColors.of(context).accent.withAlpha(102),
          ),
          const SizedBox(height: 8),
          Text(
            'Photo',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.of(context).accent.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuationParagraph() {
    return Text(
      'I called my mother today. We talked about nothing in particular \u2014 '
      'the weather, the neighbour\u2019s new dog, whether the tomatoes would '
      'survive another frost. But it wasn\u2019t about the words. It was about '
      'the sound of her voice, steady and warm, a reminder that some things '
      'remain unchanged even as everything else shifts.',
      style: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.readingText,
        height: 1.8,
      ),
    );
  }

  Widget _buildContinuationParagraph2() {
    return Text(
      'Tonight I will sleep with the window cracked open, letting the cool air '
      'carry in the scent of damp earth and early blossoms. Tomorrow will bring '
      'its own questions, but for now, this is enough. This is more than enough.',
      style: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.readingText,
        height: 1.8,
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/export'),
          icon: const Icon(Icons.download_rounded, size: 20),
          label: Text(
            'Download as PDF',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.of(context).textPrimary,
            foregroundColor: AppColors.of(context).card,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
