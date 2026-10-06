# Primitive Matrix Golden Tests

Visual regression tests for `CometChatAvatar`, `CometChatBadge`, `CometChatStatusIndicator` and `CometChatReceipt`. One matrix per primitive, rendered directly.

## Running

```bash
flutter test test/shared_ui/core_widgets/goldens/                  # verify
flutter test test/shared_ui/core_widgets/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `avatar_matrix` | Initials avatar at 24 / 32 / 40 / 48 / 64 / 96; one initial, no name (fallback), rounded-square with a placeholder text style, bordered. The initials do not scale with the avatar: their size comes from the screen width, not the avatar size |
| `badge_matrix` | Count 0 (nothing), 1, 9 (circle), 12, 99 (pill), 250, 1200 (overflow label) |
| `status_indicator_matrix` | Online dot at 8 / 12 / 16, with a background ring, private (shield) and password (lock) badges, and the unstyled default |
| `receipt_matrix` | waiting, sent, delivered, read, error at 16 and 24: each state's colour and size |

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
