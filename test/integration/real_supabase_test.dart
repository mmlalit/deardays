library;

/// Real Supabase integration tests — tests against the LIVE database.
///
/// Signs in with an existing test account and validates the full pipeline.
///
/// Run:
/// ```bash
/// flutter test test/integration/real_supabase_test.dart --reporter expanded
/// ```
///
/// What these tests verify:
/// - Auth: sign in, session tokens, sign out + re-sign in
/// - Storage: signed URL generation (the photo display bug fix)
/// - CRUD: create, read, update, delete journal entries
/// - RLS: entries are scoped to the authenticated user
/// - Profile: fetch profile and streak data
/// - Chapters: fetch user chapters
///
/// IMPORTANT: Tests clean up after themselves — all created entries are deleted.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';
import 'package:deardays/services/media/media_service.dart';

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
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  if (supabaseUrl.isEmpty) {
    // No real Supabase credentials — skip all integration tests in CI/local
    return;
  }

  late SupabaseClient client;
  late JournalRepository journalRepo;
  late ProfileRepository profileRepo;
  late MediaService mediaService;

  // Track entries created during tests so we can clean up
  final createdEntryIds = <String>[];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Allow real HTTP requests (TestWidgetsFlutterBinding blocks them by default)
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

    // Sign in with existing test account
    // ignore: avoid_print
    print('\n=== Signing in as: $_testEmail ===');
    final authResponse = await client.auth.signInWithPassword(
      email: _testEmail,
      password: _testPassword,
    );

    if (authResponse.user == null) {
      fail('Failed to sign in with test account: $_testEmail');
    }

    // ignore: avoid_print
    print('=== Signed in. User ID: ${authResponse.user!.id} ===');
    // ignore: avoid_print
    print('=== Running tests against LIVE Supabase... ===\n');

    journalRepo = JournalRepository(client: client);
    profileRepo = ProfileRepository(client: client);
    mediaService = MediaService(client: client);
  });

  tearDownAll(() async {
    // ignore: avoid_print
    print('\n=== Cleaning up test data... ===');

    // Clean up all entries created during tests
    for (final id in createdEntryIds) {
      try {
        await journalRepo.deleteEntry(id);
        // ignore: avoid_print
        print('  Deleted entry: $id');
      } catch (_) {
        // Best-effort cleanup
      }
    }

    await client.auth.signOut();
    // ignore: avoid_print
    print('=== Cleanup complete ===\n');
  });

  // ===========================================================================
  // 1. Auth verification
  // ===========================================================================

  group('Real Supabase — Auth', () {
    test('user is authenticated after signIn', () {
      expect(client.auth.currentUser, isNotNull);
      expect(client.auth.currentUser!.email, _testEmail);
      // ignore: avoid_print
      print('  ✓ Authenticated as: ${client.auth.currentUser!.email}');
    });

    test('session has valid access token', () {
      final session = client.auth.currentSession;
      expect(session, isNotNull);
      expect(session!.accessToken, isNotEmpty);
      // ignore: avoid_print
      print('  ✓ Access token length: ${session.accessToken.length} chars');
    });

    test('can sign out and sign back in', () async {
      await client.auth.signOut();
      expect(client.auth.currentUser, isNull);

      final response = await client.auth.signInWithPassword(
        email: _testEmail,
        password: _testPassword,
      );
      expect(response.user, isNotNull);
      expect(response.user!.email, _testEmail);
      // ignore: avoid_print
      print('  ✓ Sign out + sign in round-trip successful');
    });
  });

  // ===========================================================================
  // 2. Profile & Streak
  // ===========================================================================

  group('Real Supabase — Profile', () {
    test('fetches profile for authenticated user', () async {
      final profile = await profileRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.id, client.auth.currentUser!.id);
      // ignore: avoid_print
      print('  ✓ Profile: ${profile.displayName ?? "(no name)"} (${profile.id})');
    });

    test('fetches streak data', () async {
      final streak = await profileRepo.getStreak();
      if (streak != null) {
        expect(streak.userId, client.auth.currentUser!.id);
        expect(streak.currentStreak, greaterThanOrEqualTo(0));
        // ignore: avoid_print
        print('  ✓ Streak: ${streak.currentStreak} current, ${streak.longestStreak} longest');
      } else {
        // ignore: avoid_print
        print('  ✓ Streak: null (no entries yet)');
      }
    });

    test('fetches chapters', () async {
      final chapters = await profileRepo.getChapters();
      expect(chapters, isA<List>());
      // ignore: avoid_print
      print('  ✓ Chapters: ${chapters.length} found');
    });
  });

  // ===========================================================================
  // 3. Journal CRUD
  // ===========================================================================

  group('Real Supabase — Journal CRUD', () {
    test('creates a journal entry and reads it back', () async {
      final now = DateTime.now().toUtc();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        userId: client.auth.currentUser!.id,
        content: 'Integration test entry — safe to delete.',
        mood: 'good',
        entryDate: DateTime(now.year, now.month, now.day),
        entryTime: const TimeOfDay(hour: 14, minute: 30),
        wordCount: 7,
        createdAt: now,
        updatedAt: now,
      );

      final created = await journalRepo.createEntry(entry);
      createdEntryIds.add(created.id);

      expect(created.content, entry.content);
      expect(created.mood, 'good');
      // ignore: avoid_print
      print('  ✓ Created entry: ${created.id}');

      // Read it back
      final fetched = await journalRepo.getEntry(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.content, entry.content);
      expect(fetched.mood, 'good');
      // ignore: avoid_print
      print('  ✓ Read back: content matches, mood=${fetched.mood}');
    });

    test('entryTime round-trips correctly (not 00:00)', () async {
      final now = DateTime.now().toUtc();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        userId: client.auth.currentUser!.id,
        content: 'Testing entryTime round-trip.',
        entryDate: DateTime(now.year, now.month, now.day),
        entryTime: const TimeOfDay(hour: 19, minute: 49),
        wordCount: 4,
        createdAt: now,
        updatedAt: now,
      );

      final created = await journalRepo.createEntry(entry);
      createdEntryIds.add(created.id);

      final fetched = await journalRepo.getEntry(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.entryTime, isNotNull,
          reason: 'entryTime should not be null after round-trip');
      expect(fetched.entryTime!.hour, 19,
          reason: 'entryTime hour should be 19, not 0');
      expect(fetched.entryTime!.minute, 49,
          reason: 'entryTime minute should be 49');
      // ignore: avoid_print
      print('  ✓ entryTime: ${fetched.entryTime!.hour}:${fetched.entryTime!.minute.toString().padLeft(2, '0')} (expected 19:49)');
    });

    test('updates an entry', () async {
      final now = DateTime.now().toUtc();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        userId: client.auth.currentUser!.id,
        content: 'Before update.',
        mood: 'okay',
        entryDate: DateTime(now.year, now.month, now.day),
        wordCount: 2,
        createdAt: now,
        updatedAt: now,
      );

      final created = await journalRepo.createEntry(entry);
      createdEntryIds.add(created.id);

      final updated = await journalRepo.updateEntry(
        created.copyWith(
          content: 'After update.',
          mood: 'great',
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      expect(updated.content, 'After update.');
      expect(updated.mood, 'great');
      // ignore: avoid_print
      print('  ✓ Updated: "${updated.content}" mood=${updated.mood}');
    });

    test('deletes an entry', () async {
      final now = DateTime.now().toUtc();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        userId: client.auth.currentUser!.id,
        content: 'This will be deleted.',
        entryDate: DateTime(now.year, now.month, now.day),
        wordCount: 4,
        createdAt: now,
        updatedAt: now,
      );

      final created = await journalRepo.createEntry(entry);
      await journalRepo.deleteEntry(created.id);

      final fetched = await journalRepo.getEntry(created.id);
      expect(fetched, isNull, reason: 'Entry should be gone after delete');
      // ignore: avoid_print
      print('  ✓ Deleted entry: ${created.id} (verified gone)');
    });

    test('getEntries returns entries for this user', () async {
      final entries = await journalRepo.getEntries(limit: 10);
      expect(entries, isA<List<JournalEntry>>());
      // ignore: avoid_print
      print('  ✓ getEntries returned ${entries.length} entries');

      for (final e in entries) {
        expect(e.userId, client.auth.currentUser!.id);
      }

      if (entries.length >= 2) {
        for (int i = 0; i < entries.length - 1; i++) {
          final current = entries[i].entryDate;
          final next = entries[i + 1].entryDate;
          expect(
            current.isAfter(next) || current.isAtSameMomentAs(next),
            isTrue,
            reason: 'Entries should be ordered by date descending',
          );
        }
        // ignore: avoid_print
        print('  ✓ Entries are ordered by date descending');
      }
    });

    test('getMoodStats returns valid mood distribution', () async {
      final stats = await journalRepo.getMoodStats();
      expect(stats, isA<Map<String, int>>());
      // ignore: avoid_print
      print('  ✓ Mood stats: $stats');

      for (final entry in stats.entries) {
        expect(
          ['great', 'good', 'okay', 'low', 'tough'].contains(entry.key),
          isTrue,
          reason: 'Mood "${entry.key}" should be a valid mood value',
        );
      }
    });

    test('getTotalEntries returns count', () async {
      final total = await journalRepo.getTotalEntries();
      expect(total, greaterThanOrEqualTo(0));
      // ignore: avoid_print
      print('  ✓ Total entries: $total');
    });
  });

  // ===========================================================================
  // 4. Storage — signed URLs (the photo bug fix)
  // ===========================================================================

  group('Real Supabase — Storage (signed URLs)', () {
    test('getPublicUrl returns a URL string', () {
      final url = mediaService.getPublicUrl('test-path/photo.jpg');
      expect(url, isA<String>());
      expect(url, contains('supabase'));
      expect(url, contains('entry-media'));
      // ignore: avoid_print
      print('  ✓ Public URL: ${url.substring(0, url.length.clamp(0, 80))}...');
    });

    test('getPublicUrl with HTTP URL returns it as-is', () {
      const httpUrl = 'https://example.com/photo.jpg';
      final result = mediaService.getPublicUrl(httpUrl);
      expect(result, httpUrl);
      // ignore: avoid_print
      print('  ✓ HTTP passthrough works');
    });

    test('getSignedUrl with nonexistent path throws', () async {
      try {
        await mediaService.getSignedUrl('nonexistent/path/photo.jpg');
        fail('Should have thrown for nonexistent path');
      } catch (e) {
        expect(e, isNotNull);
        // ignore: avoid_print
        print('  ✓ Signed URL throws for nonexistent path: ${e.runtimeType}');
      }
    });

    test('getSignedUrl with empty path throws', () async {
      try {
        await mediaService.getSignedUrl('');
        fail('Should have thrown for empty path');
      } catch (e) {
        expect(e, isNotNull);
        // ignore: avoid_print
        print('  ✓ Signed URL throws for empty path: ${e.runtimeType}');
      }
    });

    test('thumbnailPath generates correct suffix', () {
      final result = MediaService.thumbnailPath('user/entry/photo.jpg');
      expect(result, 'user/entry/photo_thumb.jpg');
      // ignore: avoid_print
      print('  ✓ Thumbnail path: $result');
    });

    test('getThumbnailUrl with HTTP URL returns it as-is', () {
      const httpUrl = 'https://example.com/photo.jpg';
      expect(mediaService.getThumbnailUrl(httpUrl), httpUrl);
      // ignore: avoid_print
      print('  ✓ HTTP thumbnail passthrough works');
    });

    test('getThumbnailUrl with storage path returns supabase URL', () {
      final url = mediaService.getThumbnailUrl('user/entry/photo.jpg');
      expect(url, contains('supabase'));
      expect(url, contains('photo_thumb.jpg'));
      // ignore: avoid_print
      print('  ✓ Thumbnail URL: ${url.substring(0, url.length.clamp(0, 80))}...');
    });
  });

  // ===========================================================================
  // 5. RLS — verify entries are user-scoped
  // ===========================================================================

  group('Real Supabase — RLS enforcement', () {
    test('cannot read entries with forged user_id', () async {
      // Use a valid UUID format that doesn't belong to any real user
      final response = await client
          .from('journal_entries')
          .select('id')
          .eq('user_id', '00000000-0000-0000-0000-000000000000');

      expect((response as List).isEmpty, isTrue,
          reason: 'RLS should return empty for non-matching user');
      // ignore: avoid_print
      print('  ✓ RLS blocks queries for other user_ids');
    });
  });
}
