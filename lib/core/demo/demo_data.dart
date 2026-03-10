import 'package:flutter/material.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/book/data/models/book.dart';

/// Static demo data shown when demo mode is active.
/// No network calls are made — all data is local.
class DemoData {
  DemoData._();

  static const _uid = 'demo-user-001';

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  static final UserProfile profile = UserProfile(
    id: _uid,
    displayName: 'Alex Rivera',
    encryptionSalt: 'demo-salt',
    writingStyle: 'memoir',
    isSubscribed: true,
    subscriptionPlan: 'annual',
    bookOrganization: 'yearly',
    trialStartedAt: DateTime.now().subtract(const Duration(days: 30)),
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  );

  // ---------------------------------------------------------------------------
  // Streak
  // ---------------------------------------------------------------------------

  static final Streak streak = Streak(
    id: 'demo-streak-001',
    userId: _uid,
    currentStreak: 12,
    longestStreak: 28,
    lastEntryDate: DateTime.now(),
    totalEntries: 47,
  );

  // ---------------------------------------------------------------------------
  // Books
  // ---------------------------------------------------------------------------

  static final List<Book> books = [
    Book(
      id: 'demo-book-2025',
      userId: _uid,
      title: 'My Story 2025',
      coverColor: '#6366F1',
      writingStyle: 'memoir',
      startDate: DateTime(2025, 1, 1),
      sortOrder: 0,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'demo-book-2024',
      userId: _uid,
      title: 'My Story 2024',
      coverColor: '#10B981',
      writingStyle: 'memoir',
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 12, 31),
      sortOrder: 1,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 12, 31),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Journal Entries
  // ---------------------------------------------------------------------------

  static final List<JournalEntry> entries = [
    JournalEntry(
      id: 'demo-001',
      userId: _uid,
      content:
          'A Morning Worth Remembering\n\nToday I woke up before sunrise and decided to take a walk through the neighbourhood. The streets were quiet — just birdsong and the distant hum of the city waking up. I grabbed a coffee from that little corner café that just opened and sat on the bench by the fountain. It felt like I had the whole world to myself for twenty minutes.',
      rawContent:
          'Woke up early and went for a walk. Got coffee from the new café near the fountain. Really peaceful.',
      polishedContent:
          'A Morning Worth Remembering\n\nToday I woke up before sunrise and decided to take a walk through the neighbourhood...',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(hours: 3)),
      entryTime: const TimeOfDay(hour: 7, minute: 15),
      locationName: 'Central Park, New York',
      isAiPolished: true,
      hasPhoto: true,
      isMilestone: true,
      milestoneType: 'travel',
      wordCount: 78,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      media: [
        EntryMedia(id: 'demo-media-001', entryId: 'demo-001', userId: _uid, mediaType: 'photo', storagePath: 'demo/photos/park_1.jpg', sortOrder: 0, createdAt: DateTime.now()),
        EntryMedia(id: 'demo-media-002', entryId: 'demo-001', userId: _uid, mediaType: 'photo', storagePath: 'demo/photos/park_2.jpg', sortOrder: 1, createdAt: DateTime.now()),
        EntryMedia(id: 'demo-media-003', entryId: 'demo-001', userId: _uid, mediaType: 'photo', storagePath: 'demo/photos/park_3.jpg', sortOrder: 2, createdAt: DateTime.now()),
      ],
    ),
    JournalEntry(
      id: 'demo-002',
      userId: _uid,
      content:
          'Team lunch today turned into a two-hour conversation about where we all want to be in five years. Marcus said he wants to open a bakery, which honestly surprised everyone. Sarah is thinking about going back to school for architecture. I realised I haven\'t thought seriously about my own five-year plan in months. Maybe that\'s the next thing to figure out.',
      rawContent:
          'Had a long team lunch. Marcus wants a bakery, Sarah is thinking about architecture school. I need to think about my own goals.',
      mood: 'good',
      entryDate: DateTime.now().subtract(const Duration(days: 1)),
      entryTime: const TimeOfDay(hour: 13, minute: 30),
      locationName: 'Downtown Bistro',
      isAiPolished: false,
      wordCount: 68,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    JournalEntry(
      id: 'demo-003',
      userId: _uid,
      content:
          'Lessons From a Difficult Call\n\nThe call with the client did not go how I hoped. Months of work and they\'re going in a different direction. I stayed calm on the phone but afterward I needed to step outside and just breathe. Failure stings. But sitting here now, I can see what I\'d do differently — listen more carefully to what they were actually asking for, not what I assumed they needed.',
      rawContent:
          'The client call went badly. They\'re dropping the project. Frustrated but trying to learn from it.',
      polishedContent:
          'Lessons From a Difficult Call\n\nThe call with the client did not go how I hoped...',
      mood: 'tough',
      entryDate: DateTime.now().subtract(const Duration(days: 3)),
      entryTime: const TimeOfDay(hour: 17, minute: 45),
      isAiPolished: true,
      wordCount: 82,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    JournalEntry(
      id: 'demo-004',
      userId: _uid,
      content:
          'Called Mom tonight. We talked for almost an hour — mostly about nothing important: her garden, the neighbour\'s new puppy, what she watched on television. But there was this moment near the end where she said "I just love hearing your voice." I held onto that long after we hung up.',
      rawContent:
          'Called mom for an hour. Talked about her garden and random stuff. She said she loves hearing my voice. Sweet.',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(days: 5)),
      entryTime: const TimeOfDay(hour: 20, minute: 0),
      isAiPolished: false,
      wordCount: 61,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    JournalEntry(
      id: 'demo-005',
      userId: _uid,
      content:
          'Saturday in the City\n\nSpent the afternoon at the art museum. Didn\'t plan it — just wandered in to escape the rain. There was an exhibition on light and shadow in photography that completely stopped me in my tracks. One photo of a woman reading by a window — just the ordinary moment of it — made me want to write more, notice more, slow down more.',
      rawContent:
          'Randomly went to the art museum. Rain was the excuse but stayed for hours. The photography exhibition was incredible.',
      polishedContent:
          'Saturday in the City\n\nSpent the afternoon at the art museum...',
      mood: 'good',
      entryDate: DateTime.now().subtract(const Duration(days: 7)),
      entryTime: const TimeOfDay(hour: 15, minute: 20),
      locationName: 'Metropolitan Museum of Art',
      isAiPolished: true,
      hasPhoto: false,
      wordCount: 73,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Mood stats (for Explore / charts)
  // ---------------------------------------------------------------------------

  static const Map<String, int> moodStats = {
    'great': 14,
    'good': 18,
    'okay': 9,
    'low': 4,
    'tough': 2,
  };

  static final List<Map<String, String>> weeklyMoods = List.generate(7, (i) {
    final date = DateTime.now().subtract(Duration(days: 6 - i));
    final moods = ['good', 'great', 'okay', 'good', 'tough', 'great', 'good'];
    return {
      'date': date.toIso8601String(),
      'mood': moods[i],
    };
  });
}
