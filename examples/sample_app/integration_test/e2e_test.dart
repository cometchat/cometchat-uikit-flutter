/// CometChat Flutter UIKit — E2E Test Suite (consolidated)
///
/// Architecture:
///   - User A: Full Flutter app running on device (emulator/simulator/browser)
///   - User B: CometChat REST API calls from same test process (no second device)
///
/// User B's REST calls trigger real WebSocket events that User A's app
/// receives through the SDK's listener system. No timers. No second emulator.
///
/// Every test case from the three source sheets is implemented exactly once,
/// in one feature-named suite under `suites/`:
///   - "CometChat E2E Test Cases - 1to1 Conversations"  (1TO1-*)
///   - "CometChat E2E Test Cases - Realtime Dual Device" (RT-*)
///   - "CometChat Automated Test Cases - E2E Tests"      (E2E-*)
///
/// Run everything on a device:
///   ./integration_test/run_android.sh emulator-5554
///   ./integration_test/run_ios.sh
///   ./integration_test/run_web.sh
///
/// Or run a single suite:
///   flutter test integration_test/suites/<suite>_test.dart -d <device>
library;

// ---------------------------------------------------------------------------
// Aggregator entry point — added when the tree was flattened out of the
// accidental `integration_test/integration_test/` nesting.
//
// Until then this file was documentation only: it had no `main()`, so nothing
// could target the 50-suite tree as a unit and it ran in no pipeline. It now
// mirrors `all_e2e_tests.dart`, which does the same for the two legacy suites:
// each suite's `main()` registers its own groups against the shared binding
// (`IntegrationTestWidgetsFlutterBinding.ensureInitialized()` is idempotent),
// so calling them in sequence builds one run out of all 50 files.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/e2e_test.dart -d DEVICE
//
// Prefer the runner scripts for day-to-day work — they run suite by suite, so
// one failure does not cost the whole run and results land per suite:
//
//   ./integration_test/run_ios.sh        ./integration_test/run_android.sh
//
// `calls_test.dart` and `composer_voice_test.dart` need WebRTC and audio
// recording, so this target is device-only; the web wrappers stay per suite.
// ---------------------------------------------------------------------------

import 'suites/accessibility_audit_test.dart' as accessibility_audit_test;
import 'suites/ai_assistant_test.dart' as ai_assistant_test;
import 'suites/auth_test.dart' as auth_test;
import 'suites/block_user_test.dart' as block_user_test;
import 'suites/calls_test.dart' as calls_test;
import 'suites/composer_draft_test.dart' as composer_draft_test;
import 'suites/composer_test.dart' as composer_test;
import 'suites/composer_voice_test.dart' as composer_voice_test;
import 'suites/configuration_test.dart' as configuration_test;
import 'suites/connection_test.dart' as connection_test;
import 'suites/conversation_gap_test.dart' as conversation_gap_test;
import 'suites/conversations_test.dart' as conversations_test;
import 'suites/edge_cases_test.dart' as edge_cases_test;
import 'suites/group_composer_test.dart' as group_composer_test;
import 'suites/group_header_test.dart' as group_header_test;
import 'suites/group_media_messages_test.dart' as group_media_messages_test;
import 'suites/group_members_test.dart' as group_members_test;
import 'suites/group_message_actions_test.dart' as group_message_actions_test;
import 'suites/group_reactions_test.dart' as group_reactions_test;
import 'suites/group_thread_messages_test.dart' as group_thread_messages_test;
import 'suites/groups_extended_test.dart' as groups_extended_test;
import 'suites/groups_realtime_test.dart' as groups_realtime_test;
import 'suites/groups_test.dart' as groups_test;
import 'suites/media_messages_test.dart' as media_messages_test;
import 'suites/media_viewer_and_tools_test.dart' as media_viewer_and_tools_test;
import 'suites/mentions_one_to_one_test.dart' as mentions_one_to_one_test;
import 'suites/message_actions_test.dart' as message_actions_test;
import 'suites/message_header_test.dart' as message_header_test;
import 'suites/message_information_test.dart' as message_information_test;
import 'suites/messaging/delete_message_test.dart'
    as messaging_delete_message_test;
import 'suites/messaging/edit_message_test.dart' as messaging_edit_message_test;
import 'suites/messaging/receive_message_test.dart'
    as messaging_receive_message_test;
import 'suites/messaging/send_message_test.dart' as messaging_send_message_test;
import 'suites/notification_feed_test.dart' as notification_feed_test;
import 'suites/pagination_test.dart' as pagination_test;
import 'suites/pinned_messages_test.dart' as pinned_messages_test;
import 'suites/polls_test.dart' as polls_test;
import 'suites/presence_test.dart' as presence_test;
import 'suites/reactions_test.dart' as reactions_test;
import 'suites/read_receipts_test.dart' as read_receipts_test;
import 'suites/rich_text_composer_test.dart' as rich_text_composer_test;
import 'suites/saved_messages_test.dart' as saved_messages_test;
import 'suites/search_in_conversation_test.dart' as search_in_conversation_test;
import 'suites/search_test.dart' as search_test;
import 'suites/swipe_to_reply_test.dart' as swipe_to_reply_test;
import 'suites/thread_replies_test.dart' as thread_replies_test;
import 'suites/typing_indicator_test.dart' as typing_indicator_test;
import 'suites/ui_surfaces_test.dart' as ui_surfaces_test;
import 'suites/user_info_test.dart' as user_info_test;
import 'suites/users_test.dart' as users_test;

void main() {
  accessibility_audit_test.main();
  ai_assistant_test.main();
  auth_test.main();
  block_user_test.main();
  calls_test.main();
  composer_draft_test.main();
  composer_test.main();
  composer_voice_test.main();
  configuration_test.main();
  connection_test.main();
  conversation_gap_test.main();
  conversations_test.main();
  edge_cases_test.main();
  group_composer_test.main();
  group_header_test.main();
  group_media_messages_test.main();
  group_members_test.main();
  group_message_actions_test.main();
  group_reactions_test.main();
  group_thread_messages_test.main();
  groups_extended_test.main();
  groups_realtime_test.main();
  groups_test.main();
  media_messages_test.main();
  media_viewer_and_tools_test.main();
  mentions_one_to_one_test.main();
  message_actions_test.main();
  message_header_test.main();
  message_information_test.main();
  messaging_delete_message_test.main();
  messaging_edit_message_test.main();
  messaging_receive_message_test.main();
  messaging_send_message_test.main();
  notification_feed_test.main();
  pagination_test.main();
  pinned_messages_test.main();
  polls_test.main();
  presence_test.main();
  reactions_test.main();
  read_receipts_test.main();
  rich_text_composer_test.main();
  saved_messages_test.main();
  search_in_conversation_test.main();
  search_test.main();
  swipe_to_reply_test.main();
  thread_replies_test.main();
  typing_indicator_test.main();
  ui_surfaces_test.main();
  user_info_test.main();
  users_test.main();
}
