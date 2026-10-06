# Incoming Call Golden Tests

Visual regression tests for `CometChatIncomingCall`. The real banner is rendered in its idle (ringing) state through its `incomingCallBloc` seam: no Calls SDK session, no ringtone.

## Running

```bash
flutter test test/call_ui/incoming_call/goldens/                  # verify
flutter test test/call_ui/incoming_call/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `incoming_call_audio` | Caller name, "Incoming audio call" subtitle with icon, avatar, Decline and Accept buttons |
| `incoming_call_video` | The same for a video call |

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
