# Group Members Golden Tests

Visual regression tests for `CometChatGroupMembers`. The real screen is rendered and held in a fixed state through its `groupMembersBloc` seam.

## Running

```bash
flutter test test/chat_ui/group_members/goldens/                  # verify
flutter test test/chat_ui/group_members/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `group_members_scope_chips` | Member row with each trailing chip: owner (filled), admin (outlined), moderator (tinted), participant (none), and the logged-in user titled "You" |
| `group_members_selection` | Multi-select: checkboxes, checked rows highlighted with the check badge on the avatar |
| `group_members_state_empty` | The empty state. It is blank today: the screen calls the default empty view without an icon, title or subtitle. The golden pins that; rebake when the Kit gives it content |
| `group_members_state_error` | Error illustration, title, subtitle, Retry button |

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
