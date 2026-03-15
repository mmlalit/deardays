/// RevenueCat configuration for DearDays.
///
/// API keys are injected at build time via `--dart-define` flags:
///
/// ```bash
/// flutter run \
///   --dart-define=REVENUECAT_APPLE_KEY=appl_xxxxx \
///   --dart-define=REVENUECAT_GOOGLE_KEY=goog_xxxxx
/// ```
///
/// You can find your API keys in the RevenueCat dashboard:
/// https://app.revenuecat.com → Project → API Keys
class RevenueCatConfig {
  RevenueCatConfig._();

  /// RevenueCat Apple (iOS/macOS) API key.
  static const String appleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_KEY',
    defaultValue: '',
  );

  /// RevenueCat Google (Android) API key.
  static const String googleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_KEY',
    defaultValue: '',
  );

  // ---------------------------------------------------------------------------
  // Entitlement & Product IDs
  // ---------------------------------------------------------------------------
  // These must match what you configure in:
  //   1. RevenueCat dashboard → Entitlements
  //   2. App Store Connect → Subscriptions
  //   3. Google Play Console → Subscriptions
  // ---------------------------------------------------------------------------

  /// The entitlement identifier that gates premium access.
  static const String entitlementId = 'DearDays Pro';

  /// Product identifier for the monthly subscription.
  static const String monthlyProductId = 'monthly';

  /// Product identifier for the yearly subscription.
  static const String yearlyProductId = 'yearly';
}
