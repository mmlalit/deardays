/// Contract for AI text processing services.
///
/// Implementations: [AiService] (HTTP to Supabase edge functions), test mocks.
abstract class IAiService {
  Future<String> transcribeAudio(String audioFilePath);

  Future<String> lightPolish(String rawText, {String? language});

  Future<String> polishNarrative(String rawText, {String style = 'memoir', String? language});

  Future<String> generateTitle(String entryText, {String? language});

  Future<String> chat({
    required List<Map<String, String>> messages,
    String? mood,
    bool isFirstCheckIn = false,
    String? language,
  });

  Future<String> generateShareSummary(String entryText, {String? language});

  Future<Map<String, dynamic>> analyzeEntries(List<String> entries, {String? language});

  Future<void> tagEntry({required String entryId, required String content});

  Future<Map<String, dynamic>> smartMemorySearch({required String query, String? language});

  Future<({String story, String? summary})> generateWeeklyStory(
    List<String> dailyStories, {
    List<String> tags = const [],
    List<String> people = const [],
    List<String> moods = const [],
    String? language,
  });

  Future<({String story, String? summary})> generateMonthlyStory(
    List<String> weeklySummaries, {
    List<String> tags = const [],
    List<String> people = const [],
    List<String> moods = const [],
    String? language,
  });

  Future<({String story, String? summary})> generateYearlyStory(
    List<String> monthlySummaries, {
    List<String> tags = const [],
    List<String> people = const [],
    List<String> moods = const [],
    String? language,
  });

  Future<String> generateLifetimeStory(
    List<String> yearlyStories, {
    List<String> keyMomentTexts = const [],
    String? language,
  });

  Future<String> optimizeImage({required String imageBase64, String mimeType = 'image/jpeg'});

  Future<Map<String, String>> analyzeStory(String storyText);
}
