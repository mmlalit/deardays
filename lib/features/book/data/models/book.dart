class Book {
  final String id;
  final String userId;
  final String title;
  final String coverColor;
  final String writingStyle;
  final DateTime startDate;
  final DateTime? endDate;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Book({
    required this.id,
    required this.userId,
    required this.title,
    this.coverColor = '#6B4EFF',
    this.writingStyle = 'memoir',
    required this.startDate,
    this.endDate,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Book copyWith({
    String? id,
    String? userId,
    String? title,
    String? coverColor,
    String? writingStyle,
    DateTime? startDate,
    DateTime? endDate,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      coverColor: coverColor ?? this.coverColor,
      writingStyle: writingStyle ?? this.writingStyle,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'cover_color': coverColor,
      'writing_style': writingStyle,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      coverColor: (map['cover_color'] as String?) ?? '#6B4EFF',
      writingStyle: (map['writing_style'] as String?) ?? 'memoir',
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() => 'Book(id: $id, title: $title)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
