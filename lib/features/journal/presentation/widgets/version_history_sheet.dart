import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Bottom sheet that shows the version history of a journal entry.
///
/// Displays up to 3 versions:
/// - Raw: Original transcript or typed text
/// - Clean: Light-polished (grammar/spelling fixes)
/// - AI Story: Full AI literary narrative
class VersionHistorySheet extends StatefulWidget {
  final JournalEntry entry;

  const VersionHistorySheet({super.key, required this.entry});

  /// Shows the version history sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context, JournalEntry entry) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VersionHistorySheet(entry: entry),
    );
  }

  @override
  State<VersionHistorySheet> createState() => _VersionHistorySheetState();
}

class _VersionHistorySheetState extends State<VersionHistorySheet> {
  int _selectedVersion = 0;

  List<_VersionData> get _versions {
    final versions = <_VersionData>[];

    // AI Story version (polished narrative)
    if (widget.entry.polishedContent != null &&
        widget.entry.polishedContent!.isNotEmpty) {
      versions.add(_VersionData(
        label: 'AI Story',
        icon: Icons.auto_awesome_rounded,
        description: 'Full AI literary narrative',
        content: widget.entry.polishedContent!,
      ));
    }

    // Clean version (light polish / current content)
    versions.add(_VersionData(
      label: 'Clean',
      icon: Icons.edit_note_rounded,
      description: 'Grammar & spelling fixed',
      content: widget.entry.content,
    ));

    // Raw version (original transcript)
    if (widget.entry.rawContent != null &&
        widget.entry.rawContent!.isNotEmpty &&
        widget.entry.rawContent != widget.entry.content) {
      versions.add(_VersionData(
        label: 'Original',
        icon: Icons.mic_rounded,
        description: 'Raw transcript or typed text',
        content: widget.entry.rawContent!,
      ));
    }

    return versions;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final versions = _versions;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textMuted.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 22, color: colors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Version History',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${versions.length} version${versions.length == 1 ? '' : 's'} available',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded,
                      size: 22, color: colors.textMuted),
                ),
              ],
            ),
          ),

          // Version tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(versions.length, (i) {
                final v = versions[i];
                final isSelected = i == _selectedVersion;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedVersion = i),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: i < versions.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent.withAlpha(15)
                            : colors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? colors.accent
                              : colors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(v.icon,
                              size: 18,
                              color: isSelected
                                  ? colors.accent
                                  : colors.textMuted),
                          const SizedBox(height: 4),
                          Text(
                            v.label,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? colors.accent
                                  : colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Version description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    versions[_selectedVersion].description,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Content
          Flexible(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  versions[_selectedVersion].content,
                  style: GoogleFonts.newsreader(
                    fontSize: 15,
                    color: colors.textPrimary,
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionData {
  final String label;
  final IconData icon;
  final String description;
  final String content;

  const _VersionData({
    required this.label,
    required this.icon,
    required this.description,
    required this.content,
  });
}
