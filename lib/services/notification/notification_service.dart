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
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
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
  // Weekly Recap & On This Day notifications
  // ---------------------------------------------------------------------------

  // Additional notification IDs
  static const _weeklyRecapId = 1003;
  static const _onThisDayId = 1004;
  static const _streakReminderId = 1005;

  /// Schedule a weekly recap notification every Sunday evening at 7pm.
  Future<void> scheduleWeeklyRecap({
    required String weekSummary,
    required int memoriesCount,
    required String topMood,
  }) async {
    _ensureInitialized();
    await _plugin.cancel(_weeklyRecapId);

    final body = memoriesCount > 0
        ? 'Your week: $memoriesCount memories, mostly feeling $topMood. Tap to see your reflection.'
        : 'Start capturing your week \u2014 your future self will thank you.';

    final now = tz.TZDateTime.now(tz.local);
    var sunday = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 0);
    while (sunday.weekday != DateTime.sunday || sunday.isBefore(now)) {
      sunday = sunday.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _weeklyRecapId,
      'Your Week in Review',
      body,
      sunday,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body, contentTitle: 'Your Week in Review'),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_recap',
    );

    debugPrint('[NotificationService] Weekly recap scheduled for Sunday 7pm.');
  }

  /// Shows an immediate "On This Day" notification for a past memory.
  Future<void> showOnThisDayNotification({
    required String entryExcerpt,
    required int yearsAgo,
  }) async {
    _ensureInitialized();

    final title = '$yearsAgo year${yearsAgo == 1 ? '' : 's'} ago today';
    final body = entryExcerpt.length > 100
        ? '${entryExcerpt.substring(0, 100)}...'
        : entryExcerpt;

    await _plugin.show(
      _onThisDayId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'on_this_day',
    );

    debugPrint('[NotificationService] On This Day: $yearsAgo years ago.');
  }

  /// Schedules a daily "On This Day" check at 8am.
  Future<void> scheduleOnThisDayCheck() async {
    _ensureInitialized();

    final scheduledTime = _nextInstanceOfTime(const TimeOfDay(hour: 8, minute: 0));

    await _plugin.zonedSchedule(
      _onThisDayId + 100,
      'A memory from your past',
      'You have memories from this day in previous years. Tap to revisit.',
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'on_this_day_check',
    );

    debugPrint('[NotificationService] On This Day check scheduled for 8am daily.');
  }

  /// Schedule streak-at-risk notification at 9pm.
  Future<void> scheduleStreakReminder({
    required int currentStreak,
  }) async {
    _ensureInitialized();
    await _plugin.cancel(_streakReminderId);

    if (currentStreak <= 0) return;

    final body = 'You have a $currentStreak day streak! Don\'t forget to journal today.';
    final scheduledTime = _nextInstanceOfTime(const TimeOfDay(hour: 21, minute: 0));

    await _plugin.zonedSchedule(
      _streakReminderId,
      'Keep your streak alive!',
      body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body, contentTitle: 'Keep your streak alive!'),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'streak_reminder_$currentStreak',
    );

    debugPrint('[NotificationService] Streak reminder scheduled for 9pm.');
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
