class Streak {
  final String id;
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastEntryDate;
  final int totalEntries;

  const Streak({
    required this.id,
    required this.userId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastEntryDate,
    this.totalEntries = 0,
  });

  Streak copyWith({
    String? id,
    String? userId,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastEntryDate,
    int? totalEntries,
  }) {
    return Streak(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastEntryDate: lastEntryDate ?? this.lastEntryDate,
      totalEntries: totalEntries ?? this.totalEntries,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_entry_date': lastEntryDate?.toIso8601String(),
      'total_entries': totalEntries,
    };
  }

  factory Streak.fromMap(Map<String, dynamic> map) {
    return Streak(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longest_streak'] as num?)?.toInt() ?? 0,
      lastEntryDate: map['last_entry_date'] != null
          ? DateTime.parse(map['last_entry_date'] as String)
          : null,
      totalEntries: (map['total_entries'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return 'Streak(userId: $userId, current: $currentStreak, longest: $longestStreak)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Streak && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
