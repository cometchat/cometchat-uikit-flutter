import 'package:flutter/material.dart';

import '../../flutter_chat_ui_kit.dart';

///Configuration class for [CometChatMessageList]
///
/// ```dart
///
/// MessageListConfiguration(
///          messageAlignment: ChatAlignment.standard,
///      messageTypes: [
///        TemplateUtils
///            .getAudioMessageTemplate(),
///        TemplateUtils
///            .getTextMessageTemplate(),
///        CometChatMessageTemplate(
///            type: 'custom', name: 'custom')
///      ],
///      customView: CustomView(),
///      excludeMessageTypes: [
///        CometChatUIMessageTypes.image
///      ],
///      errorText: 'Something went wrong',
///      emptyText: 'No messages',
///      limit: 30,
///      onlyUnread: false,
///      hideDeletedMessages: false,
///      hideThreadReplies: false,
///      tags: [],
///      hideError: false,
///      scrollToBottomOnNewMessage: false,
///      customIncomingMessageSound: 'asset url',
///      excludedMessageOptions: [
///        MessageOptionConstants.editMessage
///      ],
///      hideMessagesFromBlockedUsers: false,
///      receivedMessageInputData:
///          MessageInputData(
///              title: true, thumbnail: true),
///      sentMessageInputData: MessageInputData(
///          title: false, thumbnail: false),
///    )
///
/// ```
///
///
class MessageListConfiguration {
  const MessageListConfiguration({
    this.messagesRequestBuilder,
    this.messageListStyle,
    this.controller,
    this.emptyStateText,
    this.errorStateText,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.hideError,
    this.avatarStyle,
    this.disableSoundForMessages,
    this.customSoundForMessages,
    this.customSoundForMessagePackage,
    this.readIcon,
    this.deliveredIcon,
    this.sentIcon,
    this.waitIcon,
    this.alignment,
    this.showAvatar,
    this.datePattern,
    this.hideTimestamp,
    this.timestampAlignment,
    this.templates,
    this.newMessageIndicatorText,
    this.scrollToBottomOnNewMessages,
    this.onThreadRepliesClick,
    this.headerView,
    this.footerView,
    this.dateSeparatorPattern,
    this.onError,
    this.theme,
    this.disableReceipt = false,
  });

  ///[messagesRequestBuilder] custom request builder for fetching messages
  final MessagesRequestBuilder? messagesRequestBuilder;

  ///[messageListStyle] sets style
  final MessageListStyle? messageListStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state behind the dialog
  final WidgetBuilder? errorStateView;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[avatarStyle] set style for avatar visible in leading view of message bubble
  final AvatarStyle? avatarStyle;

  final bool? disableSoundForMessages;

  ///asset url to Sound
  final String? customSoundForMessages;

  ///if sending sound url from other package pass package name here
  final String? customSoundForMessagePackage;

  ///custom read icon visible at read receipt
  final Widget? readIcon;

  ///custom message delivered icon
  final Widget? deliveredIcon;

  /// custom sent icon visible at read receipt
  final Widget? sentIcon;

  ///custom wait icon visible at read receipt
  final Widget? waitIcon;

  ///used to set the alignment of messages in CometChatMessageList. It can be either "leftAligned" or "standard"
  final ChatAlignment? alignment;

  ///toggle visibility for avatar
  final bool? showAvatar;

  ///datePattern custom date pattern visible in receipts
  final String Function(BaseMessage message)? datePattern;

  ///[hideTimestamp] set style for avatar
  final bool? hideTimestamp;

  ///[timestampAlignment] set style for avatar
  final TimeAlignment? timestampAlignment;

  ///[templates] set message type allowed
  final List<CometChatMessageTemplate>? templates;

  ///[newMessageIndicatorText] set style for avatar
  final String? newMessageIndicatorText;

  ///Should scroll to bottom on new message?, by default false
  final bool? scrollToBottomOnNewMessages;

  ///call back for click on thread indicator
  final ThreadRepliesClick? onThreadRepliesClick;

  ///[footerView] sets custom widget to footer
  ///
  /// typically name is shown
  final WidgetBuilder? headerView;

  ///[footerView] sets custom widget to footer
  ///
  /// typically time and read receipt is shown
  final WidgetBuilder? footerView;

  ///[dateSeparatorPattern] pattern for  date separator
  final String Function(DateTime)? dateSeparatorPattern;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[disableReceipt] controls visibility of read receipts
  final bool? disableReceipt;
}
