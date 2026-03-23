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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  backendLiveTests();
  e2eMemoryFlowTests();
}
