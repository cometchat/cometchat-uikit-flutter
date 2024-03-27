import 'package:flutter/material.dart';

import '../../../../../cometchat_chat_uikit.dart';

///[TextModerationExtensionDecorator] is a the view model for [TextModerationExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class TextModerationExtensionDecorator extends DataSourceDecorator {
  TextModerationExtensionDecorator(DataSource dataSource, {this.configuration})
      : super(dataSource);

  TextModerationConfiguration? configuration;

  @override
  Widget getTextMessageBubble(
      String messageText,
      TextMessage message,
      BuildContext context,
      BubbleAlignment alignment,
      CometChatTheme theme,
      TextBubbleStyle? style) {
    String filteredText = getContentText(message);
    return super.getTextMessageBubble(filteredText, message, context, alignment,
        configuration?.theme ?? theme, configuration?.style ?? style);
  }

  @override
  String getLastConversationMessage(
      Conversation conversation, BuildContext context) {
    BaseMessage? message = conversation.lastMessage;
    if (message != null &&
        message.type == MessageTypeConstants.text &&
        message.category == MessageCategoryConstants.message) {
      return getContentText(message as TextMessage);
    } else {
      return super.getLastConversationMessage(conversation, context);
    }
  }

  String getContentText(TextMessage message) {
    String text;
    text = checkProfanityMessage(message);
    if (text == message.text) {
      text = checkDataMasking(message);
    }
    return text;
  }

  static String checkProfanityMessage(BaseMessage baseMessage) {
    String result = (baseMessage as TextMessage).text;
    Map<String, Map>? extensionList =
        ExtensionModerator.extensionCheck(baseMessage);
    if (extensionList != null) {
      try {
        if (extensionList.containsKey(ExtensionConstants.profanityFilter)) {
          Map<dynamic, dynamic>? profanityFilter =
              extensionList[ExtensionConstants.profanityFilter];

          if (profanityFilter != null) {
            String profanity = profanityFilter["profanity"];
            String cleanMessage = profanityFilter["message_clean"];

            if (profanity == "no") {
              result = (baseMessage).text;
            } else {
              result = cleanMessage;
            }
          }
        } else {
          result = (baseMessage).text;
        }
      } catch (e) {
        debugPrint("$e");
      }
    }
    return result;
  }

  static String checkDataMasking(BaseMessage baseMessage) {
    String result = (baseMessage as TextMessage).text;
    String sensitiveData;
    String messageMasked;
    Map<String, Map>? extensionList =
        ExtensionModerator.extensionCheck(baseMessage);
    if (extensionList != null) {
      try {
        if (extensionList.containsKey(ExtensionConstants.dataMasking)) {
          Map<dynamic, dynamic>? dataMasking =
              extensionList[ExtensionConstants.dataMasking];
          Map<dynamic, dynamic> dataObject = dataMasking?["data"];
          if (dataObject.containsKey("sensitive_data") &&
              dataObject.containsKey("message_masked")) {
            sensitiveData = dataObject["sensitive_data"];
            messageMasked = dataObject["message_masked"];
            if (sensitiveData == "no") {
              result = (baseMessage).text;
            } else {
              result = messageMasked;
            }
          } else if (dataObject.containsKey("action") &&
              dataObject.containsKey("message")) {
            result = dataObject["message"];
          }
        } else {
          result = (baseMessage).text;
        }
      } catch (e, stack) {
        debugPrint(stack.toString());
      }
    }
    return result;
  }

  @override
  String getId() {
    return "profanityBusiness";
  }
}
