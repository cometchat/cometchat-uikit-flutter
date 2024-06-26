import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessageComposerConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatMessageComposer]
///can be used by a component where [CometChatMessageComposer] is a child component
/// ```dart
/// MessageComposerConfiguration(
///      messageComposerStyle: MessageComposerStyle(),
///      sendButtonView: Container(),
///      auxiliaryButtonView:({group, user}) => Container()
///    )
/// ```
class MessageComposerConfiguration {
  const MessageComposerConfiguration({
    this.auxiliaryButtonView,
    this.headerView,
    this.footerView,
    this.secondaryButtonView,
    this.sendButtonView,
    this.attachmentOptions,
    this.text,
    this.onChange,
    this.maxLine,
    this.auxiliaryButtonsAlignment,
    this.placeholderText,
    this.messageComposerStyle,
    this.hideLiveReaction,
    this.stateCallBack,
    this.onError,
    this.attachmentIconURL,
    this.onSendButtonTap,
    this.theme,
    this.disableSoundForMessages = false,
    this.customSoundForMessage,
    this.liveReactionIconURL,
    this.customSoundForMessagePackage,
    this.attachmentIcon,
    this.liveReactionIcon,
    this.recordIcon,
    this.playIcon,
    this.deleteIcon,
    this.stopIcon,
    this.submitIcon,
    this.pauseIcon,
    this.disableTypingEvents,
    this.mediaRecorderStyle,
    this.hideVoiceRecording,
    this.voiceRecordingIcon,
    this.aiOptionStyle,
    this.aiIconPackageName,
    this.aiIcon,
    this.aiIconURL,
    this.textFormatters,
    this.disableMentions,
    this.textEditingController,
  });

  ///[messageComposerStyle] message composer style
  final MessageComposerStyle? messageComposerStyle;

  ///[auxiliaryButtonView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? auxiliaryButtonView;

  ///[headerView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? headerView;

  ///[footerView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? footerView;

  ///[secondaryButtonView] ui component to be forwarded to message input component
  final ComposerWidgetBuilder? secondaryButtonView;

  ///[sendButtonView] ui component to be forwarded to message input component
  final Widget? sendButtonView;

  ///[attachmentOptions] options to display on tapping attachment button
  final ComposerActionsBuilder? attachmentOptions;

  ///[text] initial text for the input field
  final String? text;

  ///[placeholderText] hint text for input field
  final String? placeholderText;

  ///[onChange] callback to handle change in value of text in the input field
  final Function(String)? onChange;

  ///[maxLine] maximum lines allowed to increase in the input field
  final int? maxLine;

  ///[auxiliaryButtonsAlignment] controls position auxiliary button view
  final AuxiliaryButtonsAlignment? auxiliaryButtonsAlignment;

  ///[hideLiveReaction] if true hides live reaction option
  final bool? hideLiveReaction;

  ///[stateCallBack]
  final void Function(CometChatMessageComposerController)? stateCallBack;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[attachmentIconURL] path of the icon to show in the attachments button
  final String? attachmentIconURL;

  ///[onSendButtonTap] some task to execute if user presses the primary/send button
  final Function(BuildContext, BaseMessage, PreviewMessageMode?)?
      onSendButtonTap;

  ///[theme] sets the theme for this component
  final CometChatTheme? theme;

  ///[disableSoundForMessages] if true then disables outgoing message sound
  final bool disableSoundForMessages;

  ///[customSoundForMessage] custom outgoing message sound assets url
  final String? customSoundForMessage;

  ///[liveReactionIconURL] is the path of the icon to show in the live reaction button
  final String? liveReactionIconURL;

  ///if sending sound url from other package pass package name here
  final String? customSoundForMessagePackage;

  ///[attachmentIcon] custom attachment icon
  final Widget? attachmentIcon;

  ///[liveReactionIcon] custom live reaction icon
  final Widget? liveReactionIcon;

  ///[recordIcon] provides icon to the start Icon/widget
  final Widget? recordIcon;

  ///[playIcon] provides icon to the play Icon/widget
  final Widget? playIcon;

  ///[pauseIcon] provides icon to the play Icon/widget
  final Widget? pauseIcon;

  ///[deleteIcon] provides icon to the close Icon/widget
  final Widget? deleteIcon;

  ///[stopIcon] provides icon to the stop Icon/widget
  final Widget? stopIcon;

  ///[submitIcon] provides icon to the submit Icon/widget
  final Widget? submitIcon;

  ///[disableTypingEvents] if true then disables is typing indicator
  final bool? disableTypingEvents;

  ///[mediaRecorderStyle] provides style to the media recorder
  final MediaRecorderStyle? mediaRecorderStyle;

  ///[hideVoiceRecording] provides option to hide voice recording
  final bool? hideVoiceRecording;

  ///[voiceRecordingIcon] provides icon to the voice recording Icon/widget
  final Widget? voiceRecordingIcon;

  ///[aiOptionStyle] sets the ai option sheet style for
  final AIOptionsStyle? aiOptionStyle;

  ///[attachmentIcon] custom ai icon
  final Widget? aiIcon;

  ///[aiIconURL] path of the icon to show in the ai button
  final String? aiIconURL;

  ///[aiIconPackageName] package name to show icon from
  final String? aiIconPackageName;

  ///[textFormatters] is a list of [CometChatTextFormatter] which is used to format the text
  final List<CometChatTextFormatter>? textFormatters;

  ///[disableMentions] disables mentions in the composer
  final bool? disableMentions;

  ///[textEditingController] controls the state of the text field
  final TextEditingController? textEditingController;
}
