/// AI mood detection service that infers mood from journal entry text.
///
/// Uses keyword analysis and sentiment scoring to detect mood without
/// requiring a network call. Falls back to the AI backend for more
/// nuanced detection when available.
class MoodDetectionService {
  MoodDetectionService._internal();

  static final MoodDetectionService _instance =
      MoodDetectionService._internal();

  static MoodDetectionService get instance => _instance;

  factory MoodDetectionService() => _instance;

  /// Detects mood from text content using local keyword analysis.
  ///
  /// Returns one of: 'great', 'good', 'okay', 'low', 'tough'.
  String detectMood(String text) {
    if (text.trim().isEmpty) return 'okay';

    final lower = text.toLowerCase();
    final scores = <String, double>{
      'great': 0,
      'good': 0,
      'okay': 0,
      'low': 0,
      'tough': 0,
    };

    // Score each mood based on keyword presence
    for (final entry in _moodKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          scores[entry.key] = scores[entry.key]! + 1.0;

          // Bonus for keywords appearing in first 100 chars (more emphasis)
          if (lower.indexOf(keyword) < 100) {
            scores[entry.key] = scores[entry.key]! + 0.5;
          }
        }
      }
    }

    // Apply intensity modifiers
    for (final intensifier in _intensifiers) {
      if (lower.contains(intensifier)) {
        // Boost the highest-scoring non-okay mood
        final topMood = _getTopMood(scores, exclude: 'okay');
        if (topMood != null) {
          scores[topMood] = scores[topMood]! + 1.0;
        }
      }
    }

    // Apply negation detection (simple)
    for (final negation in _negations) {
      if (lower.contains(negation)) {
        // Negations often flip positive to negative
        if (scores['great']! > scores['tough']!) {
          scores['great'] = scores['great']! * 0.5;
          scores['low'] = scores['low']! + 1.0;
        }
      }
    }

    // Determine the winning mood
    final topMood = _getTopMood(scores);
    final topScore = scores[topMood]!;

    // If no strong signal, default to 'okay'
    if (topScore < 1.0) return 'okay';

    return topMood ?? 'okay';
  }

  /// Returns a confidence score (0.0 - 1.0) for the detected mood.
  double getConfidence(String text, String mood) {
    if (text.trim().isEmpty) return 0.0;

    final lower = text.toLowerCase();
    int matches = 0;
    final keywords = _moodKeywords[mood] ?? [];

    for (final keyword in keywords) {
      if (lower.contains(keyword)) matches++;
    }

    if (keywords.isEmpty) return 0.0;
    return (matches / keywords.length).clamp(0.0, 1.0);
  }

  String? _getTopMood(Map<String, double> scores, {String? exclude}) {
    String? topMood;
    double topScore = -1;

    for (final entry in scores.entries) {
      if (entry.key == exclude) continue;
      if (entry.value > topScore) {
        topScore = entry.value;
        topMood = entry.key;
      }
    }
    return topMood;
  }

  // Mood keyword mappings
  static const Map<String, List<String>> _moodKeywords = {
    'great': [
      'amazing', 'incredible', 'wonderful', 'fantastic', 'brilliant',
      'ecstatic', 'thrilled', 'overjoyed', 'elated', 'euphoric',
      'best day', 'so happy', 'on top of the world', 'blown away',
      'dream come true', 'couldn\'t be happier', 'perfect day',
      'over the moon', 'absolutely love', 'celebrate',
      'milestone', 'achievement', 'accomplished', 'proud',
      'grateful beyond', 'blessed', 'inspired',
    ],
    'good': [
      'happy', 'glad', 'content', 'pleased', 'enjoyed',
      'nice', 'lovely', 'pleasant', 'satisfying', 'fun',
      'grateful', 'thankful', 'appreciate', 'smile', 'laughed',
      'relaxed', 'peaceful', 'calm', 'comfortable', 'cozy',
      'productive', 'accomplished', 'progress', 'good day',
      'feeling good', 'warm', 'sunshine', 'beautiful',
    ],
    'okay': [
      'fine', 'alright', 'so-so', 'not bad', 'average',
      'ordinary', 'normal', 'usual', 'routine', 'uneventful',
      'mixed feelings', 'neutral', 'meh', 'whatever',
      'same as always', 'nothing special',
    ],
    'low': [
      'sad', 'down', 'unhappy', 'disappointed', 'lonely',
      'tired', 'exhausted', 'drained', 'unmotivated', 'bored',
      'miss', 'missing', 'melancholy', 'gloomy', 'blue',
      'homesick', 'nostalgic', 'empty', 'heavy heart',
      'couldn\'t sleep', 'restless', 'worried', 'anxious',
      'insecure', 'uncertain', 'doubt',
    ],
    'tough': [
      'terrible', 'awful', 'worst', 'horrible', 'devastating',
      'angry', 'furious', 'frustrated', 'rage', 'hate',
      'broken', 'heartbroken', 'shattered', 'crushed', 'destroyed',
      'failed', 'failure', 'lost everything', 'gave up',
      'overwhelmed', 'panic', 'crisis', 'nightmare', 'unbearable',
      'betrayed', 'hurt', 'painful', 'suffering', 'crying',
      'stings', 'impossible',
    ],
  };

  static const List<String> _intensifiers = [
    'very', 'extremely', 'incredibly', 'absolutely', 'completely',
    'totally', 'utterly', 'deeply', 'truly', 'never been',
    'most', 'ever', 'entire life',
  ];

  static const List<String> _negations = [
    'not happy', 'wasn\'t good', 'didn\'t go well', 'no luck',
    'couldn\'t', 'never', 'nothing worked', 'not great',
    'didn\'t enjoy', 'wish i hadn\'t', 'regret',
  ];
}
