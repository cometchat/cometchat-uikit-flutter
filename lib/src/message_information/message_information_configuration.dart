import '../../cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

///[MessageInformationConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatMessageInformation]
///can be used by a component where [CometChatConversationsWithMessages] is a child component
class MessageInformationConfiguration {
  const MessageInformationConfiguration({
    this.title,
    this.closeIcon,
    this.messageInformationStyle,
    this.theme,
    this.onClose,
    this.bubbleView,
    this.listItemView,
    this.subTitleView,
    this.onError,
    this.receiptDatePattern,
    this.listItemStyle,
    this.readIcon,
    this.deliveredIcon,
    this.loadingStateView,
    this.loadingIconUrl,
    this.errorStateText,
    this.emptyStateView,
    this.emptyStateText,
    this.errorStateView,
  });

  ///[title] to be shown at head
  final String? title;

  ///[bubbleView] bubble view for parent message
  final Widget Function(BaseMessage, BuildContext context)? bubbleView;

  ///[listItemView] list item view for parent message
  final Widget Function(BaseMessage message, MessageReceipt messageReceipt,
      BuildContext context)? listItemView;

  ///[sunTitleView] gives subtitle view
  final Widget Function(BaseMessage message, MessageReceipt messageReceipt,
      BuildContext context)? subTitleView;

  ///[receiptDatePattern] to format receipt date
  final String? receiptDatePattern;

  ///to update Close Icon
  final Widget? closeIcon;

  ///[onClose] call function to be called on close button click
  final VoidCallback? onClose;

  ///[onError] callback triggered in case any error happens when fetching groups
  final OnError? onError;

  ///[messageInformationStyle] style parameter
  final MessageInformationStyle? messageInformationStyle;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///read icon widget
  final Widget? readIcon;

  ///delivered icon widget
  final Widget? deliveredIcon;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[loadingIconUrl] url to be displayed when loading
  final String? loadingIconUrl;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[errorStateView] returns view fow error state
  final WidgetBuilder? errorStateView;
}
