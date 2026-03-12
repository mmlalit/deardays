/// Local keyword-based tag suggestion service.
///
/// Scans entry content for keyword matches and returns a list of suggested tags.
/// No network calls — entirely local.
class TagSuggestionService {
  TagSuggestionService._();

  /// All available tags.
  static const allTags = [
    'Travel',
    'Celebration',
    'Family',
    'Work',
    'Reflection',
    'Growth',
    'Health',
    'Friends',
    'Food',
    'Nature',
    'Adventure',
    'Gratitude',
    'Love',
    'Milestone',
    'Creativity',
  ];

  /// Keyword → tag mapping. Keys are lowercase.
  static const _keywordMap = <String, String>{
    // Travel
    'travel': 'Travel',
    'trip': 'Travel',
    'flight': 'Travel',
    'airport': 'Travel',
    'vacation': 'Travel',
    'holiday': 'Travel',
    'beach': 'Travel',
    'hotel': 'Travel',
    'explore': 'Travel',
    'destination': 'Travel',
    'journey': 'Travel',
    'tour': 'Travel',
    'abroad': 'Travel',
    'passport': 'Travel',
    'suitcase': 'Travel',

    // Celebration
    'birthday': 'Celebration',
    'party': 'Celebration',
    'celebrate': 'Celebration',
    'celebration': 'Celebration',
    'anniversary': 'Celebration',
    'wedding': 'Celebration',
    'graduation': 'Celebration',
    'surprise': 'Celebration',
    'toast': 'Celebration',
    'cheers': 'Celebration',

    // Family
    'family': 'Family',
    'mom': 'Family',
    'mother': 'Family',
    'dad': 'Family',
    'father': 'Family',
    'parent': 'Family',
    'sister': 'Family',
    'brother': 'Family',
    'daughter': 'Family',
    'son': 'Family',
    'grandma': 'Family',
    'grandpa': 'Family',
    'kids': 'Family',
    'children': 'Family',

    // Work
    'work': 'Work',
    'office': 'Work',
    'meeting': 'Work',
    'project': 'Work',
    'promotion': 'Work',
    'boss': 'Work',
    'client': 'Work',
    'deadline': 'Work',
    'colleague': 'Work',
    'career': 'Work',
    'presentation': 'Work',
    'team': 'Work',

    // Reflection
    'reflect': 'Reflection',
    'reflection': 'Reflection',
    'thinking': 'Reflection',
    'realize': 'Reflection',
    'realized': 'Reflection',
    'thought': 'Reflection',
    'journal': 'Reflection',
    'meditat': 'Reflection',
    'mindful': 'Reflection',
    'introspect': 'Reflection',

    // Growth
    'growth': 'Growth',
    'learn': 'Growth',
    'lesson': 'Growth',
    'improve': 'Growth',
    'progress': 'Growth',
    'challenge': 'Growth',
    'overcome': 'Growth',
    'achieve': 'Growth',
    'goal': 'Growth',
    'personal': 'Growth',
    'develop': 'Growth',

    // Health
    'health': 'Health',
    'run': 'Health',
    'running': 'Health',
    'gym': 'Health',
    'workout': 'Health',
    'exercise': 'Health',
    'yoga': 'Health',
    'doctor': 'Health',
    'fitness': 'Health',
    'marathon': 'Health',
    'hike': 'Health',
    'hiking': 'Health',
    'walk': 'Health',

    // Friends
    'friend': 'Friends',
    'friends': 'Friends',
    'buddy': 'Friends',
    'pal': 'Friends',
    'hang out': 'Friends',
    'reunion': 'Friends',
    'catch up': 'Friends',
    'reconnect': 'Friends',

    // Food
    'food': 'Food',
    'dinner': 'Food',
    'lunch': 'Food',
    'breakfast': 'Food',
    'restaurant': 'Food',
    'cook': 'Food',
    'recipe': 'Food',
    'coffee': 'Food',
    'cake': 'Food',
    'meal': 'Food',

    // Nature
    'nature': 'Nature',
    'mountain': 'Nature',
    'forest': 'Nature',
    'ocean': 'Nature',
    'lake': 'Nature',
    'river': 'Nature',
    'sunset': 'Nature',
    'sunrise': 'Nature',
    'garden': 'Nature',
    'park': 'Nature',
    'trail': 'Nature',
    'tree': 'Nature',

    // Adventure
    'adventure': 'Adventure',
    'trek': 'Adventure',
    'climb': 'Adventure',
    'dive': 'Adventure',
    'surf': 'Adventure',
    'camp': 'Adventure',
    'camping': 'Adventure',
    'expedition': 'Adventure',
    'skydive': 'Adventure',

    // Gratitude
    'grateful': 'Gratitude',
    'gratitude': 'Gratitude',
    'thankful': 'Gratitude',
    'blessed': 'Gratitude',
    'appreciate': 'Gratitude',
    'lucky': 'Gratitude',

    // Love
    'love': 'Love',
    'romance': 'Love',
    'romantic': 'Love',
    'partner': 'Love',
    'date night': 'Love',
    'kiss': 'Love',
    'heart': 'Love',

    // Milestone
    'milestone': 'Milestone',
    'first time': 'Milestone',
    'achievement': 'Milestone',
    'record': 'Milestone',
    'best': 'Milestone',
    'biggest': 'Milestone',

    // Creativity
    'creative': 'Creativity',
    'creativity': 'Creativity',
    'art': 'Creativity',
    'paint': 'Creativity',
    'write': 'Creativity',
    'music': 'Creativity',
    'drawing': 'Creativity',
    'photo': 'Creativity',
    'design': 'Creativity',
    'museum': 'Creativity',
  };

  /// Suggest tags based on entry content. Returns unique tags sorted by
  /// match confidence (number of keyword hits), limited to [maxTags].
  static List<String> suggest(String content, {int maxTags = 5}) {
    final lower = content.toLowerCase();
    final hitCount = <String, int>{};

    for (final entry in _keywordMap.entries) {
      if (lower.contains(entry.key)) {
        hitCount[entry.value] = (hitCount[entry.value] ?? 0) + 1;
      }
    }

    if (hitCount.isEmpty) {
      // Return a sensible default
      return ['Reflection'];
    }

    // Sort by hit count descending
    final sorted = hitCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(maxTags).map((e) => e.key).toList();
  }
}
