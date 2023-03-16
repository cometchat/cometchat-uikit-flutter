import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkPreviewExtensionDecorator extends DataSourceDecorator {
  String messageTranslationTypeConstant = ExtensionConstants.linkPreview;
  LinkPreviewConfiguration? configuration;

  LinkPreviewExtensionDecorator(DataSource dataSource,{this.configuration}) : super(dataSource);

  @override
  Widget getTextMessageContentView(TextMessage message, BuildContext context,
      BubbleAlignment _alignment, CometChatTheme theme) {
    Widget? child =
        super.getTextMessageContentView(message, context, _alignment, theme);
    return LinkPreviewBubble(
      theme: configuration?.theme ?? theme,
      onTapUrl: onTapUrl,
      links: getMessageLinks(message),
      child: child,
      defaultImage: configuration?.defaultImage,
      style: configuration?.style,
    );
  }

  @override
  String getId() {
    return "LinkPreview";
  }

  List<dynamic> getMessageLinks(BaseMessage message) {
    Map<String, Map>? extensionList =
        ExtensionModerator.extensionCheck(message);
    List<dynamic> links = [];
    if (extensionList != null) {
      try {
        if (extensionList.containsKey(ExtensionConstants.linkPreview)) {
          Map<dynamic, dynamic>? linkPreview =
              extensionList[ExtensionConstants.linkPreview];
          links = linkPreview?["links"] ?? [];
        }
      } catch (e) {
        debugPrint('$e');
      }
    }
    return links;
  }

  final RegExp _emailRegex = RegExp(
    r'^(.*?)((mailto:)?[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z][A-Z]+)',
    caseSensitive: false,
  );
  final RegExp _urlRegex =
      RegExp(r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+');

  final RegExp _phoneNumberRegex =
      RegExp(r'^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}');
  Future<void> onTapUrl(String url) async {
    if (_urlRegex.hasMatch(url)) {
      if (!RegExp(r'^(https?:\/\/)').hasMatch(url)) {
        url = 'https://' + url;
      }
      await launch(url);
    } else if (_emailRegex.hasMatch(url)) {
      await launch('mailto:$url');
    } else if (_phoneNumberRegex.hasMatch(url)) {
      await launch('tel:$url');
    }
  }
}
