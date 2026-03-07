import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

class OnThisDayScreen extends StatelessWidget {
  const OnThisDayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 22, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ON THIS DAY',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Revisiting your favorite chapters',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Scrollable timeline ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1 Year Ago section ──
                    _buildSectionHeader('1 YEAR AGO TODAY'),
                    const SizedBox(height: 12),
                    _buildMemoryCard(
                      context,
                      year: '2024',
                      location: 'LOWER EAST SIDE, NY',
                      mood: 'Grateful',
                      quote:
                          'The afternoon light poured through the cafe window like liquid gold. I watched the steam rise from my cup and thought about how far we\'d come.',
                    ),
                    const SizedBox(height: 32),

                    // ── 3 Years Ago section ──
                    _buildSectionHeader('3 YEARS AGO TODAY'),
                    const SizedBox(height: 12),
                    _buildMemoryCard(
                      context,
                      year: '2022',
                      location: 'SILVER LAKE, LA',
                      mood: 'Hopeful',
                      quote:
                          'We planted the garden today. Tiny seeds in dark soil, full of impossible promise. I think that\'s what hope looks like.',
                    ),
                    const SizedBox(height: 32),

                    // ── Bottom prompt ──
                    _buildBottomPrompt(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ──
  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: Colors.black45,
      ),
    );
  }

  // ── Memory card ──
  Widget _buildMemoryCard(
    BuildContext context, {
    required String year,
    required String location,
    required String mood,
    required String quote,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Text(
                year,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Photo placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Icons.image_outlined,
                    size: 40, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Location + mood tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.place, size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.favorite, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  mood,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Narrative quote
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u201C',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      height: 0.6,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quote,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.55,
                      color: Colors.black87,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '\u201D',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        height: 0.6,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Read Full Entry button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Read Full Entry',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom prompt ──
  Widget _buildBottomPrompt() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 18, color: Colors.black38),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'That\u2019s all the memories for today.\nMake a new one?',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
