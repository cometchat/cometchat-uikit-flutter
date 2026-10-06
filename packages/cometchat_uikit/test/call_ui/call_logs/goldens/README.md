# Call Logs Golden Tests

Visual regression tests for `CometChatCallLogs`. The real screen is rendered and held in a fixed state through its `callLogsBloc` seam; the Calls SDK is not involved.

## Running

```bash
flutter test test/call_ui/call_logs/goldens/                  # verify
flutter test test/call_ui/call_logs/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `call_logs_list_loaded` | Call-log row: outgoing audio / video, incoming audio / video (green direction glyph, neutral title), missed audio / video (red glyph and red title), date subtitle, call-back button |
| `call_logs_state_empty` | Empty icon, title, subtitle |
| `call_logs_state_error` | Error illustration, title, subtitle, Retry button |

The direction and audio/video glyphs are Material `Icon`s, so in the CI variant incoming and outgoing, and audio and video, differ only by position and colour. The platform variant tells them apart.

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

The loading (shimmer) state has no golden on purpose: it is an animation, so
the rasterised frame depends on the controller's phase — baked on macOS these
passed locally and failed on CI's Linux runner. The loading views keep their
widget-test coverage instead.
