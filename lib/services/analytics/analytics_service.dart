import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Analytics service backed by PostHog for production event tracking.
///
/// Configure via dart-define:
/// ```bash
/// flutter run \
///   --dart-define=POSTHOG_API_KEY=phc_xxx \
///   --dart-define=POSTHOG_HOST=https://us.i.posthog.com
/// ```
///
/// When no API key is configured, events are logged locally only (debug mode).
class AnalyticsService {
  AnalyticsService._internal();

  static final AnalyticsService _instance = AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  factory AnalyticsService() => _instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  String? _userId;

  // In-memory event buffer (capped to prevent unbounded growth in long sessions).
  static const int _maxEvents = 10000;
  final List<TrackedEvent> _events = [];
  List<TrackedEvent> get events => List.unmodifiable(_events);

  // User properties (persistent across events)
  final Map<String, String> _userProperties = {};
  Map<String, String> get userProperties => Map.unmodifiable(_userProperties);

  // PostHog configuration (via dart-define)
  static const String _postHogApiKey = String.fromEnvironment(
    'POSTHOG_API_KEY',
    defaultValue: '',
  );

  static const String _postHogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  bool get isConfigured => _postHogApiKey.isNotEmpty;

  Posthog? _posthog;

  /// Initializes the analytics service and PostHog SDK.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (isConfigured && !kDebugMode) {
      final config = PostHogConfig(_postHogApiKey);
      config.host = _postHogHost;
      config.captureApplicationLifecycleEvents = true;
      config.debug = kDebugMode;
      await Posthog().setup(config);
      _posthog = Posthog();
    }

    debugPrint('[AnalyticsService] Initialized. PostHog: ${isConfigured ? "enabled" : "disabled (no key)"}');
  }

  /// Sets the current user for analytics attribution.
  void identify(String userId, {Map<String, String>? properties}) {
    _userId = userId;
    if (properties != null) {
      _userProperties.addAll(properties);
    }
    track(AnalyticsEvent.userIdentified, properties: {'user_id': userId});

    // Identify in PostHog
    _posthog?.identify(
      userId: userId,
      userProperties: properties,
    );
  }

  /// Clears user identity (e.g., on logout).
  void reset() {
    _userId = null;
    _userProperties.clear();
    track(AnalyticsEvent.userLoggedOut);
    _posthog?.reset();
  }

  /// Sets a user property that persists across all future events.
  void setUserProperty(String key, String value) {
    _userProperties[key] = value;
    _posthog?.identify(userId: _userId ?? 'anonymous', userPropertiesSetOnce: {key: value});
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
    // Evict oldest events if buffer exceeds cap
    if (_events.length > _maxEvents) {
      final evicted = _events.length - _maxEvents;
      _events.removeRange(0, evicted);
      debugPrint('[Analytics] Buffer full, evicted $evicted oldest events');
    }

    if (kDebugMode) {
      debugPrint(
        '[AnalyticsService] $eventName '
        '${properties?.isNotEmpty == true ? properties : ""}',
      );
    }

    // Send to PostHog
    _posthog?.capture(
      eventName: eventName,
      properties: properties,
    );
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
    _posthog?.screen(screenName: screenName);
  }

  /// Checks if a feature flag is enabled (PostHog feature flags).
  Future<bool> isFeatureEnabled(String flagKey) async {
    if (_posthog == null) return false;
    return await _posthog!.isFeatureEnabled(flagKey);
  }

  /// Gets a feature flag value (for multivariate flags).
  Future<dynamic> getFeatureFlagValue(String flagKey) async {
    if (_posthog == null) return null;
    return await _posthog!.getFeatureFlag(flagKey);
  }

  /// Reloads feature flags from PostHog.
  Future<void> reloadFeatureFlags() async {
    await _posthog?.reloadFeatureFlags();
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

  // Sync
  static const syncCompleted = 'sync_completed';
  static const syncFailed = 'sync_failed';
  static const conflictDetected = 'conflict_detected';
  static const conflictResolved = 'conflict_resolved';
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
