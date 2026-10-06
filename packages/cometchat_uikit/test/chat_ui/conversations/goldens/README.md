# Conversations Golden Tests

Visual regression tests for `CometChatConversationListItem` using [alchemist](https://pub.dev/packages/alchemist).

## Running

```bash
# Verify goldens match baselines (CI mode)
flutter test test/chat_ui/conversations/goldens/

# Regenerate baselines after intentional design changes
flutter test test/chat_ui/conversations/goldens/ --update-goldens
```

## Structure

```
goldens/
├── conversation_list_item_golden_test.dart   # 8 variants × 2 themes = 16 tests
├── README.md
└── goldens/
    ├── ci/          # Text-obscured PNGs (cross-platform safe)
    │   ├── list_item_user_read.png
    │   ├── list_item_user_unread.png
    │   ├── list_item_user_unread_many.png
    │   ├── list_item_user_online.png
    │   ├── list_item_user_selected.png
    │   ├── list_item_group_public.png
    │   ├── list_item_group_private.png
    │   └── list_item_group_password.png
    └── macos/       # Full-text PNGs (macOS-only, human-readable)
        └── (same 8 files)
```

## Variants covered

| # | Variant | What it pins |
|---|---------|-------------|
| 1 | user_read | Basic layout: avatar + title + "Tap to start" subtitle |
| 2 | user_unread | Unread badge (single digit, fixed 20×20 circle) |
| 3 | user_unread_many | Unread badge (multi-digit, auto-width) |
| 4 | user_online | Green status indicator dot |
| 5 | group_public | Group avatar, no type indicator |
| 6 | group_private | Shield icon on status indicator |
| 7 | group_password | Lock icon on status indicator |
| 8 | user_selected | Selection checkbox (checked) + highlighted background |

Each variant renders light + dark themes side-by-side in a single golden.

## When to regenerate

- After changing `CometChatConversationListItem` layout, spacing, or colors
- After updating `CometChatConversationsStyle` defaults
- After changing avatar, badge, or status-indicator sizing
- After theme color palette changes

## Notes

- `lastMessage` is intentionally `null` in all variants to avoid pulling in the full subtitle-formatter / mentions / moderation chain. Those paths are covered by L3 widget tests and L5 E2E.
- CI variant uses Ahem font (text rendered as black boxes) for cross-platform consistency.
- macOS variant renders real text — useful for human review but only reproducible on macOS.

## State views (`conversations_state_views_golden_test.dart`)

The real `CometChatConversations` screen, held in each state through its
`conversationsBloc` seam. CI baselines only, light + dark side by side.

| Golden | What it pins |
|---|---|
| `conversations_state_empty` | Empty illustration, title, subtitle |
| `conversations_state_error` | Error illustration, title, subtitle (this screen's error view has no Retry button) |

The loading (shimmer) state has no golden on purpose: it is an animation, so
the rasterised frame depends on the controller's phase — baked on macOS these
passed locally and failed on CI's Linux runner. The loading views keep their
widget-test coverage instead.
