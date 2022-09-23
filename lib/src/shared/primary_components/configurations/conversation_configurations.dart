import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A Configuration object for [CometchatConversation]
///
/// this Configuration object can be used to configure [CometchatConversation] properties
/// from parents

/// {@tool snippet}
/// ```dart
/// ConversationConfigurations(
/// avatarConfiguration:
/// const AvatarConfiguration(),
/// conversationListConfiguration:
/// const  ConversationListConfigurations(),
/// title: "CHATS",
/// dateConfiguration:
/// const DateConfiguration(),
/// conversationType: ConversationTypes.both,
/// badgeCountConfiguration:const BadgeCountConfiguration(),
/// conversationListItemConfiguration:ConversationListItemConfigurations(
/// inputData:ConversationInputData<Conversation>
/// (subtitle:(Conversation
/// conv) {
/// return "Conv Subtitle";
/// }))),
///```
/// {@end-tool}
class ConversationConfigurations {
  const ConversationConfigurations({
    this.conversationType = ConversationTypes.both,
    this.title,
    this.showBackButton = true,
    this.backButton,
    this.hideStartConversation = false,
    this.startConversationIcon,
    this.hideSearch = false,
    this.search,
    this.avatarConfiguration,
    this.statusIndicatorConfiguration,
    this.badgeCountConfiguration,
    this.conversationListItemConfiguration,
    this.dateConfiguration,
    this.messageReceiptConfiguration,
    this.conversationListConfiguration,
  });

  ///[conversationType] conversation type user/group/both
  final ConversationTypes conversationType;

  ///[title] title text
  final String? title;

  ///[showBackButton] show back button on true
  final bool showBackButton;

  ///[backButton] icon for back button
  final Widget? backButton;

  ///[hideStartConversation] if true then hides start conversation icon
  final bool hideStartConversation;

  ///[startConversationIcon] start conversation icon
  final Icon? startConversationIcon;

  ///[hideSearch] if true then hides search box
  final bool hideSearch;

  ///[search] search box
  final Widget? search;

  ///[avatarConfigurations]
  final AvatarConfiguration? avatarConfiguration;

  ///[statusIndicatorConfiguration]
  final StatusIndicatorConfiguration? statusIndicatorConfiguration;

  ///[badgeCountConfiguration]
  final BadgeCountConfiguration? badgeCountConfiguration;

  ///[conversationListItemConfigurations]
  final ConversationListItemConfigurations? conversationListItemConfiguration;

  ///[dateConfiguration]
  final DateConfiguration? dateConfiguration;

  ///[messageReceiptConfiguration]
  final MessageReceiptConfiguration? messageReceiptConfiguration;

  ///[conversationListConfigurations]
  final ConversationListConfigurations? conversationListConfiguration;
}
