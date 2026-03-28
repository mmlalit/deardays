// Future roadmap feature stubs for DearDays.
// These are planned features to be implemented in future sprints.
// Each stub documents the feature and where it should plug in.

import 'package:flutter/foundation.dart';

// ─── Natural Language Search ──────────────────────────────────────────────
// Where: ExploreScreen search bar
// Description: Allow queries like "entries when I was proud of myself"
// Implementation: Pass query to AiService.semanticSearch(query, entries)
// AiService would embed the query + each entry, return cosine-similarity ranked results
// TODO(v2): Implement semantic_search in AiService
// TODO(v2): Add "AI Search" toggle in ExploreScreen search bar

// ─── Real-time Audio Waveform ─────────────────────────────────────────────
// Where: RecordingScreen._buildWaveform
// Description: Drive waveform bar heights from live audio amplitude
// Implementation: Use record package's onAmplitude stream
//   record.onAmplitude.listen((amp) => setState(() => _amplitude = amp.current))
//   Map amplitude (-60dB to 0dB) to bar heights (4px to 40px)
// TODO(v2): Replace fixed animation with amplitude-driven bars in RecordingScreen

// ─── Body/Emotion Mapping ─────────────────────────────────────────────────
// Where: CheckInScreen after mood selection
// Description: Let user tap a body outline to indicate where they feel the emotion
// Implementation: Custom painter with tap detection, SVG body outline
//   Store bodyArea: 'chest' | 'stomach' | 'head' | 'shoulders' | 'throat'
//   Add body_area field to JournalEntry model
// TODO(v2): Add body mapping step to CheckInFlow

// ─── Collaborative Chapters ──────────────────────────────────────────────
// Where: LibraryScreen chapter card long-press menu
// Description: Invite family members to co-author a chapter
// Implementation: Supabase RLS policy update, shared book_contributors table
//   Book model: add contributors: List<String> (user IDs)
//   Invite flow: BookRepository.inviteContributor(bookId, email)
// TODO(v3): Implement book sharing + contributor model in BookRepository

// ─── Annual Year in Review ────────────────────────────────────────────────
// Where: LibraryScreen featured card (December/January)
// Description: Auto-generated "Your 2025 in Review" beautiful summary book
// Implementation: AiService.generateYearInReview(entries) returns structured doc
//   Show as special MyLifeBookScreen variant with cover photo + monthly summaries
//   Share as PDF
// TODO(v3): Implement in AiService.generateYearInReview + dedicated screen

/// Logs all future features to console (dev mode helper)
void printFutureRoadmap() {
  debugPrint('=== DearDays Future Roadmap ===');
  debugPrint('v2: Natural language search');
  debugPrint('v2: Real-time audio waveform');
  debugPrint('v2: Body/emotion mapping in check-in');
  debugPrint('v3: Collaborative chapters');
  debugPrint('v3: Annual Year in Review');
}
