import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/services/analytics/analytics_service.dart';

/// Smart paywall trigger that shows the paywall at optimal moments.
///
/// Trigger points (configurable):
/// 1. After creating 2nd entry (user has experienced value)
/// 2. After viewing AI-polished version for first time
/// 3. After 3rd day of use (engagement established)
/// 4. When trying to export/share (feature gate)
///
/// Rules:
/// - Never show paywall within 24h of a previous dismissal
/// - Never show paywall during first entry creation
/// - Max 1 paywall per session
class PaywallTrigger {
  PaywallTrigger._internal();

  static final PaywallTrigger _instance = PaywallTrigger._internal();

  factory PaywallTrigger() => _instance;

  bool _shownThisSession = false;

  /// Checks if the paywall should be shown after entry creation.
  ///
  /// Shows after the 2nd entry (first entry is free to build trust).
  Future<bool> shouldShowAfterEntry(int totalEntries) async {
    if (_shownThisSession) return false;
    if (totalEntries < 2) return false;
    if (await _wasRecentlyDismissed()) return false;
    return true;
  }

  /// Checks if the paywall should be shown for a gated feature.
  ///
  /// Features like export, AI polish (after trial), advanced sharing.
  Future<bool> shouldShowForFeature(String featureName) async {
    if (_shownThisSession) return false;
    if (await _wasRecentlyDismissed()) return false;

    AnalyticsService().track(AnalyticsEvent.paywallShown, properties: {
      'trigger': 'feature_gate',
      'feature': featureName,
    });

    return true;
  }

  /// Shows the paywall screen and tracks the outcome.
  Future<bool> showPaywall(BuildContext context, {String? trigger}) async {
    if (_shownThisSession) return false;

    _shownThisSession = true;

    AnalyticsService().track(AnalyticsEvent.paywallShown, properties: {
      if (trigger != null) 'trigger': trigger,
    });

    final result = await context.push<bool>('/paywall');
    final converted = result == true;

    if (converted) {
      AnalyticsService().track(AnalyticsEvent.paywallConverted, properties: {
        if (trigger != null) 'trigger': trigger,
      });
    } else {
      AnalyticsService().track(AnalyticsEvent.paywallDismissed, properties: {
        if (trigger != null) 'trigger': trigger,
      });
      await _recordDismissal();
    }

    return converted;
  }

  /// Checks if the paywall was dismissed within the last 24 hours.
  Future<bool> _wasRecentlyDismissed() async {
    try {
      final box = await Hive.openBox('paywall');
      final lastDismissed = box.get('last_dismissed') as int?;
      if (lastDismissed == null) return false;

      final dismissedAt =
          DateTime.fromMillisecondsSinceEpoch(lastDismissed);
      return DateTime.now().difference(dismissedAt).inHours < 24;
    } catch (_) {
      return false;
    }
  }

  /// Records the current time as the last paywall dismissal.
  Future<void> _recordDismissal() async {
    try {
      final box = await Hive.openBox('paywall');
      await box.put(
          'last_dismissed', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Ignore storage errors
    }
  }

  /// Resets session state (call on app restart).
  void resetSession() {
    _shownThisSession = false;
  }
}
