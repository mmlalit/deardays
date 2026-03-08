import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Handles local push notifications for daily journaling reminders
/// and streak celebration alerts.
///
/// Notification content matches the DearDays brand:
///   Title: "How was your day?"
///   Body:  "Tap to capture today's chapter."
///   Streak badge is included in the body when streak > 1.
class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  /// Singleton accessor.
  static NotificationService get instance => _instance;

  factory NotificationService() => _instance;

  bool _initialized = false;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Fixed notification IDs
  static const _dailyReminderId = 1001;
  static const _streakId = 1002;

  // Android notification channel
  static const _channelId = 'deardays_daily';
  static const _channelName = 'Daily Reminder';
  static const _channelDesc = 'Daily journaling reminder from DearDays';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes the notification plugin, creates channels, and requests
  /// permissions on iOS/Android 13+.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone data for scheduled notifications
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
        // Request notification permission on Android 13+
        await androidPlugin.requestNotificationsPermission();
      }
    }

    _initialized = true;
    debugPrint('[NotificationService] Initialized.');
  }

  /// Handles notification tap — navigates to the app's check-in screen.
  void _onNotificationTapped(NotificationResponse response) {
    // The app will already open; GoRouter handles initial routing.
    // A deep-link payload could be added here later if needed.
    debugPrint('[NotificationService] Tapped: ${response.payload}');
  }

  // ---------------------------------------------------------------------------
  // Daily reminder
  // ---------------------------------------------------------------------------

  /// Schedules a repeating daily reminder at the given [time].
  ///
  /// Notification matches the mockup:
  ///   Title: "How was your day?"
  ///   Body:  "Tap to capture today's chapter."
  ///
  /// If [streak] > 1, appends the streak count to the body.
  Future<void> scheduleDailyReminder(
    TimeOfDay time, {
    int streak = 0,
  }) async {
    _ensureInitialized();

    // Cancel any existing reminder first
    await _plugin.cancel(_dailyReminderId);

    final body = streak > 1
        ? '🔥 $streak day streak! Tap to capture today\'s chapter.'
        : 'Tap to capture today\'s chapter.';

    final scheduledTime = _nextInstanceOfTime(time);

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'How was your day?',
      body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: 'How was your day?',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );

    debugPrint(
      '[NotificationService] Daily reminder scheduled for '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}',
    );
  }

  /// Cancels any previously scheduled daily reminder.
  Future<void> cancelReminder() async {
    _ensureInitialized();
    await _plugin.cancel(_dailyReminderId);
    debugPrint('[NotificationService] Daily reminder cancelled.');
  }

  // ---------------------------------------------------------------------------
  // Streak notification
  // ---------------------------------------------------------------------------

  /// Shows an immediate celebratory notification for a streak milestone.
  ///
  /// Called after saving a journal entry when the streak is notable
  /// (e.g. 3, 7, 14, 30, 50, 100, 365 days).
  Future<void> showStreakNotification(int streak) async {
    _ensureInitialized();

    final title = _streakTitle(streak);
    final body = _streakBody(streak);

    await _plugin.show(
      _streakId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'streak_$streak',
    );

    debugPrint('[NotificationService] Streak notification for $streak days.');
  }

  /// Returns true if [streak] is a milestone worth celebrating.
  static bool isStreakMilestone(int streak) {
    return const {3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365}
        .contains(streak);
  }

  String _streakTitle(int streak) {
    if (streak >= 365) return '🎉 One year of journaling!';
    if (streak >= 100) return '🏆 $streak day streak!';
    if (streak >= 30) return '🔥 $streak days in a row!';
    if (streak >= 7) return '⭐ $streak day streak!';
    return '✨ $streak day streak!';
  }

  String _streakBody(int streak) {
    if (streak >= 365) {
      return 'You\'ve journaled every day for a year. Your future self will treasure this.';
    }
    if (streak >= 100) {
      return 'Triple digits! Your dedication to writing is remarkable.';
    }
    if (streak >= 30) {
      return 'A full month of daily journaling. You\'re building something beautiful.';
    }
    if (streak >= 7) {
      return 'A whole week! Your story is growing, one day at a time.';
    }
    return 'You\'re on a roll! Keep capturing your story.';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the next occurrence of the given time as a TZDateTime.
  /// If the time has already passed today, it returns tomorrow's instance.
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'NotificationService has not been initialized. Call init() first.',
      );
    }
  }
}
