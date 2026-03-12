import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/config/revenuecat_config.dart';

/// Wraps the RevenueCat SDK for in-app subscription management.
///
/// Responsibilities:
///   - Initialise RevenueCat with the correct platform API key
///   - Link the RevenueCat customer to the Supabase user ID
///   - Fetch available packages (monthly / yearly)
///   - Execute purchases and restores
///   - Query current entitlement status
class RevenueCatService {
  bool _isConfigured = false;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Call once at app startup (after Supabase init).
  ///
  /// Sets the RevenueCat API key for the current platform and, if the user is
  /// already authenticated, identifies them so purchase history syncs.
  Future<void> init() async {
    if (_isConfigured) return;

    // Web and Desktop are not supported by RevenueCat.
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;

    final apiKey = Platform.isIOS || Platform.isMacOS
        ? RevenueCatConfig.appleApiKey
        : RevenueCatConfig.googleApiKey;

    if (apiKey.isEmpty) {
      debugPrint('[RevenueCat] No API key configured — skipping init.');
      return;
    }

    final configuration = PurchasesConfiguration(apiKey);

    // If the user is already signed in, set their Supabase UID as the
    // RevenueCat app user ID so purchases are linked to the right account.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      configuration.appUserID = userId;
    }

    await Purchases.configure(configuration);
    _isConfigured = true;

    debugPrint('[RevenueCat] Configured for ${Platform.operatingSystem}');
  }

  /// Whether RevenueCat has been configured (false on web or if no key).
  bool get isConfigured => _isConfigured;

  // ---------------------------------------------------------------------------
  // User identification
  // ---------------------------------------------------------------------------

  /// Links the current RevenueCat anonymous user to the Supabase user ID.
  /// Call this right after the user signs in or signs up.
  Future<void> login(String supabaseUserId) async {
    if (!_isConfigured) return;
    await Purchases.logIn(supabaseUserId);
  }

  /// Resets the RevenueCat user to anonymous. Call on sign-out.
  Future<void> logout() async {
    if (!_isConfigured) return;
    await Purchases.logOut();
  }

  // ---------------------------------------------------------------------------
  // Offerings / Packages
  // ---------------------------------------------------------------------------

  /// Returns the current offerings from RevenueCat.
  /// Each offering contains packages (monthly, yearly, etc.).
  Future<Offerings> getOfferings() async {
    return await Purchases.getOfferings();
  }

  /// Convenience: returns the monthly [Package] from the default offering,
  /// or `null` if not available.
  Future<Package?> getMonthlyPackage() async {
    final offerings = await getOfferings();
    return offerings.current?.monthly;
  }

  /// Convenience: returns the annual [Package] from the default offering,
  /// or `null` if not available.
  Future<Package?> getAnnualPackage() async {
    final offerings = await getOfferings();
    return offerings.current?.annual;
  }

  // ---------------------------------------------------------------------------
  // Purchases
  // ---------------------------------------------------------------------------

  /// Initiates the purchase flow for a given [package].
  /// Returns the updated [CustomerInfo] after purchase.
  ///
  /// Throws [PlatformException] if the user cancels or if there is a store error.
  Future<CustomerInfo> purchasePackage(Package package) async {
    final result = await Purchases.purchasePackage(package);
    return result;
  }

  /// Restores previous purchases (useful when the user reinstalls or
  /// switches devices).
  Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }

  // ---------------------------------------------------------------------------
  // Entitlement checks
  // ---------------------------------------------------------------------------

  /// Returns the current [CustomerInfo] which contains entitlement data.
  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  /// Whether the user currently has an active "premium" entitlement.
  Future<bool> isPremium() async {
    if (!_isConfigured) return false;

    final info = await getCustomerInfo();
    return info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);
  }

  /// Returns the active subscription plan name ('monthly' or 'yearly'),
  /// or `null` if no active subscription.
  Future<String?> getActivePlan() async {
    if (!_isConfigured) return null;

    final info = await getCustomerInfo();
    final entitlement =
        info.entitlements.active[RevenueCatConfig.entitlementId];
    if (entitlement == null) return null;

    final productId = entitlement.productIdentifier;
    if (productId.contains('yearly') || productId.contains('annual')) {
      return 'yearly';
    }
    return 'monthly';
  }

  /// Returns the expiration date of the active premium entitlement, or `null`.
  Future<DateTime?> getExpirationDate() async {
    if (!_isConfigured) return null;

    final info = await getCustomerInfo();
    final entitlement =
        info.entitlements.active[RevenueCatConfig.entitlementId];
    if (entitlement == null) return null;

    final expiresStr = entitlement.expirationDate;
    if (expiresStr == null) return null;
    return DateTime.tryParse(expiresStr);
  }

  // ---------------------------------------------------------------------------
  // Listener for real-time entitlement updates
  // ---------------------------------------------------------------------------

  /// Registers a listener that fires whenever the customer's entitlement
  /// status changes (purchase, renewal, cancellation, billing issue, etc.).
  void addCustomerInfoListener(void Function(CustomerInfo) listener) {
    if (!_isConfigured) return;
    Purchases.addCustomerInfoUpdateListener(listener);
  }
}
