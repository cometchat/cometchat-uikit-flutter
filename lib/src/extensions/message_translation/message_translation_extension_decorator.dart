import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class MessageExtensionTranslationDecorator extends DataSourceDecorator {
  String messageTranslationTypeConstant = 'message-translation';
  MessageTranslationConfiguration? configuration;

  MessageExtensionTranslationDecorator(DataSource dataSource,
      {this.configuration})
      : super(dataSource);

  @override
  Widget getTextMessageContentView(TextMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme) {
    return getContentView(message, context, _alignment, theme);
  }

  @override
  List<CometChatMessageOption> getTextMessageOptions(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group) {
    List<CometChatMessageOption> textTemplateOptions = super
        .getTextMessageOptions(loggedInUser, messageObject, context, group);

    
    if (messageObject.metadata!=null && messageObject.metadata!.containsKey('translated_message')==false) {
      textTemplateOptions.add(getOption(context));
    }

    return textTemplateOptions;
  }

  @override
  String getId() {
    return "MessageTranslation";
  }

  CometChatMessageOption getOption(BuildContext context) {
    return CometChatMessageOption(
        id: MessageOptionConstants.translateMessage,
        title: configuration?.optionTitle ??
            Translations.of(context).translate_message,
        icon: configuration?.optionIconUrl ?? AssetConstants.translate,
        packageName:
            configuration?.optionIconUrlPackageName ?? UIConstants.packageName,
        iconTint: configuration?.optionStyle?.iconTint,
        titleStyle: configuration?.optionStyle?.titleStyle,
        onClick:
            (BaseMessage message, CometChatMessageListController state) async {
          _translateMessage(message, context, state);
        });
  }

  _translateMessage(BaseMessage message, BuildContext context,
      CometChatMessageListController state) {
    CometChatTheme theme = cometChatTheme;
    if (message is TextMessage) {
      CometChat.callExtension(
          messageTranslationTypeConstant, 'POST', ExtensionUrls.translate, {
        "msgId": message.id,
        "text": message.text,
        "languages": [Localizations.localeOf(context).languageCode]
      }, onSuccess: (Map<String, dynamic> res) {
        Map<String, dynamic>? data = res["data"];
        if (data != null && data.containsKey('translations')) {
          String? translatedMessage =
              data['translations']?[0]?['message_translated'];

          if (translatedMessage != null && translatedMessage.isNotEmpty && translatedMessage!=message.text) {
            Map<String, dynamic> metadata =
                message.metadata ?? <String, dynamic>{};
            metadata.addAll({'translated_message': translatedMessage});
            message.metadata = metadata;
            state.updateElement(message);
          }
        }
      }, onError: (CometChatException e) {
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
            style: ConfirmDialogStyle(
                backgroundColor: theme.palette.mode == PaletteThemeModes.light
                    ? theme.palette.getBackground()
                    : Color.alphaBlend(theme.palette.getAccent200(),
                        theme.palette.getBackground()),
                shadowColor: theme.palette.getAccent300(),
                confirmButtonTextStyle: TextStyle(
                    fontSize: theme.typography.text2.fontSize,
                    fontWeight: theme.typography.text2.fontWeight,
                    color: theme.palette.getPrimary())),
            confirmButtonText: Translations.of(context).okay,
            onConfirm: () {
              Navigator.pop(context);
            });
      });
    }
  }

  Widget getContentView(TextMessage message, BuildContext context,
      BubbleAlignment alignment, CometChatTheme theme) {
    Widget? child =
        super.getTextMessageContentView(message, context, alignment, theme);
    if (message.metadata != null &&
        message.metadata!.containsKey('translated_message')) {
      return MessageTranslationBubble(
        translatedText: message.metadata?['translated_message'],
        theme: configuration?.theme ?? theme,
        alignment: alignment,
        child: child,
        style: configuration?.style,
      );
    } else {
      return child;
    }
  }

  String getErrorTranslatedText(BuildContext context, String errorCode) {
    if (errorCode == "ERROR_INTERNET_UNAVAILABLE") {
      return Translations.of(context).error_internet_unavailable;
    } else {}

    return Translations.of(context).something_went_wrong_error;
  }
}
