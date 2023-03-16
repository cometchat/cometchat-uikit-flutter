import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class PollsConfiguration {
  PollsConfiguration(
      {this.createPollsStyle,
      this.pollsBubbleStyle,
      this.theme,
      this.title,
      this.questionPlaceholderText,
      this.answerPlaceholderText,
      this.answerHelpText,
      this.addAnswerText,
      this.deleteIcon,
      this.closeIcon,
      this.createPollIcon,
      this.optionTitle,
      this.optionIconUrl,
      this.optionIconUrlPackageName,
      this.optionStyle});

  ///[createPollsStyle] styling parameters for creating poll
  final CreatePollsStyle? createPollsStyle;

  ///[pollsBubbleStyle] styling parameters for polls bubble
  final PollsBubbleStyle? pollsBubbleStyle;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

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

  ///[optionIconUrl] is the path to the icon image for the option for this extension
  final String? optionIconUrl;

  ///[optionIconUrlPackageName] is the name of the package where the icon for the option for this extension is located
  final String? optionIconUrlPackageName;

  ///[optionStyle] provides style to the option that generates a polls
  final PollsOptionStyle? optionStyle;
}
