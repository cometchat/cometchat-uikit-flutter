# Users Golden Tests

Visual regression tests for `CometChatUsers`. The real screen (app bar, search box, sticky headers, rows) is rendered and held in a fixed state through its `usersBloc` seam.

## Running

```bash
flutter test test/chat_ui/users/goldens/                  # verify
flutter test test/chat_ui/users/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `users_list_loaded` | User row: avatar, name, online dot present / absent, alphabetical sticky headers |
| `users_list_selection` | Multi-select: checkboxes, checked rows highlighted, count title and confirm action |
| `users_state_empty` | Empty illustration, title, subtitle |
| `users_state_error` | Error illustration, title, subtitle, Retry button |

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
