import 'package:flutter/material.dart';
import '../../../../../cometchat_chat_uikit.dart';

///[ImageModerationExtensionDecorator] is a the view model for [ImageModerationExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class ImageModerationExtensionDecorator extends DataSourceDecorator {
  User? loggedInUser;
  ImageModerationConfiguration? configuration;

  ImageModerationExtensionDecorator(super.dataSource, {this.configuration}) {
    getLoggedInUser();
  }

  getLoggedInUser() async {
    loggedInUser = await CometChat.getLoggedInUser();
  }

  @override
  Widget getImageMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment alignment, CometChatTheme theme) {
    Widget child =
        super.getImageMessageContentView(message, context, alignment, theme);
    if (message.sender?.uid == loggedInUser?.uid) {
      return child;
    }

    return getImageContent(message, child, theme);
  }

  getImageContent(MediaMessage message, Widget child, CometChatTheme theme) {
    return ImageModerationFilter(
      key: UniqueKey(),
      message: message,
      theme: theme,
      warningText: configuration?.warningText,
      style: configuration?.style,
      child: child,
    );
  }

  @override
  String getId() {
    return "ImageModeration";
  }
}
