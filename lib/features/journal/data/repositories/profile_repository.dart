import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository({required SupabaseClient client}) : _client = client;

  String get _userId => _client.auth.currentUser!.id;

  /// Fetches the current user's profile.
  Future<UserProfile?> getProfile() async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();

    if (response == null) return null;

    return UserProfile.fromMap(response);
  }

  /// Updates the current user's profile and returns the updated version.
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final map = profile.toMap();
    // Remove fields that should not be overwritten by the client.
    map.remove('created_at');

    final response = await _client
        .from('profiles')
        .update(map)
        .eq('id', _userId)
        .select()
        .single();

    return UserProfile.fromMap(response);
  }

  /// Fetches the current user's streak data.
  Future<Streak?> getStreak() async {
    final response = await _client
        .from('streaks')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) return null;

    return Streak.fromMap(response);
  }

  /// Fetches all chapters for the current user, ordered by chapter number.
  Future<List<Chapter>> getChapters() async {
    final response = await _client
        .from('chapters')
        .select()
        .eq('user_id', _userId)
        .order('chapter_number', ascending: true);

    return (response as List<dynamic>)
        .map((row) => Chapter.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new chapter with the next available chapter_number.
  Future<Chapter> createChapter(String title) async {
    // Get the current max chapter_number
    final existing = await getChapters();
    final nextNumber = existing.isEmpty
        ? 1
        : existing.map((c) => c.chapterNumber).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now().toUtc();
    final response = await _client
        .from('chapters')
        .insert({
          'user_id': _userId,
          'title': title,
          'chapter_number': nextNumber,
          'start_date': now.toIso8601String().split('T').first,
          'entry_count': 0,
        })
        .select()
        .single();

    return Chapter.fromMap(response);
  }

  /// Seeds 4 default chapters if user has none. Returns existing or new chapters.
  Future<List<Chapter>> seedDefaultChapters() async {
    final existing = await getChapters();
    if (existing.isNotEmpty) return existing;

    // Call the RPC which inserts defaults only if user has 0 chapters
    await _client.rpc('seed_default_chapters', params: {'p_user_id': _userId});

    return getChapters();
  }
}
