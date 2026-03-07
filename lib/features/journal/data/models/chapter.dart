class Chapter {
  final String id;
  final String userId;
  final String title;
  final int chapterNumber;
  final DateTime startDate;
  final DateTime? endDate;
  final int entryCount;
  final DateTime createdAt;

  const Chapter({
    required this.id,
    required this.userId,
    required this.title,
    required this.chapterNumber,
    required this.startDate,
    this.endDate,
    this.entryCount = 0,
    required this.createdAt,
  });

  Chapter copyWith({
    String? id,
    String? userId,
    String? title,
    int? chapterNumber,
    DateTime? startDate,
    DateTime? endDate,
    int? entryCount,
    DateTime? createdAt,
  }) {
    return Chapter(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      entryCount: entryCount ?? this.entryCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'chapter_number': chapterNumber,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'entry_count': entryCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      chapterNumber: (map['chapter_number'] as num).toInt(),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      entryCount: (map['entry_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  String toString() {
    return 'Chapter(id: $id, title: $title, chapterNumber: $chapterNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chapter && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
