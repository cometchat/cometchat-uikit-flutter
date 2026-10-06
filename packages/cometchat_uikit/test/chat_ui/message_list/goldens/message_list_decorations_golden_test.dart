/// Golden pins for the non-bubble rows of the message list: the date
/// separator, the "New Messages" unread divider, and the group-action
/// (member joined / kicked / scope changed) bubble. Each is the real Kit
/// widget, built with the arguments `CometChatMessageList` passes it.
///
///   flutter test test/chat_ui/message_list/goldens/                  # verify
///   flutter test test/chat_ui/message_list/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_message_harness.dart';

/// An action message in the list is the content view of a centre-aligned
/// [CometChatMessageBubble] with no header, footer or status row, on the
/// transparent fill `BubbleUIBuilder.getBubbleStyle` gives group actions.
Widget _action(String text) => CometChatMessageBubble(
  alignment: BubbleAlignment.center,
  style: const CometChatMessageBubbleStyle(backgroundColor: Color(0x00000000)),
  contentView: CometChatActionBubble(text: text),
);

void _row(
  String fileName,
  String description,
  Widget Function() build, {
  double height = 64,
}) {
  goldenLightDark(
    fileName,
    description,
    size: Size(375, height),
    alignment: Alignment.center,
    padding: EdgeInsets.zero,
    // A list row: full width, unbounded height, content centred. Unbounded
    // height matters — the action bubble is a Container with an alignment,
    // which fills whatever height it is offered.
    build: () => Column(
      mainAxisSize: MainAxisSize.min,
      children: [Center(child: build())],
    ),
  );
}

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      _row(
        'date_separator_absolute',
        'date separator — an older day renders as an absolute date pill',
        // Noon, so no timezone can move it onto a neighbouring day; far enough
        // back that it never becomes "Today", "Yesterday" or a weekday name.
        () => CometChatDate(
          date: DateTime(2023, 11, 14, 12),
          pattern: DateTimePattern.dayDateFormat,
        ),
      );
      _row(
        'date_separator_custom_string',
        'date separator — dateSeparatorPattern output, e.g. "Today"',
        () => CometChatDate(
          date: DateTime(2023, 11, 14, 12),
          pattern: DateTimePattern.dayDateFormat,
          customDateString: 'Today',
        ),
      );
      _row(
        'new_messages_indicator',
        'new-messages indicator — error-coloured rules either side of a label',
        () => const CometChatNewMessageIndicator(),
      );
      _row(
        'action_bubble_short',
        'group-action bubble — short event text, pill hugs the label',
        () => _action('Priya joined'),
      );
      _row(
        'action_bubble_long',
        'group-action bubble — long event text ellipsised at 85% width',
        () => _action(
          'Morgan Reyes changed the scope of Tomas Lindqvist '
          'from participant to moderator',
        ),
      );
    },
  );
}
