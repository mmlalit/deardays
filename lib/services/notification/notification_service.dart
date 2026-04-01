import 'dart:io';

import 'package:go_router/go_router.dart';

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

  // Stores a pending navigation payload until the navigator is ready.
  String? _pendingPayload;

  // Optional navigator key for deep-link navigation from notification taps.
  // Set via [setNavigatorKey] after the app's MaterialApp is built.
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Register the app's navigator key so notification taps can navigate.
  /// TODO: Ensure setNavigatorKey is called after MaterialApp is built
  /// (e.g. in AppShell.initState or via a GlobalKey passed from main.dart).
  /// Without this, notification taps that arrive before the navigator is ready
  /// will be queued in [_pendingPayload] but never delivered if the key is
  /// never set.
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    // Process any payload that arrived before the navigator was ready.
    if (_pendingPayload != null) {
      _navigateForPayload(_pendingPayload!);
      _pendingPayload = null;
    }
  }

  /// Handles notification tap — deep-links to the relevant screen.
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('[NotificationService] Tapped: $payload');
    if (payload == null) return;
    if (_navigatorKey?.currentContext == null) {
      // Navigator not ready yet — store and process when setNavigatorKey is called.
      _pendingPayload = payload;
      return;
    }
    _navigateForPayload(payload);
  }

  void _navigateForPayload(String payload) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;
    try {
      // Use go_router for deep-link navigation.
      // ignore: use_build_context_synchronously
      final route = switch (payload) {
        'checkin'             => '/checkin',
        'timeline'            => '/timeline',
        'weekly_recap'        => '/story?period=weekly',
        'story_ready_weekly'  => '/story?period=weekly',
        'story_ready_monthly' => '/story?period=monthly',
        'story_ready_yearly'  => '/story?period=yearly',
        final s when s.startsWith('streak') => '/home',
        _                     => '/home', // Unknown payload — home
      };
      // ignore: use_build_context_synchronously
      GoRouter.of(ctx).push(route);
    } catch (e) {
      debugPrint('[NotificationService] Deep-link navigation failed: $e');
    }
  }

  /// Processes any notification that launched the app (cold start).
  Future<void> processInitialNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (response != null && response.payload != null) {
      debugPrint('[NotificationService] App launched via notification: ${response.payload}');
      _pendingPayload = response.payload;
    }
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
  static const _writingPromptId = 1006;
  static const _storyReadyId = 1007;

  // Guard: show On This Day at most once per app session per day.
  DateTime? _onThisDayShownDate;

  // ── Writing prompts ────────────────────────────────────────────────────────

  static const _writingPrompts = [
    'What surprised you today?',
    'Who made you smile this week?',
    'What are you avoiding thinking about?',
    '3 words for today — go.',
    'What did you learn today?',
    'What do you wish you had said?',
    'Describe today in one colour.',
    'What small thing went right today?',
    'What would your future self want to remember?',
    'What made you feel alive recently?',
    'What are you grateful for right now?',
    'What is weighing on you?',
    'Describe a moment from today in detail.',
    'What conversation is still on your mind?',
    'What do you keep putting off?',
    'If today were a chapter title, what would it be?',
    'What are you looking forward to?',
    'What would you do differently today?',
    'Who influenced you this week without knowing it?',
    'What does "enough" look like for you right now?',
    'What emotion is loudest today?',
    'Write about a door you opened — or closed — recently.',
    'What have you been too hard on yourself about?',
    'What are you proud of that nobody knows?',
    'What is something simple that made today better?',
    'Describe the last time you felt truly present.',
    'What are you afraid to write down?',
    'What does your body need right now?',
    'One thing you want to remember from this week.',
    'What would you tell a friend who felt exactly like you do today?',
  ];

  static const _moodEmoji = {
    'happy':     '😊',
    'joy':       '😄',
    'grateful':  '🙏',
    'gratitude': '🙏',
    'love':      '❤️',
    'excited':   '🎉',
    'calm':      '😌',
    'peaceful':  '🌿',
    'neutral':   '😐',
    'tired':     '😴',
    'anxious':   '😰',
    'sad':       '😔',
    'angry':     '😤',
    'stressed':  '😫',
  };

  static String _emojiFor(String? mood) =>
      mood == null ? '' : (_moodEmoji[mood.toLowerCase()] ?? '');

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static String _monthName(int month) =>
      (month >= 1 && month <= 12) ? _months[month] : 'This month';

  /// Schedule a weekly recap notification every Sunday evening at 7pm.
  Future<void> scheduleWeeklyRecap({
    required String weekSummary,
    required int memoriesCount,
    required String topMood,
  }) async {
    _ensureInitialized();
    await _plugin.cancel(_weeklyRecapId);

    const title = '📔 How was your week?';
    final body = memoriesCount > 0
        ? 'You captured $memoriesCount memories this week — mostly ${_emojiFor(topMood)} $topMood. Tap to see your weekly reflection.'
        : 'This week is still a blank page. A few words now will mean the world to future you.';

    final now = tz.TZDateTime.now(tz.local);
    var sunday = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 0);
    while (sunday.weekday != DateTime.sunday || sunday.isBefore(now)) {
      sunday = sunday.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _weeklyRecapId,
      title,
      body,
      sunday,
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

  // ── Story notifications ─────────────────────────────────────────────────

  static const int _dailyStoryId = 4001;
  static const int _weeklyStoryId = 4002;
  static const int _monthlyStoryId = 4003;
  static const int _yearlyStoryId = 4004;
  static const int _noEntryReminderId = 4005;

  /// Show notification when daily story is generated.
  Future<void> showDailyStoryNotification({
    List<String> highlights = const [],
  }) async {
    _ensureInitialized();

    const title = 'Your day\'s story is ready 📖';
    final body = highlights.isNotEmpty
        ? highlights.take(2).join(' · ')
        : 'Tap to read your day as a narrative.';

    await _plugin.show(
      _dailyStoryId, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high, priority: Priority.high,
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'story_daily',
    );
  }

  /// Show notification when weekly story is generated.
  Future<void> showWeeklyStoryNotification() async {
    _ensureInitialized();
    await _plugin.show(
      _weeklyStoryId,
      'Your week in review is ready ✨',
      'See your weekly story with highlights and mood.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'story_weekly',
    );
  }

  /// Show notification when monthly story is generated.
  Future<void> showMonthlyStoryNotification(String monthName) async {
    _ensureInitialized();
    await _plugin.show(
      _monthlyStoryId,
      'Your $monthName story is ready 📚',
      'Read your month as a narrative.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'story_monthly',
    );
  }

  /// Show notification when yearly story is generated.
  Future<void> showYearlyStoryNotification(int year) async {
    _ensureInitialized();
    await _plugin.show(
      _yearlyStoryId,
      'Your $year story is ready 🎉',
      'Read your year in review.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'story_yearly',
    );
  }

  /// Schedule a "still time to capture today" reminder at 9 PM.
  Future<void> scheduleNoEntryReminder() async {
    _ensureInitialized();
    await _plugin.cancel(_noEntryReminderId);

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 21, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _noEntryReminderId,
      'Still time to capture today 💭',
      'Your day has a story worth saving.',
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'no_entry_reminder',
    );
  }

  /// Cancel the no-entry reminder (called when user saves a memory today).
  Future<void> cancelNoEntryReminder() async {
    await _plugin.cancel(_noEntryReminderId);
  }

  /// Schedules a rotating daily writing prompt at [time].
  ///
  /// Uses day-of-year modulo the prompt bank so the prompt is deterministic
  /// for a given date (same day always picks same prompt).
  Future<void> scheduleWritingPrompt(TimeOfDay time) async {
    _ensureInitialized();
    await _plugin.cancel(_writingPromptId);

    final dayOfYear = _dayOfYear(DateTime.now());
    final prompt = _writingPrompts[dayOfYear % _writingPrompts.length];

    final scheduledTime = _nextInstanceOfTime(time);

    await _plugin.zonedSchedule(
      _writingPromptId,
      '✍️ Today\'s prompt',
      prompt,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(prompt, contentTitle: '✍️ Today\'s prompt'),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'writing_prompt',
    );

    debugPrint('[NotificationService] Writing prompt scheduled: "$prompt"');
  }

  /// Shows an immediate notification when a story is ready.
  ///
  /// [period] is "weekly", "monthly", or "yearly".
  /// [entryCount] is how many entries were used.
  /// [topMood] optional dominant mood — adds an emoji to the body.
  /// [periodDate] optional date used to personalise the title (e.g. "March", "2025").
  Future<void> showStoryReadyNotification({
    required String period,
    required int entryCount,
    String? topMood,
    DateTime? periodDate,
  }) async {
    _ensureInitialized();

    final moodClause = topMood != null && topMood.isNotEmpty
        ? ' — mostly ${_emojiFor(topMood)} $topMood'
        : '';

    final String title;
    final String body;

    switch (period) {
      case 'weekly':
        title = '📖 This week\'s story is ready';
        body = entryCount > 0
            ? '$entryCount memories, woven into one story$moodClause. See how your week reads.'
            : 'Your weekly reflection is ready to read.';
      case 'monthly':
        final monthName = periodDate != null
            ? _monthName(periodDate.month)
            : 'This month';
        title = '📚 Your $monthName chapter is written';
        body = entryCount > 0
            ? '$entryCount entries from $monthName — your chapter is written. Tap to read it.'
            : 'Your $monthName story is ready to read.';
      case 'yearly':
        final year = periodDate?.year.toString() ?? 'This year';
        title = '✨ Your $year year in review';
        body = entryCount > 0
            ? '$entryCount memories across $year. A whole year of your life, in your own words.'
            : 'Your year in review is ready to read.';
      default:
        title = '📖 Your story is ready';
        body = 'Tap to read your reflection.';
    }

    await _plugin.show(
      _storyReadyId,
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
      payload: 'story_ready_$period',
    );

    debugPrint('[NotificationService] Story ready notification: $period ($entryCount entries)');
  }

  /// Shows the On This Day notification with a real entry excerpt.
  /// Guards against showing more than once per calendar day.
  Future<void> maybeShowOnThisDay({
    required String entryExcerpt,
    required int yearsAgo,
  }) async {
    final today = DateTime.now();
    if (_onThisDayShownDate != null &&
        _onThisDayShownDate!.year == today.year &&
        _onThisDayShownDate!.month == today.month &&
        _onThisDayShownDate!.day == today.day) {
      return; // already shown today
    }
    _onThisDayShownDate = today;
    await showOnThisDayNotification(
      entryExcerpt: entryExcerpt,
      yearsAgo: yearsAgo,
    );
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
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

  /// Cancels the daily writing prompt notification.
  Future<void> cancelWritingPrompt() async {
    _ensureInitialized();
    await _plugin.cancel(_writingPromptId);
  }

  /// Cancels any pending streak-at-risk reminder (call after entry saved).
  Future<void> cancelStreakReminder() async {
    _ensureInitialized();
    await _plugin.cancel(_streakReminderId);
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

  static int _dayOfYear(DateTime date) =>
      date.difference(DateTime(date.year, 1, 1)).inDays;

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'NotificationService has not been initialized. Call init() first.',
      );
    }
  }
}
