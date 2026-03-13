import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Universal search service for searching across journal entries.
///
/// Supports:
/// - Keyword search across content, tags, moods, and locations
/// - Semantic relevance ranking
/// - Search result highlighting
/// - Recent searches history
class SearchService {
  SearchService._internal();

  static final SearchService _instance = SearchService._internal();

  static SearchService get instance => _instance;

  factory SearchService() => _instance;

  static const int _maxRecentSearches = 10;
  final List<String> _recentSearches = [];
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Searches journal entries by keyword.
  ///
  /// Matches against: content, rawContent, polishedContent, mood, locationName.
  /// Results are ranked by relevance (title match > content match > metadata match).
  List<SearchResult> search(String query, List<JournalEntry> entries) {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();
    final queryWords = normalizedQuery.split(RegExp(r'\s+'));
    final results = <SearchResult>[];

    for (final entry in entries) {
      final score = _calculateRelevance(entry, normalizedQuery, queryWords);
      if (score > 0) {
        results.add(SearchResult(
          entry: entry,
          relevanceScore: score,
          matchedField: _getMatchedField(entry, normalizedQuery),
          excerpt: _extractExcerpt(entry.content, normalizedQuery),
        ));
      }
    }

    // Sort by relevance score (highest first)
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    // Track recent search
    _addRecentSearch(query.trim());

    return results;
  }

  /// Calculates a relevance score for an entry against the query.
  double _calculateRelevance(
    JournalEntry entry,
    String query,
    List<String> queryWords,
  ) {
    double score = 0.0;
    final content = entry.content.toLowerCase();
    final rawContent = (entry.rawContent ?? '').toLowerCase();
    final polished = (entry.polishedContent ?? '').toLowerCase();
    final location = (entry.locationName ?? '').toLowerCase();
    final mood = (entry.mood ?? '').toLowerCase();

    // Extract title (first line of content)
    final title = content.split('\n').first.toLowerCase();

    // Exact phrase match in title — highest relevance
    if (title.contains(query)) score += 10.0;

    // Exact phrase match in content
    if (content.contains(query)) score += 5.0;

    // Match in raw/polished content
    if (rawContent.contains(query)) score += 3.0;
    if (polished.contains(query)) score += 3.0;

    // Location match
    if (location.contains(query)) score += 4.0;

    // Mood match
    if (mood == query) score += 3.0;

    // Individual word matches (partial relevance)
    for (final word in queryWords) {
      if (word.length < 2) continue;
      if (title.contains(word)) score += 2.0;
      if (content.contains(word)) score += 1.0;
      if (location.contains(word)) score += 1.5;
    }

    // Recency boost (entries from last 30 days get a small boost)
    final daysSinceEntry = DateTime.now().difference(entry.entryDate).inDays;
    if (daysSinceEntry <= 30) {
      score += 0.5 * (1 - daysSinceEntry / 30);
    }

    return score;
  }

  /// Identifies which field matched the query.
  String _getMatchedField(JournalEntry entry, String query) {
    final title = entry.content.split('\n').first.toLowerCase();
    if (title.contains(query)) return 'title';
    if (entry.content.toLowerCase().contains(query)) return 'content';
    if ((entry.locationName ?? '').toLowerCase().contains(query)) {
      return 'location';
    }
    if ((entry.mood ?? '').toLowerCase() == query) return 'mood';
    return 'content';
  }

  /// Extracts an excerpt around the matched query term.
  String _extractExcerpt(String content, String query) {
    final lower = content.toLowerCase();
    final index = lower.indexOf(query);

    if (index == -1) {
      // Return first 120 chars if no direct match
      return content.length > 120
          ? '${content.substring(0, 120)}...'
          : content;
    }

    // Extract context around the match
    final start = (index - 40).clamp(0, content.length);
    final end = (index + query.length + 80).clamp(0, content.length);
    var excerpt = content.substring(start, end).trim();

    if (start > 0) excerpt = '...$excerpt';
    if (end < content.length) excerpt = '$excerpt...';

    return excerpt;
  }

  /// Adds a search query to recent searches.
  void _addRecentSearch(String query) {
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeLast();
    }
  }

  /// Clears recent search history.
  void clearRecentSearches() {
    _recentSearches.clear();
  }

  /// Returns search suggestions based on available entry data.
  List<String> getSuggestions(String partial, List<JournalEntry> entries) {
    if (partial.trim().isEmpty) return [];

    final lower = partial.toLowerCase();
    final suggestions = <String>{};

    // Suggest from locations
    for (final entry in entries) {
      if (entry.locationName != null &&
          entry.locationName!.toLowerCase().contains(lower)) {
        suggestions.add(entry.locationName!);
      }
    }

    // Suggest from moods
    for (final mood in ['great', 'good', 'okay', 'low', 'tough']) {
      if (mood.contains(lower)) suggestions.add(mood);
    }

    return suggestions.take(5).toList();
  }
}

/// A search result with relevance ranking and context.
class SearchResult {
  final JournalEntry entry;
  final double relevanceScore;
  final String matchedField;
  final String excerpt;

  const SearchResult({
    required this.entry,
    required this.relevanceScore,
    required this.matchedField,
    required this.excerpt,
  });
}
