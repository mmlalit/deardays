import 'package:supabase_flutter/supabase_flutter.dart';

/// Cached AI reflection for one user + period + period_key.
class ReflectionCacheEntry {
  final String? summary;
  final List<String> themes;
  final DateTime generatedAt;

  const ReflectionCacheEntry({
    required this.summary,
    required this.themes,
    required this.generatedAt,
  });

  factory ReflectionCacheEntry.fromMap(Map<String, dynamic> map) {
    return ReflectionCacheEntry(
      summary: map['summary'] as String?,
      themes: (map['themes'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      generatedAt: DateTime.parse(map['generated_at'] as String),
    );
  }
}

/// Reads and writes the `reflection_cache` table.
///
/// Hierarchy:
///   weekly  — summarises raw entry texts
///   monthly — summarises the 4 weekly summaries from that month
///   yearly  — summarises the 12 monthly summaries from that year
class ReflectionCacheRepository {
  final SupabaseClient _client;
  static const _table = 'reflection_cache';

  ReflectionCacheRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // ── Period key helpers ──────────────────────────────────────────────────────

  /// ISO week key: '2026-W11'
  static String weeklyKey(DateTime date) {
    final weekNum = _isoWeekNumber(date);
    return '${date.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  /// Monthly key: '2026-03'
  static String monthlyKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Yearly key: '2026'
  static String yearlyKey(DateTime date) => date.year.toString();

  /// Returns the 4 weekly period_keys that fall within [year]-[month].
  static List<String> weekKeysForMonth(int year, int month) {
    final keys = <String>{};
    final daysInMonth = DateTimeHelper.daysInMonth(year, month);
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      keys.add(weeklyKey(date));
    }
    return keys.toList();
  }

  /// Returns the 12 monthly period_keys for [year].
  static List<String> monthKeysForYear(int year) {
    return List.generate(
      12,
      (i) => '$year-${(i + 1).toString().padLeft(2, '0')}',
    );
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  /// Returns a cached entry or null if none exists for this period + key.
  Future<ReflectionCacheEntry?> get({
    required String period,
    required String periodKey,
  }) async {
    final rows = await _client
        .from(_table)
        .select('summary, themes, generated_at')
        .eq('user_id', _userId)
        .eq('period', period)
        .eq('period_key', periodKey)
        .limit(1);

    if (rows.isEmpty) return null;
    return ReflectionCacheEntry.fromMap(rows.first);
  }

  /// Upserts a cache entry for the given period + key.
  Future<void> save({
    required String period,
    required String periodKey,
    String? summary,
    List<String> themes = const [],
  }) async {
    await _client.from(_table).upsert(
      {
        'user_id': _userId,
        'period': period,
        'period_key': periodKey,
        'summary': summary,
        'themes': themes,
        'generated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id, period, period_key',
    );
  }

  /// Fetches all cached weekly summaries for the given month.
  /// Used to build monthly summaries from weekly ones.
  Future<List<String>> getWeeklySummariesForMonth(int year, int month) async {
    final keys = weekKeysForMonth(year, month);
    if (keys.isEmpty) return [];

    final rows = await _client
        .from(_table)
        .select('summary')
        .eq('user_id', _userId)
        .eq('period', 'weekly')
        .inFilter('period_key', keys);

    return rows
        .map((r) => r['summary'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Fetches all cached monthly summaries for the given year.
  /// Used to build the yearly summary from monthly ones.
  Future<List<String>> getMonthlySummariesForYear(int year) async {
    final keys = monthKeysForYear(year);

    final rows = await _client
        .from(_table)
        .select('summary')
        .eq('user_id', _userId)
        .eq('period', 'monthly')
        .inFilter('period_key', keys);

    return rows
        .map((r) => r['summary'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ── ISO week number ─────────────────────────────────────────────────────────

  static int _isoWeekNumber(DateTime date) {
    // ISO 8601: week starts on Monday, week 1 contains the first Thursday.
    final thursday =
        date.add(Duration(days: DateTime.thursday - date.weekday));
    final firstDayOfYear = DateTime(thursday.year, 1, 1);
    final daysDiff = thursday.difference(firstDayOfYear).inDays;
    return 1 + (daysDiff / 7).floor();
  }
}

class DateTimeHelper {
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
