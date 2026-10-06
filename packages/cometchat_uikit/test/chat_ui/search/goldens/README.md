# Search Golden Tests

Visual regression tests for `CometChatSearch` using
[alchemist](https://pub.dev/packages/alchemist). The whole component is pumped
with an injected `SearchBloc` (`searchBloc:`) — a `MockBloc` held in a fixed
`SearchState` — so nothing is fetched and the screen shows exactly the state in
the test. Light + dark side by side in each PNG.

## Running

```bash
flutter test test/chat_ui/search/goldens/                   # verify
flutter test test/chat_ui/search/goldens/ --update-goldens  # rebake
```

Baselines live in `goldens/ci/`. Platform goldens are opt-in and not committed.

## Variants covered

| # | File | What it pins |
|---|---|---|
| 1 | `search_initial_filter_chips` | Initial state: search bar (back icon, hint, no clear icon) and the full unselected chip row wrapping over three lines |
| 2 | `search_results_populated` | Full screen: Chats section (online user + unread badge, private-group indicator + own last message with receipt, no-last-message row), "More", Messages section with month separators, text / mention / file / audio rows |
| 3 | `search_results_conversation_item` | Unread filter on: selected chip styling, chip row narrowed to its group, one conversation result row |
| 4 | `search_results_message_items` | Documents filter on: conversations hidden, file-message rows (doc icon, sender prefix, date) across two months |
| 5 | `search_empty` | No results: illustration, "no records" title, echoed query |
| 6 | `search_error` | Both sections failed: error icon + message |

## Notes

- The conversation row, message row, month separator and chip row are private
  to `CometChatSearch`, so they are pinned in place rather than rebuilt by hand.
- The fixed states are ones `SearchBloc` itself emits (e.g. a message filter
  sets `showConversations: false` and moves the tapped chip first).
- The text field stays empty: its controller is internal and is not driven by
  bloc state, so the hint is what shows even when `searchText` is set.
- Image / video results are omitted: their thumbnails go through
  `CachedNetworkImage`, whose cache manager needs platform channels.
- CI variant: alchemist paints each paragraph as one block in the *root* span's
  colour. The rich text-message preview has an unstyled root span, so it shows
  black in both themes — a harness artefact, not the rendered colour.
- Fixture dates are fixed 2024 days at noon, so output does not depend on the
  day or timezone the test runs in.
