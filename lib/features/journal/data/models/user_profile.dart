import 'package:deardays/core/constants/app_constants.dart';

class UserProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String encryptionSalt;
  final String writingStyle;
  final String? reminderTime;
  final bool biometricEnabled;
  final DateTime trialStartedAt;
  final bool isSubscribed;
  final String? subscriptionPlan;
  final DateTime? subscriptionExpiresAt;
  final String? revenuecatCustomerId;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    required this.encryptionSalt,
    this.writingStyle = 'memoir',
    this.reminderTime,
    this.biometricEnabled = false,
    required this.trialStartedAt,
    this.isSubscribed = false,
    this.subscriptionPlan,
    this.subscriptionExpiresAt,
    this.revenuecatCustomerId,
    required this.createdAt,
  });

  /// Whether the user is still within the free trial period.
  bool get isInTrial {
    final trialEnd = trialStartedAt.add(
      const Duration(days: AppConstants.freeTrialDays),
    );
    return DateTime.now().isBefore(trialEnd);
  }

  /// Whether the user has active access (subscribed or in trial).
  bool get hasAccess => isSubscribed || isInTrial;

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? encryptionSalt,
    String? writingStyle,
    String? reminderTime,
    bool? biometricEnabled,
    DateTime? trialStartedAt,
    bool? isSubscribed,
    String? subscriptionPlan,
    DateTime? subscriptionExpiresAt,
    String? revenuecatCustomerId,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      encryptionSalt: encryptionSalt ?? this.encryptionSalt,
      writingStyle: writingStyle ?? this.writingStyle,
      reminderTime: reminderTime ?? this.reminderTime,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      revenuecatCustomerId:
          revenuecatCustomerId ?? this.revenuecatCustomerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'encryption_salt': encryptionSalt,
      'writing_style': writingStyle,
      'reminder_time': reminderTime,
      'biometric_enabled': biometricEnabled,
      'trial_started_at': trialStartedAt.toIso8601String(),
      'is_subscribed': isSubscribed,
      'subscription_plan': subscriptionPlan,
      'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
      'revenuecat_customer_id': revenuecatCustomerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      encryptionSalt: map['encryption_salt'] as String,
      writingStyle: (map['writing_style'] as String?) ?? 'memoir',
      reminderTime: map['reminder_time'] as String?,
      biometricEnabled: (map['biometric_enabled'] as bool?) ?? false,
      trialStartedAt: DateTime.parse(map['trial_started_at'] as String),
      isSubscribed: (map['is_subscribed'] as bool?) ?? false,
      subscriptionPlan: map['subscription_plan'] as String?,
      subscriptionExpiresAt: map['subscription_expires_at'] != null
          ? DateTime.parse(map['subscription_expires_at'] as String)
          : null,
      revenuecatCustomerId: map['revenuecat_customer_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, displayName: $displayName, hasAccess: $hasAccess)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
