/// Represents a pending write operation to be replayed when online.
enum SyncOperationType { create, update, delete }

class SyncOperation {
  final String id;
  final SyncOperationType type;
  final String tableName;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const SyncOperation({
    required this.id,
    required this.type,
    required this.tableName,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  SyncOperation copyWith({
    int? retryCount,
    String? lastError,
  }) {
    return SyncOperation(
      id: id,
      type: type,
      tableName: tableName,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'tableName': tableName,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastError': lastError,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      type: SyncOperationType.values.byName(json['type'] as String),
      tableName: json['tableName'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}
