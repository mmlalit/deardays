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
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _expandedSections = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInProvider);
    final sections = state.sections;

    if (sections.isEmpty) {
      return _buildEmptyState();
    }

    // Filter sections by search query
    final filtered = _searchQuery.isEmpty
        ? sections
        : sections.where((s) {
            final userText = s.messages
                .where((m) => m.isUser)
                .map((m) => m.text.toLowerCase())
                .join(' ');
            return userText.contains(_searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _buildSearchBar(),
        ),
        // Content
        Expanded(
          child: filtered.isEmpty
              ? _buildNoResults()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: filtered.length + 1, // +1 for header
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildDateHeader();
                    final sectionIndex = index - 1;
                    final section = filtered[sectionIndex];
                    final originalIndex = sections.indexOf(section);
                    return _buildEntryCard(
                        section, originalIndex, sectionIndex == filtered.length - 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(26)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search your entries...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textMuted,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: AppColors.textMuted,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
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
              Icons.auto_stories_outlined,
              size: 56,
              color: AppColors.primary.withAlpha(76),
            ),
            const SizedBox(height: 16),
            Text(
              'No entries yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a check-in from the home screen\nto see your journal entries here.',
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

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 40,
              color: AppColors.textMuted.withAlpha(76),
            ),
            const SizedBox(height: 12),
            Text(
              'No matching entries',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(today);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        dateStr,
        style: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEntryCard(
      ConversationSection section, int originalIndex, bool isLast) {
    final timeStr = DateFormat('h:mm a').format(section.startTime);
    final userMessages = section.messages.where((m) => m.isUser).toList();
    final isExpanded = _expandedSections.contains(originalIndex);

    // Combine user messages into a single narrative
    final narrative = userMessages.map((m) => m.text).join('\n\n');
    final preview = narrative.length > 150
        ? '${narrative.substring(0, 150)}...'
        : narrative;
    final wordCount =
        userMessages.fold<int>(0, (sum, m) => sum + m.text.split(' ').length);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 32 : 12),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedSections.remove(originalIndex);
            } else {
              _expandedSections.add(originalIndex);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isExpanded
                  ? AppColors.primary.withAlpha(51)
                  : AppColors.primary.withAlpha(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isExpanded ? 10 : 5),
                blurRadius: isExpanded ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: mood + time + word count
              Row(
                children: [
                  if (section.mood != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _moodColor(section.mood!).withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _moodIcon(section.mood!),
                            size: 12,
                            color: _moodColor(section.mood!),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            section.mood!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _moodColor(section.mood!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '$wordCount words',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Entry text
              Text(
                isExpanded ? narrative : preview,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.7,
                ),
              ),
              // Voice indicator
              if (userMessages.any((m) => m.isVoice)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.mic, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      'From voice',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
              // Expand/collapse hint
              if (narrative.length > 150) ...[
                const SizedBox(height: 8),
                Center(
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
