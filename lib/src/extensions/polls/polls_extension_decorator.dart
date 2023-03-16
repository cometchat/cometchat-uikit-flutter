import 'package:flutter/material.dart';
import '../../../../../flutter_chat_ui_kit.dart';

class PollsExtensionDecorator extends DataSourceDecorator {
  String pollsTypeConstant = "extension_poll";
  PollsConfiguration? configuration;

  User? loggedInUser;

  PollsExtensionDecorator(DataSource dataSource, {this.configuration})
      : super(dataSource) {
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
    CometChatTheme _theme = theme ?? cometChatTheme;

    List<CometChatMessageTemplate> templateList =
        super.getAllMessageTemplates(theme: _theme);

    templateList.add(getTemplate(theme: _theme));

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
      return Translations.of(context).custom_message_poll;
    } else {
      return super.getLastConversationMessage(conversation, context);
    }
  }

  CometChatMessageTemplate getTemplate({CometChatTheme? theme}) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    return CometChatMessageTemplate(
        type: pollsTypeConstant,
        category: CometChatMessageCategory.custom,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment) {
          return getContentView(message as CustomMessage, _theme, context);
        },
        options: ChatConfigurator.getDataSource().getCommonOptions,
        bottomView: ChatConfigurator.getDataSource().getBottomView);
  }

  Widget getContentView(CustomMessage _customMessage, CometChatTheme _theme,
      BuildContext context) {
    if (_customMessage.deletedAt != null) {
      return super.getDeleteMessageBubble(_customMessage, _theme);
    }
    return CometChatPollsBubble(
      loggedInUser: loggedInUser?.uid,
      theme: configuration?.theme ?? _theme,
      choosePoll: choosePoll,
      senderUid: _customMessage.sender?.uid,
      pollQuestion: _customMessage.customData?["question"] ?? "",
      pollId: _customMessage.customData?["id"],
      metadata: getPollsResult(_customMessage),
      style: configuration?.pollsBubbleStyle,
    );
  }

  CometChatMessageComposerAction getAttachmentOption(
      CometChatTheme _theme, BuildContext context, Map<String, dynamic>? id) {
    return CometChatMessageComposerAction(
        id: pollsTypeConstant,
        title:
            configuration?.optionTitle ?? Translations.of(context).poll + 's',
        iconUrl: configuration?.optionIconUrl ?? AssetConstants.polls,
        iconUrlPackageName:
            configuration?.optionIconUrlPackageName ?? UIConstants.packageName,
        titleStyle: TextStyle(
                color: _theme.palette.getAccent(),
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight)
            .merge(configuration?.optionStyle?.titleStyle),
        iconTint: configuration?.optionStyle?.iconTint ??
            _theme.palette.getAccent700(),
        background: configuration?.optionStyle?.background,
        cornerRadius: configuration?.optionStyle?.cornerRadius,
        iconBackground: configuration?.optionStyle?.iconBackground,
        iconCornerRadius: configuration?.optionStyle?.iconCornerRadius,
        onItemClick: (String? uid, String? guid) {
          if (uid != null || guid != null) {
            return Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CometChatCreatePoll(
                          user: uid,
                          group: guid,
                          theme: _theme,
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
    Map<String, dynamic> _result = {};
    Map<String, Map>? extensionList =
        ExtensionModerator.extensionCheck(baseMessage);
    if (extensionList != null) {
      try {
        if (extensionList.containsKey(ExtensionConstants.polls)) {
          Map? _polls = extensionList[ExtensionConstants.polls];
          if (_polls != null) {
            if (_polls.containsKey("results")) {
              _result = _polls["results"];
            }
          }
        }
      } catch (e, stacktrace) {
        debugPrint("$stacktrace");
      }
    }
    return _result;
  }

  bool isNotThread(Map<String, dynamic>? id) {
    int? parentMessageId;
    if (id != null && id.containsKey('parentMessageId')) {
      parentMessageId = id['parentMessageId'];
    }
    return parentMessageId == 0 || parentMessageId == null;
  }
}
