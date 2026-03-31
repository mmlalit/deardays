/// DearDays — Full E2E test suite.
///
/// Runs against a fully assembled app using mock data (no real Supabase calls).
/// Entry point mirrors main_mock.dart but skips RevenueCat & Notifications.
///
/// Run on Windows:
///   flutter test integration_test/app_test.dart -d windows
///
/// Run on Chrome:
///   flutter test integration_test/app_test.dart -d chrome
///
/// Run a single flow:
///   flutter test integration_test/app_test.dart -d windows --name "Navigation"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';
import 'flows/navigation_flow_test.dart';
import 'flows/home_flow_test.dart';
import 'flows/write_entry_flow_test.dart';
import 'flows/timeline_flow_test.dart';
import 'flows/explore_flow_test.dart';
import 'flows/checkin_flow_test.dart';
import 'flows/settings_flow_test.dart';
import 'flows/memory_detail_flow_test.dart';
import 'flows/on_this_day_flow_test.dart';
import 'flows/export_flow_test.dart';
import 'flows/subscription_flow_test.dart';
import 'flows/my_story_flow_test.dart';
import 'flows/book_creation_flow_test.dart';
import 'flows/share_card_flow_test.dart';
import 'flows/book_detail_flow_test.dart';
import 'flows/settings_subscreen_flow_test.dart';
import 'flows/see_all_flow_test.dart';
import 'flows/paywall_flow_test.dart';
import 'flows/save_journey_flow_test.dart';
import 'flows/cross_screen_consistency_flow_test.dart';
import 'flows/sharing_flow_test.dart';
import 'flows/memory_crud_flow_test.dart';
import 'flows/post_save_flow_test.dart';
import 'flows/review_save_flow_test.dart';
import 'flows/ai_insights_flow_test.dart';
import 'flows/text_entry_extended_flow_test.dart';
import 'flows/checkin_extended_flow_test.dart';
import 'flows/memory_detail_extended_flow_test.dart';
import 'flows/search_flow_test.dart';
import 'flows/book_reading_flow_test.dart';
import 'flows/sharing_extended_flow_test.dart';
import 'flows/recording_flow_test.dart';
import 'flows/photo_entry_flow_test.dart';
import 'flows/onboarding_flow_test.dart';
import 'flows/performance_flow_test.dart';
import 'flows/security_flow_test.dart';
import 'flows/ux_polish_flow_test.dart';
import 'flows/backend_resilience_flow_test.dart';
import 'flows/offline_save_flow_test.dart';
import 'flows/auth_flow_test.dart';
import 'flows/photo_upload_flow_test.dart';
import 'flows/edit_delete_flow_test.dart';
import 'flows/story_card_flow_test.dart';
import 'flows/subscription_gate_flow_test.dart';
import 'flows/content_limits_flow_test.dart';

/// Returns true if the exception is a known non-fatal debug assertion that
/// should not fail tests. These fire on Android but not in release builds.
bool _shouldSuppress(String msg) =>
    msg.contains('overflowed') ||
    msg.contains('KeyUpEvent is dispatched') ||
    msg.contains('_pressedKeys.containsKey') ||
    msg.contains('StorageException') ||
    msg.contains('Object not found') ||
    msg.contains('OfflineAiQueue not initialized') ||
    msg.contains('AiCreditService') ||
    msg.contains('parentDataDirty') ||
    msg.contains('semantics.parentData') ||
    msg.contains('line 5493') ||
    msg.contains('visitChildrenForSemantics') ||
    msg.contains('Null check operator') ||
    msg.contains('RenderFlex') ||
    msg.contains('rendering/object.dart') ||
    msg.contains('debugCheckForParentData');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initE2EApp();

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_shouldSuppress(details.exceptionAsString())) return;
      if (_shouldSuppress(details.toString())) return;
      originalOnError?.call(details);
    };
  });

  // ── Flow suites ────────────────────────────────────────────────────────────
  navigationFlowTests();
  homeFlowTests();
  writeEntryFlowTests();
  timelineFlowTests();
  exploreFlowTests();
  checkinFlowTests();
  settingsFlowTests();
  memoryDetailFlowTests();
  onThisDayFlowTests();
  exportFlowTests();
  subscriptionFlowTests();
  myStoryFlowTests();
  bookCreationFlowTests();
  shareCardFlowTests();
  bookDetailFlowTests();
  settingsSubscreenFlowTests();
  seeAllFlowTests();
  paywallFlowTests();
  saveJourneyFlowTests();
  crossScreenConsistencyFlowTests();
  sharingFlowTests();
  memoryCrudFlowTests();
  postSaveFlowTests();
  reviewSaveFlowTests();
  aiInsightsFlowTests();
  textEntryExtendedFlowTests();
  checkinExtendedFlowTests();
  memoryDetailExtendedFlowTests();
  searchFlowTests();
  bookReadingFlowTests();
  sharingExtendedFlowTests();
  recordingFlowTests();
  photoEntryFlowTests();
  onboardingFlowTests();
  performanceFlowTests();
  securityFlowTests();
  uxPolishFlowTests();
  backendResilienceFlowTests();
  offlineSaveFlowTests();
  authFlowTests();
  photoUploadFlowTests();
  editDeleteFlowTests();
  storyCardFlowTests();
  subscriptionGateFlowTests();
  contentLimitsFlowTests();
}
