import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';

class ConversationsView extends ConsumerWidget {
  const ConversationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkInProvider);
    final sections = state.sections;

    if (sections.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          _buildDateHeader(),
          const SizedBox(height: 20),
          // Conversation sections
          ...sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            return _buildConversationSection(section, index, sections.length);
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 56,
              color: AppColors.primary.withAlpha(76),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a check-in from the home screen\nto see your conversations here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your conversations today',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildConversationSection(
    ConversationSection section,
    int index,
    int total,
  ) {
    final timeStr = DateFormat('h:mm a').format(section.startTime);
    final userMessages = section.messages.where((m) => m.isUser).toList();
    final aiMessages = section.messages.where((m) => !m.isUser).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section divider with time
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: section.mood != null
                      ? _moodColor(section.mood!)
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                timeStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (section.mood != null) ...[
                const SizedBox(width: 8),
                Text(
                  '\u2022',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Feeling ${section.mood}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _moodColor(section.mood!),
                  ),
                ),
              ],
              const Spacer(),
              if (section.messages.isNotEmpty)
                Text(
                  '${section.messages.length} messages',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Conversation content — like a book page
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withAlpha(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Render conversation as flowing dialogue
                ...section.messages.asMap().entries.map((entry) {
                  final msg = entry.value;
                  final msgTime = DateFormat('h:mm a').format(msg.timestamp);

                  if (msg.isUser) {
                    return _buildUserEntry(msg, msgTime);
                  } else {
                    return _buildAiPrompt(msg, msgTime);
                  }
                }),
              ],
            ),
          ),
          // Connecting line to next section
          if (index < total - 1)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 2,
                height: 24,
                color: AppColors.primary.withAlpha(38),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserEntry(ChatMessage msg, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User text — styled like book prose
          Text(
            msg.text,
            style: GoogleFonts.playfairDisplay(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (msg.isVoice) ...[
                Icon(
                  Icons.mic,
                  size: 10,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 3),
              ],
              Text(
                time,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiPrompt(ChatMessage msg, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppColors.primary.withAlpha(76),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return AppColors.moodGreat;
      case 'good':
        return AppColors.moodGood;
      case 'okay':
        return AppColors.moodOkay;
      case 'low':
        return AppColors.moodLow;
      case 'tough':
        return AppColors.moodTough;
      default:
        return AppColors.textSecondary;
    }
  }
}
