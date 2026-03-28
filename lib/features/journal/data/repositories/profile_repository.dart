import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/core/domain/repositories/profile_repository_interface.dart';

class ProfileRepository implements IProfileRepository {
  final SupabaseClient _client;

  ProfileRepository({required SupabaseClient client}) : _client = client;

  /// Returns the current user ID, throwing if the user is not authenticated.
  String get _requireUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No authenticated user');
    return id;
  }

  /// Fetches the current user's profile.
  Future<UserProfile?> getProfile() async {
    final userId = _requireUserId;
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;

    return UserProfile.fromMap(response);
  }

  /// Updates the current user's profile and returns the updated version.
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final userId = _requireUserId;
    final map = profile.toMap();
    // Remove fields that should not be overwritten by the client.
    map.remove('created_at');

    final response = await _client
        .from('profiles')
        .update(map)
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromMap(response);
  }

  /// Fetches the current user's streak data.
  Future<Streak?> getStreak() async {
    final userId = _requireUserId;
    final response = await _client
        .from('streaks')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;

    return Streak.fromMap(response);
  }

  /// Fetches all chapters for the current user once (ordered by chapter number).
  /// Used for mutations (create/update) and one-off reads.
  Future<List<Chapter>> getChapters() async {
    final userId = _requireUserId;
    final response = await _client
        .from('chapters')
        .select('*, journal_entries(count)')
        .eq('user_id', userId)
        .order('chapter_number', ascending: true);

    return (response as List<dynamic>)
        .map((row) => Chapter.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Real-time stream of the current user's chapters, ordered by chapter number.
  /// Automatically pushes updates when chapters are added, edited, or deleted.
  /// This is the primary source used by [chaptersProvider].
  Stream<List<Chapter>> watchChapters() {
    final userId = _requireUserId;
    return _client
        .from('chapters')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('chapter_number')
        .map((rows) => rows.map(Chapter.fromMap).toList());
  }

  /// Creates a new chapter with the next available chapter_number.
  /// Retries once on duplicate chapter_number conflict (race condition).
  Future<Chapter> createChapter(String title, {int retryCount = 0}) async {
    final userId = _requireUserId;
    // Fetch only the max chapter_number — avoids loading all chapters + entries counts.
    final maxRow = await _client
        .from('chapters')
        .select('chapter_number')
        .eq('user_id', userId)
        .order('chapter_number', ascending: false)
        .limit(1)
        .maybeSingle();
    final nextNumber = (maxRow?['chapter_number'] as int? ?? 0) + 1;

    final now = DateTime.now().toUtc();
    try {
      final response = await _client
          .from('chapters')
          .insert({
            'user_id': userId,
            'title': title,
            'chapter_number': nextNumber,
            'start_date': now.toIso8601String().split('T').first,
            'entry_count': 0,
          })
          .select()
          .single();

      return Chapter.fromMap(response);
    } on PostgrestException catch (e) {
      // Retry on unique constraint violation (duplicate chapter_number from race).
      if (retryCount < 2 && (e.code == '23505' || e.message.contains('duplicate'))) {
        return createChapter(title, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  /// Updates a chapter's title and/or color.
  Future<Chapter> updateChapter(String chapterId, {String? title, int? colorValue}) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (colorValue != null) updates['color'] = colorValue;
    if (updates.isEmpty) throw ArgumentError('Nothing to update');

    final response = await _client
        .from('chapters')
        .update(updates)
        .eq('id', chapterId)
        .eq('user_id', _requireUserId)
        .select('*, journal_entries(count)')
        .single();

    return Chapter.fromMap(response);
  }

  /// Deletes a chapter by id. Does NOT delete its entries — they remain with chapter_id still set.
  Future<void> deleteChapter(String chapterId) async {
    await _client.from('chapters').delete().eq('id', chapterId).eq('user_id', _requireUserId);
  }

  /// Seeds default chapters (defined in Supabase RPC) if user has none.
  /// Returns existing or newly seeded chapters.
  Future<List<Chapter>> seedDefaultChapters() async {
    final existing = await getChapters();
    if (existing.isNotEmpty) return existing;

    final userId = _requireUserId;
    await _client.rpc('seed_default_chapters', params: {'p_user_id': userId});

    return getChapters();
  }
}
