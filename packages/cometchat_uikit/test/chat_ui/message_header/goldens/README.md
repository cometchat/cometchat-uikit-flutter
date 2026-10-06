# Message Header Golden Tests

Visual regression tests for `CometChatMessageHeader`. The real header is rendered and held in a fixed state through its `messageHeaderBloc` seam.

## Running

```bash
flutter test test/chat_ui/message_header/goldens/                  # verify
flutter test test/chat_ui/message_header/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `message_header_user_online` | Back arrow, avatar with online dot, name, "Online" subtitle, overflow menu |
| `message_header_user_last_seen` | Offline user: no dot, absolute last-seen subtitle (fixed date in another year, so clock-independent) |
| `message_header_group_members` | Group avatar with private-group badge, member-count subtitle |
| `message_header_user_typing` | Typing subtitle in the primary colour (1-1) |
| `message_header_group_typing` | "<name>: typing" subtitle in a group |
| `message_header_call_buttons` | Voice and video call buttons, shown only when the Kit is initialised with `enableCalls` |

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
