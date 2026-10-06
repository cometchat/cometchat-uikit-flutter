#!/bin/bash
# Resumable runner for ALL 36 suites on a given device. Skips completed logs.
#   run_all_resumable.sh <device> <run_dir>
set -o pipefail
DEVICE="${1:?device}"; RUN_DIR="${2:?run dir}"; mkdir -p "$RUN_DIR"
SUITES=(
  auth users conversations message_header
  messaging/send_message messaging/receive_message messaging/edit_message messaging/delete_message
  message_actions media_messages reactions thread_replies typing_indicator read_receipts
  presence block_user user_info pagination composer search calls connection configuration
  groups edge_cases ui_surfaces
  groups_extended group_composer group_message_actions group_media_messages group_reactions
  group_thread_messages group_header group_members groups_realtime composer_voice
  rich_text_composer composer_draft mentions_one_to_one swipe_to_reply search_in_conversation
  polls media_viewer_and_tools pinned_messages saved_messages message_information
  notification_feed ai_assistant conversation_gap accessibility_audit
)
is_done(){ [ -f "$1" ] && grep -qE "All tests passed!|Some tests failed\." "$1"; }
for S in "${SUITES[@]}"; do
  B=$(basename "$S"); LOG="$RUN_DIR/${B}_test.log"
  if is_done "$LOG"; then echo "skip: $B"; continue; fi
  echo "RUN: $B"
  [ "$DEVICE" != "chrome" ] && adb -s "$DEVICE" shell pm trim-caches 9999999999 >/dev/null 2>&1
  flutter test "integration_test/suites/${S}_test.dart" -d "$DEVICE" 2>&1 | tee "$LOG"
done
echo "=== ALL SUITES DONE on $DEVICE ==="
