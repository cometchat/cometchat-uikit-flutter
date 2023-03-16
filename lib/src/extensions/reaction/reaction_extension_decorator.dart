import 'package:flutter/material.dart';
import 'dart:developer';

import '../../../../../flutter_chat_ui_kit.dart';

class ReactionExtensionDecorator extends DataSourceDecorator {
  User? loggedInUser;
  ReactionConfiguration? configuration;

  ReactionExtensionDecorator(DataSource dataSource, {this.configuration})
      : super(dataSource) {
    getLoggedInUser();
  }

  getLoggedInUser() async {
    loggedInUser = await CometChat.getLoggedInUser();
  }

  @override
  Widget getBottomView(
      BaseMessage message, BuildContext context, BubbleAlignment _alignment) {
    return getBubble(message, context, _alignment);
  }

  @override
  List<CometChatMessageOption> getCommonOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    List<CometChatMessageOption> messageOptionList =
        super.getCommonOptions(loggedInUser, messageObject, context, group);
    messageOptionList.add(getOption(context));
    return messageOptionList;
  }

  getBubble(
      BaseMessage message, BuildContext context, BubbleAlignment _alignment) {
    return ReactionsBubble(
      messageObject: message,
      loggedInUserId: loggedInUser?.uid ?? '',
      onReactionClick: onReactionClick,
      addReactionIcon: configuration?.addReactionIcon,
      style: configuration?.reactionsStyle,
      theme: configuration?.theme,
    );
  }

  CometChatMessageOption getOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.messageInformation,
        title:
            configuration?.optionTitle ?? Translations.of(context).add_reaction,
        icon: configuration?.optionIconUrl ?? AssetConstants.reactionsAdd,
        packageName:
            configuration?.optionIconUrlPackageName ?? UIConstants.packageName,
        iconTint: configuration?.optionStyle?.iconTint,
        titleStyle: configuration?.optionStyle?.titleStyle,
        onClick:
            (BaseMessage message, CometChatMessageListController state) async {
          String? emoji = await showCometChatEmojiKeyboard(
              context: state.context,
              backgroundColor:
                  configuration?.emojiKeyboardStyle?.backgroundColor,
              categoryLabel:
                  configuration?.emojiKeyboardStyle?.categoryLabelStyle,
              dividerColor: configuration?.emojiKeyboardStyle?.dividerColor,
              selectedCategoryIconColor:
                  configuration?.emojiKeyboardStyle?.selectedCategoryIconColor,
              titleStyle: configuration?.emojiKeyboardStyle?.titleStyle,
              unselectedCategoryIconColor: configuration
                  ?.emojiKeyboardStyle?.unselectedCategoryIconColor);
          if (emoji != null) {
            BaseMessage messageNew =
                _addRemoveReaction(message, emoji, state.loggedInUser!);
            state.updateElement(messageNew);
            CometChat.callExtension(ExtensionConstants.reactions, 'POST',
                ExtensionUrls.reaction, {'msgId': message.id, 'emoji': emoji},
                onSuccess: (Map<String, dynamic> res) {
              debugPrint('on reaction submitted $res');
            }, onError: (CometChatException e) {
              _addRemoveReaction(message, emoji, state.loggedInUser!);
            });
          }
        });
  }

  onReactionClick(String? emoji, BaseMessage message) async {
    User? loggedInUser = await CometChat.getLoggedInUser();
    if (loggedInUser == null) return;

    if (emoji != null) {
      BaseMessage messageNew = _addRemoveReaction(message, emoji, loggedInUser);
      CometChatMessageEvents.ccMessageEdited(
          messageNew, MessageEditStatus.success);
      CometChat.callExtension(ExtensionConstants.reactions, 'POST',
          ExtensionUrls.reaction, {'msgId': message.id, 'emoji': emoji},
          onSuccess: (Map<String, dynamic> res) {
        debugPrint('$res');
      }, onError: (CometChatException e) {
        _addRemoveReaction(message, emoji, loggedInUser);
      });
    }
  }

  BaseMessage _addRemoveReaction(
      BaseMessage message, String emoji, User? loggedInUser) {
    //---giving reactions first time---
    Map<String, dynamic> metadata = message.metadata ?? <String, dynamic>{};

    if (!metadata.containsKey("@injected")) {
      metadata["@injected"] = <String, dynamic>{};
    }
    Map<String, dynamic> injected = metadata["@injected"];

    if (!injected.containsKey("extensions")) {
      metadata["@injected"]["extensions"] = <String, dynamic>{};
    }
    Map<String, dynamic> extensions = metadata["@injected"]["extensions"];

    if (!extensions.containsKey("reactions")) {
      metadata["@injected"]["extensions"]["reactions"] = <String, dynamic>{};
    }
    Map<String, dynamic> reactions;

    try {
      reactions = metadata["@injected"]["extensions"]["reactions"];
    } catch (_) {
      reactions = <String, dynamic>{};
    }

    if (!reactions.containsKey(emoji)) {
      metadata["@injected"]["extensions"]["reactions"]
          [emoji] = <String, dynamic>{};
    }

    Map<String, dynamic> reactedUsers =
        metadata["@injected"]["extensions"]["reactions"][emoji];

    if (!reactedUsers.containsKey(loggedInUser!.uid)) {
      metadata["@injected"]["extensions"]["reactions"][emoji]
          [loggedInUser.uid] = {
        "name": loggedInUser.name,
        "avatar": loggedInUser.avatar
      };
    } else {
      reactedUsers.remove(loggedInUser.uid);
      if (reactedUsers.isEmpty) {
        reactions.remove(emoji);
        metadata["@injected"]["extensions"]["reactions"] = reactions;
      } else {
        metadata["@injected"]["extensions"]["reactions"][emoji] = reactedUsers;
      }
    }

    message.metadata = metadata;
    log("new meta data is ${message.metadata}");
    return message;
  }

  @override
  String getId() {
    return "reaction";
  }
}
