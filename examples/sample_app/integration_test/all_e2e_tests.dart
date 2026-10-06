// Aggregator entry point for the Android E2E pipeline.
//
// `am instrument` on Android runs whichever Dart `main()` was compiled into
// the test APK at build time (selected via `-Ptarget=...`). To run multiple
// integration test files in a single emulator run we wire them up here and
// point gradle at this file.
//
// Each underlying file already calls `IntegrationTestWidgetsFlutterBinding
// .ensureInitialized()` (which is idempotent) and registers its own
// `setUpAll` / `tearDownAll` / `testWidgets`. Calling both `main()` functions
// in sequence registers all groups against the same binding before the
// runner starts execution.
//
// Locally you can still run either file directly via:
//   flutter test integration_test/conversations_e2e_test.dart -d <device>
//   flutter test integration_test/message_list_e2e_test.dart -d <device>
//
// WHAT THIS FILE DOES NOT RUN (ENG-38688). These two suites are 18 of the 393
// E2E tests in the tree. The other 375 — every suite under integration_test/
// suites/ and every web_* wrapper — are reachable only from e2e_test.dart or a
// run_*.sh, so no pull request runs them. integration_test/e2e_coverage_map.csv
// records which is which in its `status` column, and the E2E compile gate
// prints both totals in its job summary on every run.
//
// Adding a suite here is what moves its rows from `local` to `ci`, so do it
// deliberately: these suites need a live backend, credentials and a second
// user, and the Android E2E job now fails the build on a test failure rather
// than reporting it. Add them once the seeded-login path has a clean run, a
// few at a time, regenerating the map with
// `dart run tool/e2e_coverage_map.dart` each time.

import 'conversations_e2e_test.dart' as conversations;
import 'message_list_e2e_test.dart' as message_list;

void main() {
  conversations.main();
  message_list.main();
}
