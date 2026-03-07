import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedMoodIndex;

  static const List<_MoodOption> _moods = [
    _MoodOption('Great', Icons.sentiment_very_satisfied),
    _MoodOption('Good', Icons.sentiment_satisfied),
    _MoodOption('Okay', Icons.sentiment_neutral),
    _MoodOption('Low', Icons.sentiment_dissatisfied),
    _MoodOption('Tough', Icons.sentiment_very_dissatisfied),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildMoodSelector(),
          const SizedBox(height: 36),
          _buildRecordButton(),
          const SizedBox(height: 36),
          _buildTodayEntry(),
          const SizedBox(height: 24),
          _buildOnThisDay(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NOVEMBER 14, 2025',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Good evening, Sarah',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.15),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              'S',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Mood selector
  // ──────────────────────────────────────────────

  Widget _buildMoodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling?',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_moods.length, (index) {
            final mood = _moods[index];
            final isSelected = _selectedMoodIndex == index;

            return GestureDetector(
              onTap: () => setState(() => _selectedMoodIndex = index),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.08),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      mood.icon,
                      size: 26,
                      color: isSelected
                          ? Colors.white
                          : AppColors.primary.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mood.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Record button
  // ──────────────────────────────────────────────

  Widget _buildRecordButton() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Record your day',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              // Navigate to write entry
            },
            child: Text(
              'Write instead',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Today's entry card
  // ──────────────────────────────────────────────

  Widget _buildTodayEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY\'S ENTRY',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mood badge + location + time
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.moodGood.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Good',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.moodGood,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Home',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '8:42 PM',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Narrative preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'The autumn light filtered through the kitchen window as I '
                      'made my morning coffee. There\'s something about this time '
                      'of year that makes ordinary moments feel like small gifts...',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Photo thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: AppColors.primary.withOpacity(0.12),
                      child: Icon(
                        Icons.photo_outlined,
                        size: 24,
                        color: AppColors.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // On This Day
  // ──────────────────────────────────────────────

  Widget _buildOnThisDay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ON THIS DAY',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1 Year Ago',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56,
                  height: 56,
                  color: AppColors.primary.withOpacity(0.15),
                  child: Icon(
                    Icons.photo_outlined,
                    size: 22,
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"We drove up to the mountains today and the leaves '
                  'were at their peak — a sea of amber and crimson..."',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Data model
// ──────────────────────────────────────────────

class _MoodOption {
  final String label;
  final IconData icon;

  const _MoodOption(this.label, this.icon);
}
