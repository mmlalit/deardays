import 'package:flutter/foundation.dart';

/// Lightweight analytics service for tracking user behavior and feature usage.
///
/// Events are logged locally in debug mode and can be forwarded to a backend
/// analytics endpoint (Firebase Analytics, Mixpanel, etc.) in production.
///
/// All events are typed via [AnalyticsEvent] constants to prevent typos
/// and ensure consistency across the codebase.
class AnalyticsService {
  AnalyticsService._internal();

  static final AnalyticsService _instance = AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  factory AnalyticsService() => _instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  String? _userId;

  // In-memory event buffer for the current session
  final List<TrackedEvent> _events = [];
  List<TrackedEvent> get events => List.unmodifiable(_events);

  // User properties (persistent across events)
  final Map<String, String> _userProperties = {};
  Map<String, String> get userProperties => Map.unmodifiable(_userProperties);

  // Backend endpoint for analytics (configured via dart-define)
  static const String _analyticsEndpoint = String.fromEnvironment(
    'ANALYTICS_URL',
    defaultValue: '',
  );

  bool get isConfigured => _analyticsEndpoint.isNotEmpty;

  /// Initializes the analytics service.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[AnalyticsService] Initialized.');
  }

  /// Sets the current user for analytics attribution.
  void identify(String userId, {Map<String, String>? properties}) {
    _userId = userId;
    if (properties != null) {
      _userProperties.addAll(properties);
    }
    track(AnalyticsEvent.userIdentified, properties: {'user_id': userId});
  }

  /// Clears user identity (e.g., on logout).
  void reset() {
    _userId = null;
    _userProperties.clear();
    track(AnalyticsEvent.userLoggedOut);
  }

  /// Sets a user property that persists across all future events.
  void setUserProperty(String key, String value) {
    _userProperties[key] = value;
  }

  /// Tracks a single event with optional properties.
  void track(String eventName, {Map<String, String>? properties}) {
    final event = TrackedEvent(
      name: eventName,
      userId: _userId,
      properties: {
        ...?properties,
        ..._userProperties,
      },
      timestamp: DateTime.now(),
    );

    _events.add(event);

    if (kDebugMode) {
      debugPrint(
        '[AnalyticsService] $eventName '
        '${properties?.isNotEmpty == true ? properties : ""}',
      );
    }

    // In production with a configured endpoint, this would batch and POST events.
  }

  /// Tracks the start of a timed event. Call [endTimedEvent] to record duration.
  void startTimedEvent(String eventName) {
    _timedEvents[eventName] = DateTime.now();
  }

  /// Ends a timed event and tracks it with the elapsed duration.
  void endTimedEvent(String eventName, {Map<String, String>? properties}) {
    final start = _timedEvents.remove(eventName);
    if (start == null) return;

    final duration = DateTime.now().difference(start);
    track(eventName, properties: {
      ...?properties,
      'duration_ms': duration.inMilliseconds.toString(),
    });
  }

  final Map<String, DateTime> _timedEvents = {};

  /// Tracks a screen view.
  void trackScreen(String screenName) {
    track(AnalyticsEvent.screenView, properties: {'screen': screenName});
  }

  /// Clears all stored events.
  void clear() {
    _events.clear();
    _timedEvents.clear();
  }
}

/// Pre-defined analytics event names to ensure consistency.
abstract class AnalyticsEvent {
  // Auth
  static const userIdentified = 'user_identified';
  static const userLoggedOut = 'user_logged_out';
  static const userSignedUp = 'user_signed_up';
  static const userLoggedIn = 'user_logged_in';
  static const trialStarted = 'trial_started';

  // Entry creation
  static const entryCreated = 'entry_created';
  static const voiceRecorded = 'voice_recorded';
  static const textEntryStarted = 'text_entry_started';
  static const checkInCompleted = 'checkin_completed';
  static const entryEdited = 'entry_edited';
  static const entryDeleted = 'entry_deleted';

  // AI
  static const aiPolishUsed = 'ai_polish_used';
  static const aiMoodDetected = 'ai_mood_detected';
  static const aiHighlightExtracted = 'ai_highlight_extracted';
  static const aiTitleGenerated = 'ai_title_generated';

  // Book
  static const bookGenerated = 'book_generated';
  static const bookExported = 'book_exported';
  static const bookViewed = 'book_viewed';

  // Share
  static const shareCardCreated = 'share_card_created';
  static const shareCardShared = 'share_card_shared';

  // Engagement
  static const streakMilestone = 'streak_milestone';
  static const onThisDayViewed = 'on_this_day_viewed';
  static const searchPerformed = 'search_performed';
  static const weeklyReportViewed = 'weekly_report_viewed';

  // Subscription
  static const subscriptionViewed = 'subscription_viewed';
  static const subscriptionStarted = 'subscription_started';
  static const paywallShown = 'paywall_shown';
  static const paywallDismissed = 'paywall_dismissed';
  static const paywallConverted = 'paywall_converted';

  // Navigation
  static const screenView = 'screen_view';

  // Backup
  static const backupStarted = 'backup_started';
  static const backupCompleted = 'backup_completed';
  static const restoreStarted = 'restore_started';
  static const restoreCompleted = 'restore_completed';
}

/// A single tracked analytics event.
class TrackedEvent {
  final String name;
  final String? userId;
  final Map<String, String> properties;
  final DateTime timestamp;

  const TrackedEvent({
    required this.name,
    this.userId,
    this.properties = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'user_id': userId,
        'properties': properties,
        'timestamp': timestamp.toIso8601String(),
      };
}
