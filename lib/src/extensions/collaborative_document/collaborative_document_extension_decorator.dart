import 'package:flutter/material.dart';
import '../../../../../flutter_chat_ui_kit.dart';

class CollaborativeDocumentExtensionDecorator extends DataSourceDecorator {
  String collaborativeDocumentExtensionTypeConstant = ExtensionType.document;
  CollaborativeDocumentConfiguration? configuration;

  User? loggedInUser;

  CollaborativeDocumentExtensionDecorator(DataSource dataSource,
      {this.configuration})
      : super(dataSource) {
    getLoggedInUser();
  }

  getLoggedInUser() async {
    loggedInUser = await CometChat.getLoggedInUser();
  }

  @override
  String getId() {
    return "CollaborativeDocument";
  }

  @override
  List<String> getAllMessageTypes() {
    List<String> ab = super.getAllMessageTypes();
    ab.add(collaborativeDocumentExtensionTypeConstant);

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
        message.type == collaborativeDocumentExtensionTypeConstant &&
        message.category == MessageCategoryConstants.custom) {
      return Translations.of(context).custom_message_document;
    } else {
      return super.getLastConversationMessage(conversation, context);
    }
  }

  CometChatMessageTemplate getTemplate({CometChatTheme? theme}) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    return CometChatMessageTemplate(
        type: collaborativeDocumentExtensionTypeConstant,
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
    return CometChatCollaborativeDocumentBubble(
      url: getWebViewUrl(_customMessage),
      title: configuration?.title,
      subtitle: configuration?.subtitle,
      buttonText: configuration?.buttonText,
      icon: configuration?.icon,
      theme: configuration?.theme,
      style: DocumentBubbleStyle(
          background: configuration?.style?.background,
          dividerColor: configuration?.style?.dividerColor,
          buttonTextStyle: configuration?.style?.buttonTextStyle,
          subtitleStyle: configuration?.style?.subtitleStyle,
          titleStyle: configuration?.style?.titleStyle,
          iconTint: configuration?.style?.iconTint,
          webViewAppBarColor: configuration?.style?.webViewAppBarColor,
          webViewBackIconColor: configuration?.style?.webViewBackIconColor,
          webViewTitleStyle: configuration?.style?.webViewTitleStyle),
    );
  }

  sendCollaborativeDocument(BuildContext context, String receiverID,
      String receiverType, CometChatTheme theme) {
    CometChat.callExtension(
        ExtensionConstants.document,
        "POST",
        ExtensionUrls.document,
        {"receiver": receiverID, "receiverType": receiverType},
        onSuccess: (Map<String, dynamic> map) {
      debugPrint("Success map $map");
    }, onError: (CometChatException e) {
      debugPrint('$e');
      String _error = getErrorTranslatedText(context, e.code);
      showCometChatConfirmDialog(
          context: context,
          messageText: Text(
            _error,
            style: TextStyle(
                fontSize: theme.typography.title2.fontSize,
                fontWeight: theme.typography.title2.fontWeight,
                color: theme.palette.getAccent(),
                fontFamily: theme.typography.title2.fontFamily),
          ),
          confirmButtonText: Translations.of(context).try_again,
          cancelButtonText: Translations.of(context).cancel_capital,
          onConfirm: () {
            Navigator.pop(context);
            sendCollaborativeDocument(context, receiverID, receiverType, theme);
          });
    });
  }

  CometChatMessageComposerAction getAttachmentOption(
      CometChatTheme _theme, BuildContext context, Map<String, dynamic>? id) {
    return CometChatMessageComposerAction(
        id: collaborativeDocumentExtensionTypeConstant,
        title: configuration?.optionTitle ??
            Translations.of(context).collaborative_document,
        iconUrl: configuration?.optionIconUrl ??
            AssetConstants.collaborativeDocument,
        iconUrlPackageName:
            configuration?.optionIconUrlPackageName ?? UIConstants.packageName,
        titleStyle: configuration?.optionStyle?.titleStyle ??
            TextStyle(
                color: _theme.palette.getAccent(),
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight),
        iconTint: configuration?.optionStyle?.iconTint ??
            _theme.palette.getAccent700(),
        background: configuration?.optionStyle?.background,
        cornerRadius: configuration?.optionStyle?.cornerRadius,
        iconBackground: configuration?.optionStyle?.iconBackground,
        iconCornerRadius: configuration?.optionStyle?.iconCornerRadius,
        onItemClick: (String? uid, String? guid) {
          String receiverType = '';
          if (uid == null) {
            receiverType = ReceiverTypeConstants.group;
          } else {
            receiverType = ReceiverTypeConstants.user;
          }
          sendCollaborativeDocument(
              context, uid ?? guid ?? '', receiverType, _theme);
        });
  }

  String? getWebViewUrl(CustomMessage? messageObject) {
    if (messageObject != null &&
        messageObject.customData != null &&
        messageObject.customData!.containsKey("document")) {
      Map? document = messageObject.customData?["document"];
      if (document != null && document.containsKey("document_url")) {
        return document["document_url"];
      }
    }
    return null;
  }

  String getErrorTranslatedText(BuildContext context, String errorCode) {
    if (errorCode == "ERROR_INTERNET_UNAVAILABLE") {
      return Translations.of(context).error_internet_unavailable;
    } else {}

    return Translations.of(context).something_went_wrong_error;
  }

  bool isNotThread(Map<String, dynamic>? id) {
    int? parentMessageId;
    if (id != null && id.containsKey('parentMessageId')) {
      parentMessageId = id['parentMessageId'];
    }
    return parentMessageId == 0 || parentMessageId == null;
  }
}
