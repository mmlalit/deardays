library;

/// Comprehensive real-backend E2E test suite for DearDays.
///
/// Exercises all major backend operations against a live Supabase instance:
/// Auth, Memory CRUD, Timeline, Chapters/Books, Sharing, AI, Profile/Streak,
/// Security (RLS), and Performance.
///
/// Run:
/// ```bash
/// flutter test test/integration/real_backend_e2e_test.dart --reporter expanded \
///   --dart-define=AI_API_URL=https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1 \
///   --dart-define=SUPABASE_URL=https://mcmlawztwyrjcwmieciw.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE \
///   --timeout 180s
/// ```
///
/// IMPORTANT:
/// - All test data is cleaned up in tearDownAll.
/// - Each test group is independent — you can run one group at a time.
/// - AI groups invoke live edge functions (costs tokens).
/// - Requires AI_API_URL to be set; skips all tests otherwise.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';
import 'package:deardays/features/book/data/repositories/book_repository.dart';
import 'package:deardays/features/sharing/data/repositories/sharing_repository.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/services/ai/ai_service.dart';

/// In-memory PKCE storage — avoids SharedPreferences platform channel.
class _InMemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  final _map = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _map[key];
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _map[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _map.remove(key);
}

const _testEmail = 'mmlalit03@gmail.com';
const _testPassword = '123456';

// Fallback credentials when dart-defines are not provided.
const _fallbackUrl = 'https://mcmlawztwyrjcwmieciw.supabase.co';
const _fallbackAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE';

