import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/analytics/analytics_service.dart';

/// Feature flag system with remote kill switches and gradual rollout support.
///
/// Architecture:
/// 1. **PostHog flags** (primary): managed via PostHog dashboard, supports
///    A/B testing and percentage rollouts. Used when PostHog is configured.
/// 2. **Supabase remote config** (fallback): a simple key-value table
///    in Supabase for kill switches when PostHog is not configured.
/// 3. **Hardcoded defaults**: safe defaults when both are unavailable (offline).
///
/// Usage:
/// ```dart
/// if (await FeatureFlags().isEnabled(Feature.aiStreaming)) {
///   // Use streaming AI
/// }
/// ```
class FeatureFlags {
  FeatureFlags._internal();
  static final FeatureFlags _instance = FeatureFlags._internal();
  factory FeatureFlags() => _instance;

  bool _initialized = false;
  Timer? _refreshTimer;

  /// Local cache of flag values (refreshed periodically).
  final Map<String, bool> _cache = {};

  /// How often to refresh flags from the server.
  static const _refreshInterval = Duration(minutes: 30);

  /// Initialize and fetch initial flag values.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await refresh();

    // Refresh periodically
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());

    if (kDebugMode) {
      debugPrint('[FeatureFlags] Initialized. Flags: $_cache');
    }
  }

  /// Check if a feature is enabled.
  Future<bool> isEnabled(Feature feature) async {
    // Check PostHog first (supports A/B testing)
    final analytics = AnalyticsService();
    if (analytics.isConfigured) {
      try {
        return await analytics.isFeatureEnabled(feature.key);
      } catch (_) {
        // Fall through to local cache
      }
    }

    // Fall back to cached value or default
    return _cache[feature.key] ?? feature.defaultValue;
  }

  /// Synchronous check using cached value only (no network call).
  /// Use this in build methods where async isn't possible.
  bool isEnabledSync(Feature feature) {
    return _cache[feature.key] ?? feature.defaultValue;
  }

  /// Refresh all flags from the server.
  Future<void> refresh() async {
    // Try PostHog feature flags
    final analytics = AnalyticsService();
    if (analytics.isConfigured) {
      try {
        await analytics.reloadFeatureFlags();
        for (final feature in Feature.values) {
          _cache[feature.key] = await analytics.isFeatureEnabled(feature.key);
        }
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[FeatureFlags] PostHog refresh failed: $e');
        }
      }
    }

    // Fallback: fetch from Supabase remote_config table
    try {
      final response = await Supabase.instance.client
          .from('remote_config')
          .select('key, value')
          .eq('platform', 'flutter');

      for (final row in response as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final key = map['key'] as String;
        final value = map['value'] as String;
        _cache[key] = value == 'true' || value == '1';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeatureFlags] Supabase fallback refresh failed: $e');
      }
      // Keep existing cache values — offline is fine
    }
  }

  /// Force-set a flag locally (for testing/debugging).
  @visibleForTesting
  void override(Feature feature, bool value) {
    _cache[feature.key] = value;
  }

  void dispose() {
    _refreshTimer?.cancel();
  }
}

/// All feature flags used in the app.
///
/// Add new features here. Set [defaultValue] to `false` for new/risky features
/// (disabled by default, enabled via remote config after testing).
/// Set to `true` for established features that may need a kill switch.
enum Feature {
  /// AI response streaming (word-by-word display).
  aiStreaming('ai_streaming', defaultValue: false),

  /// AI-powered check-in conversations.
  aiCheckIn('ai_checkin', defaultValue: true),

  /// AI polish on journal entries.
  aiPolish('ai_polish', defaultValue: true),

  /// Book/chapter generation.
  bookGeneration('book_generation', defaultValue: true),

  /// Voice recording and transcription.
  voiceRecording('voice_recording', defaultValue: true),

  /// Share card generation.
  shareCards('share_cards', defaultValue: true),

  /// Weekly AI summary/reflection.
  weeklySummary('weekly_summary', defaultValue: true),

  /// On This Day feature.
  onThisDay('on_this_day', defaultValue: true),

  /// New onboarding flow (A/B test).
  newOnboarding('new_onboarding', defaultValue: false),

  /// Paywall v2 (A/B test).
  paywallV2('paywall_v2', defaultValue: false);

  final String key;
  final bool defaultValue;

  const Feature(this.key, {required this.defaultValue});
}
