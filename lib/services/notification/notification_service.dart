import 'package:flutter/material.dart';

/// Placeholder notification service for daily journaling reminders and streak
/// celebrations.
///
/// Actual push / local notification setup will be added once
/// `flutter_local_notifications` is integrated.
class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  /// Singleton accessor.
  static NotificationService get instance => _instance;

  factory NotificationService() => _instance;

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes the notification subsystem.
  ///
  // TODO: Initialize flutter_local_notifications plugin here.
  //  - Create Android notification channel.
  //  - Request iOS provisional / alert permissions.
  Future<void> init() async {
    if (_initialized) return;

    // Placeholder — no-op until flutter_local_notifications is added.
    _initialized = true;
    debugPrint('[NotificationService] Initialized (placeholder).');
  }

  // ---------------------------------------------------------------------------
  // Daily reminder
  // ---------------------------------------------------------------------------

  /// Schedules a repeating daily reminder at the given [time].
  ///
  // TODO: Implement with flutter_local_notifications:
  //  - Use `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time`
  //    to fire every day at the specified time.
  //  - Notification title: "Time to journal"
  //  - Notification body: "Take a moment to capture today's thoughts."
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    _ensureInitialized();

    // Placeholder — log the intent.
    debugPrint(
      '[NotificationService] Daily reminder scheduled for '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')} (placeholder).',
    );
  }

  /// Cancels any previously scheduled daily reminder.
  ///
  // TODO: Cancel the notification via its fixed ID once the plugin is wired up.
  Future<void> cancelReminder() async {
    _ensureInitialized();

    // Placeholder — log the intent.
    debugPrint('[NotificationService] Daily reminder cancelled (placeholder).');
  }

  // ---------------------------------------------------------------------------
  // Streak notification
  // ---------------------------------------------------------------------------

  /// Shows a celebratory notification when the user hits a journaling [streak].
  ///
  // TODO: Show an immediate local notification:
  //  - Title: "Streak milestone!"
  //  - Body: "You've journaled $streak days in a row. Keep it up!"
  Future<void> showStreakNotification(int streak) async {
    _ensureInitialized();

    // Placeholder — log the intent.
    debugPrint(
      '[NotificationService] Streak notification for $streak days (placeholder).',
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'NotificationService has not been initialized. Call init() first.',
      );
    }
  }
}
