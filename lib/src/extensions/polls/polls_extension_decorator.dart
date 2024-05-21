import 'package:flutter/material.dart';
import '../../../../../cometchat_chat_uikit.dart';

///[PollsExtensionDecorator] is a the view model for [PollsExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class PollsExtensionDecorator extends DataSourceDecorator {
  String pollsTypeConstant = "extension_poll";
  PollsConfiguration? configuration;

  User? loggedInUser;

  PollsExtensionDecorator(super.dataSource, {this.configuration}) {
    getLoggedInUser();
  }

  getLoggedInUser() async {
    loggedInUser = await CometChat.getLoggedInUser();
  }

  @override
  String getId() {
    return "Polls";
  }

  @override
  List<String> getAllMessageTypes() {
    List<String> ab = super.getAllMessageTypes();
    ab.add(pollsTypeConstant);

    return ab;
  }

  @override
  List<String> getAllMessageCategories() {
    List<String> categoryList = super.getAllMessageCategories();
    if (!categoryList.contains(MessageCategoryConstants.custom)) {
      categoryList.add(MessageCategoryConstants.custom);
    }
    return categoryList;
  }

  @override
  List<CometChatMessageTemplate> getAllMessageTemplates(
      {CometChatTheme? theme}) {
    CometChatTheme theme0 = theme ?? cometChatTheme;

    List<CometChatMessageTemplate> templateList =
        super.getAllMessageTemplates(theme: theme0);

    templateList.add(getTemplate(theme: theme0));

    return templateList;
  }

  @override
  List<CometChatMessageComposerAction> getAttachmentOptions(
      CometChatTheme theme, BuildContext context, Map<String, dynamic>? id) {
    List<CometChatMessageComposerAction> actions =
        super.getAttachmentOptions(theme, context, id);

    if (isNotThread(id)) {
      actions.add(getAttachmentOption(theme, context, id));
    }

    return actions;
  }

  @override
  String getLastConversationMessage(
      Conversation conversation, BuildContext context) {
    BaseMessage? message = conversation.lastMessage;
    if (message != null &&
        message.type == pollsTypeConstant &&
        message.category == MessageCategoryConstants.custom) {
      return Translations.of(context).customMessagePoll;
    } else {
      return super.getLastConversationMessage(conversation, context);
    }
  }

  CometChatMessageTemplate getTemplate({CometChatTheme? theme}) {
    CometChatTheme theme0 = theme ?? cometChatTheme;

    return CometChatMessageTemplate(
        type: pollsTypeConstant,
        category: CometChatMessageCategory.custom,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment,
            {AdditionalConfigurations? additionalConfigurations}) {
          return getContentView(message as CustomMessage, theme0, context);
        },
        options: CometChatUIKit.getDataSource().getCommonOptions,
        bottomView: CometChatUIKit.getDataSource().getBottomView);
  }

  Widget getContentView(
      CustomMessage customMessage, CometChatTheme theme, BuildContext context) {
    if (customMessage.deletedAt != null) {
      return super.getDeleteMessageBubble(customMessage, theme);
    }
    return CometChatPollsBubble(
      loggedInUser: loggedInUser?.uid,
      theme: configuration?.theme ?? theme,
      choosePoll: choosePoll,
      senderUid: customMessage.sender?.uid,
      pollQuestion: customMessage.customData?["question"] ?? "",
      pollId: customMessage.customData?["id"],
      metadata: getPollsResult(customMessage),
      style: configuration?.pollsBubbleStyle,
    );
  }

  CometChatMessageComposerAction getAttachmentOption(
      CometChatTheme theme, BuildContext context, Map<String, dynamic>? id) {
    return CometChatMessageComposerAction(
        id: pollsTypeConstant,
        title:
            configuration?.optionTitle ?? '${Translations.of(context).poll}s',
        iconUrl: configuration?.optionIconUrl ?? AssetConstants.polls,
        iconUrlPackageName:
            configuration?.optionIconUrlPackageName ?? UIConstants.packageName,
        titleStyle: TextStyle(
                color: theme.palette.getAccent(),
                fontSize: theme.typography.subtitle1.fontSize,
                fontWeight: theme.typography.subtitle1.fontWeight)
            .merge(configuration?.optionStyle?.titleStyle),
        iconTint: configuration?.optionStyle?.iconTint ??
            theme.palette.getAccent700(),
        background: configuration?.optionStyle?.background,
        cornerRadius: configuration?.optionStyle?.cornerRadius,
        iconBackground: configuration?.optionStyle?.iconBackground,
        iconCornerRadius: configuration?.optionStyle?.iconCornerRadius,
        onItemClick: (context, user, group) {
          String? uid, guid;
          if (user != null) {
            uid = user.uid;
          }
          if (group != null) {
            guid = group.guid;
          }
          if (uid != null || guid != null) {
            return Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CreatePoll(
                          user: uid,
                          group: guid,
                          theme: theme,
                          style: configuration?.createPollsStyle,
                          addAnswerText: configuration?.addAnswerText,
                          answerHelpText: configuration?.answerHelpText,
                          answerPlaceholderText:
                              configuration?.answerPlaceholderText,
                          closeIcon: configuration?.closeIcon,
                          createPollIcon: configuration?.createPollIcon,
                          deleteIcon: configuration?.deleteIcon,
                          questionPlaceholderText:
                              configuration?.questionPlaceholderText,
                          title: configuration?.title,
                        )));
          }
        });
  }

  Future<void> choosePoll(String vote, String id) async {
    Map<String, dynamic> body = {"vote": vote, "id": id};

    await CometChat.callExtension(
        ExtensionConstants.polls, "POST", ExtensionUrls.votePoll, body,
        onSuccess: (Map<String, dynamic> map) {},
        onError: (CometChatException e) {
      debugPrint('${e.message}');
    });
  }

  Map<String, dynamic> getPollsResult(BaseMessage baseMessage) {
    Map<String, dynamic> result = {};
    Map<String, Map>? extensionList =
        ExtensionModerator.extensionCheck(baseMessage);
    if (extensionList != null) {
      try {
        if (extensionList.containsKey(ExtensionConstants.polls)) {
          Map? polls = extensionList[ExtensionConstants.polls];
          if (polls != null) {
            if (polls.containsKey("results")) {
              result = polls["results"];
            }
          }
        }
      } catch (e, stacktrace) {
        debugPrint("$stacktrace");
      }
    }
    return result;
  }

  bool isNotThread(Map<String, dynamic>? id) {
    int? parentMessageId;
    if (id != null && id.containsKey('parentMessageId')) {
      parentMessageId = id['parentMessageId'];
    }
    return parentMessageId == 0 || parentMessageId == null;
  }
}
