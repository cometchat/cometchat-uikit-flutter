import 'package:flutter/material.dart';
import '../../../../cometchat_chat_uikit.dart';

/// Style configuration for [CometChatConversationListItem] component.
///
/// This class encapsulates all visual styling properties for the conversation list item,
/// integrating with the CometChatTheme system for consistent styling.
class CometChatConversationListItemStyle {
  /// Icon shown inside the selection checkbox when the row is selected, in
  /// place of the default tick. [checkBoxSelectIconTint] tints it unless the
  /// icon sets its own colour.
  final Widget? checkBoxSelectIcon;

  /// Colour of the separator line drawn along the bottom of the row.
  ///
  /// Unset by default, so rows draw no separator. Setting this or
  /// [separatorHeight] turns the line on; with only [separatorHeight] set it
  /// takes the palette's light border colour. [ConversationsList] leaves it
  /// off the last row, so it only ever divides one conversation from the next.
  final Color? separatorColor;

  /// Thickness of the separator line drawn along the bottom of the row, in
  /// logical pixels. Defaults to 1 when only [separatorColor] is set.
  ///
  /// Setting it alone turns the line on in the palette's light border
  /// colour. A value of 0 or less draws no line.
  final double? separatorHeight;

  /// Background color for the list item.
  final Color? backgroundColor;

  /// Background color when the item is selected.
  final Color? selectedBackgroundColor;

  /// Text color for the conversation title.
  final Color? titleTextColor;

  /// Text style for the conversation title.
  final TextStyle? titleTextStyle;

  /// Text color for the subtitle (last message preview).
  final Color? subtitleTextColor;

  /// Text style for the subtitle.
  final TextStyle? subtitleTextStyle;

  /// Tint color for message type icons (photo, video, etc.).
  final Color? messageTypeIconTint;

  /// Stroke width for the selection checkbox.
  final double? checkBoxStrokeWidth;

  /// Corner radius for the selection checkbox.
  final BorderRadius? checkBoxBorderRadius;

  /// Stroke color for the unselected checkbox.
  final Color? checkBoxStrokeColor;

  /// Background color for the unselected checkbox.
  final Color? checkBoxBackgroundColor;

  /// Background color for the selected checkbox.
  final Color? checkBoxCheckedBackgroundColor;

  /// Tint color for the checkbox select icon.
  final Color? checkBoxSelectIconTint;

  /// Style configuration for the avatar component.
  final CometChatAvatarStyle? avatarStyle;

  /// Style configuration for the status indicator.
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;

  /// Style configuration for the date component.
  final CometChatDateStyle? dateStyle;

  /// Style configuration for the unread badge component.
  final CometChatBadgeStyle? badgeStyle;

  /// Style configuration for message receipts.
  final CometChatMessageReceiptStyle? receiptStyle;

  /// Style configuration for typing indicator.
  final CometChatTypingIndicatorStyle? typingIndicatorStyle;

  /// Background of the status dot on a private group's avatar.
  final Color? privateGroupIconBackground;

  /// Background of the status dot on a password-protected group's avatar.
  final Color? protectedGroupIconBackground;

  const CometChatConversationListItemStyle({
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.titleTextColor,
    this.titleTextStyle,
    this.subtitleTextColor,
    this.subtitleTextStyle,
    this.messageTypeIconTint,
    this.checkBoxStrokeWidth,
    this.checkBoxBorderRadius,
    this.checkBoxStrokeColor,
    this.checkBoxBackgroundColor,
    this.checkBoxCheckedBackgroundColor,
    this.checkBoxSelectIconTint,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.dateStyle,
    this.badgeStyle,
    this.receiptStyle,
    this.typingIndicatorStyle,
    this.privateGroupIconBackground,
    this.protectedGroupIconBackground,
    this.checkBoxSelectIcon,
    this.separatorColor,
    this.separatorHeight,
  });

  /// Creates a default style with values sourced from CometChatTheme.
  ///
  /// [colorPalette], [typography] and [spacing] replace the theme's own when
  /// given, so an item built with its own palette takes its defaults from it.
  factory CometChatConversationListItemStyle.fromTheme(
    BuildContext context, {
    CometChatColorPalette? colorPalette,
    CometChatTypography? typography,
    CometChatSpacing? spacing,
  }) {
    final palette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final type = typography ?? CometChatThemeHelper.getTypography(context);
    final space = spacing ?? CometChatThemeHelper.getSpacing(context);

    return CometChatConversationListItemStyle(
      backgroundColor: palette.background1,
      selectedBackgroundColor: palette.background4,
      titleTextColor: palette.textPrimary,
      titleTextStyle: type.heading4?.medium,
      subtitleTextColor: palette.textSecondary,
      subtitleTextStyle: type.body?.regular,
      messageTypeIconTint: palette.iconSecondary,
      checkBoxStrokeWidth: 1.5,
      checkBoxBorderRadius: BorderRadius.circular(space.radius1 ?? 4),
      checkBoxStrokeColor: palette.borderDefault,
      checkBoxBackgroundColor: Colors.transparent,
      checkBoxCheckedBackgroundColor: palette.primary,
      avatarStyle: const CometChatAvatarStyle(),
      statusIndicatorStyle: const CometChatStatusIndicatorStyle(),
      dateStyle: CometChatDateStyle(
        textColor: palette.textSecondary,
        textStyle: type.caption1?.regular,
      ),
      badgeStyle: CometChatBadgeStyle(
        borderRadius: BorderRadius.circular(space.radius3?.toDouble() ?? 12),
      ),
      receiptStyle: CometChatMessageReceiptStyle(),
      typingIndicatorStyle: CometChatTypingIndicatorStyle(
        textStyle: type.body?.regular,
      ),
    );
  }

