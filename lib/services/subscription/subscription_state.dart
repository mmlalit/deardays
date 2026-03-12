import 'package:purchases_flutter/purchases_flutter.dart';

/// Immutable snapshot of the user's subscription status.
class SubscriptionState {
  final bool isLoading;
  final bool isPremium;
  final String? activePlan; // 'monthly', 'yearly', or null
  final DateTime? expiresAt;
  final Package? monthlyPackage;
  final Package? yearlyPackage;
  final String? error;

  const SubscriptionState({
    this.isLoading = true,
    this.isPremium = false,
    this.activePlan,
    this.expiresAt,
    this.monthlyPackage,
    this.yearlyPackage,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isLoading,
    bool? isPremium,
    String? activePlan,
    DateTime? expiresAt,
    Package? monthlyPackage,
    Package? yearlyPackage,
    String? error,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      isPremium: isPremium ?? this.isPremium,
      activePlan: activePlan ?? this.activePlan,
      expiresAt: expiresAt ?? this.expiresAt,
      monthlyPackage: monthlyPackage ?? this.monthlyPackage,
      yearlyPackage: yearlyPackage ?? this.yearlyPackage,
      error: error,
    );
  }

  /// Price string for the monthly package (e.g., "\$4.99").
  String get monthlyPrice =>
      monthlyPackage?.storeProduct.priceString ?? '\$4.99';

  /// Price string for the yearly package (e.g., "\$34.99").
  String get yearlyPrice =>
      yearlyPackage?.storeProduct.priceString ?? '\$34.99';
}
