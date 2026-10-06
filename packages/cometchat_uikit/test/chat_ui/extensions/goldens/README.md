# Extension Bubble Golden Tests

Visual regression tests for the polls and link-preview bubbles using
[alchemist](https://pub.dev/packages/alchemist). Real Kit widgets inside a real
`CometChatMessageBubble`; light + dark side by side in each PNG.

## Running

```bash
flutter test test/chat_ui/extensions/goldens/                   # verify
flutter test test/chat_ui/extensions/goldens/ --update-goldens  # rebake
```

Baselines live in `goldens/ci/` (Ahem, cross-platform). Platform goldens are
opt-in and not committed.

## Variants covered

| # | File | What it pins |
|---|---|---|
| 1 | `poll_unvoted_incoming` | `CometChatPollsBubble`, nobody voted: empty bars, no counts, no avatars, unticked radios |
| 2 | `poll_uneven_split_incoming` | 3 / 1 / 0 split: bar lengths, overlapping voter avatars, counts, my vote ticked in primary |
| 3 | `poll_uneven_split_outgoing` | Same on the outgoing fill: white bars on `extendedPrimary700`, white radio with primary tick |
| 4 | `poll_two_options_incoming` | Two-option poll, one vote each, none mine: 50/50 bars |
| 5 | `link_preview_image_incoming` | Link preview via `MessageTemplateUtils.getTextMessageContentView`: image, title/description/url tile, text bubble below |
| 6 | `link_preview_image_outgoing` | Same on the outgoing fill (`extendedPrimary900` card, white text) |
| 7 | `link_preview_no_image_incoming` | No image in the payload: card collapses to the text tile |

## Notes

- The link-preview goldens start from a `TextMessage` whose metadata carries the
  `@injected.extensions.link-preview` block, so the real detection path runs.
- The preview image comes from the in-memory network in
  `test/helpers/golden_message_harness.dart`; nothing touches a socket.
- CI variant: text, avatar initials and Material icons (the poll tick) render
  as blocks.
