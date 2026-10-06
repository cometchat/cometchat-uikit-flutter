# Threaded Header Golden Tests

Visual regression tests for `CometChatThreadedHeader`. The real header is rendered and held in its loaded state through its `threadedHeaderBloc` seam; the parent bubble comes from the Kit's own text template.

## Running

```bash
flutter test test/chat_ui/threaded_header/goldens/                  # verify
flutter test test/chat_ui/threaded_header/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `threaded_header_incoming_parent` | Incoming parent bubble over the reply-count bar (plural) |
| `threaded_header_outgoing_parent` | Outgoing parent bubble with receipt over the reply-count bar (singular) |

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
