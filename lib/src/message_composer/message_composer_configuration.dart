import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///Configuration class for [CometChatMessageComposer]
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
    this.onSendButtonClick,
    this.theme,
    this.disableSoundForMessages = false,
    this.customSoundForMessage,
    this.liveReactionIconURL,
    this.customSoundForMessagePackage,
    this.attachmentIcon,
    this.liveReactionIcon
  });

  ///[messageComposerStyle] message composer style
  final MessageComposerStyle? messageComposerStyle;

  ///[auxiliaryButtonView] ui component to be forwarded to message input component
  final Widget Function({User? user, Group? group})? auxiliaryButtonView;

  ///[headerView] ui component to be forwarded to message input component
  final Widget? Function(BuildContext, {User? user, Group? group})? headerView;

  ///[footerView] ui component to be forwarded to message input component
  final Widget? Function(BuildContext, {User? user, Group? group})? footerView;

  ///[secondaryButtonView] ui component to be forwarded to message input component
  final Widget Function({User? user, Group? group})? secondaryButtonView;

  ///[sendButtonView] ui component to be forwarded to message input component
  final Widget? sendButtonView;

  ///[attachmentOptions] options to display on tapping attachment button
  final List<CometChatMessageComposerAction>? attachmentOptions;

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

  ///[onSendButtonClick] some task to execute if user presses the primary/send button
  final Function()? onSendButtonClick;

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
}
