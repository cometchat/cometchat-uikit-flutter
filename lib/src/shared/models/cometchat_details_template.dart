import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

class CometChatDetailsTemplate {
  final String id;
  final List<CometChatDetailsOption> Function(User? user, Group? group,
      BuildContext? context, CometChatTheme? theme)? options;
  final String? title;
  final TextStyle? titleStyle;
  final Color? sectionSeparatorColor;
  final bool? hideSectionSeparator;
  final Color? itemSeparatorColor;
  final bool? hideItemSeparator;

  const CometChatDetailsTemplate(
      {required this.id,
      this.options,
      this.title,
      this.titleStyle,
      this.sectionSeparatorColor,
      this.hideSectionSeparator,
      this.itemSeparatorColor,
      this.hideItemSeparator});

  @override
  String toString() {
    return 'CometChatDetailsTemplate{id: $id, options: $options, title: $title, titleStyle: $titleStyle, sectionSeparatorColor: $sectionSeparatorColor, hideSectionSeparator: $hideSectionSeparator, itemSeparatorColor: $itemSeparatorColor, hideItemSeparator: $hideItemSeparator}';
  }
}
