import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[StickersExtensionDecorator] is a the view model for [StickersExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class StickersExtensionDecorator extends DataSourceDecorator {
  String stickerTypeConstant = "extension_sticker";
  StickerConfiguration? configuration;

  StickersExtensionDecorator(super.dataSource, {this.configuration});

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
  Widget getAuxiliaryOptions(User? user, Group? group, BuildContext context,
      Map<String, dynamic>? id, CometChatTheme? theme) {
    List<Widget> auxiliaryButtons = [];

    Widget auxiliaryOption =
        super.getAuxiliaryOptions(user, group, context, id, theme);
    auxiliaryButtons.add(auxiliaryOption);
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
      return Translations.of(context).customMessageSticker;
    } else {
      return super.getLastConversationMessage(conversation, context);
    }
  }

  CometChatMessageTemplate getTemplate({CometChatTheme? theme}) {
    return CometChatMessageTemplate(
        type: stickerTypeConstant,
        category: CometChatMessageCategory.custom,
        contentView: (BaseMessage message, BuildContext context,
            BubbleAlignment alignment,
            {AdditionalConfigurations? additionalConfigurations}) {
          if (message.deletedAt != null) {
            return super
                .getDeleteMessageBubble(message, theme ?? cometChatTheme);
          } else {
            return CometChatStickerBubble(
              messageObject: (message as CustomMessage),
            );
          }
        },
        options: CometChatUIKit.getDataSource().getCommonOptions,
        bottomView: CometChatUIKit.getDataSource().getBottomView);
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
          updateConversation: true,
          metadata: {
            UpdateSettingsConstant.incrementUnreadCount: true,
          },
        );

        CometChatUIKit.sendCustomMessage(customMessage);
      }
    }

    return StickerAuxiliaryButton(
      keyboardButtonIcon: configuration?.keyboardButtonIcon,
      stickerButtonIcon: configuration?.stickerButtonIcon,
      theme: configuration?.theme,
      stickerIconTint: configuration?.stickerIconTint,
      keyboardIconTint: configuration?.keyboardIconTint,
      onStickerTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        CometChatUIEvents.showPanel(id, CustomUIPosition.composerBottom,
            (context) {
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
          CustomUIPosition.composerBottom,
        );
      },
    );
  }

  @override
  String getId() {
    return "Sticker";
  }
}
