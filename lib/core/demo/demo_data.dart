import 'package:flutter/material.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/book/data/models/book.dart';

/// Static demo data shown when demo mode is active.
/// No network calls are made — all data is local.
/// Photo URLs use Unsplash direct links (handled by the `startsWith('http')` check
/// in photo builders / MediaService).
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
    trialStartedAt: DateTime.now().subtract(const Duration(days: 7)),
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
      coverImageUrl: 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=600&h=600&fit=crop',
      writingStyle: 'memoir',
      startDate: DateTime(2025, 1, 1),
      sortOrder: 0,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'demo-book-family',
      userId: _uid,
      title: 'Family Life',
      coverColor: '#EC4899',
      coverImageUrl: 'https://images.unsplash.com/photo-1511895426328-dc8714191300?w=600&h=600&fit=crop',
      writingStyle: 'memoir',
      startDate: DateTime(2024, 1, 1),
      sortOrder: 1,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'demo-book-travel',
      userId: _uid,
      title: 'Travel & Adventures',
      coverColor: '#F59E0B',
      coverImageUrl: 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=600&h=600&fit=crop',
      writingStyle: 'memoir',
      startDate: DateTime(2024, 1, 1),
      sortOrder: 2,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'demo-book-2024',
      userId: _uid,
      title: 'My Story 2024',
      coverColor: '#10B981',
      coverImageUrl: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=600&h=600&fit=crop',
      writingStyle: 'memoir',
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 12, 31),
      sortOrder: 3,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 12, 31),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Journal Entries
  // ---------------------------------------------------------------------------

  static final List<JournalEntry> entries = [
    // ── Happiest + Travel: Beach sunrise ──
    JournalEntry(
      id: 'demo-001',
      userId: _uid,
      content:
          'Beach Sunrise with Family\n\nWoke up at 5am and drove to the coast with everyone. Dad made his thermos coffee and Mom packed those little sandwiches she always brings. We watched the sunrise paint the sky in orange and gold. The kids ran straight into the water despite the cold. One of those mornings you never want to end.',
      rawContent: 'Beach sunrise trip with the whole family. Amazing morning.',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(days: 2)),
      entryTime: const TimeOfDay(hour: 6, minute: 30),
      locationName: 'Malibu Beach, California',
      isAiPolished: true,
      hasPhoto: true,
      isMilestone: true,
      milestoneType: 'travel',
      wordCount: 78,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      media: [
        EntryMedia(
          id: 'demo-media-001',
          entryId: 'demo-001',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Happiest: Completed marathon ──
    JournalEntry(
      id: 'demo-002',
      userId: _uid,
      content:
          'Completed First Marathon\n\nI actually did it. 42 kilometres. My legs are destroyed but my spirit has never been higher. The last 5km were pure willpower — every step felt impossible until I turned the corner and saw the finish line. The crowd was cheering and I started crying. Best feeling of my entire life.',
      rawContent: 'Finished my first marathon! 42km. Emotional finish.',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(days: 5)),
      entryTime: const TimeOfDay(hour: 11, minute: 0),
      locationName: 'City Marathon Route',
      isAiPolished: true,
      hasPhoto: true,
      wordCount: 72,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      media: [
        EntryMedia(
          id: 'demo-media-002',
          entryId: 'demo-002',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1513593771513-7b58b6c4af38?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Family: Mom's birthday ──
    JournalEntry(
      id: 'demo-003',
      userId: _uid,
      content:
          'Surprise Birthday for Mom\n\nWe pulled it off! Mom had no idea. Dad kept her busy at the garden centre while my sister and I decorated the whole house. When she walked in and saw everyone — her face just crumbled into the happiest tears. She kept saying "you shouldn\'t have" while hugging every single person twice. The cake was her favourite — lemon with cream cheese frosting. Family is everything.',
      rawContent: 'Threw a surprise birthday party for mom. She cried happy tears.',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(days: 8)),
      entryTime: const TimeOfDay(hour: 18, minute: 0),
      isAiPolished: true,
      hasPhoto: true,
      isMilestone: true,
      milestoneType: 'celebration',
      wordCount: 85,
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      updatedAt: DateTime.now().subtract(const Duration(days: 8)),
      media: [
        EntryMedia(
          id: 'demo-media-003',
          entryId: 'demo-003',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1464349153459-f0199f4a3660?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Family: Game night with brother ──
    JournalEntry(
      id: 'demo-004',
      userId: _uid,
      content:
          'Game Night with the Family\n\nBrother flew in for the weekend. Stayed up until 2am playing board games and eating too much pizza. Dad tried to cheat at Monopoly again and got caught. Mom fell asleep on the couch halfway through. Just like old times. These are the nights I\'ll remember forever.',
      rawContent: 'Brother visited. Game night with the whole family. Stayed up late.',
      mood: 'good',
      entryDate: DateTime.now().subtract(const Duration(days: 10)),
      entryTime: const TimeOfDay(hour: 23, minute: 30),
      isAiPolished: false,
      hasPhoto: true,
      wordCount: 62,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      media: [
        EntryMedia(
          id: 'demo-media-004',
          entryId: 'demo-004',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Travel: Paris trip ──
    JournalEntry(
      id: 'demo-005',
      userId: _uid,
      content:
          'Paris at Dusk\n\nThe city of lights never fails to enchant. Spent the afternoon wandering through Le Marais, stumbling upon hidden courtyards and the smell of fresh baguettes. Watched the Eiffel Tower light up from Trocadéro and it still took my breath away, even the third time. This trip was everything I needed.',
      rawContent: 'Exploring Paris. Le Marais, baguettes, Eiffel Tower at night.',
      polishedContent: 'Paris at Dusk\n\nThe city of lights never fails to enchant...',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(days: 14)),
      entryTime: const TimeOfDay(hour: 19, minute: 45),
      locationName: 'Paris, France',
      isAiPolished: true,
      hasPhoto: true,
      wordCount: 68,
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      updatedAt: DateTime.now().subtract(const Duration(days: 14)),
      media: [
        EntryMedia(
          id: 'demo-media-005',
          entryId: 'demo-005',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Travel: Kyoto ──
    JournalEntry(
      id: 'demo-006',
      userId: _uid,
      content:
          'Bamboo Forests of Kyoto\n\nA morning meditation in Arashiyama. The sound of bamboo swaying in the wind is something I\'ll keep forever. Walked through the ancient temple gardens and visited a tiny tea house run by an elderly couple. The matcha was the best I\'ve ever had. Japan has a way of making you slow down and notice everything.',
      rawContent: 'Visited Arashiyama bamboo forest. Tea house. Beautiful day in Kyoto.',
      mood: 'good',
      entryDate: DateTime.now().subtract(const Duration(days: 20)),
      entryTime: const TimeOfDay(hour: 9, minute: 0),
      locationName: 'Kyoto, Japan',
      isAiPolished: true,
      hasPhoto: true,
      wordCount: 72,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now().subtract(const Duration(days: 20)),
      media: [
        EntryMedia(
          id: 'demo-media-006',
          entryId: 'demo-006',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Happiest: Dinner surprise ──
    JournalEntry(
      id: 'demo-007',
      userId: _uid,
      content:
          'Surprise Birthday Dinner\n\nFriends organized the most incredible surprise dinner at that rooftop restaurant downtown. Walked in thinking it was just drinks with two people — nope, twenty faces yelling surprise. The table was covered in candles and there was a cake shaped like a book. Overwhelmed with gratitude for these people.',
      rawContent: 'Surprise birthday dinner. Friends are amazing. Rooftop restaurant.',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(days: 12)),
      entryTime: const TimeOfDay(hour: 20, minute: 30),
      locationName: 'Skyline Rooftop Bar',
      isAiPolished: false,
      hasPhoto: true,
      wordCount: 65,
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      updatedAt: DateTime.now().subtract(const Duration(days: 12)),
      media: [
        EntryMedia(
          id: 'demo-media-007',
          entryId: 'demo-007',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Family: Called Mom ──
    JournalEntry(
      id: 'demo-008',
      userId: _uid,
      content:
          'Called Mom tonight. We talked for almost an hour — mostly about nothing important: her garden, the neighbour\'s new puppy, what she watched on television. But there was this moment near the end where she said "I just love hearing your voice." I held onto that long after we hung up.',
      rawContent: 'Called mom for an hour. She said she loves hearing my voice. Sweet.',
      mood: 'good',
      entryDate: DateTime.now().subtract(const Duration(days: 4)),
      entryTime: const TimeOfDay(hour: 20, minute: 0),
      isAiPolished: false,
      wordCount: 61,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),

    // ── Travel: Beach weekend ──
    JournalEntry(
      id: 'demo-009',
      userId: _uid,
      content:
          'Beach Weekend in Goa\n\nThree days of nothing but sand, waves, and fresh seafood. Took a boat ride to a secluded beach where the water was crystal clear. Read an entire book in one sitting under a palm tree. The vacation I didn\'t know I desperately needed.',
      rawContent: 'Goa beach weekend. Boat ride, reading, seafood. Perfect trip.',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(days: 25)),
      entryTime: const TimeOfDay(hour: 16, minute: 0),
      locationName: 'Palolem Beach, Goa',
      isAiPolished: true,
      hasPhoto: true,
      wordCount: 55,
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      updatedAt: DateTime.now().subtract(const Duration(days: 25)),
      media: [
        EntryMedia(
          id: 'demo-media-009',
          entryId: 'demo-009',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&h=600&fit=crop&q=80',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
        EntryMedia(
          id: 'demo-media-009b',
          entryId: 'demo-009',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1519046904884-53103b34b206?w=800&h=600&fit=crop',
          sortOrder: 1,
          createdAt: DateTime.now(),
        ),
        EntryMedia(
          id: 'demo-media-009c',
          entryId: 'demo-009',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1476673160081-cf065607f449?w=800&h=600&fit=crop',
          sortOrder: 2,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Okay mood: Tough day at work ──
    JournalEntry(
      id: 'demo-010',
      userId: _uid,
      content:
          'Lessons From a Difficult Call\n\nThe call with the client did not go how I hoped. Months of work and they\'re going in a different direction. I stayed calm on the phone but afterward I needed to step outside and just breathe. Failure stings. But sitting here now, I can see what I\'d do differently.',
      rawContent: 'Client call went badly. Frustrated but trying to learn from it.',
      mood: 'tough',
      entryDate: DateTime.now().subtract(const Duration(days: 3)),
      entryTime: const TimeOfDay(hour: 17, minute: 45),
      isAiPolished: true,
      wordCount: 65,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),

    // ── Happiest: Art museum ──
    JournalEntry(
      id: 'demo-011',
      userId: _uid,
      content:
          'Saturday in the City\n\nSpent the afternoon at the art museum. Didn\'t plan it — just wandered in to escape the rain. There was an exhibition on light and shadow that completely stopped me. One photo of a woman reading by a window made me want to write more, notice more, slow down more.',
      rawContent: 'Randomly went to the art museum. Photography exhibition was incredible.',
      mood: 'good',
      entryDate: DateTime.now().subtract(const Duration(days: 7)),
      entryTime: const TimeOfDay(hour: 15, minute: 20),
      locationName: 'Metropolitan Museum of Art',
      isAiPolished: true,
      hasPhoto: true,
      wordCount: 65,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 7)),
      media: [
        EntryMedia(
          id: 'demo-media-011',
          entryId: 'demo-011',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1554907984-15263bfd63bd?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Family: Father-daughter hike ──
    JournalEntry(
      id: 'demo-012',
      userId: _uid,
      content:
          'Hiking with Dad\n\nDad suggested we take the mountain trail we used to do when I was a child. He\'s slower now but just as determined. We stopped at that old lookout point and sat together in comfortable silence, watching the valley below. He put his arm around me and said "This never gets old." Neither does spending time with him.',
      rawContent: 'Hiked the old trail with Dad. Great conversation at the lookout.',
      mood: 'great',
      entryDate: DateTime.now().subtract(const Duration(days: 16)),
      entryTime: const TimeOfDay(hour: 10, minute: 0),
      locationName: 'Blue Ridge Mountains',
      isAiPolished: true,
      hasPhoto: true,
      isMilestone: false,
      wordCount: 70,
      createdAt: DateTime.now().subtract(const Duration(days: 16)),
      updatedAt: DateTime.now().subtract(const Duration(days: 16)),
      media: [
        EntryMedia(
          id: 'demo-media-012',
          entryId: 'demo-012',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
    ),

    // ── Happiest: Morning coffee ──
    JournalEntry(
      id: 'demo-013',
      userId: _uid,
      content:
          'A Morning Worth Remembering\n\nToday I woke up before sunrise and decided to take a walk. The streets were quiet — just birdsong and the city waking up. I grabbed a coffee from the little corner café and sat on the bench by the fountain. It felt like I had the whole world to myself for twenty minutes.',
      rawContent: 'Early morning walk. Coffee at the new café. Really peaceful.',
      mood: 'good',
      entryDate: DateTime.now().subtract(const Duration(hours: 8)),
      entryTime: const TimeOfDay(hour: 7, minute: 15),
      locationName: 'Central Park, New York',
      isAiPolished: true,
      hasPhoto: true,
      wordCount: 65,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
      media: [
        EntryMedia(
          id: 'demo-media-013',
          entryId: 'demo-013',
          userId: _uid,
          mediaType: 'photo',
          storagePath: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800&h=600&fit=crop',
          sortOrder: 0,
          createdAt: DateTime.now(),
        ),
      ],
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
