#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# CometChat Flutter UIKit — E2E Test Runner (Android)
#
# Runs all E2E test suites on a single Android emulator.
# No second device needed — User B operates via REST API.
#
# Usage:
#   ./integration_test/run_android.sh [emulator-id]
#
# Examples:
#   ./integration_test/run_android.sh                    # Uses default emulator
#   ./integration_test/run_android.sh emulator-5554      # Specific emulator
#
# Prerequisites:
#   - One Android emulator running
#   - `flutter devices` shows the emulator
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail

DEVICE="${1:-emulator-5554}"
RESULTS_DIR="integration_test/e2e_results"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
RUN_DIR="$RESULTS_DIR/android_$TIMESTAMP"

mkdir -p "$RUN_DIR"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  CometChat Flutter UIKit — E2E Tests (Android)          ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Device: $DEVICE"
echo "║  Started: $TIMESTAMP"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Verify device is connected
echo "Checking device..."
if ! flutter devices --machine 2>/dev/null | grep -q "$DEVICE"; then
  echo "Device $DEVICE not found. Run 'flutter devices' to check."
  exit 1
fi
echo "Device detected"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# Run all test suites
# ═══════════════════════════════════════════════════════════════════════════════

SUITES=(
  "integration_test/suites/auth_test.dart"
  "integration_test/suites/users_test.dart"
  "integration_test/suites/conversations_test.dart"
  "integration_test/suites/message_header_test.dart"
  "integration_test/suites/messaging/send_message_test.dart"
  "integration_test/suites/messaging/receive_message_test.dart"
  "integration_test/suites/messaging/edit_message_test.dart"
  "integration_test/suites/messaging/delete_message_test.dart"
  "integration_test/suites/message_actions_test.dart"
  "integration_test/suites/media_messages_test.dart"
  "integration_test/suites/reactions_test.dart"
  "integration_test/suites/thread_replies_test.dart"
  "integration_test/suites/typing_indicator_test.dart"
  "integration_test/suites/read_receipts_test.dart"
  "integration_test/suites/presence_test.dart"
  "integration_test/suites/block_user_test.dart"
  "integration_test/suites/user_info_test.dart"
  "integration_test/suites/pagination_test.dart"
  "integration_test/suites/composer_test.dart"
  "integration_test/suites/search_test.dart"
  "integration_test/suites/calls_test.dart"
  "integration_test/suites/connection_test.dart"
  "integration_test/suites/configuration_test.dart"
  "integration_test/suites/groups_test.dart"
  "integration_test/suites/edge_cases_test.dart"
  "integration_test/suites/ui_surfaces_test.dart"
  # ── Group test catalog (GRP-*, RT-GRP-*, 1TO1-104) ──
  "integration_test/suites/groups_extended_test.dart"
  "integration_test/suites/group_composer_test.dart"
  "integration_test/suites/group_message_actions_test.dart"
  "integration_test/suites/group_media_messages_test.dart"
  "integration_test/suites/group_reactions_test.dart"
  "integration_test/suites/group_thread_messages_test.dart"
  "integration_test/suites/group_header_test.dart"
  "integration_test/suites/group_members_test.dart"
  "integration_test/suites/groups_realtime_test.dart"
  "integration_test/suites/composer_voice_test.dart"
  # iOS-parity suites (strict assertions; see README §5)
  "integration_test/suites/rich_text_composer_test.dart"
  "integration_test/suites/composer_draft_test.dart"
  "integration_test/suites/mentions_one_to_one_test.dart"
  "integration_test/suites/swipe_to_reply_test.dart"
  "integration_test/suites/search_in_conversation_test.dart"
  "integration_test/suites/polls_test.dart"
  "integration_test/suites/media_viewer_and_tools_test.dart"
  "integration_test/suites/pinned_messages_test.dart"
  "integration_test/suites/saved_messages_test.dart"
  "integration_test/suites/message_information_test.dart"
  "integration_test/suites/notification_feed_test.dart"
  "integration_test/suites/ai_assistant_test.dart"
  "integration_test/suites/conversation_gap_test.dart"
  "integration_test/suites/accessibility_audit_test.dart"
)

TOTAL=0
PASSED=0
FAILED=0
ERRORS=()

for SUITE in "${SUITES[@]}"; do
  BASENAME=$(basename "$SUITE" .dart)
  LOG_FILE="$RUN_DIR/${BASENAME}.log"

  echo "Running: $BASENAME"
  TOTAL=$((TOTAL + 1))

  flutter test "$SUITE" -d "$DEVICE" 2>&1 | tee "$LOG_FILE"
  EXIT_CODE=${PIPESTATUS[0]}

  if [ $EXIT_CODE -eq 0 ]; then
    echo "  PASSED"
    PASSED=$((PASSED + 1))
  else
    echo "  FAILED (exit: $EXIT_CODE)"
    FAILED=$((FAILED + 1))
    ERRORS+=("$BASENAME")
  fi
  echo ""
done

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════

cat > "$RUN_DIR/SUMMARY.md" << EOF
# E2E Test Run Summary (Android)

**Date:** $TIMESTAMP
**Device:** $DEVICE
**Total:** $TOTAL | **Passed:** $PASSED | **Failed:** $FAILED

| Suite | Status |
|-------|--------|
EOF

for SUITE in "${SUITES[@]}"; do
  BASENAME=$(basename "$SUITE" .dart)
  if [[ " ${ERRORS[*]} " =~ " $BASENAME " ]]; then
    echo "| $BASENAME | Failed |" >> "$RUN_DIR/SUMMARY.md"
  else
    echo "| $BASENAME | Passed |" >> "$RUN_DIR/SUMMARY.md"
  fi
done

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  RESULTS                                                ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  Total:  %-4s                                          ║\n" "$TOTAL"
printf "║  Passed: %-4s                                          ║\n" "$PASSED"
printf "║  Failed: %-4s                                          ║\n" "$FAILED"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Results: $RUN_DIR/"
echo "╚══════════════════════════════════════════════════════════╝"

exit $FAILED
