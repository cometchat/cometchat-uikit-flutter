import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[PollsConfiguration] configured the v5 polls extension. No v6 API accepts it:
/// the extension is enabled from the CometChat Dashboard, and the
/// deprecation message names the components that now configure what it
/// described.
@Deprecated(
  'No API in v6 accepts an extension configuration object; the polls extension is enabled from the CometChat Dashboard. Style the poll bubble with pollsBubbleStyle on CometChatIncomingMessageBubbleStyle and CometChatOutgoingMessageBubbleStyle, replace or hide the composer\'s poll option with CometChatMessageComposer.attachmentOptions (id ExtensionType.extensionPoll) or hidePollsOption, and style the option sheet with CometChatMessageComposerStyle.attachmentOptionSheetStyle. The create-poll sheet\'s title, placeholder and help texts and its icons have no replacement. Will be removed in 7.0.0.',
)
class PollsConfiguration {
  /// Creates a [PollsConfiguration].
  PollsConfiguration({
    this.pollsBubbleStyle,
    this.title,
    this.questionPlaceholderText,
    this.answerPlaceholderText,
    this.answerHelpText,
    this.addAnswerText,
    this.deleteIcon,
    this.closeIcon,
    this.createPollIcon,
    this.optionTitle,
    this.optionIcon,
    this.optionStyle,
  });

  ///[pollsBubbleStyle] styling parameters for polls bubble
  final CometChatPollsBubbleStyle? pollsBubbleStyle;

  ///[title] title default is 'Create Poll'
  final String? title;

  ///[questionPlaceholderText] default is 'Question'
  final String? questionPlaceholderText;

  ///[answerPlaceholderText] default is 'Answer 1'
  final String? answerPlaceholderText;

  ///[answerHelpText] default is 'SET THE ANSWERS'
  final String? answerHelpText;

  ///[addAnswerText] default is 'Add Another Answer'
  final String? addAnswerText;

  ///[deleteIcon]
  final Widget? deleteIcon;

  ///[closeIcon] replace close icon
  final Widget? closeIcon;

  ///[createPollIcon] replace poll icon
  final Widget? createPollIcon;

  ///[optionTitle] is the name for the option for this extension
  final String? optionTitle;

  ///[optionIcon] is the icon for the option for this extension
  final Widget? optionIcon;

  ///[optionStyle] provides style to the option that generates a polls
  final PollsOptionStyle? optionStyle;
}