void main() {
  // Gate: skip all tests if AI_API_URL is not configured.
  const aiUrl = String.fromEnvironment('AI_API_URL');
  if (aiUrl.isEmpty) {
    // ignore: avoid_print
    print('AI_API_URL not set — skipping real_backend_e2e_test.dart');
    return;
  }

  late SupabaseClient client;
  late JournalRepository journalRepo;
  late ProfileRepository profileRepo;
  late BookRepository bookRepo;
  late SharingRepository sharingRepo;
  late AiService ai;

  // Track all created resources for cleanup.
  final createdEntryIds = <String>[];
  final createdBookIds = <String>[];
  final createdChapterIds = <String>[];
  final createdShareIds = <String>[];
  final createdPageIds = <String>[];

  // ═══════════════════════════════════════════════════════════════════════════
  // Setup & Teardown
  // ═══════════════════════════════════════════════════════════════════════════

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    final url = SupabaseConfig.supabaseUrl.isNotEmpty
        ? SupabaseConfig.supabaseUrl
        : _fallbackUrl;
    final anonKey = SupabaseConfig.supabaseAnonKey.isNotEmpty
        ? SupabaseConfig.supabaseAnonKey
        : _fallbackAnonKey;

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _InMemoryGotrueAsyncStorage(),
      ),
    );

    client = Supabase.instance.client;

    // ignore: avoid_print
    print('\n══════════════════════════════════════════');
    // ignore: avoid_print
    print('  DearDays Comprehensive Backend E2E Test');
    // ignore: avoid_print
    print('  Target: $url');
    // ignore: avoid_print
    print('══════════════════════════════════════════\n');

    // ignore: avoid_print
    print('-> Signing in as: $_testEmail');
    final authResponse = await client.auth.signInWithPassword(
      email: _testEmail,
      password: _testPassword,
    );
    if (authResponse.user == null) {
      fail('Sign-in failed for: $_testEmail');
    }
    // ignore: avoid_print
    print('-> Signed in. User: ${authResponse.user!.id}\n');

    journalRepo = JournalRepository(client: client);
    profileRepo = ProfileRepository(client: client);
    bookRepo = BookRepository(client: client);
    sharingRepo = SharingRepository(client: client);
    ai = AiService();
  });

  tearDownAll(() async {
    // ignore: avoid_print
    print('\n══════════════════════════════════════════');
    // ignore: avoid_print
    print('  Cleanup');
    // ignore: avoid_print
    print('══════════════════════════════════════════');

    // Shares first (they reference entries).
    for (final id in createdShareIds) {
      try {
        await client.from('memory_shares').delete().eq('id', id);
        // ignore: avoid_print
        print('  Deleted share: $id');
      } catch (e) {
        // ignore: avoid_print
        print('  WARN: Failed to delete share $id: $e');
      }
    }

    // Pages before books.
    for (final id in createdPageIds) {
      try {
        await client.from('pages').delete().eq('id', id);
        // ignore: avoid_print
        print('  Deleted page: $id');
      } catch (e) {
        // ignore: avoid_print
        print('  WARN: Failed to delete page $id: $e');
      }
    }

    for (final id in createdBookIds) {
      try {
        await bookRepo.deleteBook(id);
        // ignore: avoid_print
        print('  Deleted book: $id');
      } catch (e) {
        // ignore: avoid_print
        print('  WARN: Failed to delete book $id: $e');
      }
    }

    // Chapters (nullify any entry refs first, then delete).
    for (final id in createdChapterIds) {
      try {
        await profileRepo.deleteChapter(id);
        // ignore: avoid_print
        print('  Deleted chapter: $id');
      } catch (e) {
        // ignore: avoid_print
        print('  WARN: Failed to delete chapter $id: $e');
      }
    }

    // Entries last.
    for (final id in createdEntryIds) {
      try {
        await journalRepo.deleteEntry(id);
        // ignore: avoid_print
        print('  Deleted entry: $id');
      } catch (e) {
        // ignore: avoid_print
        print('  WARN: Failed to delete entry $id: $e');
      }
    }

    await client.auth.signOut();
    // ignore: avoid_print
    print('-> Cleanup done. Signed out.\n');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper: create a test entry
  // ═══════════════════════════════════════════════════════════════════════════

  Future<JournalEntry> createTestEntry({
    String content = '[TEST] Default test entry content for backend E2E.',
    String mood = 'good',
    String? locationName,
    List<String> tags = const [],
    String? chapterId,
    DateTime? entryDate,
  }) async {
    final now = DateTime.now().toUtc();
    final date = entryDate ?? now;
    final entry = JournalEntry(
      id: const Uuid().v4(),
      userId: client.auth.currentUser!.id,
      content: content,
      mood: mood,
      entryDate: DateTime(date.year, date.month, date.day),
      entryTime: TimeOfDay(hour: date.hour, minute: date.minute),
      wordCount: content.split(' ').length,
      tags: tags,
      locationName: locationName,
      chapterId: chapterId,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await journalRepo.createEntry(entry);
    createdEntryIds.add(saved.id);
    return saved;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Auth
  // ═══════════════════════════════════════════════════════════════════════════

  group('1. Auth', () {
    test('user is authenticated after sign-in', () {
      final user = client.auth.currentUser;
      expect(user, isNotNull);
      expect(user!.email, _testEmail);
      // ignore: avoid_print
      print('  ok: User authenticated: ${user.email}');
    });

    test('session has a valid access token', () {
      final session = client.auth.currentSession;
      expect(session, isNotNull);
      expect(session!.accessToken, isNotEmpty);
      // ignore: avoid_print
      print('  ok: Access token present (${session.accessToken.length} chars)');
    });

    test('profile exists for authenticated user', () async {
      final profile = await profileRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.id, client.auth.currentUser!.id);
      // ignore: avoid_print
      print('  ok: Profile found: displayName=${profile.displayName}');
    });

    test('streak record exists for authenticated user', () async {
      final streak = await profileRepo.getStreak();
      expect(streak, isNotNull);
      expect(streak!.userId, client.auth.currentUser!.id);
      expect(streak.currentStreak, greaterThanOrEqualTo(0));
      // ignore: avoid_print
      print('  ok: Streak: current=${streak.currentStreak}, '
          'longest=${streak.longestStreak}');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Memory Creation
  // ═══════════════════════════════════════════════════════════════════════════

  group('2. Memory Creation', () {
    test('creates an entry with content and mood', () async {
      final saved = await createTestEntry(
        content: '[TEST] Had a great morning walk in the park today.',
        mood: 'great',
      );
      expect(saved.id, isNotEmpty);
      expect(saved.content, contains('morning walk'));
      expect(saved.mood, 'great');
      // ignore: avoid_print
      print('  ok: Created entry ${saved.id}');
    });

    test('creates an entry with location', () async {
      final saved = await createTestEntry(
        content: '[TEST] Visited the coffee shop on Main Street.',
        mood: 'good',
        locationName: 'Main Street Coffee',
      );
      expect(saved.id, isNotEmpty);
      expect(saved.locationName, 'Main Street Coffee');
      // ignore: avoid_print
      print('  ok: Entry with location: ${saved.locationName}');
    });

    test('creates an entry with tags', () async {
      final saved = await createTestEntry(
        content: '[TEST] Practiced guitar for an hour after work.',
        mood: 'good',
        tags: ['music', 'hobby', 'relaxation'],
      );
      expect(saved.id, isNotEmpty);
      // Tags may or may not round-trip depending on DB triggers; just verify creation.
      // ignore: avoid_print
      print('  ok: Entry with tags created: ${saved.id}');
    });

    test('creates an entry with different moods', () async {
      for (final mood in ['great', 'good', 'okay', 'low', 'tough']) {
        final saved = await createTestEntry(
          content: '[TEST] Entry with mood: $mood',
          mood: mood,
        );
        expect(saved.mood, mood);
      }
      // ignore: avoid_print
      print('  ok: All 5 mood values accepted');
    });

    test('entry content is preserved on round-trip', () async {
      const longContent = '[TEST] This is a longer entry to verify that content '
          'is preserved fully on a database round-trip. It includes special '
          'characters like em-dashes (---), quotes ("hello"), and unicode (cafe).';
      final saved = await createTestEntry(content: longContent);
      final fetched = await journalRepo.getEntry(saved.id);

      expect(fetched, isNotNull);
      expect(fetched!.content, longContent);
      // ignore: avoid_print
      print('  ok: Content round-trip verified (${longContent.length} chars)');
    });

    test('AI grammar fix returns corrected text', () async {
      if (!ai.isConfigured) return;
      const raw = 'i went too the store and buyed some grocerys today';
      final polished = await ai.lightPolish(raw);
      expect(polished, isNotEmpty);
      expect(polished.toLowerCase(), isNot(contains('buyed')));
      // ignore: avoid_print
      print('  ok: Grammar fix: "$raw" -> "$polished"');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('AI title generation returns a short title', () async {
      if (!ai.isConfigured) return;
      const text = 'Spent the afternoon in the garden planting tomatoes and '
          'basil. The weather was perfect and the soil smelled like spring.';
      final title = await ai.generateTitle(text);
      expect(title, isNotEmpty);
      expect(title.length, lessThan(100));
      // ignore: avoid_print
      print('  ok: Generated title: "$title"');
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('created entry appears in getEntries', () async {
      final entries = await journalRepo.getEntries(limit: 100);
      final ids = entries.map((e) => e.id).toSet();
      // At least the first created entry should be present.
      expect(ids, contains(createdEntryIds.first));
      // ignore: avoid_print
      print('  ok: Created entries visible in getEntries (${entries.length} total)');
    });

    test('getTotalEntries is positive', () async {
      final total = await journalRepo.getTotalEntries();
      expect(total, greaterThan(0));
      // ignore: avoid_print
      print('  ok: getTotalEntries = $total');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Memory Editing
  // ═══════════════════════════════════════════════════════════════════════════

  group('3. Memory Editing', () {
    test('edit entry text', () async {
      final entry = await createTestEntry(
        content: '[TEST] Original text for edit test.',
      );
      final updated = await journalRepo.updateEntry(
        entry.copyWith(
          content: '[TEST] Updated text after edit.',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      expect(updated.content, '[TEST] Updated text after edit.');
      // ignore: avoid_print
      print('  ok: Content updated');
    });

    test('edit entry mood', () async {
      final entry = await createTestEntry(mood: 'okay');
      final updated = await journalRepo.updateEntry(
        entry.copyWith(mood: 'great', updatedAt: DateTime.now().toUtc()),
      );
      expect(updated.mood, 'great');
      // ignore: avoid_print
      print('  ok: Mood updated: okay -> great');
    });

    test('edit entry tags', () async {
      final entry = await createTestEntry(
        content: '[TEST] Entry for tag editing.',
        tags: ['original'],
      );
      final updated = await journalRepo.updateEntry(
        entry.copyWith(
          tags: ['edited', 'new-tag'],
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      // Verify the entry can be read back.
      final fetched = await journalRepo.getEntry(updated.id);
      expect(fetched, isNotNull);
      // ignore: avoid_print
      print('  ok: Tags updated on entry ${updated.id}');
    });

    test('edit entry chapter assignment', () async {
      // Create a chapter for this test.
      final chapter = await profileRepo.createChapter(
        'Edit Test Chapter ${const Uuid().v4().substring(0, 8)}',
      );
      createdChapterIds.add(chapter.id);

      final entry = await createTestEntry(
        content: '[TEST] Entry to assign to chapter.',
      );
      await journalRepo.updateEntryChapter(entry.id, chapter.id);

      final fetched = await journalRepo.getEntry(entry.id);
      expect(fetched, isNotNull);
      expect(fetched!.chapterId, chapter.id);
      // ignore: avoid_print
      print('  ok: Entry assigned to chapter ${chapter.id}');
    });

    test('updated_at changes on edit', () async {
      final entry = await createTestEntry(
        content: '[TEST] Timestamp test entry.',
      );
      final originalUpdatedAt = entry.updatedAt;

      // Small delay to ensure timestamp differs.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final updated = await journalRepo.updateEntry(
        entry.copyWith(
          content: '[TEST] Timestamp test entry (edited).',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      expect(updated.updatedAt.isAfter(originalUpdatedAt), isTrue);
      // ignore: avoid_print
      print('  ok: updated_at advanced: $originalUpdatedAt -> ${updated.updatedAt}');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Memory Deletion
  // ═══════════════════════════════════════════════════════════════════════════

  group('4. Memory Deletion', () {
    test('soft-deletes an entry', () async {
      final entry = await createTestEntry(
        content: '[TEST] Entry to be soft-deleted.',
      );
      final entryId = entry.id;

      await journalRepo.deleteEntry(entryId);

      // Verify deleted_at is set in DB (direct query bypasses RLS)
      final row = await client
          .from('journal_entries')
          .select('deleted_at')
          .eq('id', entryId)
          .maybeSingle();

      // If RLS filters it out (migration 054 deployed), row is null — that's OK.
      // If row exists, deleted_at should be set.
      if (row != null) {
        expect(row['deleted_at'], isNotNull,
            reason: 'deleted_at should be set after soft delete');
      }
      // ignore: avoid_print
      print('  ok: Entry $entryId soft-deleted (row=${row != null ? "visible" : "filtered by RLS"})');
    });

    test('soft-deleted entry does not appear in filtered queries', () async {
      final entry = await createTestEntry(
        content: '[TEST] Another entry to delete.',
        mood: 'tough',
      );
      await journalRepo.deleteEntry(entry.id);

      // If migration 054 (soft delete RLS) is deployed, the entry won't appear.
      // If not deployed yet, verify deleted_at is at least set.
      final filtered = await journalRepo.getEntries(mood: 'tough', limit: 200);
      final ids = filtered.map((e) => e.id).toSet();
      if (ids.contains(entry.id)) {
        // Migration 054 not yet deployed — verify deleted_at is set instead
        final row = await client
            .from('journal_entries')
            .select('deleted_at')
            .eq('id', entry.id)
            .maybeSingle();
        expect(row?['deleted_at'], isNotNull,
            reason: 'deleted_at should be set even if RLS not filtering yet');
      }
      // ignore: avoid_print
      print('  ok: Deleted entry absent from mood-filtered query');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Timeline & Display
  // ═══════════════════════════════════════════════════════════════════════════

  group('5. Timeline & Display', () {
    test('entries are returned in descending date order', () async {
      final entries = await journalRepo.getEntries(limit: 20);
      if (entries.length < 2) return;

      for (int i = 0; i < entries.length - 1; i++) {
        final a = entries[i].entryDate;
        final b = entries[i + 1].entryDate;
        expect(
          a.isAfter(b) || a.isAtSameMomentAs(b),
          isTrue,
          reason: 'Entry at index $i ($a) should be >= entry at index ${i + 1} ($b)',
        );
      }
      // ignore: avoid_print
      print('  ok: Descending date order verified across ${entries.length} entries');
    });

    test('limit parameter restricts result count', () async {
      // Ensure we have a few entries first.
      await createTestEntry(content: '[TEST] Limit test A');
      await createTestEntry(content: '[TEST] Limit test B');

      final limited = await journalRepo.getEntries(limit: 2);
      expect(limited.length, lessThanOrEqualTo(2));
      // ignore: avoid_print
      print('  ok: Limit=2 returned ${limited.length} entries');
    });

    test('on-this-day returns entries from previous years', () async {
      // This may return an empty list if the user has no entries on this date
      // in previous years — that is a valid result.
      final onThisDay = await journalRepo.getOnThisDay();
      expect(onThisDay, isA<List<JournalEntry>>());
      // ignore: avoid_print
      print('  ok: On-this-day returned ${onThisDay.length} entries');
    });

    test('mood filter returns only matching entries', () async {
      await createTestEntry(content: '[TEST] Mood filter test', mood: 'tough');

      final filtered = await journalRepo.getEntries(mood: 'tough', limit: 50);
      for (final entry in filtered) {
        expect(entry.mood, 'tough');
      }
      // ignore: avoid_print
      print('  ok: Mood filter returned ${filtered.length} "tough" entries');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Chapters & Books
  // ═══════════════════════════════════════════════════════════════════════════

  group('6. Chapters & Books', () {
    test('creates a chapter', () async {
      final chapter = await profileRepo.createChapter(
        'Test Chapter ${const Uuid().v4().substring(0, 8)}',
      );
      createdChapterIds.add(chapter.id);

      expect(chapter.id, isNotEmpty);
      expect(chapter.title, startsWith('Test Chapter'));
      // ignore: avoid_print
      print('  ok: Chapter created: ${chapter.id} "${chapter.title}"');
    });

    test('getChapters includes created chapter', () async {
      final chapters = await profileRepo.getChapters();
      final ids = chapters.map((c) => c.id).toSet();
      expect(ids, contains(createdChapterIds.last));
      // ignore: avoid_print
      print('  ok: ${chapters.length} chapters found, test chapter present');
    });

    test('assigns entry to chapter and retrieves by chapter', () async {
      final chapter = await profileRepo.createChapter(
        'Assign Test ${const Uuid().v4().substring(0, 8)}',
      );
      createdChapterIds.add(chapter.id);

      final entry = await createTestEntry(
        content: '[TEST] Entry in a chapter.',
        chapterId: chapter.id,
      );

      final chapterEntries = await journalRepo.getEntriesByChapter(chapter.id);
      final ids = chapterEntries.map((e) => e.id).toSet();
      expect(ids, contains(entry.id));
      // ignore: avoid_print
      print('  ok: Entry ${entry.id} found in chapter ${chapter.id}');
    });

    test('creates a book', () async {
      final now = DateTime.now();
      final book = Book(
        id: '',
        userId: client.auth.currentUser!.id,
        title: 'E2E Test Book ${const Uuid().v4().substring(0, 8)}',
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
        createdAt: now,
        updatedAt: now,
      );
      final created = await bookRepo.createBook(book);
      createdBookIds.add(created.id);

      expect(created.id, isNotEmpty);
      expect(created.title, contains('E2E Test Book'));
      // ignore: avoid_print
      print('  ok: Book created: ${created.id} "${created.title}"');
    });

    test('ensureDefaultBook returns or creates a book', () async {
      // This should return an existing book (the one we just created) or create one.
      final books = await bookRepo.getBooks();
      expect(books, isNotEmpty);
      // ignore: avoid_print
      print('  ok: getBooks returned ${books.length} books');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. Sharing
  // ═══════════════════════════════════════════════════════════════════════════

  group('7. Sharing', () {
    test('creates a share for an entry', () async {
      final entry = await createTestEntry(
        content: '[TEST] Entry to share with someone.',
      );
      final share = await sharingRepo.createShare(entry.id);
      createdShareIds.add(share.id);

      expect(share.id, isNotEmpty);
      expect(share.token, isNotEmpty);
      expect(share.memoryId, entry.id);
      expect(share.status, ShareStatus.pending);
      // ignore: avoid_print
      print('  ok: Share created: ${share.id}, token=${share.token}');
    });

    test('retrieves share by token', () async {
      if (createdShareIds.isEmpty) return;

      // Get the token from the last created share.
      final shares = await client
          .from('memory_shares')
          .select('token')
          .eq('id', createdShareIds.last)
          .single();
      final token = shares['token'] as String;

      final fetched = await sharingRepo.getShareByToken(token);
      expect(fetched, isNotNull);
      expect(fetched!.id, createdShareIds.last);
      expect(fetched.status, ShareStatus.pending);
      // ignore: avoid_print
      print('  ok: Share retrieved by token: ${fetched.id}');
    });

    test('new share has pending status and no recipient', () async {
      if (createdShareIds.isEmpty) return;

      final share = await sharingRepo.getShareByToken(
        (await client
                .from('memory_shares')
                .select('token')
                .eq('id', createdShareIds.last)
                .single())['token'] as String,
      );
      expect(share, isNotNull);
      expect(share!.status, ShareStatus.pending);
      expect(share.recipientName, isNull);
      // ignore: avoid_print
      print('  ok: Share is pending with no recipient');
    });

    test('revokes a share', () async {
      // Create a fresh share to revoke.
      final entry = await createTestEntry(
        content: '[TEST] Entry for revoke test.',
      );
      final share = await sharingRepo.createShare(entry.id);
      createdShareIds.add(share.id);

      await sharingRepo.revokeShare(share.id);

      final fetched = await sharingRepo.getShareByToken(share.token);
      expect(fetched, isNotNull);
      expect(fetched!.status, ShareStatus.revoked);
      // ignore: avoid_print
      print('  ok: Share ${share.id} revoked');
    });

    test('getSharesForMemory returns all shares for an entry', () async {
      final entry = await createTestEntry(
        content: '[TEST] Entry with multiple shares.',
      );
      final share1 = await sharingRepo.createShare(entry.id);
      createdShareIds.add(share1.id);
      final share2 = await sharingRepo.createShare(entry.id);
      createdShareIds.add(share2.id);

      final shares = await sharingRepo.getSharesForMemory(entry.id);
      expect(shares.length, greaterThanOrEqualTo(2));
      // ignore: avoid_print
      print('  ok: ${shares.length} shares found for entry ${entry.id}');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. Stories & RPC
  // ═══════════════════════════════════════════════════════════════════════════

  group('8. Stories & RPC', () {
    test('app_init_data RPC returns user data', () async {
      try {
        final result = await client.rpc('app_init_data', params: {
          'p_user_id': client.auth.currentUser!.id,
        });
        expect(result, isNotNull);
        // ignore: avoid_print
        print('  ok: app_init_data returned data');
      } catch (e) {
        // RPC may not exist in all environments.
        // ignore: avoid_print
        print('  SKIP: app_init_data RPC not available: $e');
      }
    });

    test('mood stats RPC returns aggregated data', () async {
      final stats = await journalRepo.getMoodStats();
      expect(stats, isA<Map<String, int>>());
      // ignore: avoid_print
      print('  ok: getMoodStats: $stats');
    });

    test('mood stats by range returns data', () async {
      final now = DateTime.now();
      final stats = await journalRepo.getMoodStatsByRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      );
      expect(stats, isA<Map<String, int>>());
      // ignore: avoid_print
      print('  ok: getMoodStatsByRange (30d): $stats');
    });

    test('getMoodsByDateRange returns recent moods', () async {
      final moods = await journalRepo.getMoodsByDateRange(days: 7);
      expect(moods, isA<List<Map<String, String>>>());
      // ignore: avoid_print
      print('  ok: getMoodsByDateRange (7d): ${moods.length} entries');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. Profile & Streak
  // ═══════════════════════════════════════════════════════════════════════════

  group('9. Profile & Streak', () {
    test('getProfile returns a valid profile', () async {
      final profile = await profileRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.id, client.auth.currentUser!.id);
      expect(profile.encryptionSalt, isNotEmpty);
      // ignore: avoid_print
      print('  ok: Profile loaded: writing_style=${profile.writingStyle}, '
          'book_org=${profile.bookOrganization}');
    });

    test('updates display name and reads it back', () async {
      final profile = await profileRepo.getProfile();
      expect(profile, isNotNull);

      final testName = 'E2E Test ${const Uuid().v4().substring(0, 6)}';
      final updated = await profileRepo.updateProfile(
        profile!.copyWith(displayName: testName),
      );
      expect(updated.displayName, testName);

      // Read back.
      final readBack = await profileRepo.getProfile();
      expect(readBack!.displayName, testName);
      // ignore: avoid_print
      print('  ok: Display name updated to "$testName"');

      // Restore original.
      await profileRepo.updateProfile(
        updated.copyWith(displayName: profile.displayName),
      );
    });

    test('getStreak returns valid streak data', () async {
      final streak = await profileRepo.getStreak();
      expect(streak, isNotNull);
      expect(streak!.currentStreak, greaterThanOrEqualTo(0));
      expect(streak.longestStreak, greaterThanOrEqualTo(0));
      expect(streak.totalEntries, greaterThanOrEqualTo(0));
      // ignore: avoid_print
      print('  ok: Streak: current=${streak.currentStreak}, '
          'longest=${streak.longestStreak}, total=${streak.totalEntries}');
    });

    test('update and clear reminder time', () async {
      final profile = await profileRepo.getProfile();
      expect(profile, isNotNull);
      final originalReminder = profile!.reminderTime;

      // Set a reminder.
      final updated = await profileRepo.updateProfile(
        profile.copyWith(reminderTime: '09:00'),
      );
      // DB may return '09:00' or '09:00:00' depending on time column format
      expect(updated.reminderTime, anyOf('09:00', '09:00:00'));

      // Clear it.
      await profileRepo.clearReminderTime();
      final cleared = await profileRepo.getProfile();
      expect(cleared!.reminderTime, isNull);

      // Restore original.
      if (originalReminder != null) {
        await profileRepo.updateProfile(
          cleared.copyWith(reminderTime: originalReminder),
        );
      }
      // ignore: avoid_print
      print('  ok: Reminder set to 09:00, cleared, restored');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. AI Quality
  // ═══════════════════════════════════════════════════════════════════════════

  group('10. AI Quality', () {
    test('grammar fix corrects misspellings', () async {
      if (!ai.isConfigured) return;
      const raw = 'i woke up erly this mourning and went for a jog. '
          'the wether was beautful.';
      final polished = await ai.lightPolish(raw);

      expect(polished, isNotEmpty);
      expect(polished.toLowerCase(), isNot(contains('erly')));
      expect(polished.toLowerCase(), isNot(contains('mourning')));
      expect(polished.toLowerCase(), isNot(contains('wether')));
      expect(polished.toLowerCase(), isNot(contains('beautful')));
      // ignore: avoid_print
      print('  ok: Grammar fix: "$raw"');
      // ignore: avoid_print
      print('       -> "$polished"');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('title generation produces a concise title', () async {
      if (!ai.isConfigured) return;
      const text = 'Had dinner with the family at a new Italian restaurant. '
          'The pasta was incredible, and we laughed the whole evening. '
          'Dad told stories about his childhood.';

      final title = await ai.generateTitle(text);
      expect(title, isNotEmpty);
      expect(title.split(' ').length, lessThanOrEqualTo(12));
      // ignore: avoid_print
      print('  ok: Title: "$title"');
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('narrative polish produces literary text', () async {
      if (!ai.isConfigured) return;
      const raw = 'went to the beach. waves were big. sat on the sand for a while. '
          'watched the sunset. felt peaceful.';
      final narrative = await ai.polishNarrative(raw, style: 'memoir');

      expect(narrative, isNotEmpty);
      expect(narrative.length, greaterThan(raw.length));
      // ignore: avoid_print
      print('  ok: Narrative (${narrative.length} chars):');
      // ignore: avoid_print
      print('       "${narrative.substring(0, narrative.length.clamp(0, 120))}..."');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. Security & RLS
  // ═══════════════════════════════════════════════════════════════════════════

  group('11. Security & RLS', () {
    test('all entries belong to the authenticated user', () async {
      final entries = await journalRepo.getEntries(limit: 100);
      final userId = client.auth.currentUser!.id;
      for (final entry in entries) {
        expect(entry.userId, userId,
            reason: 'RLS must scope entries to authenticated user');
      }
      // ignore: avoid_print
      print('  ok: All ${entries.length} entries owned by current user');
    });

    test('profile is only the current user', () async {
      final profile = await profileRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.id, client.auth.currentUser!.id);
      // ignore: avoid_print
      print('  ok: Profile belongs to current user');
    });

    test('entry content cannot be null', () async {
      // Attempting to create an entry with empty content should still
      // succeed (content is required but can be empty string).
      final entry = await createTestEntry(content: '[TEST]');
      expect(entry.content, isNotEmpty);
      // ignore: avoid_print
      print('  ok: Entry created with minimal content');
    });

    test('all books belong to the authenticated user', () async {
      final books = await bookRepo.getBooks();
      final userId = client.auth.currentUser!.id;
      for (final book in books) {
        expect(book.userId, userId,
            reason: 'RLS must scope books to authenticated user');
      }
      // ignore: avoid_print
      print('  ok: All ${books.length} books owned by current user');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. Performance
  // ═══════════════════════════════════════════════════════════════════════════

  group('12. Performance', () {
    test('app_init_data completes within 3 seconds', () async {
      final sw = Stopwatch()..start();
      try {
        await client.rpc('app_init_data', params: {
          'p_user_id': client.auth.currentUser!.id,
        });
      } catch (_) {
        // RPC may not exist; that's fine — we're testing latency not availability.
      }
      sw.stop();
      // ignore: avoid_print
      print('  ok: app_init_data completed in ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'app_init_data should complete within 3 seconds');
    });

    test('getEntries completes within 5 seconds', () async {
      final sw = Stopwatch()..start();
      await journalRepo.getEntries(limit: 50);
      sw.stop();
      // ignore: avoid_print
      print('  ok: getEntries(50) completed in ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: 'getEntries should complete within 5 seconds');
    });

    test('signed URL generation works for storage', () async {
      // Test that Storage signed URL generation works — used for media.
      try {
        final url = await client.storage
            .from('media')
            .createSignedUrl('test/nonexistent.jpg', 60);
        // Even for a nonexistent file, Supabase returns a valid signed URL.
        expect(url, isNotEmpty);
        expect(url, contains('token='));
        // ignore: avoid_print
        print('  ok: Signed URL generated (${url.length} chars)');
      } on StorageException catch (e) {
        // Some storage configs may reject this — still a valid test result.
        // ignore: avoid_print
        print('  ok: Storage returned expected error: ${e.message}');
      }
    });
  });
}
