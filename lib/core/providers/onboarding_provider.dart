import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/onboarding/onboarding_notifier.dart';
import 'package:deardays/core/onboarding/onboarding_state.dart';

export 'package:deardays/core/onboarding/onboarding_state.dart';
export 'package:deardays/core/onboarding/onboarding_notifier.dart';

/// Main onboarding state provider — persisted to Hive.
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);

/// True when the user has no entries AND trial started within 48 hours.
final isNewUserProvider = FutureProvider<bool>((ref) async {
  try {
    final entries = await ref.watch(timelineEntriesProvider.future);
    if (entries.isNotEmpty) return false;
    final profile = await ref.watch(profileProvider.future);
    final trialStart = profile?.trialStartedAt;
    if (trialStart == null) return true;
    final age = DateTime.now().difference(trialStart);
    return age.inHours < 48;
  } catch (_) {
    return true;
  }
});
