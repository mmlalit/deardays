import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';

class ConversationsView extends ConsumerStatefulWidget {
  const ConversationsView({super.key});

  @override
  ConsumerState<ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends ConsumerState<ConversationsView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInProvider);
    final sections = state.sections;

    if (sections.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover / title section
          _buildTitleSection(sections.length),
          const SizedBox(height: 28),
          // Contents list
          _buildContents(sections),
          // Active conversation detail
          if (_activeIndex != null &&
              _activeIndex! < sections.length) ...[
            const SizedBox(height: 8),
            _buildConversationDetail(sections[_activeIndex!]),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // -- Title Section (like Life Book cover) ------------------------------

  Widget _buildTitleSection(int count) {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(today);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.readingBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.readingText.withAlpha(26),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.chat_outlined,
              size: 36,
              color: AppColors.primary.withAlpha(153),
            ),
            const SizedBox(height: 16),
            Text(
              'Today\'s Conversations',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.readingText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dateStr,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.readingText.withAlpha(128),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withAlpha(102),
                ),
              ),
              child: Text(
                '$count session${count != 1 ? 's' : ''}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Contents list (like Life Book chapters) ---------------------------

  Widget _buildContents(List<ConversationSection> sections) {
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
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          return _buildContentItem(section, index);
        }),
      ],
    );
  }

  Widget _buildContentItem(ConversationSection section, int index) {
    final isActive = _activeIndex == index;
    final timeStr = DateFormat('h:mm a').format(section.startTime);
    final userMessages = section.messages.where((m) => m.isUser).toList();
    final messageCount = section.messages.length;
    final wordCount = userMessages.fold<int>(
        0, (sum, m) => sum + m.text.split(' ').length);

    // Generate a title from the first user message
    String title;
    if (userMessages.isNotEmpty) {
      final firstMsg = userMessages.first.text;
      title = firstMsg.length > 50
          ? '${firstMsg.substring(0, 50)}...'
          : firstMsg;
    } else {
      title = 'Conversation at $timeStr';
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeIndex = isActive ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withAlpha(13)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (first user message preview)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.readingText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Metadata line
                  Row(
                    children: [
                      Text(
                        timeStr.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.readingText.withAlpha(102),
                        ),
                      ),
                      if (section.mood != null) ...[
                        Text(
                          '  \u2022  ',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.readingText.withAlpha(64),
                          ),
                        ),
                        Icon(
                          _moodIcon(section.mood!),
                          size: 12,
                          color: _moodColor(section.mood!),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          section.mood!,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _moodColor(section.mood!),
                          ),
                        ),
                      ],
                      Text(
                        '  \u2022  $messageCount messages',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.readingText.withAlpha(102),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isActive
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_right,
              size: 20,
              color: isActive
                  ? AppColors.primary
                  : AppColors.readingText.withAlpha(76),
            ),
          ],
        ),
      ),
    );
  }

  // -- Conversation Detail (book-style reading view) --------------------

  Widget _buildConversationDetail(ConversationSection section) {
    final userMessages = section.messages.where((m) => m.isUser).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.readingText.withAlpha(20)),
          const SizedBox(height: 16),
          // Entry header (date + mood + time)
          Row(
            children: [
              Text(
                DateFormat('MMMM d, yyyy').format(section.startTime),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.readingText.withAlpha(153),
                ),
              ),
              if (section.mood != null) ...[
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
                Icon(
                  _moodIcon(section.mood!),
                  size: 14,
                  color: _moodColor(section.mood!),
                ),
                const SizedBox(width: 4),
                Text(
                  section.mood!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _moodColor(section.mood!),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Render conversation messages
          ...section.messages.asMap().entries.map((entry) {
            final msg = entry.value;
            final isFirst = entry.key == 0 && msg.isUser;
            return _buildMessageEntry(msg, isFirst);
          }),
        ],
      ),
    );
  }

  Widget _buildMessageEntry(ChatMessage msg, bool isFirstUserMsg) {
    if (msg.isUser) {
      return _buildUserEntry(msg, isFirstUserMsg);
    } else {
      return _buildAiEntry(msg);
    }
  }

  Widget _buildUserEntry(ChatMessage msg, bool isFirst) {
    // First user message gets a drop cap like Life Book
    if (isFirst && msg.text.length > 1) {
      final firstChar = msg.text[0].toUpperCase();
      final restText = msg.text.substring(1);

      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstChar,
                  style: GoogleFonts.manrope(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 0.85,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    restText,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: AppColors.readingText,
                      height: 1.8,
                    ),
                  ),
                ),
              ],
            ),
            if (msg.isVoice) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.mic, size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    'From voice',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Subsequent user messages — regular prose
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.text,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: AppColors.readingText,
              height: 1.8,
            ),
          ),
          if (msg.isVoice) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.mic, size: 11, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(
                  'From voice',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiEntry(ChatMessage msg) {
    // AI messages shown as indented, italic prompts with left border
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppColors.primary.withAlpha(64),
              width: 2,
            ),
          ),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  // -- Empty State ------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 56,
              color: AppColors.primary.withAlpha(76),
            ),
            const SizedBox(height: 16),
            Text(
              'No entries yet',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation from the home screen\nto see your journal entries here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
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

  // -- Mood helpers -----------------------------------------------------

  IconData _moodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return Icons.sentiment_very_satisfied;
      case 'good':
        return Icons.sentiment_satisfied;
      case 'okay':
        return Icons.sentiment_neutral;
      case 'low':
        return Icons.sentiment_dissatisfied;
      case 'tough':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
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
