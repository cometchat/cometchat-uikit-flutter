# Message List Golden Tests

Pixel pins for the message-list bubble as the list actually composes it:
a `CometChatMessageBubble` carrying a `CometChatTextBubble` content view and a
`CometChatReceipt` status-info view — the same slots
`CometChatMessageList._buildMessageItem` fills.

## Variants

| File | What it pins |
|---|---|
| `message_list_sent_read` | Outgoing bubble, read receipt |
| `message_list_sent_delivered` | Outgoing bubble, delivered receipt |
| `message_list_sent_only` | Outgoing bubble, sent receipt |
| `message_list_received` | Incoming bubble, no receipt |
| `message_list_long_text` | Multi-line wrapping inside the bubble |
| `message_list_emoji_only` | Emoji-only bubble — scaled, unpadded, no background |

Each renders light and dark side by side, so 6 files × 2 variants = 12 baselines.

## Running

```bash
flutter test test/chat_ui/message_list/goldens/                   # verify
flutter test test/chat_ui/message_list/goldens/ --update-goldens  # rebake
```

## Two things worth knowing before you touch this file

**The bubble caps itself at 75% of `MediaQuery` width.** A `MediaQueryData`
without a `size` is `Size.zero`, which collapses the text to one character per
line and overflows the scenario by ~1,700px. `_themed` supplies an explicit
size for that reason.

**Both variants draw body text in the test default face.** The Kit's text
styles never name a `fontFamily`, so a `TextSpan` style with a null family
falls back to what `flutter_test` provides rather than to the host font — the
scenario labels and Material icons differ between `ci/` and `macos/`, the body
text does not. These goldens therefore pin geometry, colour and receipt state;
**real font metrics are Layer 3's job**, covered on-device in
`master_app/integration_test/device/ui_kit_device_test.dart`.

## CI behaviour

`CI=true` (or `ALCHEMIST_CI=true`) disables the platform variant, so only the
`ci/` baselines run in a container.

## Output

```
goldens/
├── ci/      # 6 PNGs, text obscured, platform-agnostic
├── macos/   # 6 PNGs, rendered for human review
├── message_list_golden_test.dart
└── README.md
```

## List decorations (`message_list_decorations_golden_test.dart`)

The non-bubble rows of the list. Each is the real Kit widget, laid out as a
list row (full width, unbounded height, centred), light + dark in one PNG.
CI (`ci/`) baselines only.

| File | What it pins |
|---|---|
| `date_separator_absolute` | `CometChatDate` with `dayDateFormat` for an older day: pill fill, border, caption colour |
| `date_separator_custom_string` | Same pill driven by `customDateString` (the `dateSeparatorPattern` path) — pill width follows the label |
| `new_messages_indicator` | `CometChatNewMessageIndicator`: error-coloured rules either side of the label, in both themes |
| `action_bubble_short` | `CometChatActionBubble` in a centre-aligned, transparent `CometChatMessageBubble` — the pill hugs a short label |
| `action_bubble_long` | Long group-event text: capped at 85% of screen width, single line, ellipsised |

The date fixtures are at noon on a fixed 2023 day, so neither the timezone nor
the day the test runs can turn them into "Today" or a weekday name.
