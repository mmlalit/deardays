import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';
import 'package:deardays/features/book/data/services/book_generator_service.dart';

class BookCreationScreen extends ConsumerStatefulWidget {
  const BookCreationScreen({super.key});

  @override
  ConsumerState<BookCreationScreen> createState() => _BookCreationScreenState();
}

class _BookCreationScreenState extends ConsumerState<BookCreationScreen> {
  BookCreationApproach? _selectedApproach;

  List<JournalEntry> get _allEntries {
    final entriesAsync = ref.read(timelineEntriesProvider);
    return entriesAsync.valueOrNull ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DearDaysHeader(
              title: 'Create a Book',
              mode: HeaderMode.push,
            ),
            Expanded(
              child: _selectedApproach == null
                  ? _buildApproachSelection(context)
                  : _buildApproachFlow(context),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Approach Selection ───────────────────────────────────────────────

  Widget _buildApproachSelection(BuildContext context) {
    final colors = AppColors.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Choose how to create your book',
            style: GoogleFonts.newsreader(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select an approach and we\'ll help you build it.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildApproachCard(
            context,
            approach: BookCreationApproach.pickAndChoose,
            icon: Icons.checklist_rounded,
            title: 'Pick & Choose',
            description:
                'Manually select which entries and chapters go in your book. Full creative control.',
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 14),
          _buildApproachCard(
            context,
            approach: BookCreationApproach.dailyDiary,
            icon: Icons.calendar_month_rounded,
            title: 'Daily Diary',
            description:
                'Pick a date range and all your entries become pages, organized by day, week, and month.',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 14),
          _buildApproachCard(
            context,
            approach: BookCreationApproach.aiSurprise,
            icon: Icons.auto_awesome,
            title: 'AI Surprise Me',
            description:
                'Let AI curate the most meaningful entries from your journal into a beautiful book.',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildApproachCard(
    BuildContext context, {
    required BookCreationApproach approach,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedApproach = approach),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 16, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  // ─── Approach Flow Router ─────────────────────────────────────────────

  Widget _buildApproachFlow(BuildContext context) {
    switch (_selectedApproach!) {
      case BookCreationApproach.pickAndChoose:
        return _PickAndChooseFlow(
          entries: _allEntries,
          onBack: () => setState(() => _selectedApproach = null),
          onCreateBook: _onBookCreated,
        );
      case BookCreationApproach.dailyDiary:
        return _DailyDiaryFlow(
          entries: _allEntries,
          onBack: () => setState(() => _selectedApproach = null),
          onCreateBook: _onBookCreated,
        );
      case BookCreationApproach.aiSurprise:
        return _AiSurpriseFlow(
          entries: _allEntries,
          onBack: () => setState(() => _selectedApproach = null),
          onCreateBook: _onBookCreated,
        );
    }
  }

  void _onBookCreated(GeneratedBook book) {
    context.push('/book-detail', extra: book);
  }
}

// =============================================================================
// Pick & Choose Flow
// =============================================================================

class _PickAndChooseFlow extends StatefulWidget {
  final List<JournalEntry> entries;
  final VoidCallback onBack;
  final void Function(GeneratedBook) onCreateBook;

  const _PickAndChooseFlow({
    required this.entries,
    required this.onBack,
    required this.onCreateBook,
  });

  @override
  State<_PickAndChooseFlow> createState() => _PickAndChooseFlowState();
}

class _PickAndChooseFlowState extends State<_PickAndChooseFlow> {
  final _selected = <String>{};
  final _expandedMonths = <String>{};
  final _titleController = TextEditingController(text: 'My Story');

  Map<String, List<JournalEntry>> get _grouped {
    final map = <String, List<JournalEntry>>{};
    final sorted = List<JournalEntry>.from(widget.entries)
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    for (final e in sorted) {
      final key = DateFormat.yMMMM().format(e.entryDate);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final grouped = _grouped;

    return Column(
      children: [
        // Title input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _titleController,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Book Title',
              labelStyle: GoogleFonts.manrope(color: colors.textMuted),
              filled: true,
              fillColor: colors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.accent, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Selection count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${_selected.length} entries selected',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onBack,
                child: Text(
                  'Back',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Entry list grouped by month
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final month = grouped.keys.elementAt(index);
              final entries = grouped[month]!;
              final isExpanded = _expandedMonths.contains(month);
              final selectedInMonth =
                  entries.where((e) => _selected.contains(e.id)).length;
              final allSelected = selectedInMonth == entries.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month header with checkbox
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_expandedMonths.contains(month)) {
                          _expandedMonths.remove(month);
                        } else {
                          _expandedMonths.add(month);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (allSelected) {
                                  for (final e in entries) {
                                    _selected.remove(e.id);
                                  }
                                } else {
                                  for (final e in entries) {
                                    _selected.add(e.id);
                                  }
                                }
                              });
                            },
                            child: Icon(
                              allSelected
                                  ? Icons.check_box
                                  : selectedInMonth > 0
                                      ? Icons.indeterminate_check_box
                                      : Icons.check_box_outline_blank,
                              color: allSelected || selectedInMonth > 0
                                  ? colors.accent
                                  : colors.textMuted,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              month,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${entries.length} entries',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Individual entries
                  if (isExpanded)
                    ...entries.map((entry) => _buildEntryTile(entry)),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
        // Create button
        _buildCreateButton(colors),
      ],
    );
  }

  Widget _buildEntryTile(JournalEntry entry) {
    final colors = AppColors.of(context);
    final isSelected = _selected.contains(entry.id);
    final firstLine = entry.content.split('\n').first;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selected.remove(entry.id);
          } else {
            _selected.add(entry.id);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        margin: const EdgeInsets.only(left: 20, bottom: 2),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentFaint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected ? colors.accent : colors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat.yMMMd().format(entry.entryDate),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (entry.mood != null)
              _moodDot(entry.mood!),
          ],
        ),
      ),
    );
  }

  Widget _moodDot(String mood) {
    final color = switch (mood) {
      'great' => AppColors.moodGreat,
      'good' => AppColors.moodGood,
      'okay' => AppColors.moodOkay,
      'low' => AppColors.moodLow,
      'tough' => AppColors.moodTough,
      _ => Colors.grey,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildCreateButton(AppPalette colors) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selected.isEmpty ? null : _createBook,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.border,
              disabledForegroundColor: colors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Create Book (${_selected.length} entries)',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _createBook() {
    final selectedEntries =
        widget.entries.where((e) => _selected.contains(e.id)).toList();
    final service = BookGeneratorService();
    final book = service.generateFromEntries(
      entries: selectedEntries,
      title: _titleController.text.trim().isEmpty
          ? 'My Story'
          : _titleController.text.trim(),
      author: 'You',
    );
    widget.onCreateBook(book);
  }
}

// =============================================================================
// Daily Diary Flow
// =============================================================================

class _DailyDiaryFlow extends StatefulWidget {
  final List<JournalEntry> entries;
  final VoidCallback onBack;
  final void Function(GeneratedBook) onCreateBook;

  const _DailyDiaryFlow({
    required this.entries,
    required this.onBack,
    required this.onCreateBook,
  });

  @override
  State<_DailyDiaryFlow> createState() => _DailyDiaryFlowState();
}

class _DailyDiaryFlowState extends State<_DailyDiaryFlow> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
  }

