import 'package:flutter/material.dart';
import '../../../../../flutter_chat_ui_kit.dart';

class ImageModerationExtensionDecorator extends DataSourceDecorator {
  User? loggedInUser;
  ImageModerationConfiguration? configuration;

  ImageModerationExtensionDecorator(DataSource dataSource,{this.configuration}) : super(dataSource) {
    getLoggedInUser();
  }

  getLoggedInUser() async {
    loggedInUser = await CometChat.getLoggedInUser();
  }

  @override
  Widget getImageMessageContentView(MediaMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme) {
    Widget _child =
        super.getImageMessageContentView(message, context, _alignment, theme);
    if (message.sender?.uid == loggedInUser?.uid) {
      return _child;
    }

    return getImageContent(message, _child, theme);
  }

  getImageContent(MediaMessage message, Widget child, CometChatTheme theme) {
    return ImageModerationFilter(
      key: UniqueKey(),
      message: message,
      theme: theme,
      child: child,
      warningText: configuration?.warningText,
      style: configuration?.style,
    );
  }

  @override
  String getId() {
    return "ImageModeration";
  }
}
