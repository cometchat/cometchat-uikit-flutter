import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///Template class for setting message types
///
///```dart
/// CometChatMessageTemplate.getTemplate(
///      MessageTypeConstants.text);
///CometChatMessageTemplate(
///   name: 'custom',
///   type: 'custom',
///   customView: (BaseMessage baseMessage) {},
///   options: [
///     TemplateUtils2.editOption,
///     TemplateUtils2.deleteOption,
///     CometChatMessageOption(id: '',title: 'Share',iconUrl: 'assets url',optionFor: OptionFor.sender)
///   ])
/// ```

class CometChatMessageTemplate {
  CometChatMessageTemplate(
      {required this.type,
      required this.category,
      this.bubbleView,
      this.options,
      this.headerView,
      this.footerView,
      this.contentView,
      this.bottomView});

  String type;
  String category;
  Widget? Function(BaseMessage, BuildContext, BubbleAlignment alignment)?
      bubbleView;
  Widget? Function(BaseMessage, BuildContext, BubbleAlignment alignment)?
      headerView;
  Widget? Function(BaseMessage, BuildContext, BubbleAlignment alignment)?
      footerView;
  Widget? Function(BaseMessage, BuildContext, BubbleAlignment alignment)?
      contentView;
  List<CometChatMessageOption>? Function(User loggedInUser,
      BaseMessage messageObject, BuildContext context, Group? group)? options;
  Widget? Function(BaseMessage, BuildContext, BubbleAlignment alignment)?
      bottomView;

  @override
  String toString() {
    return 'CometChatMessageTemplate{type: $type, category: $category, bubbleView: $bubbleView, headerView: $headerView, footerView: $footerView, contentView: $contentView, options: $options}';
  }
}
