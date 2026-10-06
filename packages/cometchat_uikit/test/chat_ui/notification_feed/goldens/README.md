# Notification Feed Golden Tests

Visual regression tests for `CometChatNotificationFeed`. The real screen is rendered and held in a fixed state through its `notificationFeedBloc` seam. Items are years old, so the card prints an absolute date whatever day the test runs on.

## Running

```bash
flutter test test/chat_ui/notification_feed/goldens/                  # verify
flutter test test/chat_ui/notification_feed/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `notification_feed_loaded` | Category chips with unread counts, and the feed item card (category, date, card body) for one unread and two read items |
| `notification_feed_state_empty` | Empty icon, title, subtitle under the chips |
| `notification_feed_state_error` | Error icon, title, subtitle, Retry button |
| `notification_feed_state_loading` | Centered spinner and label (captured at a fixed frame) |

## Reading the CI pictures

Baselines live in `goldens/ci/` and are rendered by alchemist's CI variant: the
Ahem font, with every text run painted as a solid block in the text's colour.
Three things follow, none of them a Kit defect:

- Material `Icon`s are font glyphs, so they are blocks too. Their size, colour
  and position are pinned; their shape is not. Asset icons (`Image.asset`)
  render normally.
- An editable text field is painted as a black block in both themes.
- A rich-text span whose root style has no colour is painted black.

Platform (real-font) goldens are opt-in (`ALCHEMIST_PLATFORM_GOLDENS=true`) and
are not checked in for this folder. Each PNG holds the light and the dark
scenario side by side; the harness is `test/helpers/golden_harness.dart`.