  /// Merges this style with another style, with the other style taking precedence.
  CometChatConversationListItemStyle merge(
    CometChatConversationListItemStyle? other,
  ) {
    if (other == null) return this;

    return CometChatConversationListItemStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      selectedBackgroundColor:
          other.selectedBackgroundColor ?? selectedBackgroundColor,
      titleTextColor: other.titleTextColor ?? titleTextColor,
      titleTextStyle: other.titleTextStyle ?? titleTextStyle,
      subtitleTextColor: other.subtitleTextColor ?? subtitleTextColor,
      subtitleTextStyle: other.subtitleTextStyle ?? subtitleTextStyle,
      messageTypeIconTint: other.messageTypeIconTint ?? messageTypeIconTint,
      checkBoxStrokeWidth: other.checkBoxStrokeWidth ?? checkBoxStrokeWidth,
      checkBoxBorderRadius: other.checkBoxBorderRadius ?? checkBoxBorderRadius,
      checkBoxStrokeColor: other.checkBoxStrokeColor ?? checkBoxStrokeColor,
      checkBoxBackgroundColor:
          other.checkBoxBackgroundColor ?? checkBoxBackgroundColor,
      checkBoxCheckedBackgroundColor:
          other.checkBoxCheckedBackgroundColor ??
          checkBoxCheckedBackgroundColor,
      checkBoxSelectIconTint:
          other.checkBoxSelectIconTint ?? checkBoxSelectIconTint,
      avatarStyle: other.avatarStyle ?? avatarStyle,
      statusIndicatorStyle: other.statusIndicatorStyle ?? statusIndicatorStyle,
      dateStyle: other.dateStyle ?? dateStyle,
      badgeStyle: other.badgeStyle ?? badgeStyle,
      receiptStyle: other.receiptStyle ?? receiptStyle,
      typingIndicatorStyle: other.typingIndicatorStyle ?? typingIndicatorStyle,
      privateGroupIconBackground:
          other.privateGroupIconBackground ?? privateGroupIconBackground,
      protectedGroupIconBackground:
          other.protectedGroupIconBackground ?? protectedGroupIconBackground,
      checkBoxSelectIcon: other.checkBoxSelectIcon ?? checkBoxSelectIcon,
      separatorColor: other.separatorColor ?? separatorColor,
      separatorHeight: other.separatorHeight ?? separatorHeight,
    );
  }

  /// Creates a copy of this style with the given fields replaced.
  CometChatConversationListItemStyle copyWith({
    Color? backgroundColor,
    Color? selectedBackgroundColor,
    Color? titleTextColor,
    TextStyle? titleTextStyle,
    Color? subtitleTextColor,
    TextStyle? subtitleTextStyle,
    Color? messageTypeIconTint,
    double? checkBoxStrokeWidth,
    BorderRadius? checkBoxBorderRadius,
    Color? checkBoxStrokeColor,
    Color? checkBoxBackgroundColor,
    Color? checkBoxCheckedBackgroundColor,
    Color? checkBoxSelectIconTint,
    CometChatAvatarStyle? avatarStyle,
    CometChatStatusIndicatorStyle? statusIndicatorStyle,
    CometChatDateStyle? dateStyle,
    CometChatBadgeStyle? badgeStyle,
    CometChatMessageReceiptStyle? receiptStyle,
    CometChatTypingIndicatorStyle? typingIndicatorStyle,
    Color? privateGroupIconBackground,
    Color? protectedGroupIconBackground,
    Widget? checkBoxSelectIcon,
    Color? separatorColor,
    double? separatorHeight,
  }) {
    return CometChatConversationListItemStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      selectedBackgroundColor:
          selectedBackgroundColor ?? this.selectedBackgroundColor,
      titleTextColor: titleTextColor ?? this.titleTextColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      subtitleTextColor: subtitleTextColor ?? this.subtitleTextColor,
      subtitleTextStyle: subtitleTextStyle ?? this.subtitleTextStyle,
      messageTypeIconTint: messageTypeIconTint ?? this.messageTypeIconTint,
      checkBoxStrokeWidth: checkBoxStrokeWidth ?? this.checkBoxStrokeWidth,
      checkBoxBorderRadius: checkBoxBorderRadius ?? this.checkBoxBorderRadius,
      checkBoxStrokeColor: checkBoxStrokeColor ?? this.checkBoxStrokeColor,
      checkBoxBackgroundColor:
          checkBoxBackgroundColor ?? this.checkBoxBackgroundColor,
      checkBoxCheckedBackgroundColor:
          checkBoxCheckedBackgroundColor ?? this.checkBoxCheckedBackgroundColor,
      checkBoxSelectIconTint:
          checkBoxSelectIconTint ?? this.checkBoxSelectIconTint,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      statusIndicatorStyle: statusIndicatorStyle ?? this.statusIndicatorStyle,
      dateStyle: dateStyle ?? this.dateStyle,
      badgeStyle: badgeStyle ?? this.badgeStyle,
      receiptStyle: receiptStyle ?? this.receiptStyle,
      typingIndicatorStyle: typingIndicatorStyle ?? this.typingIndicatorStyle,
      privateGroupIconBackground:
          privateGroupIconBackground ?? this.privateGroupIconBackground,
      protectedGroupIconBackground:
          protectedGroupIconBackground ?? this.protectedGroupIconBackground,
      checkBoxSelectIcon: checkBoxSelectIcon ?? this.checkBoxSelectIcon,
      separatorColor: separatorColor ?? this.separatorColor,
      separatorHeight: separatorHeight ?? this.separatorHeight,
    );
  }
}
