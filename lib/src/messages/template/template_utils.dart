import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

///Utils class related to message template
class TemplateUtils {
  static const editOption = CometChatMessageOptions(
      id: MessageOptionConstants.editMessage,
      title: "Edit",
      iconUrl: "assets/icons/edit.png",
      optionFor: OptionFor.sender,
      packageName: UIConstants.packageName);
  static CometChatMessageOptions deleteOption = const CometChatMessageOptions(
      id: MessageOptionConstants.deleteMessage,
      title: "Delete",
      iconUrl: "assets/icons/delete.png",
      optionFor: OptionFor.sender,
      packageName: UIConstants.packageName);
  static const replyOption = CometChatMessageOptions(
      id: MessageOptionConstants.replyMessage,
      title: "Reply",
      iconUrl: "assets/icons/reply.png",
      optionFor: OptionFor.both,
      packageName: UIConstants.packageName);
  static const replyInThreadOption = CometChatMessageOptions(
      id: MessageOptionConstants.replyInThreadMessage,
      title: "Start Thread",
      iconUrl: "assets/icons/thread.png",
      optionFor: OptionFor.both,
      packageName: UIConstants.packageName);
  static const shareOption = CometChatMessageOptions(
      id: MessageOptionConstants.shareMessage,
      title: "Share",
      iconUrl: "assets/icons/share.png",
      optionFor: OptionFor.both);
  static const copyOption = CometChatMessageOptions(
      id: MessageOptionConstants.copyMessage,
      title: "Copy Text",
      iconUrl: "assets/icons/copy.png",
      optionFor: OptionFor.both,
      packageName: UIConstants.packageName);
  static const forwardOption = CometChatMessageOptions(
      id: MessageOptionConstants.forwardMessage,
      title: "Forward",
      iconUrl: "assets/icons/forward.png",
      optionFor: OptionFor.both,
      packageName: UIConstants.packageName);
  static const informationOption = CometChatMessageOptions(
      id: MessageOptionConstants.messageInformation,
      title: "Information",
      iconUrl: "assets/icons/info.png",
      optionFor: OptionFor.both);
  static const translateOption = CometChatMessageOptions(
      id: MessageOptionConstants.translateMessage,
      title: "Translate",
      iconUrl: "assets/icons/translate.png",
      optionFor: OptionFor.both,
      packageName: UIConstants.packageName);
  static const reactToMessageOption = CometChatMessageOptions(
      id: MessageOptionConstants.reactToMessage,
      title: "Reaction",
      iconUrl: "assets/icons/edit.png",
      optionFor: OptionFor.both,
      packageName: UIConstants.packageName);

