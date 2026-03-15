import 'package:uuid/uuid.dart';

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
  final DateTime? lastRetryAt;

  /// Unique key for this sync operation. The server uses this to deduplicate
  /// retries — if the same idempotencyKey is sent twice, the second is a no-op.
  final String idempotencyKey;

  const SyncOperation({
    required this.id,
    required this.type,
    required this.tableName,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.lastRetryAt,
    required this.idempotencyKey,
  });

  /// Creates a new SyncOperation with an auto-generated idempotency key.
  factory SyncOperation.create({
    required String id,
    required SyncOperationType type,
    required String tableName,
    required Map<String, dynamic> payload,
  }) {
    return SyncOperation(
      id: id,
      type: type,
      tableName: tableName,
      payload: payload,
      createdAt: DateTime.now(),
      idempotencyKey: const Uuid().v4(),
    );
  }

  SyncOperation copyWith({
    int? retryCount,
    String? lastError,
    DateTime? lastRetryAt,
  }) {
    return SyncOperation(
      id: id,
      type: type,
      tableName: tableName,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      idempotencyKey: idempotencyKey,
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
        'lastRetryAt': lastRetryAt?.toIso8601String(),
        'idempotencyKey': idempotencyKey,
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
      lastRetryAt: json['lastRetryAt'] != null
          ? DateTime.parse(json['lastRetryAt'] as String)
          : null,
      idempotencyKey: json['idempotencyKey'] as String? ?? const Uuid().v4(),
    );
  }
}
