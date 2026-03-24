import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:deardays/services/subscription/revenuecat_service.dart';
import 'package:deardays/services/subscription/subscription_state.dart';
import 'package:deardays/core/config/revenuecat_config.dart';
import 'package:deardays/services/auth/auth_service.dart';

// ---------------------------------------------------------------------------
// Service singleton
// ---------------------------------------------------------------------------

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

// ---------------------------------------------------------------------------
// Subscription state notifier
// ---------------------------------------------------------------------------

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref.watch(revenueCatServiceProvider));
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final RevenueCatService _service;

  SubscriptionNotifier(this._service) : super(const SubscriptionState()) {
    _init();
  }

  Future<void> _init() async {
    if (!_service.isConfigured) {
      state = state.copyWith(isLoading: false);
      return;
    }

    // Listen for real-time updates (renewals, cancellations, billing issues).
    _service.addCustomerInfoListener(_onCustomerInfoUpdate);

    await refresh();
  }

  /// Fetches the latest subscription status and available packages.
  Future<void> refresh() async {
    if (!_service.isConfigured) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await Future.wait([
        _service.isPremium(),
        _service.getActivePlan(),
        _service.getExpirationDate(),
        _service.getMonthlyPackage(),
        _service.getAnnualPackage(),
      ]);

      final rcPremium = results[0] as bool;

      // Server-side double-check alongside RevenueCat
      bool serverVerified = false;
      try {
        serverVerified = await AuthService().hasActiveSubscription();
      } catch (_) {
        serverVerified = rcPremium; // fallback to RevenueCat on network failure
      }
      final isPremium = rcPremium && serverVerified;

      state = SubscriptionState(
        isLoading: false,
        isPremium: isPremium,
        activePlan: results[1] as String?,
        expiresAt: results[2] as DateTime?,
        monthlyPackage: results[3] as Package?,
        yearlyPackage: results[4] as Package?,
      );
    } catch (e, st) {
      debugPrint('[Subscription] refresh error: $e');
      final msg = e.toString();
      if (e is PlatformException || msg.contains('Purchases')) {
        // RevenueCat error — expected on platforms without RevenueCat
        state = state.copyWith(isLoading: false, isPremium: false);
      } else {
        debugPrint('[Subscription] refresh stack: $st');
        state = state.copyWith(isLoading: false, error: 'Could not check subscription status.');
      }
    }
  }

  /// Purchases the monthly subscription.
  Future<bool> purchaseMonthly() async {
    return _purchase(state.monthlyPackage);
  }

  /// Purchases the yearly subscription.
  Future<bool> purchaseYearly() async {
    return _purchase(state.yearlyPackage);
  }

  /// Purchases a specific [package]. Returns `true` on success.
  Future<bool> _purchase(Package? package) async {
    if (package == null) {
      state = state.copyWith(error: 'Package not available. Try again later.');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final info = await _service.purchasePackage(package);
      final isPremium =
          info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);

      // Server-side double-check
      bool serverVerified = false;
      try {
        serverVerified = await AuthService().hasActiveSubscription();
      } catch (_) {
        serverVerified = isPremium; // fallback to RevenueCat on network failure
      }
      final verified = isPremium && serverVerified;

      state = state.copyWith(
        isLoading: false,
        isPremium: verified,
        activePlan: verified ? _planFromInfo(info) : null,
        expiresAt: verified ? _expiresFromInfo(info) : null,
      );

      return verified;
    } catch (e) {
      final message = e.toString();
      // Don't show error for user-cancelled purchases.
      final isCancelled = message.contains('PurchaseCancelledError') ||
          message.contains('userCancelled');
      state = state.copyWith(
        isLoading: false,
        error: isCancelled ? null : 'Purchase failed. Please try again.',
      );
      return false;
    }
  }

  /// Restores previous purchases.
  Future<bool> restorePurchases() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final info = await _service.restorePurchases();
      final isPremium =
          info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);

      // Server-side double-check
      bool serverVerified = false;
      try {
        serverVerified = await AuthService().hasActiveSubscription();
      } catch (_) {
        serverVerified = isPremium; // fallback to RevenueCat on network failure
      }
      final verified = isPremium && serverVerified;

      state = state.copyWith(
        isLoading: false,
        isPremium: verified,
        activePlan: verified ? _planFromInfo(info) : null,
        expiresAt: verified ? _expiresFromInfo(info) : null,
      );

      return verified;
    } catch (e) {
      debugPrint('[Subscription] restore error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not restore purchases. Please try again.',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _onCustomerInfoUpdate(CustomerInfo info) {
    final isPremium =
        info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);

    state = state.copyWith(
      isPremium: isPremium,
      activePlan: isPremium ? _planFromInfo(info) : null,
      expiresAt: isPremium ? _expiresFromInfo(info) : null,
    );
  }

  String? _planFromInfo(CustomerInfo info) {
    final entitlement =
        info.entitlements.active[RevenueCatConfig.entitlementId];
    if (entitlement == null) return null;
    final pid = entitlement.productIdentifier;
    if (pid.contains('yearly') || pid.contains('annual')) return 'yearly';
    return 'monthly';
  }

  DateTime? _expiresFromInfo(CustomerInfo info) {
    final entitlement =
        info.entitlements.active[RevenueCatConfig.entitlementId];
    if (entitlement == null) return null;
    final str = entitlement.expirationDate;
    if (str == null) return null;
    return DateTime.tryParse(str);
  }
}