  static List<CometChatMessageOptions> textTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    //messageOptionList.addAll(getCommonOptions());
    messageOptionList.add(editOption);
    //messageOptionList.add(replyOption);
    //messageOptionList.add(replyInThreadOption);
    //messageOptionList.add(shareOption);
    messageOptionList.add(copyOption);
    // messageOptionList.add(forwardOption);
    // messageOptionList.add(informationOption);
    messageOptionList.add(translateOption);
    messageOptionList.add(reactToMessageOption);
    messageOptionList.add(deleteOption);
    return messageOptionList;
  }

  static List<CometChatMessageOptions> imageTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> videoTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> audioTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> fileTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> whiteboardTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> documentTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> pollTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> stickerTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> locationTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> fileTemplateOptions() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.addAll(getCommonOptions());
    return messageOptionList;
  }

  static List<CometChatMessageOptions> customTemplateOption() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.add(deleteOption);
    return messageOptionList;
  }

  static getDefaultTextTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.text,
      name: "Text",
      options: textTemplateOption(),
      // customView2: (BaseMessage message) {
      //   return Container(
      //     height: 100,
      //     width: 100,
      //     decoration: BoxDecoration(
      //         color: Colors.redAccent,
      //         border: Border.all(color: Colors.blue)),
      //     child: Text(
      //       (message as TextMessage).text,
      //       style: TextStyle(
      //         color: Colors.blue,
      //       ),
      //     ),
      //   );
      // }
    );
  }

  static getDefaultAudioTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.audio,
      name: "Audio",
      iconUrl: "assets/icons/audio.png",
      iconUrlPackageName: UIConstants.packageName,
      options: audioTemplateOption(),
    );
  }

  static getDefaultVideoTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.video,
      name: "Video",
      iconUrl: "assets/icons/photo_library.png",
      iconUrlPackageName: UIConstants.packageName,
      options: videoTemplateOption(),
    );
  }

  static getDefaultImageTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.image,
      name: "Image",
      iconUrl: "assets/icons/photo_library.png",
      iconUrlPackageName: UIConstants.packageName,
      options: imageTemplateOption(),
    );
  }

  static getDefaultLocationTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.location,
      name: "Location",
      iconUrl: "assets/icons/location.png",
      iconUrlPackageName: UIConstants.packageName,
      options: locationTemplateOption(),
    );
  }

  static getDefaultPollTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.poll,
      name: "Poll",
      iconUrl: "assets/icons/polls.png",
      iconUrlPackageName: UIConstants.packageName,
      options: pollTemplateOption(),
    );
  }

  static getDefaultCollaborativeWhiteboardTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.whiteboard,
      name: "collaborativeWhiteboard",
      iconUrl: "assets/icons/collaborative_whiteboard.png",
      iconUrlPackageName: UIConstants.packageName,
      options: whiteboardTemplateOption(),
    );
  }

  static getDefaultCollaborativeDocumentTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.document,
      name: "Collaborative Document",
      iconUrl: "assets/icons/collaborative_document.png",
      iconUrlPackageName: UIConstants.packageName,
      options: documentTemplateOption(),
    );
  }

  static getDefaultStickerTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.sticker,
      name: "sticker",
      options: stickerTemplateOption(),
    );
  }

  static getDefaultGroupActionsTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.groupActions,
      name: "groupActions",
      options: [],
    );
  }

  static getDefaultCustomTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.custom,
      name: "Image",
      options: customTemplateOption(),
    );
  }

  static getDefaultFileTemplate() {
    return CometChatMessageTemplate(
      type: MessageTypeConstants.file,
      name: "File",
      iconUrl: "assets/icons/attachment_file.png",
      iconUrlPackageName: UIConstants.packageName,
      options: fileTemplateOptions(),
    );
  }

  //Function returns map [ type: CometChatMessageTemplate ]
  static Map<String, List<ActionItem>> getActionMap(
      List<CometChatMessageTemplate> templateList) {
    Map<String, List<ActionItem>> actionMap = {};

    for (CometChatMessageTemplate template in templateList) {
      List<ActionItem> actionList = [];
      if (template.options != null) {
        for (CometChatMessageOptions options in template.options!) {
          actionList.add(options.toActionItem());
        }
      }
      actionMap[template.type] = actionList;
    }
    return actionMap;
  }

  static Map<String, List<CometChatMessageOptions>> getMessageMap(
      List<CometChatMessageTemplate> templateList) {
    Map<String, List<CometChatMessageOptions>> messageMap = {};

    for (CometChatMessageTemplate template in templateList) {
      List<CometChatMessageOptions> messageOptionList = [];
      if (template.options != null) {
        messageOptionList.addAll(template.options!);
      }
      messageMap[template.type] = messageOptionList;
    }
    return messageMap;
  }

  // static List<CometChatMessageTemplate> defaultTemplate = [
  //   getDefaultTextTemplate(),
  //   getDefaultImageTemplate(),
  //   getDefaultVideoTemplate(),
  //   getDefaultAudioTemplate(),
  //   getDefaultFileTemplate(),
  //   getDefaultPollTemplate(),
  //   getDefaultStickerTemplate(),
  //   getDefaultCollaborativeWhiteboardTemplate(),
  //   getDefaultCollaborativeDocumentTemplate(),
  //   getDefaultGroupActionsTemplate(),
  //   getDefaultLocationTemplate(),
  //   //getDefaultCustomTemplate(),
  // ];

  static List<CometChatMessageTemplate> getDefaultTemplate() {
    return [
      getDefaultTextTemplate(),
      getDefaultImageTemplate(),
      getDefaultVideoTemplate(),
      getDefaultAudioTemplate(),
      getDefaultFileTemplate(),
      getDefaultPollTemplate(),
      getDefaultStickerTemplate(),
      getDefaultCollaborativeWhiteboardTemplate(),
      getDefaultCollaborativeDocumentTemplate(),
      getDefaultGroupActionsTemplate(),
      //getDefaultLocationTemplate(),
      //getDefaultCustomTemplate(),
    ];
  }

  static List<CometChatMessageOptions> getCommonOptions() {
    List<CometChatMessageOptions> messageOptionList = [];
    messageOptionList.add(reactToMessageOption);
    messageOptionList.add(replyOption);
    // messageOptionList.add(replyInThreadOption);
    //messageOptionList.add(forwardOption);
    // messageOptionList.add(shareOption);
    // messageOptionList.add(informationOption);
    messageOptionList.add(deleteOption);
    return messageOptionList;
  }

  // static List<CometChatMessageOptions> commonOptions = [
  //   deleteOption,
  //   replyOption,
  //   replyInThreadOption,
  //   forwardOption,
  //   shareOption,
  //   informationOption,
  // ];

  static String getMessageCategory(String messageType) {
    late String category = MessageTypeConstants.custom;
    switch (messageType) {
      case MessageTypeConstants.text:
        category = MessageCategoryConstants.message;
        break;
      case MessageTypeConstants.image:
        category = MessageCategoryConstants.message;
        break;
      case MessageTypeConstants.video:
        category = MessageCategoryConstants.message;
        break;
      case MessageTypeConstants.document:
        category = MessageCategoryConstants.custom;
        break;
      case MessageTypeConstants.whiteboard:
        category = MessageCategoryConstants.custom;
        break;
      case MessageTypeConstants.sticker:
        category = MessageCategoryConstants.custom;
        break;
      case MessageTypeConstants.location:
        category = MessageCategoryConstants.custom;
        break;
      case MessageTypeConstants.poll:
        category = MessageCategoryConstants.custom;
        break;
      case MessageTypeConstants.groupActions:
        category = MessageCategoryConstants.action;
        break;
      case MessageTypeConstants.file:
        category = MessageCategoryConstants.message;
        break;
      default:
        category = MessageCategoryConstants.custom;
        break;
    }
    return category;
  }

  static String getMessageTypeToSubtitle(
      String messageType, BuildContext context) {
    String subtitle = messageType;
    switch (messageType) {
      case MessageTypeConstants.text:
        subtitle = Translations.of(context).text;
        break;
      case MessageTypeConstants.image:
        subtitle = Translations.of(context).message_image;
        break;
      case MessageTypeConstants.video:
        subtitle = Translations.of(context).message_video;
        break;
      case MessageTypeConstants.document:
        subtitle = Translations.of(context).custom_message_document;
        break;
      case MessageTypeConstants.whiteboard:
        subtitle = Translations.of(context).custom_message_whiteboard;
        break;
      case MessageTypeConstants.sticker:
        subtitle = Translations.of(context).custom_message_sticker;
        break;
      case MessageTypeConstants.location:
        subtitle = Translations.of(context).custom_message_location;
        break;
      case MessageTypeConstants.poll:
        subtitle = Translations.of(context).custom_message_poll;
        break;
      case MessageTypeConstants.file:
        subtitle = Translations.of(context).message_file;
        break;
      case MessageTypeConstants.audio:
        subtitle = Translations.of(context).message_audio;
        break;
      default:
        subtitle = messageType;
        break;
    }
    return subtitle;
  }

  static String getMessageTypeToTemplateTitle(
      String title, String messageType, BuildContext context) {
    String subtitle = title;
    switch (messageType) {
      case MessageTypeConstants.document:
        subtitle = Translations.of(context).collaborative_document;
        break;
      case MessageTypeConstants.whiteboard:
        subtitle = Translations.of(context).collaborative_whiteboard;
        break;
      case MessageTypeConstants.location:
        subtitle = Translations.of(context).location;
        break;
      case MessageTypeConstants.poll:
        subtitle = Translations.of(context).poll;
        break;
      case MessageTypeConstants.file:
        subtitle = Translations.of(context).file;
        break;
      case MessageTypeConstants.audio:
        subtitle = Translations.of(context).audio;
        break;
      default:
        subtitle = title;
        break;
    }
    return subtitle;
  }

  static String getLocalizeMessageOptionTitle(
      String messageOption, BuildContext context) {
    String localizedTitle = messageOption;
    switch (messageOption) {
      case MessageOptionConstants.editMessage:
        localizedTitle = Translations.of(context).edit;
        break;
      case MessageOptionConstants.replyMessage:
        localizedTitle = Translations.of(context).reply;
        break;
      case MessageOptionConstants.replyInThreadMessage:
        localizedTitle = Translations.of(context).start_thread;
        break;
      case MessageOptionConstants.shareMessage:
        localizedTitle = Translations.of(context).share;
        break;
      case MessageOptionConstants.copyMessage:
        localizedTitle = Translations.of(context).copy_text;
        break;
      case MessageOptionConstants.forwardMessage:
        localizedTitle = Translations.of(context).forward;
        break;
      case MessageOptionConstants.messageInformation:
        localizedTitle = Translations.of(context).information;
        break;
      case MessageOptionConstants.translateMessage:
        localizedTitle = Translations.of(context).translate;
        break;
      case MessageOptionConstants.deleteMessage:
        localizedTitle = Translations.of(context).delete;
        break;
      default:
        localizedTitle = messageOption;
        break;
    }
    return localizedTitle;
  }
}
