import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/services/search/search_service.dart';
import 'package:deardays/services/ai/ai_service.dart';

/// Universal search screen.
/// - Keyword search: instant, client-side (SearchService)
/// - AI memory search: backend-powered via /memory-search edge function
///   which does rule-based parsing + SQL filter + vector reranking + Gemini summary
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _searchService = SearchService();
  final _aiService = AiService();

  List<SearchResult> _results = [];
  bool _hasSearched = false;

  // AI Memory Search state
  bool _isAiSearching = false;
  String? _aiAnswer;
  List<JournalEntry> _aiReferencedEntries = [];
  List<String> _followUpQuestions = [];
  bool _showAiSuggestion = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Detects if the query looks like a natural language question.
  bool _isQuestion(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.endsWith('?')) return true;
    final questionStarters = [
      'when ', 'what ', 'where ', 'how ', 'why ', 'who ',
      'did i', 'have i', 'was i', 'am i', 'do i',
      'tell me', 'show me', 'find me', 'search for',
      'last time', 'first time',
    ];
    return questionStarters.any((s) => trimmed.startsWith(s));
  }

  void _performSearch(List<JournalEntry> entries) {
    final query = _controller.text;
    final isQ = _isQuestion(query);
    setState(() {
      _results = _searchService.search(query, entries);
      _hasSearched = query.trim().isNotEmpty;
      _showAiSuggestion = isQ && query.trim().length > 5;
      if (!_isAiSearching) {
        _aiAnswer = null;
        _aiReferencedEntries = [];
        _followUpQuestions = [];
      }
    });
  }

  /// Smart AI search: calls /memory-search edge function (server-side).
  /// Returns entry IDs, then loads those entries from the repository.
  Future<void> _performAiSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty || !_aiService.isConfigured) return;

    setState(() {
      _isAiSearching = true;
      _aiAnswer = null;
      _aiReferencedEntries = [];
      _followUpQuestions = [];
      _showAiSuggestion = false;
    });

    try {
      final language = ref.read(localeProvider).languageName;

      final result = await _aiService.smartMemorySearch(
        query: query,
        language: language != 'English' ? language : null,
      );

      final answer = result['answer'] as String? ?? '';
      final entryIds = result['entryIds'] as List<String>? ?? [];
      final followUps = result['followUpQuestions'] as List<String>? ?? [];

      // Load the matched entries from the repository
      List<JournalEntry> referenced = [];
      if (entryIds.isNotEmpty) {
        try {
          final repo = ref.read(journalRepositoryProvider);
          referenced = await repo.getEntriesByIds(entryIds);
        } catch (_) {
          // Fall back to timeline entries if repository fetch fails
          final allEntries = ref.read(timelineEntriesProvider).valueOrNull ?? [];
          referenced = allEntries
              .where((e) => entryIds.contains(e.id))
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _aiAnswer = answer;
          _aiReferencedEntries = referenced;
          _followUpQuestions = followUps;
          _isAiSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiAnswer = "I couldn't search your memories right now. Try again later.";
          _aiReferencedEntries = [];
          _followUpQuestions = [];
          _isAiSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(colors, entriesAsync),
            Expanded(
              child: entriesAsync.when(
                data: (entries) => _buildBody(colors, entries),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text('Unable to load entries',
                      style: GoogleFonts.manrope(color: colors.textSecondary)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(
      AppPalette colors, AsyncValue<List<JournalEntry>> entriesAsync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded,
                size: 22, color: colors.textPrimary),
          ),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: (_) {
                  entriesAsync.whenData(_performSearch);
                },
                onSubmitted: (_) {
                  if (_isQuestion(_controller.text)) {
                    _performAiSearch();
                  }
                },
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search memories or ask a question...',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: 15,
                    color: colors.textMuted,
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: colors.textMuted),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: colors.textMuted),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = [];
                              _hasSearched = false;
                              _aiAnswer = null;
                              _aiReferencedEntries = [];
                              _followUpQuestions = [];
                              _showAiSuggestion = false;
                              _isAiSearching = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppPalette colors, List<JournalEntry> entries) {
    if (!_hasSearched) {
      return _buildRecentSearches(colors, entries);
    }
    if (_isAiSearching) {
      return _buildAiLoading(colors);
    }
    if (_aiAnswer != null) {
      return _buildAiResults(colors, entries);
    }
    return _buildKeywordResults(colors, entries);
  }

  Widget _buildKeywordResults(AppPalette colors, List<JournalEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showAiSuggestion && _aiService.isConfigured)
          _buildAiSuggestionBanner(colors),
        if (_results.isEmpty)
          Expanded(child: _buildEmptyResults(colors))
        else
          ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '${_results.length} result${_results.length == 1 ? '' : 's'}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colors.border.withAlpha(80)),
                itemBuilder: (_, i) =>
                    _buildResultCard(colors, _results[i], entries),
              ),
            ),
          ],
      ],
    );
  }

  Widget _buildAiSuggestionBanner(AppPalette colors) {
    return GestureDetector(
      onTap: _performAiSearch,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.accent.withAlpha(15),
              colors.accent.withAlpha(8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.accent.withAlpha(40)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 20, color: colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ask AI to search your memories',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: colors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildAiLoading(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching your memories...',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'AI is searching across your journal',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiResults(AppPalette colors, List<JournalEntry> allEntries) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // AI Answer card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.accent.withAlpha(12),
                colors.accent.withAlpha(6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.accent.withAlpha(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 18, color: colors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'AI Memory Search',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _aiAnswer!,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  height: 1.6,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Referenced entries
        if (_aiReferencedEntries.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'REFERENCED MEMORIES',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ..._aiReferencedEntries.map(
              (entry) => _buildReferencedEntry(colors, entry, allEntries)),
        ],

        // Follow-up questions
        if (_followUpQuestions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'EXPLORE FURTHER',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ..._followUpQuestions.map((q) => _buildFollowUpChip(colors, q)),
        ],

        // Keyword matches below AI results
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'KEYWORD MATCHES',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ..._results.take(5).map((r) => _buildResultCard(colors, r, allEntries)),
        ],
      ],
    );
  }

  Widget _buildFollowUpChip(AppPalette colors, String question) {
    return GestureDetector(
      onTap: () {
        _controller.text = question;
        _performAiSearch();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                question,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencedEntry(
      AppPalette colors, JournalEntry entry, List<JournalEntry> allEntries) {
    final title = entry.content.split('\n').first.trim();
    final dateStr = DateFormat('MMM dd, yyyy').format(entry.entryDate);
    final moodEmoji = _moodEmoji(entry.mood);

    return InkWell(
      onTap: () {
        final idx = allEntries.indexWhere((e) => e.id == entry.id);
        context.push('/memory',
            extra: MemoryDetailArgs(
              entry: entry,
              allEntries: allEntries,
              initialIndex: idx >= 0 ? idx : 0,
            ));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withAlpha(15),
              ),
              child: Center(
                child: Text(moodEmoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(AppPalette colors, List<JournalEntry> entries) {
    final recent = _searchService.recentSearches;

    final aiExamples = [
      'When was the last time I felt proud?',
      'What made me happiest this month?',
      'Where have I written from most?',
    ];

    if (recent.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.search_rounded,
                size: 56, color: colors.textMuted.withAlpha(80)),
            const SizedBox(height: 16),
            Text(
              'Search your memories',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find entries by keyword, mood, or place',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textMuted,
              ),
            ),
            if (_aiService.isConfigured) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 16, color: colors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'TRY ASKING',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...aiExamples.map((example) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        _controller.text = example;
                        _performSearch(entries);
                        _performAiSearch();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          example,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT SEARCHES',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _searchService.clearRecentSearches();
                  setState(() {});
                },
                child: Text(
                  'Clear',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recent.map((query) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history_rounded,
                    size: 20, color: colors.textMuted),
                title: Text(query,
                    style: GoogleFonts.manrope(
                        fontSize: 14, color: colors.textPrimary)),
                onTap: () {
                  _controller.text = query;
                  _performSearch(entries);
                },
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyResults(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: colors.textMuted.withAlpha(80)),
          const SizedBox(height: 16),
          Text(
            'No memories found',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different keyword or phrase',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
      AppPalette colors, SearchResult result, List<JournalEntry> allEntries) {
    final entry = result.entry;
    final title = entry.content.split('\n').first.trim();
    final dateStr = DateFormat('MMM dd, yyyy').format(entry.entryDate);
    final moodEmoji = _moodEmoji(entry.mood);

    return InkWell(
      onTap: () {
        final idx = allEntries.indexWhere((e) => e.id == entry.id);
        context.push('/memory',
            extra: MemoryDetailArgs(
              entry: entry,
              allEntries: allEntries,
              initialIndex: idx >= 0 ? idx : 0,
            ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withAlpha(15),
              ),
              child: Center(
                child: Text(moodEmoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.excerpt,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                      if (entry.locationName != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_outlined,
                            size: 12, color: colors.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            entry.locationName!,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _moodEmoji(String? mood) {
    switch (mood) {
      case 'great':
        return '\u{1F60D}';
      case 'good':
        return '\u{1F60A}';
      case 'okay':
        return '\u{1F610}';
      case 'low':
        return '\u{1F614}';
      case 'tough':
        return '\u{1F622}';
      default:
        return '\u{1F4DD}';
    }
  }
}
