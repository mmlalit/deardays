import 'package:flutter/material.dart';

/// Visual fallback for book/chapter cards when no cover image is available.
///
/// Maps common chapter themes to gradient colors + icons based on
/// keyword matching against the book title.
class ChapterVisual {
  final Color primary;
  final Color secondary;
  final IconData icon;
  /// Curated stock photo URL for this category (Unsplash).
  final String? stockImageUrl;

  const ChapterVisual({
    required this.primary,
    required this.secondary,
    required this.icon,
    this.stockImageUrl,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary],
      );

  /// Returns a visual based on keyword matching in [title].
  /// Falls back to a hash-based selection for unknown titles.
  static ChapterVisual forTitle(String title) {
    final lower = title.toLowerCase();

    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.key) {
        if (lower.contains(keyword)) return entry.value;
      }
    }

    // Deterministic fallback based on title hash
    final index = title.hashCode.abs() % _fallbacks.length;
    return _fallbacks[index];
  }

  static const _keywordMap = <List<String>, ChapterVisual>{
    ['family', 'home', 'parent', 'mom', 'dad', 'child', 'kids']:
        ChapterVisual(
      primary: Color(0xFFFF8A65),
      secondary: Color(0xFFFF5722),
      icon: Icons.family_restroom,
      stockImageUrl:
          'https://images.unsplash.com/photo-1606791405792-1004f1718d0c?w=600&h=600&fit=crop',
    ),
    ['travel', 'trip', 'adventure', 'vacation', 'journey', 'explore']:
        ChapterVisual(
      primary: Color(0xFF4DD0E1),
      secondary: Color(0xFF00897B),
      icon: Icons.flight_takeoff,
      stockImageUrl:
          'https://images.unsplash.com/photo-1530789253388-582c481c54b0?w=600&h=600&fit=crop',
    ),
    ['career', 'work', 'job', 'office', 'business', 'professional']:
        ChapterVisual(
      primary: Color(0xFF7986CB),
      secondary: Color(0xFF3949AB),
      icon: Icons.work_outline,
      stockImageUrl:
          'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=600&h=600&fit=crop',
    ),
    ['growth', 'self', 'mindful', 'meditat', 'wellness', 'health', 'fitness']:
        ChapterVisual(
      primary: Color(0xFF81C784),
      secondary: Color(0xFF388E3C),
      icon: Icons.spa,
      stockImageUrl:
          'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=600&h=600&fit=crop',
    ),
    ['love', 'romance', 'relationship', 'dating', 'partner', 'heart']:
        ChapterVisual(
      primary: Color(0xFFF48FB1),
      secondary: Color(0xFFE91E63),
      icon: Icons.favorite_outline,
      stockImageUrl:
          'https://images.unsplash.com/photo-1518568403628-2ef91db3862c?w=600&h=600&fit=crop',
    ),
    ['friend', 'social', 'people', 'community']: ChapterVisual(
      primary: Color(0xFFCE93D8),
      secondary: Color(0xFF8E24AA),
      icon: Icons.people_outline,
      stockImageUrl:
          'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=600&h=600&fit=crop',
    ),
    ['school', 'study', 'learn', 'education', 'college', 'university']:
        ChapterVisual(
      primary: Color(0xFF90CAF9),
      secondary: Color(0xFF1565C0),
      icon: Icons.school_outlined,
      stockImageUrl:
          'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=600&h=600&fit=crop',
    ),
    ['food', 'cook', 'recipe', 'kitchen', 'baking']: ChapterVisual(
      primary: Color(0xFFFFCC80),
      secondary: Color(0xFFF57C00),
      icon: Icons.restaurant,
      stockImageUrl:
          'https://images.unsplash.com/photo-1466637574441-749b8f19452f?w=600&h=600&fit=crop',
    ),
    ['music', 'song', 'concert', 'playlist']: ChapterVisual(
      primary: Color(0xFFB39DDB),
      secondary: Color(0xFF5E35B1),
      icon: Icons.music_note,
      stockImageUrl:
          'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&h=600&fit=crop',
    ),
    ['nature', 'outdoor', 'garden', 'plant', 'hiking']: ChapterVisual(
      primary: Color(0xFFA5D6A7),
      secondary: Color(0xFF2E7D32),
      icon: Icons.park,
      stockImageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=600&fit=crop',
    ),
    ['pet', 'dog', 'cat', 'animal']: ChapterVisual(
      primary: Color(0xFFBCAAA4),
      secondary: Color(0xFF795548),
      icon: Icons.pets,
      stockImageUrl:
          'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=600&h=600&fit=crop',
    ),
    ['creative', 'art', 'paint', 'draw', 'craft', 'design']: ChapterVisual(
      primary: Color(0xFFF8BBD0),
      secondary: Color(0xFFAD1457),
      icon: Icons.palette,
      stockImageUrl:
          'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?w=600&h=600&fit=crop',
    ),
    ['2024', '2025', '2026', '2027', '2028']: ChapterVisual(
      primary: Color(0xFF80DEEA),
      secondary: Color(0xFF00838F),
      icon: Icons.calendar_today,
      stockImageUrl:
          'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=600&h=600&fit=crop',
    ),
    ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december', 'jan ', 'feb ', 'mar ', 'apr ', 'may ', 'jun ', 'jul ', 'aug ', 'sep ', 'oct ', 'nov ', 'dec ']:
        ChapterVisual(
      primary: Color(0xFF80CBC4),
      secondary: Color(0xFF00695C),
      icon: Icons.date_range,
      stockImageUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&h=600&fit=crop',
    ),
    ['q1', 'q2', 'q3', 'q4', 'quarter']: ChapterVisual(
      primary: Color(0xFF9FA8DA),
      secondary: Color(0xFF283593),
      icon: Icons.date_range,
      stockImageUrl:
          'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=600&h=600&fit=crop',
    ),
  };

  static const _fallbacks = [
    ChapterVisual(
      primary: Color(0xFF7986CB),
      secondary: Color(0xFF3F51B5),
      icon: Icons.auto_stories,
    ),
    ChapterVisual(
      primary: Color(0xFFFFAB91),
      secondary: Color(0xFFE64A19),
      icon: Icons.bookmark_outline,
    ),
    ChapterVisual(
      primary: Color(0xFF80CBC4),
      secondary: Color(0xFF00796B),
      icon: Icons.menu_book,
    ),
    ChapterVisual(
      primary: Color(0xFFCE93D8),
      secondary: Color(0xFF7B1FA2),
      icon: Icons.auto_awesome,
    ),
    ChapterVisual(
      primary: Color(0xFF90CAF9),
      secondary: Color(0xFF1976D2),
      icon: Icons.edit_note,
    ),
  ];
}
