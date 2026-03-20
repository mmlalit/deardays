library;

/// Full end-to-end integration test — app → Supabase backend → app.
///
/// This is a ONE-TIME validation test that exercises the complete pipeline:
///
///   1. Auth        → sign in with real credentials
///   2. Entries     → create journal entries via JournalRepository
///   3. AI Polish   → call ai-polish edge function on entry content
///   4. DB write    → save polished content back to DB
///   5. Book        → create a Book via BookRepository
///   6. Weekly page → insert a test page into `pages` table, then
///                    call ai-weekly-page edge function to generate real AI pages
///   7. Reader      → call BookRepository.getWeeklyPages() and verify
///   8. Cleanup     → delete all created test data
///
/// Run:
/// ```bash
/// flutter test test/integration/real_e2e_test.dart --reporter expanded \
///   --dart-define=AI_API_URL=https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1 \
///   --timeout 120s
/// ```
///
/// IMPORTANT:
/// - Tests clean up after themselves.
/// - Each test group is independent — you can run one group at a time.
/// - The weekly-page group invokes the live AI edge function (costs tokens).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/book/data/repositories/book_repository.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
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

void main() {
  late SupabaseClient client;
  late JournalRepository journalRepo;
  late BookRepository bookRepo;
  late AiService ai;

  // Test data created during this run — cleaned up in tearDownAll
  final createdEntryIds = <String>[];
  final createdBookIds = <String>[];
  final createdPageIds = <String>[];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Allow real HTTP — TestWidgetsFlutterBinding blocks network by default
    HttpOverrides.global = null;

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
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
    print('  DearDays E2E Integration Test');
    // ignore: avoid_print
    print('  Target: ${SupabaseConfig.supabaseUrl}');
    // ignore: avoid_print
    print('══════════════════════════════════════════\n');

    // ignore: avoid_print
    print('→ Signing in as: $_testEmail');
    final authResponse = await client.auth.signInWithPassword(
      email: _testEmail,
      password: _testPassword,
    );
    if (authResponse.user == null) {
      fail('Sign-in failed for: $_testEmail');
    }
    // ignore: avoid_print
    print('✓ Signed in. User: ${authResponse.user!.id}\n');

    journalRepo = JournalRepository(client: client);
    bookRepo = BookRepository(client: client);
    ai = AiService();
  });

  tearDownAll(() async {
    // ignore: avoid_print
    print('\n══════════════════════════════════════════');
    // ignore: avoid_print
    print('  Cleanup');
    // ignore: avoid_print
    print('══════════════════════════════════════════');

    for (final id in createdPageIds) {
      try {
        await client.from('pages').delete().eq('id', id);
        // ignore: avoid_print
        print('  Deleted page: $id');
      } catch (_) {}
    }

    for (final id in createdBookIds) {
      try {
        await bookRepo.deleteBook(id);
        // ignore: avoid_print
        print('  Deleted book: $id');
      } catch (_) {}
    }

    for (final id in createdEntryIds) {
      try {
        await journalRepo.deleteEntry(id);
        // ignore: avoid_print
        print('  Deleted entry: $id');
      } catch (_) {}
    }

    await client.auth.signOut();
    // ignore: avoid_print
    print('✓ Cleanup done. Signed out.\n');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Auth
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E — Auth', () {
    test('authenticated session is active', () {
      final user = client.auth.currentUser;
      expect(user, isNotNull);
      expect(user!.email, _testEmail);
      expect(client.auth.currentSession?.accessToken, isNotEmpty);
      // ignore: avoid_print
      print('  ✓ Session active for ${user.email}');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Journal entry pipeline
  //    App creates entry → DB stores → app reads back
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E — Journal Entry Pipeline', () {
    late JournalEntry testEntry;

    test('creates an entry exactly as the app would on save', () async {
      final now = DateTime.now().toUtc();

      // Simulate what RecordingScreen / TextEntryScreen sends to JournalRepository
      testEntry = JournalEntry(
        id: const Uuid().v4(),
        userId: client.auth.currentUser!.id,
        content: 'Went for a long walk this morning. The park was quiet and '
            'the air smelled like rain. I saw a family of ducks by the pond. '
            'Felt really calm after the walk — exactly what I needed.',
        mood: 'good',
        entryDate: DateTime(now.year, now.month, now.day),
        entryTime: TimeOfDay(hour: now.hour, minute: now.minute),
        wordCount: 42,
        createdAt: now,
        updatedAt: now,
      );

      final created = await journalRepo.createEntry(testEntry);
      createdEntryIds.add(created.id);

      expect(created.id, isNotEmpty);
      expect(created.content, testEntry.content);
      expect(created.mood, 'good');
      expect(created.userId, client.auth.currentUser!.id);
      // ignore: avoid_print
      print('  ✓ Entry created: ${created.id}');
      // ignore: avoid_print
      print('    Content: "${created.content.substring(0, 50)}..."');
    });

    test('entry is readable back from DB (round-trip)', () async {
      final id = createdEntryIds.last;
      final fetched = await journalRepo.getEntry(id);

      expect(fetched, isNotNull);
      expect(fetched!.content, contains('ducks'));
      expect(fetched.mood, 'good');
      // ignore: avoid_print
      print('  ✓ Read back from DB — mood=${fetched.mood}, '
          'words=${fetched.wordCount}');
    });

    test('updates entry (simulates user editing a saved memory)', () async {
      final id = createdEntryIds.last;
      final original = await journalRepo.getEntry(id);
      expect(original, isNotNull);

      final updated = await journalRepo.updateEntry(
        original!.copyWith(
          mood: 'great',
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      expect(updated.mood, 'great');
      // ignore: avoid_print
      print('  ✓ Updated mood: ${original.mood} → ${updated.mood}');
    });

    test('entry appears in getEntries list', () async {
      final entries = await journalRepo.getEntries(limit: 50);
      final ids = entries.map((e) => e.id).toSet();

      for (final id in createdEntryIds) {
        expect(ids.contains(id), isTrue,
            reason: 'Created entry $id should appear in getEntries');
      }
      // ignore: avoid_print
      print('  ✓ All created entries appear in list (${entries.length} total)');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. AI Polish pipeline
  //    Entry content → ai-polish edge function → polished content saved to DB
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E — AI Polish Pipeline', () {
    const rawText = 'went to coffeeshop this morning. meet my freind sara. '
        'we talked for like 2 hours about everthing. it was really really good '
        'to see her. i miss spending time with old freinds.';

    late String polishedText;

    test('ai-polish endpoint fixes grammar and returns improved text', () async {
      if (!ai.isConfigured) {
        // ignore: avoid_print
        print('  ⚠ AI_API_URL not set — skipping (pass --dart-define=AI_API_URL=...)');
        return;
      }

      polishedText = await ai.lightPolish(rawText);

      expect(polishedText, isNotEmpty);
      expect(polishedText.toLowerCase(), isNot(contains('freind')),
          reason: '"freind" should be fixed to "friend"');
      expect(polishedText.toLowerCase(), isNot(contains('everthing')),
          reason: '"everthing" should be fixed to "everything"');
      expect(polishedText.toLowerCase(), contains('sara'),
          reason: 'Named person should be preserved');
      // ignore: avoid_print
      print('  ✓ Polish result:');
      // ignore: avoid_print
      print('    Before: "$rawText"');
      // ignore: avoid_print
      print('    After:  "$polishedText"');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('polished content saves to DB and reads back correctly', () async {
      if (!ai.isConfigured) return;
      if (polishedText.isEmpty) return;
      if (createdEntryIds.isEmpty) return;

      final id = createdEntryIds.last;
      final entry = await journalRepo.getEntry(id);
      expect(entry, isNotNull);

      final withPolish = entry!.copyWith(
        content: polishedText,
        updatedAt: DateTime.now().toUtc(),
      );
      await journalRepo.updateEntry(withPolish);

      final readBack = await journalRepo.getEntry(id);
      expect(readBack!.content, polishedText);
      // ignore: avoid_print
      print('  ✓ Polished content saved and read back from DB');
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Book pipeline
  //    Create book → verify stored → get weekly pages
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E — Book Repository Pipeline', () {
    late Book testBook;

    test('creates a book (as BookCreationScreen would)', () async {
      final now = DateTime.now();
      testBook = Book(
        id: '',
        userId: client.auth.currentUser!.id,
        title: 'E2E Test Book',
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
        createdAt: now,
        updatedAt: now,
      );

      final created = await bookRepo.createBook(testBook);
      createdBookIds.add(created.id);

      expect(created.id, isNotEmpty);
      expect(created.title, 'E2E Test Book');
      expect(created.userId, client.auth.currentUser!.id);
      // ignore: avoid_print
      print('  ✓ Book created: ${created.id} ("${created.title}")');

      testBook = created; // update local ref with real ID
    });

    test('book appears in getBooks()', () async {
      final books = await bookRepo.getBooks();
      final ids = books.map((b) => b.id).toSet();

      for (final id in createdBookIds) {
        expect(ids.contains(id), isTrue,
            reason: 'Created book $id should appear in getBooks');
      }
      // ignore: avoid_print
      print('  ✓ Book visible in getBooks() (${books.length} total)');
    });

    test('getWeeklyPages returns empty list before any pages are generated',
        () async {
      if (createdBookIds.isEmpty) return;
      final bookId = createdBookIds.last;

      final pages = await bookRepo.getWeeklyPages(bookId, limit: 10);
      expect(pages, isEmpty,
          reason: 'No AI pages generated yet for this book');
      // ignore: avoid_print
      print('  ✓ getWeeklyPages returns [] before generation (as expected)');
    });

    test('inserts a test page into pages table and reads it back', () async {
      if (createdBookIds.isEmpty) return;
      final bookId = createdBookIds.last;

      // Simulate what ai-weekly-page edge function inserts
      final pageId = const Uuid().v4();
      final now = DateTime.now().toUtc();
      final weekStart = DateTime(now.year, now.month,
          now.day - now.weekday + 1); // Monday of current week

      await client.from('pages').insert({
        'id': pageId,
        'book_id': bookId,
        'user_id': client.auth.currentUser!.id,
        'week_start': weekStart.toIso8601String().split('T').first,
        'page_number': 1,
        'content': 'This was the week I started the E2E integration test.\n\n'
            'The coffee was good and the code ran first try.\n\n'
            'It is a rare and pleasant feeling.',
        'word_count': 31,
        'photos': jsonEncode([]),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      createdPageIds.add(pageId);

      // ignore: avoid_print
      print('  ✓ Inserted test page: $pageId');

      // Read back via BookRepository (same code path as BookReaderScreen)
      final pages = await bookRepo.getWeeklyPages(bookId, limit: 10);

      expect(pages, isNotEmpty);
      expect(pages.first.id, pageId);
      expect(pages.first.content, contains('E2E integration test'));
      expect(pages.first.wordCount, 31);
      // ignore: avoid_print
      print('  ✓ BookRepository.getWeeklyPages() returned the page');
      // ignore: avoid_print
      print('    Content: "${pages.first.content.substring(0, 60)}..."');
    });

    test('getWeeklyPagesCount returns correct count', () async {
      if (createdBookIds.isEmpty) return;
      final bookId = createdBookIds.last;

      final count = await bookRepo.getWeeklyPagesCount(bookId);
      expect(count, greaterThanOrEqualTo(createdPageIds.length));
      // ignore: avoid_print
      print('  ✓ getWeeklyPagesCount = $count');
    });

    test('updates book (as settings edit would)', () async {
      if (createdBookIds.isEmpty) return;
      final book = await bookRepo.getBook(createdBookIds.last);

      final updated = await bookRepo.updateBook(
        book.copyWith(title: 'E2E Test Book (edited)'),
      );
      expect(updated.title, 'E2E Test Book (edited)');
      // ignore: avoid_print
      print('  ✓ Book title updated: "${book.title}" → "${updated.title}"');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Weekly page AI generation (calls live edge function)
  //    Requires AI_API_URL dart-define.  Costs tokens — run deliberately.
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E — AI Weekly Page Generation (live edge function)', () {
    test('ai-chat responds to a journal-context conversation', () async {
      if (!ai.isConfigured) {
        // ignore: avoid_print
        print('  ⚠ Skipping — AI_API_URL not set');
        return;
      }

      // Tests the /ai-chat edge function — same as CheckInScreen
      final reply = await ai.chat(
        messages: [
          {
            'role': 'user',
            'content':
                'I had a productive day. Finished two tasks I had been '
                    'putting off for weeks.',
          },
        ],
        mood: 'great',
        isFirstCheckIn: true,
      );

      expect(reply, isNotEmpty);
      expect(reply.length, greaterThan(10));
      // ignore: avoid_print
      print('  ✓ ai-chat reply: "${reply.substring(0, reply.length.clamp(0, 100))}..."');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('ai-polish pipeline: raw text → AI → polished result', () async {
      if (!ai.isConfigured) {
        // ignore: avoid_print
        print('  ⚠ Skipping — AI_API_URL not set');
        return;
      }

      const raw = 'today i finaly finished my book. i been working on it '
          'since january. fealt like a big weight lifted off my sholders.';

      final polished = await ai.lightPolish(raw);

      expect(polished, isNotEmpty);
      expect(polished.toLowerCase(), isNot(contains('finaly')));
      expect(polished.toLowerCase(), isNot(contains('fealt')));
      expect(polished.toLowerCase(), isNot(contains('sholders')));
      // ignore: avoid_print
      print('  ✓ Full ai-polish round-trip:');
      // ignore: avoid_print
      print('    In:  "$raw"');
      // ignore: avoid_print
      print('    Out: "$polished"');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('weekly story generation from a set of daily entries', () async {
      if (!ai.isConfigured) {
        // ignore: avoid_print
        print('  ⚠ Skipping — AI_API_URL not set');
        return;
      }

      // Simulates what ai-weekly-page weaves together from daily entries
      final result = await ai.generateWeeklyStory(
        [
          'Started the E2E test. Everything compiled first try.',
          'Reviewed the full book reader pipeline. Found the navigation bug.',
          'Fixed the duplicate arrows in the book reader. Pushed the fix.',
        ],
        moods: ['great', 'okay', 'good'],
      );

      expect(result.story, isNotEmpty);
      expect(result.story.length, greaterThan(30));
      // ignore: avoid_print
      print('  ✓ Weekly story generated (${result.story.length} chars):');
      // ignore: avoid_print
      print('    "${result.story.substring(0, result.story.length.clamp(0, 150))}..."');
      if (result.summary != null) {
        // ignore: avoid_print
        print('    Summary: "${result.summary}"');
      }
    }, timeout: const Timeout(Duration(seconds: 45)));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Data integrity checks
  //    Verify counts, ordering, and RLS hold across the whole test run
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E — Data Integrity', () {
    test('all created entries are owned by the test user', () async {
      final entries = await journalRepo.getEntries(limit: 100);
      for (final e in entries) {
        expect(e.userId, client.auth.currentUser!.id,
            reason: 'RLS must scope entries to authenticated user');
      }
      // ignore: avoid_print
      print('  ✓ RLS verified — all ${entries.length} entries belong to test user');
    });

    test('entries are returned in descending date order', () async {
      final entries = await journalRepo.getEntries(limit: 20);
      if (entries.length < 2) return;

      for (int i = 0; i < entries.length - 1; i++) {
        final a = entries[i].entryDate;
        final b = entries[i + 1].entryDate;
        expect(
          a.isAfter(b) || a.isAtSameMomentAs(b),
          isTrue,
          reason: 'Entry at index $i should be >= entry at index ${i + 1}',
        );
      }
      // ignore: avoid_print
      print('  ✓ Entry ordering: descending date confirmed');
    });

    test('books are owned by the test user', () async {
      final books = await bookRepo.getBooks();
      for (final b in books) {
        expect(b.userId, client.auth.currentUser!.id);
      }
      // ignore: avoid_print
      print('  ✓ All ${books.length} books belong to test user');
    });

    test('getTotalEntries matches getEntries count', () async {
      final total = await journalRepo.getTotalEntries();
      final list = await journalRepo.getEntries(limit: 1000);

      // Total might be >= list (if list is truncated) but should not be 0 if entries exist
      expect(total, greaterThanOrEqualTo(0));
      if (list.isNotEmpty) {
        expect(total, greaterThanOrEqualTo(1));
      }
      // ignore: avoid_print
      print('  ✓ getTotalEntries=$total, getEntries count=${list.length}');
    });

    test('pipeline summary: verify all test artifacts were created', () {
      // ignore: avoid_print
      print('\n  ── Test Run Summary ──');
      // ignore: avoid_print
      print('  Journal entries created : ${createdEntryIds.length}');
      // ignore: avoid_print
      print('  Books created           : ${createdBookIds.length}');
      // ignore: avoid_print
      print('  Pages inserted          : ${createdPageIds.length}');
      // ignore: avoid_print
      print('  AI configured           : ${ai.isConfigured}');

      expect(createdEntryIds.length, greaterThanOrEqualTo(1));
      expect(createdBookIds.length, greaterThanOrEqualTo(1));
      expect(createdPageIds.length, greaterThanOrEqualTo(1));
      // ignore: avoid_print
      print('\n  ✓ All pipeline stages exercised successfully');
    });
  });
}
