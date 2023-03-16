import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class StickersExtensionDecorator extends DataSourceDecorator {
  String stickerTypeConstant = "extension_sticker";
  StickerConfiguration? configuration;

  StickersExtensionDecorator(DataSource dataSource, {this.configuration})
      : super(dataSource);

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
  Widget getAuxiliaryOptions(User? user, Group? group, BuildContext context,
      Map<String, dynamic>? id) {
    List<Widget> auxiliaryButtons = [];

    Widget _widget = super.getAuxiliaryOptions(user, group, context, id);
    auxiliaryButtons.add(_widget);
    auxiliaryButtons.add(getStickerAuxiliaryButton(user, group, context, id));

    return auxiliaryButtons.isEmpty
        ? const SizedBox()
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [...auxiliaryButtons],
          );
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
  List<String> getAllMessageTypes() {
    List<String> ab = super.getAllMessageTypes();
    ab.add(stickerTypeConstant);
    return ab;
  }

  @override
  String getLastConversationMessage(
      Conversation conversation, BuildContext context) {
    BaseMessage? message = conversation.lastMessage;
    if (message != null &&
        message.type == stickerTypeConstant &&
        message.category == MessageCategoryConstants.custom) {
      return Translations.of(context).custom_message_sticker;
    } else {
      return super.getLastConversationMessage(conversation, context);
    }
  }

  CometChatMessageTemplate getTemplate({CometChatTheme? theme}) {
    return CometChatMessageTemplate(
        type: stickerTypeConstant,
        category: CometChatMessageCategory.custom,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment) {
          return CometChatStickerBubble(
            messageObject: (message as CustomMessage),
          );
        },
        options: ChatConfigurator.getDataSource().getCommonOptions,
        bottomView: ChatConfigurator.getDataSource().getBottomView);
  }

  getStickerAuxiliaryButton(User? user, Group? group, BuildContext context,
      Map<String, dynamic>? id) {
    onStickerTap(Sticker st) async {
      Map<String, String> customData = {};
      customData["sticker_url"] = st.stickerUrl;
      customData["sticker_name"] = st.stickerName;

      String receiverID;
      String receiverType;
      int parentMessageId = id?['parentMessageId'] ?? 0;

      if (user != null) {
        receiverID = user.uid;
        receiverType = ReceiverTypeConstants.user;
      } else {
        receiverID = group!.guid;
        receiverType = ReceiverTypeConstants.group;
      }

      User? loggedInUser = await CometChat.getLoggedInUser();
      if (loggedInUser != null) {
        CustomMessage customMessage = CustomMessage(
          receiverUid: receiverID,
          type: stickerTypeConstant,
          customData: customData,
          receiverType: receiverType,
          sender: loggedInUser,
          category: CometChatMessageCategory.custom,
          parentMessageId: parentMessageId,
          muid: DateTime.now().microsecondsSinceEpoch.toString(),
        );

        CometChatUIKit.sendCustomMessage(customMessage);
      }
    }

    return StickerAuxiliaryButton(
      keyboardButtonIcon: configuration?.keyboardButtonIcon,
      stickerButtonIcon: configuration?.stickerButtonIcon,
      theme: configuration?.theme,
      onStickerTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        CometChatUIEvents.showPanel(id, alignment.composerBottom, (context) {
          return CometChatStickerKeyboard(
            onStickerTap: onStickerTap,
            keyboardStyle: configuration?.stickerKeyboardStyle,
            emptyStateText: configuration?.emptyStateText,
            emptyStateView: configuration?.errorStateView,
            errorIcon: configuration?.errorIcon,
            errorStateText: configuration?.errorStateText,
            errorStateView: configuration?.errorStateView,
            loadingStateView: configuration?.loadingStateView,
            theme: configuration?.theme,
          );
        });
      },
      onKeyboardTap: () {
        CometChatUIEvents.hidePanel(
          id,
          alignment.composerBottom,
        );
      },
    );
  }

  @override
  String getId() {
    return "Sticker";
  }
}
