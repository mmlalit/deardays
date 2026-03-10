import 'package:flutter/material.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock JournalEntries — covers all categories, moods, voice/AI flags
// Use via main_mock.dart: flutter run -t lib/main_mock.dart
// ─────────────────────────────────────────────────────────────────────────────

final mockEntries = <JournalEntry>[
  // ── 2026 ──────────────────────────────────────────────────────────────────

  JournalEntry(
    id: 'mock-001',
    userId: 'mock-user',
    content: 'Trip to Bali with the family\n\nWe finally made it to Bali after two years of talking about this trip. The flight was long but the moment we landed and felt the warm air, all the exhaustion vanished. The kids were so excited — Aanya kept pointing at palm trees like she had never seen one before.\n\nWe stayed in a small villa near Ubud surrounded by rice paddies. Every morning we woke up to the sound of roosters and distant temple bells. It was the most peaceful thing I have heard in years.',
    mood: 'great',
    entryDate: DateTime(2026, 3, 5),
    entryTime: const TimeOfDay(hour: 8, minute: 30),
    locationName: 'Ubud, Bali',
    hasPhoto: true,
    hasVoice: true,
    isAiPolished: true,
    isMilestone: true,
    milestoneType: 'travel',
    wordCount: 110,
    createdAt: DateTime(2026, 3, 5),
    updatedAt: DateTime(2026, 3, 5),
    media: [
      EntryMedia(id: 'media-001', entryId: 'mock-001', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/bali_1.jpg', sortOrder: 0, createdAt: DateTime(2026, 3, 5)),
      EntryMedia(id: 'media-002', entryId: 'mock-001', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/bali_2.jpg', sortOrder: 1, createdAt: DateTime(2026, 3, 5)),
      EntryMedia(id: 'media-003', entryId: 'mock-001', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/bali_3.jpg', sortOrder: 2, createdAt: DateTime(2026, 3, 5)),
      EntryMedia(id: 'media-004', entryId: 'mock-001', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/bali_4.jpg', sortOrder: 3, createdAt: DateTime(2026, 3, 5)),
    ],
  ),

  JournalEntry(
    id: 'mock-002',
    userId: 'mock-user',
    content: 'Mom\'s birthday dinner\n\nToday we celebrated mom\'s 60th birthday at her favourite restaurant. Dad had secretly arranged for all her old friends to be there — she cried when she walked in and saw everyone. It was one of those rare evenings where everyone forgets their phones and just talks and laughs.\n\nShe kept saying she could not believe how fast time had passed. I think that is something we all felt tonight.',
    mood: 'great',
    entryDate: DateTime(2026, 2, 18),
    entryTime: const TimeOfDay(hour: 21, minute: 15),
    locationName: 'Mumbai',
    hasPhoto: true,
    hasVoice: false,
    isAiPolished: false,
    isMilestone: true,
    milestoneType: 'birthday',
    wordCount: 94,
    createdAt: DateTime(2026, 2, 18),
    updatedAt: DateTime(2026, 2, 18),
    media: [
      EntryMedia(id: 'media-005', entryId: 'mock-002', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/birthday_1.jpg', sortOrder: 0, createdAt: DateTime(2026, 2, 18)),
    ],
  ),

  JournalEntry(
    id: 'mock-003',
    userId: 'mock-user',
    content: 'Got the promotion\n\nReceived official confirmation today — I am the new Head of Product. Three years of hard work, late nights, and a couple of really difficult quarters. The boss called me into his office and I honestly thought it was going to be bad news.\n\nWhen he said congratulations I had to ask him to repeat it. The whole office knew before I even got back to my desk. Feels surreal.',
    mood: 'great',
    entryDate: DateTime(2026, 2, 3),
    entryTime: const TimeOfDay(hour: 14, minute: 0),
    locationName: 'Bengaluru',
    hasVoice: true,
    isAiPolished: true,
    isMilestone: true,
    milestoneType: 'promotion',
    wordCount: 88,
    createdAt: DateTime(2026, 2, 3),
    updatedAt: DateTime(2026, 2, 3),
  ),

  JournalEntry(
    id: 'mock-004',
    userId: 'mock-user',
    content: 'Sunday morning run\n\nWoke up early and went for a run along the lake road before the city woke up. There is something about those first thirty minutes of the day when the world is still quiet. Finished 8 km, personal best for this month.\n\nFeeling strong. The gym routine is finally paying off. Need to keep this momentum going through the week.',
    mood: 'good',
    entryDate: DateTime(2026, 1, 26),
    entryTime: const TimeOfDay(hour: 7, minute: 10),
    locationName: 'Bengaluru',
    hasVoice: false,
    isAiPolished: false,
    wordCount: 72,
    createdAt: DateTime(2026, 1, 26),
    updatedAt: DateTime(2026, 1, 26),
  ),

  JournalEntry(
    id: 'mock-005',
    userId: 'mock-user',
    content: 'Reconnecting with old friends\n\nMet Rahul and Priya after almost three years. We used to be inseparable in college — the kind of friends you assume will always be around. Life pulls people in different directions and suddenly years pass.\n\nWe spent four hours at that small café talking as if no time had passed at all. It reminded me how important it is to make time for the people who know the old version of you.',
    mood: 'good',
    entryDate: DateTime(2026, 1, 11),
    entryTime: const TimeOfDay(hour: 18, minute: 45),
    hasVoice: false,
    isAiPolished: false,
    wordCount: 85,
    createdAt: DateTime(2026, 1, 11),
    updatedAt: DateTime(2026, 1, 11),
  ),

  // ── 2025 ──────────────────────────────────────────────────────────────────

  JournalEntry(
    id: 'mock-006',
    userId: 'mock-user',
    content: 'Beach vacation — Goa\n\nFive days in South Goa. The pace of life there is completely different. No meetings, no notifications that feel urgent, just the sound of waves and the warmth of sand underfoot.\n\nWe explored a few hidden beaches that the tourist maps do not show. On the last evening we watched the sun set from a small shack where a fisherman was playing guitar. That image will stay with me for a long time.',
    mood: 'great',
    entryDate: DateTime(2025, 12, 27),
    entryTime: const TimeOfDay(hour: 19, minute: 0),
    locationName: 'South Goa',
    hasPhoto: true,
    hasVoice: true,
    isAiPolished: true,
    wordCount: 95,
    createdAt: DateTime(2025, 12, 27),
    updatedAt: DateTime(2025, 12, 27),
    media: [
      EntryMedia(id: 'media-006', entryId: 'mock-006', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/goa_1.jpg', sortOrder: 0, createdAt: DateTime(2025, 12, 27)),
      EntryMedia(id: 'media-007', entryId: 'mock-006', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/goa_2.jpg', sortOrder: 1, createdAt: DateTime(2025, 12, 27)),
      EntryMedia(id: 'media-008', entryId: 'mock-006', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/goa_3.jpg', sortOrder: 2, createdAt: DateTime(2025, 12, 27)),
    ],
  ),

  JournalEntry(
    id: 'mock-007',
    userId: 'mock-user',
    content: 'A difficult quarter at work\n\nThis has been one of the harder stretches professionally. The project I led did not hit targets despite months of effort. There is a specific kind of exhaustion that comes from trying your hardest and still falling short.\n\nI know there are lessons here. I just need some time before I can see them clearly. Need to speak with my mentor this week.',
    mood: 'low',
    entryDate: DateTime(2025, 11, 14),
    entryTime: const TimeOfDay(hour: 22, minute: 30),
    hasVoice: false,
    isAiPolished: false,
    wordCount: 80,
    createdAt: DateTime(2025, 11, 14),
    updatedAt: DateTime(2025, 11, 14),
  ),

  JournalEntry(
    id: 'mock-008',
    userId: 'mock-user',
    content: 'Daughter\'s first day of school\n\nAanya started first grade today. I have been thinking about this day for so long that the actual morning felt both enormous and completely ordinary at the same time. She was nervous at breakfast and kept asking if her teacher would be nice.\n\nWhen she came home she said school was "okay but the crayons were the good kind." I do not know what that means but she was happy. That is enough.',
    mood: 'good',
    entryDate: DateTime(2025, 6, 9),
    entryTime: const TimeOfDay(hour: 16, minute: 30),
    hasPhoto: true,
    hasVoice: true,
    isAiPolished: false,
    isMilestone: true,
    milestoneType: 'achievement',
    wordCount: 98,
    createdAt: DateTime(2025, 6, 9),
    updatedAt: DateTime(2025, 6, 9),
    media: [
      EntryMedia(id: 'media-009', entryId: 'mock-008', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/school_1.jpg', sortOrder: 0, createdAt: DateTime(2025, 6, 9)),
    ],
  ),

  JournalEntry(
    id: 'mock-009',
    userId: 'mock-user',
    content: 'Mountain trek — Himachal\n\nCompleted a 3-day trek in Spiti Valley with a group of eight strangers who became friends by day two. High altitude, thin air, and no cell reception. The disconnect was exactly what I needed.\n\nThere is a specific kind of clarity that only comes when you are carrying everything you need on your back and have nowhere else to be. I want more of that.',
    mood: 'great',
    entryDate: DateTime(2025, 5, 20),
    entryTime: const TimeOfDay(hour: 17, minute: 0),
    locationName: 'Spiti Valley, Himachal Pradesh',
    hasVoice: false,
    isAiPolished: true,
    wordCount: 86,
    createdAt: DateTime(2025, 5, 20),
    updatedAt: DateTime(2025, 5, 20),
  ),

  JournalEntry(
    id: 'mock-010',
    userId: 'mock-user',
    content: 'Realizing what I actually want\n\nHad a long conversation with myself during a walk today. Not a metaphorical one — I genuinely needed to step away from all the noise and just think.\n\nI realized that I have been optimizing for the wrong things. Career metrics, approval from people I do not even admire. Time to reorient. Growth is not always a straight line and that is something I am slowly learning to be okay with.',
    mood: 'okay',
    entryDate: DateTime(2025, 4, 3),
    entryTime: const TimeOfDay(hour: 9, minute: 45),
    hasVoice: false,
    isAiPolished: false,
    wordCount: 89,
    createdAt: DateTime(2025, 4, 3),
    updatedAt: DateTime(2025, 4, 3),
  ),

  JournalEntry(
    id: 'mock-011',
    userId: 'mock-user',
    content: 'New client win — startup series A\n\nThe pitch we have been working on for six weeks finally landed. The startup signed and it is the largest contract our team has closed this year. Everyone at the office was buzzing.\n\nThere is a particular satisfaction in seeing a proposal you poured real thought into get recognized. Celebrated with the team over dinner.',
    mood: 'great',
    entryDate: DateTime(2025, 3, 15),
    entryTime: const TimeOfDay(hour: 18, minute: 0),
    locationName: 'Bengaluru',
    hasVoice: true,
    isAiPolished: false,
    wordCount: 76,
    createdAt: DateTime(2025, 3, 15),
    updatedAt: DateTime(2025, 3, 15),
  ),

  // ── 2024 ──────────────────────────────────────────────────────────────────

  JournalEntry(
    id: 'mock-012',
    userId: 'mock-user',
    content: 'Dad\'s retirement party\n\nAfter 35 years in the same company, dad retired today. We threw him a small party at home — family, a few close colleagues, the neighbours who have known him for decades.\n\nHe gave a small speech and for the first time in my life I saw him emotional in front of other people. He thanked mom for "keeping him from becoming the boring person work was trying to turn him into." Everyone laughed. I will never forget that line.',
    mood: 'great',
    entryDate: DateTime(2024, 12, 1),
    entryTime: const TimeOfDay(hour: 20, minute: 0),
    locationName: 'Pune',
    hasVoice: false,
    isAiPolished: true,
    wordCount: 102,
    createdAt: DateTime(2024, 12, 1),
    updatedAt: DateTime(2024, 12, 1),
  ),

  JournalEntry(
    id: 'mock-013',
    userId: 'mock-user',
    content: 'Japan trip — Tokyo to Kyoto\n\nTwo weeks in Japan. I have visited many countries but Japan feels different. Everything works. The trains are on time, the food is extraordinary, people are genuinely kind in a way that does not feel performed.\n\nKyoto in autumn was something out of a painting. We visited seventeen temples in four days. By the end I stopped trying to photograph everything and just tried to be present.',
    mood: 'great',
    entryDate: DateTime(2024, 11, 8),
    entryTime: const TimeOfDay(hour: 21, minute: 30),
    locationName: 'Kyoto, Japan',
    hasPhoto: true,
    hasVoice: true,
    isAiPolished: true,
    wordCount: 97,
    createdAt: DateTime(2024, 11, 8),
    updatedAt: DateTime(2024, 11, 8),
    media: [
      EntryMedia(id: 'media-010', entryId: 'mock-013', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/japan_1.jpg', sortOrder: 0, createdAt: DateTime(2024, 11, 8)),
      EntryMedia(id: 'media-011', entryId: 'mock-013', userId: 'mock-user', mediaType: 'photo', storagePath: 'mock/photos/japan_2.jpg', sortOrder: 1, createdAt: DateTime(2024, 11, 8)),
    ],
  ),

  JournalEntry(
    id: 'mock-014',
    userId: 'mock-user',
    content: 'Health scare — and what came after\n\nThe doctor found something concerning during the routine check-up last month. Two weeks of tests followed. Everything turned out to be fine, but those two weeks changed something in how I think about time.\n\nI am not planning to make any dramatic changes. But I noticed I have been more patient with people, slower to react to small frustrations. Fear has a way of rearranging priorities.',
    mood: 'okay',
    entryDate: DateTime(2024, 8, 22),
    entryTime: const TimeOfDay(hour: 11, minute: 0),
    hasVoice: false,
    isAiPolished: false,
    wordCount: 85,
    createdAt: DateTime(2024, 8, 22),
    updatedAt: DateTime(2024, 8, 22),
  ),

  JournalEntry(
    id: 'mock-015',
    userId: 'mock-user',
    content: 'Starting the meditation habit\n\nDay 30 of daily meditation. What started as a desperate attempt to manage stress has quietly become the most important part of my morning. I do not think I have become calmer exactly — I just notice the moments before I lose my temper more quickly now.\n\nThat gap between stimulus and reaction is where the work happens. Thirty seconds of breathing can change the outcome of an entire conversation.',
    mood: 'good',
    entryDate: DateTime(2024, 7, 4),
    entryTime: const TimeOfDay(hour: 7, minute: 30),
    hasVoice: false,
    isAiPolished: false,
    wordCount: 90,
    createdAt: DateTime(2024, 7, 4),
    updatedAt: DateTime(2024, 7, 4),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Mock derived data — derived from mockEntries for provider overrides
// ─────────────────────────────────────────────────────────────────────────────

Map<String, int> get mockMoodStats {
  final stats = <String, int>{};
  for (final e in mockEntries) {
    if (e.mood != null) stats[e.mood!] = (stats[e.mood!] ?? 0) + 1;
  }
  return stats;
}

List<Map<String, String>> get mockWeeklyMoods {
  final now = DateTime.now();
  return List.generate(7, (i) {
    final d = now.subtract(Duration(days: 6 - i));
    final moods = ['good', 'great', 'okay', 'good', 'great', 'okay', 'good'];
    return {
      'date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'mood': moods[i],
    };
  });
}
