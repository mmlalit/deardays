/// Backend test runner — real Supabase, real data, full cleanup.
///
/// Run:
///   flutter test integration_test/backend_app_test.dart \
///     -d windows \
///     --dart-define-from-file=dart_defines.env \
///     --reporter expanded
library;

import 'package:integration_test/integration_test.dart';

import 'backend_tests/backend_live_test.dart';
import 'backend_tests/e2e_memory_flow_test.dart';
import 'backend_tests/home_backend_test.dart';
import 'backend_tests/timeline_backend_test.dart';
import 'backend_tests/explore_backend_test.dart';
import 'backend_tests/search_backend_test.dart';
import 'backend_tests/memory_detail_backend_test.dart';
import 'backend_tests/settings_backend_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Original suites
  backendLiveTests();
  e2eMemoryFlowTests();

  // New suites — UI changes from this session
  homeBackendTests();
  timelineBackendTests();
  exploreBackendTests();
  searchBackendTests();
  memoryDetailBackendTests();
  settingsBackendTests();
}
