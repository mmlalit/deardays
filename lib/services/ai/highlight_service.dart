import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// AI highlight extraction service that identifies meaningful quotes
/// and key moments from journal entries.
///
/// Extracts:
/// - Quotable sentences (emotionally resonant, well-phrased)
/// - Key moments (turning points, insights, realizations)
/// - Shareable excerpts for social cards
class HighlightService {
  HighlightService._internal();

  static final HighlightService _instance = HighlightService._internal();

  static HighlightService get instance => _instance;

  factory HighlightService() => _instance;

  /// Extracts the most meaningful highlight from an entry.
  ///
  /// Returns the single best quote/sentence from the entry content.
  String? extractHighlight(JournalEntry entry) {
    final highlights = extractHighlights(entry, maxHighlights: 1);
    return highlights.isEmpty ? null : highlights.first.text;
  }

  /// Extracts multiple highlights from an entry, ranked by impact score.
  List<Highlight> extractHighlights(
    JournalEntry entry, {
    int maxHighlights = 3,
  }) {
    final content = entry.polishedContent ?? entry.content;
    if (content.trim().isEmpty) return [];

    // Split into sentences
    final sentences = _splitIntoSentences(content);
    if (sentences.isEmpty) return [];

    // Score each sentence
    final scored = <Highlight>[];
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.length < 15 || trimmed.length > 200) continue;

      final score = _scoreSentence(trimmed, content);
      if (score > 0) {
        scored.add(Highlight(
          text: trimmed,
          score: score,
          type: _classifyHighlight(trimmed),
          entryId: entry.id,
          entryDate: entry.entryDate,
        ));
      }
    }

    // Sort by score and return top N
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxHighlights).toList();
  }

  /// Extracts highlights across multiple entries (for weekly reports, etc.).
  List<Highlight> extractWeeklyHighlights(
    List<JournalEntry> entries, {
    int maxHighlights = 5,
  }) {
    final allHighlights = <Highlight>[];

    for (final entry in entries) {
      allHighlights.addAll(extractHighlights(entry, maxHighlights: 2));
    }

    // Sort by score and deduplicate
    allHighlights.sort((a, b) => b.score.compareTo(a.score));

    // Remove similar highlights (Levenshtein-like check)
    final unique = <Highlight>[];
    for (final h in allHighlights) {
      if (!unique.any((u) => _isSimilar(u.text, h.text))) {
        unique.add(h);
      }
      if (unique.length >= maxHighlights) break;
    }

    return unique;
  }

  /// Splits text into sentences, handling common edge cases.
  List<String> _splitIntoSentences(String text) {
    // Remove title (first line if short)
    final lines = text.split('\n');
    String body = text;
    if (lines.length > 1 && lines.first.trim().length < 80) {
      body = lines.skip(1).join('\n');
    }

    // Split on sentence-ending punctuation
    return body
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  /// Scores a sentence for "highlight-worthiness".
  double _scoreSentence(String sentence, String fullContent) {
    double score = 0.0;
    final lower = sentence.toLowerCase();

    // Emotional resonance keywords
    for (final word in _emotionalKeywords) {
      if (lower.contains(word)) score += 2.0;
    }

    // Insight markers (realizations, lessons)
    for (final marker in _insightMarkers) {
      if (lower.contains(marker)) score += 3.0;
    }

    // Poetic/literary quality indicators
    for (final indicator in _literaryIndicators) {
      if (lower.contains(indicator)) score += 1.5;
    }

    // Sentence length sweet spot (20-120 chars scores highest)
    if (sentence.length >= 20 && sentence.length <= 120) {
      score += 2.0;
    } else if (sentence.length > 120 && sentence.length <= 160) {
      score += 1.0;
    }

    // Penalize sentences that are too generic/mundane
    for (final mundane in _mundanePatterns) {
      if (lower.startsWith(mundane)) score -= 2.0;
    }

    // Penalize if it's the first sentence (often just context/setup)
    final firstSentenceEnd = fullContent.indexOf(RegExp(r'[.!?]'));
    if (firstSentenceEnd > 0 &&
        sentence == fullContent.substring(0, firstSentenceEnd + 1).trim()) {
      score -= 1.0;
    }

    return score.clamp(0.0, 20.0);
  }

  /// Classifies the type of highlight.
  HighlightType _classifyHighlight(String sentence) {
    final lower = sentence.toLowerCase();

    for (final marker in _insightMarkers) {
      if (lower.contains(marker)) return HighlightType.insight;
    }

    for (final word in _emotionalKeywords) {
      if (lower.contains(word)) return HighlightType.emotion;
    }

    return HighlightType.moment;
  }

  /// Checks if two strings are too similar (>70% word overlap).
  bool _isSimilar(String a, String b) {
    final wordsA = a.toLowerCase().split(RegExp(r'\s+')).toSet();
    final wordsB = b.toLowerCase().split(RegExp(r'\s+')).toSet();
    final overlap = wordsA.intersection(wordsB).length;
    final total = wordsA.union(wordsB).length;
    return total > 0 && overlap / total > 0.7;
  }

  static const List<String> _emotionalKeywords = [
    'love', 'heart', 'tears', 'crying', 'beautiful',
    'grateful', 'thankful', 'blessed', 'proud', 'happy',
    'joy', 'peace', 'hope', 'faith', 'strength',
    'cherish', 'treasure', 'precious', 'forever', 'remember',
    'miss', 'longing', 'bittersweet', 'overwhelmed',
  ];

  static const List<String> _insightMarkers = [
    'i realized', 'i learned', 'i understand now', 'it hit me',
    'i never knew', 'changed my mind', 'opened my eyes',
    'taught me', 'made me see', 'i finally', 'i can see',
    'what matters', 'what counts', 'the truth is',
    'looking back', 'in hindsight', 'i\'ve grown',
  ];

  static const List<String> _literaryIndicators = [
    'never gets old', 'one of those', 'held onto',
    'something about', 'the kind of', 'there was this moment',
    'it felt like', 'as if', 'the way',
  ];

  static const List<String> _mundanePatterns = [
    'i went to', 'i had', 'we went', 'today i', 'woke up',
    'got up', 'went to work', 'came home',
  ];
}

/// A highlighted excerpt from a journal entry.
class Highlight {
  final String text;
  final double score;
  final HighlightType type;
  final String entryId;
  final DateTime entryDate;

  const Highlight({
    required this.text,
    required this.score,
    required this.type,
    required this.entryId,
    required this.entryDate,
  });
}

/// Classification of highlight type.
enum HighlightType {
  /// An emotional moment or feeling
  emotion,

  /// A realization, lesson, or insight
  insight,

  /// A memorable moment or event
  moment,
}
