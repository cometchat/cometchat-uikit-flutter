# Pinned Messages Golden Tests

Visual regression tests for `CometChatPinnedMessages`. The screen takes no bloc, so the real widget runs against a fake message store registered where the SDK resolves its repositories (`test/helpers/golden_fake_sdk.dart`).

## Running

```bash
flutter test test/chat_ui/pinned_messages/goldens/                  # verify
flutter test test/chat_ui/pinned_messages/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `pinned_messages_loaded` | Pinned row header (pinned-by, date) over the message bubble, for an incoming and an outgoing message |
| `pinned_messages_state_empty` | Pin icon, title, subtitle |

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
