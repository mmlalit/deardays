import 'package:deardays/features/journal/data/models/user_profile.dart';

/// Centralized feature gating for DearDays subscription tiers.
///
/// Free tier:
///   - 3 memories per day
///   - 1 photo per memory
///   - Grammar fix on every memory
///   - Basic mood tracking + timeline
///   - 3 shares per month
///
/// Storyteller (paid):
///   - Unlimited memories per day
///   - Daily/Weekly/Monthly/Yearly story pages
///   - Unlimited photos per memory
///   - PDF book export
///   - E2E encryption
///   - Unlimited sharing
///   - Story notifications
class SubscriptionGates {
  SubscriptionGates._();

  static const int freeMemoriesPerDay = 3;
  static const int freePhotosPerMemory = 1;
  static const int freeSharesPerMonth = 3;
  static const int paidMemoriesPerDay = 999; // effectively unlimited
  static const int paidPhotosPerMemory = 10;

  /// Whether the user can access story pages (daily/weekly/monthly/yearly).
  static bool canAccessStories(UserProfile? profile) =>
      profile?.hasAccess() ?? false;

  /// Whether the user can export to PDF.
  static bool canExportPdf(UserProfile? profile) =>
      profile?.hasAccess() ?? false;

  /// Whether the user can enable E2E encryption.
  static bool canUseEncryption(UserProfile? profile) =>
      profile?.hasAccess() ?? false;

  /// Maximum memories per day for this user.
  static int maxMemoriesPerDay(UserProfile? profile) =>
      (profile?.hasAccess() ?? false) ? paidMemoriesPerDay : freeMemoriesPerDay;

  /// Maximum photos per memory for this user.
  static int maxPhotosPerMemory(UserProfile? profile) =>
      (profile?.hasAccess() ?? false) ? paidPhotosPerMemory : freePhotosPerMemory;

  /// Maximum shares per month for this user.
  static int maxSharesPerMonth(UserProfile? profile) =>
      (profile?.hasAccess() ?? false) ? 999 : freeSharesPerMonth;
}
