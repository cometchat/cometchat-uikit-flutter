# Message Information Golden Tests

Visual regression tests for `CometChatMessageInformation`. The real sheet is rendered and held in a fixed state through its `messageInformationBloc` seam. It is a DraggableScrollableSheet that opens at half the height it is given, so each scenario is a whole 375x812 screen.

## Running

```bash
flutter test test/chat_ui/message_information/goldens/                  # verify
flutter test test/chat_ui/message_information/goldens/ --update-goldens # rebake after an intended change
```

## Variants covered

| Golden | What it pins |
|---|---|
| `message_information_user` | 1-1: title, message bubble, Read and Delivered rows with their stamps |
| `message_information_group_receipts` | Group: one receipt row per member, a member who has read and one who has only received |

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
