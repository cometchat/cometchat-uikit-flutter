import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatConversationsStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatConversations]
///``` dart
///CometChatConversationsStyle(
/// backgroundColor: Colors.white,
/// border: Border.all(color: Colors.white, width: 0),
/// );
/// ```
class CometChatConversationsStyle
    extends ThemeExtension<CometChatConversationsStyle> {
  const CometChatConversationsStyle({
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.backIconColor,
    this.titleTextStyle,
    this.titleTextColor,
    this.emptyStateTextStyle,
    this.emptyStateTextColor,
    this.errorStateTextStyle,
    this.errorStateTextColor,
    this.emptyStateSubTitleTextStyle,
    this.emptyStateSubTitleTextColor,
    this.errorStateSubTitleTextStyle,
    this.errorStateSubTitleTextColor,
    this.itemTitleTextStyle,
    this.itemTitleTextColor,
    this.itemSubtitleTextStyle,
    this.itemSubtitleTextColor,
    this.messageTypeIconColor,
    this.separatorColor,
    this.separatorHeight,
    this.typingIndicatorStyle,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.badgeStyle,
    this.receiptStyle,
    this.mentionsStyle,
    this.dateStyle,
    this.deleteConversationDialogStyle,
    this.privateGroupIconBackground,
    this.protectedGroupIconBackground,
    this.checkBoxBackgroundColor,
    this.checkBoxBorder,
    this.checkBoxBorderRadius,
    this.checkBoxCheckedBackgroundColor,
    this.listItemSelectedBackgroundColor,
    this.checkboxSelectedIconColor,
    this.submitIconColor,
    this.searchIconColor,
    this.searchBackgroundColor,
    this.searchBorder,
    this.searchBorderRadius,
    this.searchPlaceHolderTextStyle,
    this.searchPlaceHolderTextColor,
    this.itemStyle,
  });

  ///[submitIconColor] provides color for submit icon
  final Color? submitIconColor;

  ///[searchIconColor] provides color for search icon
  final Color? searchIconColor;

  ///[searchBackgroundColor] provides background color for search box
  final Color? searchBackgroundColor;

  ///[searchBorder] provides border for search box
  final BorderSide? searchBorder;

  ///[searchBorderRadius] provides border radius for search box
  final BorderRadius? searchBorderRadius;

  ///[searchPlaceHolderTextStyle] provides text style for search placeholder
  final TextStyle? searchPlaceHolderTextStyle;

  ///[searchPlaceHolderTextColor] provides text color for search placeholder
  final Color? searchPlaceHolderTextColor;

  ///[backgroundColor] provides background color for the widget
  final Color? backgroundColor;

  ///[border] provides border for the widget
  final Border? border;

  ///[borderRadius] provides border radius for the widget
  final BorderRadiusGeometry? borderRadius;

  ///[backIconColor] provides color for the back icon
  final Color? backIconColor;

  ///[titleTextStyle] provides title for the widget
  final TextStyle? titleTextStyle;

  ///[titleTextColor] provides text color for the title
  final Color? titleTextColor;

  ///[emptyStateTextStyle] provides text style for empty state
  final TextStyle? emptyStateTextStyle;

  ///[emptyStateTextColor] provides text color for empty state
  final Color? emptyStateTextColor;

  ///[emptyStateSubTitleTextStyle] provides text style for empty state
  final TextStyle? emptyStateSubTitleTextStyle;

  ///[emptyStateSubTitleTextColor] provides text color for empty state
  final Color? emptyStateSubTitleTextColor;

  ///[errorStateTextStyle] provides text style for error state
  final TextStyle? errorStateTextStyle;

  ///[errorStateTextStyle] provides sub-title text style for error state
  final TextStyle? errorStateSubTitleTextStyle;

  ///[errorStateTextColor] provides text color for error state
  final Color? errorStateTextColor;

  ///[errorStateSubTitleTextColor] provides sub-title text color for error state
  final Color? errorStateSubTitleTextColor;

  ///[itemTitleTextStyle] provides text style for item tile title
  final TextStyle? itemTitleTextStyle;

  ///[itemTitleTextColor] provides text color for item tile title
  final Color? itemTitleTextColor;

  ///[itemSubtitleTextStyle] provides text style for item tile title
  final TextStyle? itemSubtitleTextStyle;

  ///[itemSubtitleTextColor] provides text color for item tile title
  final Color? itemSubtitleTextColor;

  ///[messageTypeIconColor] provides icon color for message type
  final Color? messageTypeIconColor;

  ///[separatorHeight] provides height for the separator under the app bar.
  ///For the line between conversation rows, use
  ///[CometChatConversationListItemStyle.separatorHeight] on [itemStyle].
  final double? separatorHeight;

  ///[separatorColor] provides color for the separator under the app bar.
  ///For the line between conversation rows, use
  ///[CometChatConversationListItemStyle.separatorColor] on [itemStyle].
  final Color? separatorColor;

  ///[typingIndicatorStyle] provides style for typing indicator
  final CometChatTypingIndicatorStyle? typingIndicatorStyle;

  ///[dateStyle] provides styling for CometChatDate
  final CometChatDateStyle? dateStyle;

  ///[avatarStyle] set style for avatar
  final CometChatAvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;

  ///[badgeStyle] used to customize the unread messages count indicator
  final CometChatBadgeStyle? badgeStyle;

  ///[receiptStyle] sets the style for the receipts shown in the subtitle
  final CometChatMessageReceiptStyle? receiptStyle;

  ///[mentionsStyle] sets the style for the mentions shown in the subtitle
  final CometChatMentionsStyle? mentionsStyle;

  ///[deleteConversationDialogStyle] sets the style for the dialog for deleting conversation
  final CometChatConfirmDialogStyle? deleteConversationDialogStyle;

  ///[privateGroupIconBackground] provides background color for private group icon
  final Color? privateGroupIconBackground;

  ///[protectedGroupIconBackground] provides background color for protected group icon
  final Color? protectedGroupIconBackground;

  ///[checkBoxBackgroundColor] provides background color for selected item
  final Color? checkBoxBackgroundColor;

  ///[checkBoxCheckedBackgroundColor] provides check color for selected item
  final Color? checkBoxCheckedBackgroundColor;

  ///[checkBoxBorderRadius] provides border radius for selected item
  final BorderRadiusGeometry? checkBoxBorderRadius;

  ///[listItemSelectedBackgroundColor] provides background color for selected item
  final Color? listItemSelectedBackgroundColor;

  ///[checkboxSelectedIconColor] provides color for selected item
  final Color? checkboxSelectedIconColor;

  ///[checkBoxBorder] provides border for selected item
  final BorderSide? checkBoxBorder;

  /// Style for every conversation row, including the separator line between
  /// rows ([CometChatConversationListItemStyle.separatorColor] and
  /// [CometChatConversationListItemStyle.separatorHeight]), which is off by
  /// default and never drawn after the last row.
  ///
  /// The row fields this style also carries win over it where both are set:
  /// [itemTitleTextStyle], [itemTitleTextColor], [itemSubtitleTextStyle],
  /// [itemSubtitleTextColor], [backgroundColor],
  /// [listItemSelectedBackgroundColor], [messageTypeIconColor], the checkbox
  /// fields, [privateGroupIconBackground] and [protectedGroupIconBackground].
  /// So do [avatarStyle], [badgeStyle], [statusIndicatorStyle],
  /// [receiptStyle], [dateStyle] and [typingIndicatorStyle].
  final CometChatConversationListItemStyle? itemStyle;

  static CometChatConversationsStyle of(BuildContext context) =>
      const CometChatConversationsStyle();

  @override
  CometChatConversationsStyle copyWith({
    Color? backgroundColor,
    Border? border,
    BorderRadiusGeometry? borderRadius,
    Color? backIconColor,
    TextStyle? titleTextStyle,
    Color? titleTextColor,
    TextStyle? emptyStateTextStyle,
    Color? emptyStateTextColor,
    TextStyle? errorStateTextStyle,
    Color? errorStateTextColor,
    TextStyle? emptyStateSubtitleTextStyle,
    Color? emptyStateSubtitleTextColor,
    TextStyle? errorStateSubTitleTextStyle,
    Color? errorStateSubTitleTextColor,
    TextStyle? itemTitleTextStyle,
    Color? itemTitleTextColor,
    Color? submitIconColor,
    TextStyle? itemSubtitleTextStyle,
    Color? itemSubtitleTextColor,
    Color? messageTypeIconColor,
    double? separatorHeight,
    Color? separatorColor,
    CometChatAvatarStyle? messageBubbleAvatarStyle,
    CometChatStatusIndicatorStyle? statusIndicatorStyle,
    CometChatBadgeStyle? badgeStyle,
    CometChatMessageReceiptStyle? receiptStyle,
    CometChatMentionsStyle? mentionsStyle,
    CometChatDateStyle? dateStyle,
    CometChatTypingIndicatorStyle? typingIndicatorStyle,
    CometChatConfirmDialogStyle? deleteConversationDialogStyle,
    Color? privateGroupIconBackground,
    Color? protectedGroupIconBackground,
    BorderSide? checkBoxBorder,
    Color? checkBoxBackgroundColor,
    Color? checkBoxCheckedBackgroundColor,
    BorderRadiusGeometry? checkBoxBorderRadius,
    Color? listItemSelectedBackgroundColor,
    Color? checkboxSelectedIconColor,
    Color? searchIconColor,
    Color? searchBackgroundColor,
    BorderSide? searchBorder,
    BorderRadius? searchBorderRadius,
    TextStyle? searchPlaceHolderTextStyle,
    Color? searchPlaceHolderTextColor,
    CometChatConversationListItemStyle? itemStyle,
  }) {
    return CometChatConversationsStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      backIconColor: backIconColor ?? this.backIconColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      titleTextColor: titleTextColor ?? this.titleTextColor,
      emptyStateTextStyle: emptyStateTextStyle ?? this.emptyStateTextStyle,
      emptyStateTextColor: emptyStateTextColor ?? this.emptyStateTextColor,
      errorStateTextStyle: errorStateTextStyle ?? this.errorStateTextStyle,
      errorStateTextColor: errorStateTextColor ?? this.errorStateTextColor,
      emptyStateSubTitleTextStyle:
          emptyStateSubtitleTextStyle ?? emptyStateSubTitleTextStyle,
      emptyStateSubTitleTextColor:
          emptyStateSubtitleTextColor ?? emptyStateSubTitleTextColor,
      errorStateSubTitleTextStyle:
          errorStateSubTitleTextStyle ?? this.errorStateSubTitleTextStyle,
      errorStateSubTitleTextColor:
          errorStateSubTitleTextColor ?? this.errorStateSubTitleTextColor,
      itemTitleTextStyle: itemTitleTextStyle ?? this.itemTitleTextStyle,
      itemTitleTextColor: itemTitleTextColor ?? this.itemTitleTextColor,
      itemSubtitleTextStyle:
          itemSubtitleTextStyle ?? this.itemSubtitleTextStyle,
      itemSubtitleTextColor:
          itemSubtitleTextColor ?? this.itemSubtitleTextColor,
      messageTypeIconColor: messageTypeIconColor ?? this.messageTypeIconColor,
      separatorHeight: separatorHeight ?? this.separatorHeight,
      separatorColor: separatorColor ?? this.separatorColor,
      avatarStyle: messageBubbleAvatarStyle ?? avatarStyle,
      statusIndicatorStyle: statusIndicatorStyle ?? this.statusIndicatorStyle,
      badgeStyle: badgeStyle ?? this.badgeStyle,
      receiptStyle: receiptStyle ?? this.receiptStyle,
      mentionsStyle: mentionsStyle ?? this.mentionsStyle,
      dateStyle: dateStyle ?? this.dateStyle,
      typingIndicatorStyle: typingIndicatorStyle ?? this.typingIndicatorStyle,
      deleteConversationDialogStyle:
          deleteConversationDialogStyle ?? this.deleteConversationDialogStyle,
      privateGroupIconBackground:
          privateGroupIconBackground ?? this.privateGroupIconBackground,
      protectedGroupIconBackground:
          protectedGroupIconBackground ?? this.protectedGroupIconBackground,
      checkBoxBorder: checkBoxBorder ?? this.checkBoxBorder,
      checkBoxBackgroundColor:
          checkBoxBackgroundColor ?? this.checkBoxBackgroundColor,
      checkBoxCheckedBackgroundColor:
          checkBoxCheckedBackgroundColor ?? this.checkBoxCheckedBackgroundColor,
      checkBoxBorderRadius: checkBoxBorderRadius ?? this.checkBoxBorderRadius,
      listItemSelectedBackgroundColor:
          listItemSelectedBackgroundColor ??
          this.listItemSelectedBackgroundColor,
      checkboxSelectedIconColor:
          checkboxSelectedIconColor ?? this.checkboxSelectedIconColor,
      submitIconColor: submitIconColor ?? this.submitIconColor,
      searchIconColor: searchIconColor ?? this.searchIconColor,
      searchBackgroundColor:
          searchBackgroundColor ?? this.searchBackgroundColor,
      searchBorder: searchBorder ?? this.searchBorder,
      searchBorderRadius: searchBorderRadius ?? this.searchBorderRadius,
      searchPlaceHolderTextStyle:
          searchPlaceHolderTextStyle ?? this.searchPlaceHolderTextStyle,
      searchPlaceHolderTextColor:
          searchPlaceHolderTextColor ?? this.searchPlaceHolderTextColor,
      itemStyle: itemStyle ?? this.itemStyle,
    );
  }

  CometChatConversationsStyle merge(CometChatConversationsStyle? style) {
    if (style == null) return this;
    return copyWith(
      errorStateTextColor: style.errorStateTextColor,
      emptyStateSubtitleTextStyle: style.emptyStateSubTitleTextStyle,
      emptyStateSubtitleTextColor: style.emptyStateSubTitleTextColor,
      errorStateSubTitleTextStyle: style.errorStateSubTitleTextStyle,
      errorStateSubTitleTextColor: style.errorStateSubTitleTextColor,
      itemTitleTextStyle: style.itemTitleTextStyle,
      itemTitleTextColor: style.itemTitleTextColor,
      itemSubtitleTextStyle: style.itemSubtitleTextStyle,
      itemSubtitleTextColor: style.itemSubtitleTextColor,
      messageTypeIconColor: style.messageTypeIconColor,
      separatorHeight: style.separatorHeight,
      separatorColor: style.separatorColor,
      messageBubbleAvatarStyle: style.avatarStyle,
      typingIndicatorStyle: style.typingIndicatorStyle,
      badgeStyle: style.badgeStyle,
      dateStyle: style.dateStyle,
      mentionsStyle: style.mentionsStyle,
      receiptStyle: style.receiptStyle,
      statusIndicatorStyle: style.statusIndicatorStyle,
      deleteConversationDialogStyle: style.deleteConversationDialogStyle,
      backgroundColor: style.backgroundColor,
      border: style.border,
      borderRadius: style.borderRadius,
      backIconColor: style.backIconColor,
      titleTextStyle: style.titleTextStyle,
      titleTextColor: style.titleTextColor,
      emptyStateTextStyle: style.emptyStateTextStyle,
      emptyStateTextColor: style.emptyStateTextColor,
      errorStateTextStyle: style.errorStateTextStyle,
      privateGroupIconBackground: style.privateGroupIconBackground,
      protectedGroupIconBackground: style.protectedGroupIconBackground,
      checkBoxBorder: style.checkBoxBorder,
      checkBoxBackgroundColor: style.checkBoxBackgroundColor,
      checkBoxCheckedBackgroundColor: style.checkBoxCheckedBackgroundColor,
      checkBoxBorderRadius: style.checkBoxBorderRadius,
      listItemSelectedBackgroundColor: style.listItemSelectedBackgroundColor,
      checkboxSelectedIconColor: style.checkboxSelectedIconColor,
      submitIconColor: style.submitIconColor,
      searchIconColor: style.searchIconColor,
      searchBackgroundColor: style.searchBackgroundColor,
      searchBorder: style.searchBorder,
      searchBorderRadius: style.searchBorderRadius,
      searchPlaceHolderTextStyle: style.searchPlaceHolderTextStyle,
      searchPlaceHolderTextColor: style.searchPlaceHolderTextColor,
      itemStyle: style.itemStyle,
    );
  }

  @override
  CometChatConversationsStyle lerp(
    ThemeExtension<CometChatConversationsStyle>? other,
    double t,
  ) {
    if (other is! CometChatConversationsStyle) {
      return this;
    }
    return CometChatConversationsStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      border: Border.lerp(border, other.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other.borderRadius,
        t,
      ),
      backIconColor: Color.lerp(backIconColor, other.backIconColor, t),
      titleTextStyle: TextStyle.lerp(titleTextStyle, other.titleTextStyle, t),
      titleTextColor: Color.lerp(titleTextColor, other.titleTextColor, t),
      emptyStateTextStyle: TextStyle.lerp(
        emptyStateTextStyle,
        other.emptyStateTextStyle,
        t,
      ),
      emptyStateTextColor: Color.lerp(
        emptyStateTextColor,
        other.emptyStateTextColor,
        t,
      ),
      errorStateTextStyle: TextStyle.lerp(
        errorStateTextStyle,
        other.errorStateTextStyle,
        t,
      ),
      errorStateTextColor: Color.lerp(
        errorStateTextColor,
        other.errorStateTextColor,
        t,
      ),
      emptyStateSubTitleTextStyle: TextStyle.lerp(
        emptyStateSubTitleTextStyle,
        other.emptyStateSubTitleTextStyle,
        t,
      ),
      emptyStateSubTitleTextColor: Color.lerp(
        emptyStateSubTitleTextColor,
        other.emptyStateSubTitleTextColor,
        t,
      ),
      errorStateSubTitleTextStyle: TextStyle.lerp(
        errorStateSubTitleTextStyle,
        other.errorStateSubTitleTextStyle,
        t,
      ),
      errorStateSubTitleTextColor: Color.lerp(
        errorStateSubTitleTextColor,
        other.errorStateSubTitleTextColor,
        t,
      ),
      itemTitleTextStyle: TextStyle.lerp(
        itemTitleTextStyle,
        other.itemTitleTextStyle,
        t,
      ),
      itemTitleTextColor: Color.lerp(
        itemTitleTextColor,
        other.itemTitleTextColor,
        t,
      ),
      itemSubtitleTextStyle: TextStyle.lerp(
        itemSubtitleTextStyle,
        other.itemSubtitleTextStyle,
        t,
      ),
      itemSubtitleTextColor: Color.lerp(
        itemSubtitleTextColor,
        other.itemSubtitleTextColor,
        t,
      ),
      messageTypeIconColor: Color.lerp(
        messageTypeIconColor,
        other.messageTypeIconColor,
        t,
      ),
      separatorHeight: lerpDouble(separatorHeight, other.separatorHeight, t),
      separatorColor: Color.lerp(separatorColor, other.separatorColor, t),
      avatarStyle: avatarStyle?.lerp(other.avatarStyle, t),
      typingIndicatorStyle: typingIndicatorStyle?.lerp(
        other.typingIndicatorStyle,
        t,
      ),
      badgeStyle: badgeStyle?.lerp(other.badgeStyle, t),
      dateStyle: dateStyle?.lerp(other.dateStyle, t),
      mentionsStyle: mentionsStyle?.lerp(other.mentionsStyle, t),
      receiptStyle: receiptStyle?.lerp(other.receiptStyle, t),
      statusIndicatorStyle: statusIndicatorStyle?.lerp(
        other.statusIndicatorStyle,
        t,
      ),
      deleteConversationDialogStyle: deleteConversationDialogStyle?.lerp(
        other.deleteConversationDialogStyle,
        t,
      ),
      privateGroupIconBackground: Color.lerp(
        privateGroupIconBackground,
        other.privateGroupIconBackground,
        t,
      ),
      protectedGroupIconBackground: Color.lerp(
        protectedGroupIconBackground,
        other.protectedGroupIconBackground,
        t,
      ),
      checkBoxBorder: BorderSide.lerp(
        checkBoxBorder ?? BorderSide.none,
        other.checkBoxBorder ?? BorderSide.none,
        t,
      ),
      checkBoxBackgroundColor: Color.lerp(
        checkBoxBackgroundColor,
        other.checkBoxBackgroundColor,
        t,
      ),
      checkBoxCheckedBackgroundColor: Color.lerp(
        checkBoxCheckedBackgroundColor,
        other.checkBoxCheckedBackgroundColor,
        t,
      ),
      checkBoxBorderRadius: BorderRadiusGeometry.lerp(
        checkBoxBorderRadius,
        other.checkBoxBorderRadius,
        t,
      ),
      listItemSelectedBackgroundColor: Color.lerp(
        listItemSelectedBackgroundColor,
        other.listItemSelectedBackgroundColor,
        t,
      ),
      checkboxSelectedIconColor: Color.lerp(
        checkboxSelectedIconColor,
        other.checkboxSelectedIconColor,
        t,
      ),
      submitIconColor: Color.lerp(submitIconColor, other.submitIconColor, t),
      searchIconColor: Color.lerp(searchIconColor, other.searchIconColor, t),
      searchBackgroundColor: Color.lerp(
        searchBackgroundColor,
        other.searchBackgroundColor,
        t,
      ),
      searchBorder: BorderSide.lerp(
        searchBorder ?? BorderSide.none,
        other.searchBorder ?? BorderSide.none,
        t,
      ),
      searchBorderRadius: BorderRadius.lerp(
        searchBorderRadius,
        other.searchBorderRadius,
        t,
      ),
      searchPlaceHolderTextStyle: TextStyle.lerp(
        searchPlaceHolderTextStyle,
        other.searchPlaceHolderTextStyle,
        t,
      ),
      searchPlaceHolderTextColor: Color.lerp(
        searchPlaceHolderTextColor,
        other.searchPlaceHolderTextColor,
        t,
      ),
      // The row style has no lerp of its own, so it switches halfway.
      itemStyle: t < 0.5 ? itemStyle : other.itemStyle,
    );
  }
}
