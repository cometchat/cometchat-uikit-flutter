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
///     TemplateUtils.editOption,
///     TemplateUtils.deleteOption,
///     CometChatMessageOptions(id: '',title: 'Share',iconUrl: 'assets url',optionFor: OptionFor.sender)
///   ])
/// ```

class CometChatMessageTemplate {
  CometChatMessageTemplate(
      {required this.type,
      this.category,
      required this.name,
      this.iconUrl,
      this.iconUrlPackageName,
      this.customView,
      this.options,
      this.onActionClick});

  String type;
  String? category;
  String name;
  String? iconUrl;
  String? iconUrlPackageName;
  List<CometChatMessageOptions>? options;
  Widget? Function(BaseMessage)? customView;
  Function(String? user, String? group)? onActionClick;

  addOption(CometChatMessageOptions option) {
    options?.add(option);
  }

  removeOption(String id) {
    options?.removeWhere((CometChatMessageOptions _item) => id == _item.id);
  }

  factory CometChatMessageTemplate.getTemplate(String type) {
    late CometChatMessageTemplate template;
    switch (type) {
      case MessageTypeConstants.text:
        template = TemplateUtils.getDefaultTextTemplate();
        break;
      case MessageTypeConstants.image:
        template = TemplateUtils.getDefaultImageTemplate();
        break;
      case MessageTypeConstants.video:
        template = TemplateUtils.getDefaultVideoTemplate();
        break;
      case MessageTypeConstants.document:
        template = TemplateUtils.getDefaultCollaborativeDocumentTemplate();
        break;
      case MessageTypeConstants.whiteboard:
        template = TemplateUtils.getDefaultCollaborativeWhiteboardTemplate();
        break;
      case MessageTypeConstants.sticker:
        template = TemplateUtils.getDefaultStickerTemplate();
        break;
      case MessageTypeConstants.location:
        template = TemplateUtils.getDefaultLocationTemplate();
        break;
      case MessageTypeConstants.poll:
        template = TemplateUtils.getDefaultPollTemplate();
        break;
      case MessageTypeConstants.groupActions:
        template = TemplateUtils.getDefaultGroupActionsTemplate();
        break;
      case MessageTypeConstants.file:
        template = TemplateUtils.getDefaultFileTemplate();
        break;
      default:
        template = TemplateUtils.getDefaultCustomTemplate();
        break;
    }
    return template;
  }

  @override
  String toString() {
    return 'CometChatMessageTemplate{type: $type, category: $category, name: $name, icon: $iconUrl,customView: $customView, }';
  }
}
