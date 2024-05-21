import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:url_launcher/url_launcher.dart';

///[LinkPreviewExtensionDecorator] is a the view model for [LinkPreviewExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class LinkPreviewExtensionDecorator extends DataSourceDecorator {
  String messageTranslationTypeConstant = ExtensionConstants.linkPreview;
  LinkPreviewConfiguration? configuration;

  LinkPreviewExtensionDecorator(super.dataSource, {this.configuration});

  @override
  Widget getTextMessageContentView(TextMessage message, BuildContext context,
      BubbleAlignment alignment, CometChatTheme theme,
      {AdditionalConfigurations? additionalConfigurations}) {
    Widget? child = super.getTextMessageContentView(
        message, context, alignment, theme,
        additionalConfigurations: additionalConfigurations);
    return LinkPreviewBubble(
      theme: configuration?.theme ?? theme,
      onTapUrl: onTapUrl,
      links: getMessageLinks(message),
      defaultImage: configuration?.defaultImage,
      style: configuration?.style,
      child: child,
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

  final RegExp _phoneNumberRegex = RegExp(
      r'\b(\+?( |-|\.)?\d{1,2}( |-|\.)?)?(\(?\d{3}\)?|\d{3})( |-|\.)?(\d{3}( |-|\.)?\d{4})\b');

  Future<void> onTapUrl(String url) async {
    if (_urlRegex.hasMatch(url)) {
      if (!RegExp(r'^(https?:\/\/)').hasMatch(url)) {
        url = 'https://$url';
      }
      await launchUrl(Uri.parse(url));
    } else if (_emailRegex.hasMatch(url)) {
      await launchUrl(Uri.parse('mailto:$url'));
    } else if (_phoneNumberRegex.hasMatch(url)) {
      await launchUrl(Uri.parse('tel:$url'));
    }
  }
}
