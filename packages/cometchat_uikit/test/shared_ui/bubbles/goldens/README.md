# Message-Content Bubble Golden Tests

Visual regression tests for the message-content bubbles using
[alchemist](https://pub.dev/packages/alchemist). Every golden renders the
**real Kit widget** in the content (or footer) slot of a real
`CometChatMessageBubble`, the way `CometChatMessageList` composes it, with
light and dark side by side in one PNG.

## Running

```bash
flutter test test/shared_ui/bubbles/goldens/                   # verify
flutter test test/shared_ui/bubbles/goldens/ --update-goldens  # rebake
```

Only the CI (Ahem) baselines under `goldens/ci/` are committed. Platform
goldens are opt-in (`ALCHEMIST_PLATFORM_GOLDENS=true`) and not shared.

## Variants covered

### `media_grid_bubble_golden_test.dart` — `CometChatImagesBubble` / `CometChatMediaGrid`

| # | File | What it pins |
|---|---|---|
| 1 | `media_grid_1_incoming` | One attachment: a single square, fully rounded cell |
| 2 | `media_grid_2_incoming` | Two attachments: two squares side by side, 2dp gap |
| 3 | `media_grid_3_hero_top_incoming` | Three attachments, landscape hero: hero on top (60%), two below |
| 4 | `media_grid_3_hero_left_outgoing` | Three attachments, portrait hero: hero on the left, two stacked right — chosen from the decoded aspect ratio |
| 5 | `media_grid_4_outgoing` | Four attachments: 2×2 on the outgoing (primary) fill |
| 6 | `media_grid_overflow_incoming` | Seven attachments: 2×2 with the "+3" scrim on the fourth cell |
| 7 | `media_grid_caption_incoming` | Grid + caption, incoming text colour |
| 8 | `media_grid_caption_outgoing` | Overflow grid + wrapping caption, outgoing text colour |

### `message_content_bubbles_golden_test.dart` — each as `_incoming` and `_outgoing`

| # | File stem | What it pins |
|---|---|---|
| 9–10 | `bubble_file` | `CometChatFileBubble`: type icon, title, size/date subtitle, download affordance |
| 11–12 | `bubble_files_multi` | `CometChatFilesBubble`: three file cards (pdf / xlsx / zip icons) + caption |
| 13–14 | `bubble_voice_note` | `CometChatVoiceNoteBubble` idle: play badge, waveform, duration; download only on incoming |
| 15–16 | `bubble_audios_multi` | `CometChatAudiosBubble`: two audio rows with play badge, scrubber, download |
| 17–18 | `bubble_deleted` | Deleted-message bubble via `MessageTemplateUtils.getDeleteMessageBubble` — icon/text colour by sender |
| 19–20 | `bubble_image_placeholder` | `CometChatImageBubble` with nothing to show: `background3` fill + placeholder glyph |
| 21–22 | `bubble_video_placeholder` | `CometChatVideoBubble` without a poster: fill + play badge |
| 23–24 | `bubble_text_mention` | `CometChatTextBubble` + `CometChatMentionsFormatter`: mention resolved to the display name (see note) |

### `reactions_row_golden_test.dart` — `CometChatReactions` in the footer slot

| # | File | What it pins |
|---|---|---|
| 25 | `reactions_single_incoming` | One chip: fill, border, radius |
| 26 | `reactions_several_incoming` | Three chips, none mine; multi-digit count widens its chip |
| 27 | `reactions_own_highlighted_incoming` | My reaction takes `extendedPrimary100` fill + `extendedPrimary300` border |
| 28 | `reactions_own_highlighted_outgoing` | Same under an outgoing bubble — row right-aligned |
| 29 | `reactions_overflow_incoming` | Six reactions collapse to three chips + a "+3" chip |

## When to regenerate

- After changing any of the bubbles above, `CometChatMessageBubble`, or their style defaults
- After changing `kMultiAttachmentCardRadius` / `kMultiAttachmentContentInset` or the grid arrangements
- After colour-palette or spacing token changes

## Notes

- **No network.** Grid pictures are served by an in-memory `HttpOverrides`
  (`test/helpers/golden_message_harness.dart`) as generated two-tone BMPs, one
  colour per attachment, so each cell shows real decoded pixels and which
  attachment landed where. File / audio URLs use `.invalid` and are never
  fetched.
- **The status row is mirrored, not imported.** The list builds the
  time + receipt row privately; `goldenStatusInfo` reproduces it because a
  bubble's bottom padding is designed around that row being present.
- **CI variant limits.** Text and Material icons render as blocks (the package
  sets `uses-material-design: false`, so icon glyphs are Ahem boxes — colour
  and position are still pinned). Alchemist paints each paragraph as one block
  in the root span's colour, so an inline mention's highlight is not visible:
  `bubble_text_mention` pins that the marker resolved (block width is
  "Thanks @Priya Nair!", not the raw `<@uid:…>`), not the highlight colour.
- The voice-note and audio rows log a `video_player` platform-init error in
  tests; it is caught by the Kit and the idle state is what is pinned.
