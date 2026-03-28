import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';

/// Contract for user profile and chapter data access.
///
/// Implementations: [ProfileRepository] (Supabase), test mocks.
abstract class IProfileRepository {
  Future<UserProfile?> getProfile();

  Future<UserProfile> updateProfile(UserProfile profile);

  Future<Streak?> getStreak();

  Future<List<Chapter>> getChapters();

  Stream<List<Chapter>> watchChapters();

  Future<Chapter> createChapter(String title, {int retryCount = 0});

  Future<Chapter> updateChapter(String chapterId, {String? title, int? colorValue});

  Future<void> deleteChapter(String chapterId);

  Future<List<Chapter>> seedDefaultChapters();
}
