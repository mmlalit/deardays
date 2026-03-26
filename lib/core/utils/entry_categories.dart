import 'package:flutter/material.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Centralised category detection for journal entries.
/// Returns a [Set<String>] of all matching categories so entries can appear
/// in multiple sections (e.g. "beach trip with family" → Travel + Family).
class EntryCategories {
  EntryCategories._();

  static const _travelKeywords = ['travel', 'trip', 'vacation', 'flight', 'holiday', 'beach', 'hike'];
  static const _careerKeywords = ['work', 'job', 'career', 'promotion', 'office', 'meeting', 'project'];
  static const _familyKeywords = ['family', 'mom', 'dad', 'daughter', 'son', 'child', 'husband', 'wife', 'sibling', 'grandma', 'grandpa'];

  /// Returns all matching categories for an entry.
  static Set<String> detect(JournalEntry entry) {
    final cats = <String>{};
    final text = entry.content.toLowerCase();
    if (_travelKeywords.any(text.contains)) cats.add('Travel');
    if (_careerKeywords.any(text.contains)) cats.add('Career');
    if (_familyKeywords.any(text.contains)) cats.add('Family');
    return cats;
  }

  /// Returns the single highest-priority category label for filter matching.
  static String? primary(JournalEntry entry) {
    final cats = detect(entry);
    if (cats.contains('Travel')) return 'Travel';
    if (cats.contains('Career')) return 'Career';
    if (cats.contains('Family')) return 'Family';
    if (entry.mood == 'great' || entry.mood == 'good') return 'Personal Growth';
    return null;
  }

  /// Maps categories to (label, color) pairs for tag chips.
  static List<(String, Color)> tagChips(JournalEntry entry) {
    final tags = <(String, Color)>[];
    // Mood tag first
    switch (entry.mood) {
      case 'great': tags.add(('Joy', AppColors.moodOkay));
      case 'good':  tags.add(('Happy', AppColors.moodGood));
      case 'okay':  tags.add(('Serene', AppColors.moodGood));
      case 'low':   tags.add(('Sad', AppColors.indigo));
      case 'tough': tags.add(('Growth', AppColors.orange));
    }
    // Category tags
    for (final cat in detect(entry)) {
      tags.add((cat, AppColors.blue));
    }
    return tags.take(2).toList();
  }
}