  int get _entryCount {
    return widget.entries
        .where((e) =>
            !e.entryDate.isBefore(_startDate) &&
            !e.entryDate.isAfter(_endDate))
        .length;
  }

  int get _estimatedPages {
    // ~1 page per entry plus chapter dividers
    final count = _entryCount;
    final chapters = (count / 5).ceil();
    return count + chapters + 2; // +2 for title and TOC
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              ),
              Text(
                'Daily Diary',
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a date range. All entries in that range become pages, organized by day.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          // Date pickers
          Text(
            'START DATE',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _buildDatePicker(
            context,
            date: _startDate,
            onPick: (d) => setState(() => _startDate = d),
          ),
          const SizedBox(height: 20),
          Text(
            'END DATE',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _buildDatePicker(
            context,
            date: _endDate,
            onPick: (d) => setState(() => _endDate = d),
          ),
          const SizedBox(height: 32),
          // Preview stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Entries', '$_entryCount', colors),
                    Container(
                      width: 1,
                      height: 40,
                      color: colors.border,
                    ),
                    _buildStat('Est. Pages', '$_estimatedPages', colors),
                    Container(
                      width: 1,
                      height: 40,
                      color: colors.border,
                    ),
                    _buildStat(
                      'Range',
                      '${_endDate.difference(_startDate).inDays}d',
                      colors,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Create button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _entryCount == 0 ? null : _createBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.border,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _entryCount == 0
                    ? 'No entries in this range'
                    : 'Create Book ($_entryCount entries)',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
    BuildContext context, {
    required DateTime date,
    required ValueChanged<DateTime> onPick,
  }) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: colors.accent),
            const SizedBox(width: 12),
            Text(
              DateFormat.yMMMMd().format(date),
              style: GoogleFonts.manrope(
                fontSize: 15,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, AppPalette colors) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: colors.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }

  void _createBook() {
    final service = BookGeneratorService();
    final book = service.generateDailyDiary(
      entries: widget.entries,
      startDate: _startDate,
      endDate: _endDate,
      author: 'You',
    );
    widget.onCreateBook(book);
  }
}

// =============================================================================
// AI Surprise Flow
// =============================================================================

class _AiSurpriseFlow extends StatefulWidget {
  final List<JournalEntry> entries;
  final VoidCallback onBack;
  final void Function(GeneratedBook) onCreateBook;

  const _AiSurpriseFlow({
    required this.entries,
    required this.onBack,
    required this.onCreateBook,
  });

  @override
  State<_AiSurpriseFlow> createState() => _AiSurpriseFlowState();
}

class _AiSurpriseFlowState extends State<_AiSurpriseFlow>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  GeneratedBook? _generatedBook;
  final _removedEntryIds = <String>{};
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Simulate AI processing
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final service = BookGeneratorService();
      final book = service.generateAiSurprise(
        allEntries: widget.entries,
        author: 'You',
      );
      setState(() {
        _generatedBook = book;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_isLoading) {
      return _buildLoadingState(colors);
    }

    return _buildRevealState(colors);
  }

  Widget _buildLoadingState(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + _pulseController.value * 0.15,
              child: child,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'AI is curating your story...',
            style: GoogleFonts.newsreader(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing your most meaningful moments',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation(colors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealState(AppPalette colors) {
    final book = _generatedBook!;
    final visibleEntries = book.sourceEntries
        .where((e) => !_removedEntryIds.contains(e.id))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI picked ${visibleEntries.length} entries',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Remove any you don\'t want',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: visibleEntries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = visibleEntries[index];
              final firstLine = entry.content.split('\n').first;
              final preview = entry.content.length > 120
                  ? '${entry.content.substring(0, 120)}...'
                  : entry.content;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.yMMMd().format(entry.entryDate),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() => _removedEntryIds.add(entry.id));
                      },
                      icon: Icon(Icons.close, size: 18, color: colors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Create button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: visibleEntries.isEmpty ? null : () => _createBook(visibleEntries),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: colors.border,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Create Book (${visibleEntries.length} entries)',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _createBook(List<JournalEntry> entries) {
    final service = BookGeneratorService();
    final book = service.generateFromEntries(
      entries: entries,
      title: 'Your Story: A Curated Collection',
      author: 'You',
    );
    widget.onCreateBook(book);
  }
}
