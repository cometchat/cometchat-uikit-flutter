import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// Style configuration for [CometChatSearch] widget.
class CometChatSearchStyle extends ThemeExtension<CometChatSearchStyle> {
  const CometChatSearchStyle({
    this.backgroundColor,
    // Search bar
    this.searchBackgroundColor,
    this.searchTextColor,
    this.searchTextStyle,
    this.searchPlaceHolderTextColor,
    this.searchPlaceHolderTextStyle,
    this.searchBorder,
    this.searchBorderRadius,
    this.searchBackIconColor,
    this.searchClearIconColor,
    // Filter chips
    this.searchFilterChipBackgroundColor,
    this.searchFilterChipSelectedBackgroundColor,
    this.searchFilterChipTextColor,
    this.searchFilterChipSelectedTextColor,
    this.searchFilterChipTextStyle,
    this.searchFilterChipSelectedTextStyle,
    this.searchFilterChipBorder,
    this.searchFilterChipSelectedBorder,
    this.searchFilterChipBorderRadius,
    this.searchFilterIconColor,
    this.searchFilterSelectedIconColor,
    // Section headers
    this.sectionHeaderTextColor,
    this.sectionHeaderTextStyle,
    // Conversation items
    this.searchConversationTitleTextColor,
    this.searchConversationTitleTextStyle,
    this.searchConversationSubtitleTextColor,
    this.searchConversationSubtitleTextStyle,
    this.searchConversationItemBackgroundColor,
    // Message items
    this.searchMessageSenderTextColor,
    this.searchMessageSenderTextStyle,
    this.searchMessagePreviewTextColor,
    this.searchMessagePreviewTextStyle,
    this.searchMessageDateTextColor,
    this.searchMessageDateTextStyle,
    // State views
    this.emptyStateTextColor,
    this.emptyStateTextStyle,
    this.emptyStateSubTitleTextColor,
    this.emptyStateSubTitleTextStyle,
    this.errorStateTextColor,
    this.errorStateTextStyle,
    this.errorStateSubTitleTextColor,
    this.errorStateSubTitleTextStyle,
    // See more
    this.seeMoreTextColor,
    this.seeMoreTextStyle,
    // Nested styles
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.badgeStyle,
    this.receiptStyle,
    this.dateStyle,
  });

  final Color? backgroundColor;

  // Search bar
  final Color? searchBackgroundColor;
  final Color? searchTextColor;
  final TextStyle? searchTextStyle;
  final Color? searchPlaceHolderTextColor;
  final TextStyle? searchPlaceHolderTextStyle;
  final BorderSide? searchBorder;
  final BorderRadius? searchBorderRadius;
  final Color? searchBackIconColor;
  final Color? searchClearIconColor;

  // Filter chips
  final Color? searchFilterChipBackgroundColor;
  final Color? searchFilterChipSelectedBackgroundColor;
  final Color? searchFilterChipTextColor;
  final Color? searchFilterChipSelectedTextColor;
  final TextStyle? searchFilterChipTextStyle;
  final TextStyle? searchFilterChipSelectedTextStyle;
  final BoxBorder? searchFilterChipBorder;
  final BoxBorder? searchFilterChipSelectedBorder;
  final BorderRadius? searchFilterChipBorderRadius;
  final Color? searchFilterIconColor;
  final Color? searchFilterSelectedIconColor;

  // Section headers
  final Color? sectionHeaderTextColor;
  final TextStyle? sectionHeaderTextStyle;

  // Conversation items
  final Color? searchConversationTitleTextColor;
  final TextStyle? searchConversationTitleTextStyle;
  final Color? searchConversationSubtitleTextColor;
  final TextStyle? searchConversationSubtitleTextStyle;
  final Color? searchConversationItemBackgroundColor;

  // Message items
  final Color? searchMessageSenderTextColor;
  final TextStyle? searchMessageSenderTextStyle;
  final Color? searchMessagePreviewTextColor;
  final TextStyle? searchMessagePreviewTextStyle;
  final Color? searchMessageDateTextColor;
  final TextStyle? searchMessageDateTextStyle;

  // State views
  final Color? emptyStateTextColor;
  final TextStyle? emptyStateTextStyle;
  final Color? emptyStateSubTitleTextColor;
  final TextStyle? emptyStateSubTitleTextStyle;
  final Color? errorStateTextColor;
  final TextStyle? errorStateTextStyle;
  final Color? errorStateSubTitleTextColor;
  final TextStyle? errorStateSubTitleTextStyle;

  // See more
  final Color? seeMoreTextColor;
  final TextStyle? seeMoreTextStyle;

  // Nested styles
  final CometChatAvatarStyle? avatarStyle;
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;
  final CometChatBadgeStyle? badgeStyle;
  final CometChatMessageReceiptStyle? receiptStyle;
  final CometChatDateStyle? dateStyle;

  static CometChatSearchStyle of(BuildContext context) =>
      const CometChatSearchStyle();

  CometChatSearchStyle merge(CometChatSearchStyle? other) {
    if (other == null) return this;
    return copyWith(
      backgroundColor: other.backgroundColor,
      searchBackgroundColor: other.searchBackgroundColor,
      searchTextColor: other.searchTextColor,
      searchTextStyle: other.searchTextStyle,
      searchPlaceHolderTextColor: other.searchPlaceHolderTextColor,
      searchPlaceHolderTextStyle: other.searchPlaceHolderTextStyle,
      searchBorder: other.searchBorder,
      searchBorderRadius: other.searchBorderRadius,
      searchBackIconColor: other.searchBackIconColor,
      searchClearIconColor: other.searchClearIconColor,
      searchFilterChipBackgroundColor: other.searchFilterChipBackgroundColor,
      searchFilterChipSelectedBackgroundColor:
          other.searchFilterChipSelectedBackgroundColor,
      searchFilterChipTextColor: other.searchFilterChipTextColor,
      searchFilterChipSelectedTextColor:
          other.searchFilterChipSelectedTextColor,
      searchFilterChipTextStyle: other.searchFilterChipTextStyle,
      searchFilterChipSelectedTextStyle:
          other.searchFilterChipSelectedTextStyle,
      searchFilterChipBorder: other.searchFilterChipBorder,
      searchFilterChipSelectedBorder: other.searchFilterChipSelectedBorder,
      searchFilterChipBorderRadius: other.searchFilterChipBorderRadius,
      searchFilterIconColor: other.searchFilterIconColor,
      searchFilterSelectedIconColor: other.searchFilterSelectedIconColor,
      sectionHeaderTextColor: other.sectionHeaderTextColor,
      sectionHeaderTextStyle: other.sectionHeaderTextStyle,
      searchConversationTitleTextColor: other.searchConversationTitleTextColor,
      searchConversationTitleTextStyle: other.searchConversationTitleTextStyle,
      searchConversationSubtitleTextColor:
          other.searchConversationSubtitleTextColor,
      searchConversationSubtitleTextStyle:
          other.searchConversationSubtitleTextStyle,
      searchConversationItemBackgroundColor:
          other.searchConversationItemBackgroundColor,
      searchMessageSenderTextColor: other.searchMessageSenderTextColor,
      searchMessageSenderTextStyle: other.searchMessageSenderTextStyle,
      searchMessagePreviewTextColor: other.searchMessagePreviewTextColor,
      searchMessagePreviewTextStyle: other.searchMessagePreviewTextStyle,
      searchMessageDateTextColor: other.searchMessageDateTextColor,
      searchMessageDateTextStyle: other.searchMessageDateTextStyle,
      emptyStateTextColor: other.emptyStateTextColor,
      emptyStateTextStyle: other.emptyStateTextStyle,
      emptyStateSubTitleTextColor: other.emptyStateSubTitleTextColor,
      emptyStateSubTitleTextStyle: other.emptyStateSubTitleTextStyle,
      errorStateTextColor: other.errorStateTextColor,
      errorStateTextStyle: other.errorStateTextStyle,
      errorStateSubTitleTextColor: other.errorStateSubTitleTextColor,
      errorStateSubTitleTextStyle: other.errorStateSubTitleTextStyle,
      seeMoreTextColor: other.seeMoreTextColor,
      seeMoreTextStyle: other.seeMoreTextStyle,
      avatarStyle: other.avatarStyle,
      statusIndicatorStyle: other.statusIndicatorStyle,
      badgeStyle: other.badgeStyle,
      receiptStyle: other.receiptStyle,
      dateStyle: other.dateStyle,
    );
  }

  @override
  CometChatSearchStyle copyWith({
    Color? backgroundColor,
    Color? searchBackgroundColor,
    Color? searchTextColor,
    TextStyle? searchTextStyle,
    Color? searchPlaceHolderTextColor,
    TextStyle? searchPlaceHolderTextStyle,
    BorderSide? searchBorder,
    BorderRadius? searchBorderRadius,
    Color? searchBackIconColor,
    Color? searchClearIconColor,
    Color? searchFilterChipBackgroundColor,
    Color? searchFilterChipSelectedBackgroundColor,
    Color? searchFilterChipTextColor,
    Color? searchFilterChipSelectedTextColor,
    TextStyle? searchFilterChipTextStyle,
    TextStyle? searchFilterChipSelectedTextStyle,
    BoxBorder? searchFilterChipBorder,
    BoxBorder? searchFilterChipSelectedBorder,
    BorderRadius? searchFilterChipBorderRadius,
    Color? searchFilterIconColor,
    Color? searchFilterSelectedIconColor,
    Color? sectionHeaderTextColor,
    TextStyle? sectionHeaderTextStyle,
    Color? searchConversationTitleTextColor,
    TextStyle? searchConversationTitleTextStyle,
    Color? searchConversationSubtitleTextColor,
    TextStyle? searchConversationSubtitleTextStyle,
    Color? searchConversationItemBackgroundColor,
    Color? searchMessageSenderTextColor,
    TextStyle? searchMessageSenderTextStyle,
    Color? searchMessagePreviewTextColor,
    TextStyle? searchMessagePreviewTextStyle,
    Color? searchMessageDateTextColor,
    TextStyle? searchMessageDateTextStyle,
    Color? emptyStateTextColor,
    TextStyle? emptyStateTextStyle,
    Color? emptyStateSubTitleTextColor,
    TextStyle? emptyStateSubTitleTextStyle,
    Color? errorStateTextColor,
    TextStyle? errorStateTextStyle,
    Color? errorStateSubTitleTextColor,
    TextStyle? errorStateSubTitleTextStyle,
    Color? seeMoreTextColor,
    TextStyle? seeMoreTextStyle,
    CometChatAvatarStyle? avatarStyle,
    CometChatStatusIndicatorStyle? statusIndicatorStyle,
    CometChatBadgeStyle? badgeStyle,
    CometChatMessageReceiptStyle? receiptStyle,
    CometChatDateStyle? dateStyle,
  }) {
    return CometChatSearchStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      searchBackgroundColor:
          searchBackgroundColor ?? this.searchBackgroundColor,
      searchTextColor: searchTextColor ?? this.searchTextColor,
      searchTextStyle: searchTextStyle ?? this.searchTextStyle,
      searchPlaceHolderTextColor:
          searchPlaceHolderTextColor ?? this.searchPlaceHolderTextColor,
      searchPlaceHolderTextStyle:
          searchPlaceHolderTextStyle ?? this.searchPlaceHolderTextStyle,
      searchBorder: searchBorder ?? this.searchBorder,
      searchBorderRadius: searchBorderRadius ?? this.searchBorderRadius,
      searchBackIconColor: searchBackIconColor ?? this.searchBackIconColor,
      searchClearIconColor: searchClearIconColor ?? this.searchClearIconColor,
      searchFilterChipBackgroundColor:
          searchFilterChipBackgroundColor ??
          this.searchFilterChipBackgroundColor,
      searchFilterChipSelectedBackgroundColor:
          searchFilterChipSelectedBackgroundColor ??
          this.searchFilterChipSelectedBackgroundColor,
      searchFilterChipTextColor:
          searchFilterChipTextColor ?? this.searchFilterChipTextColor,
      searchFilterChipSelectedTextColor:
          searchFilterChipSelectedTextColor ??
          this.searchFilterChipSelectedTextColor,
      searchFilterChipTextStyle:
          searchFilterChipTextStyle ?? this.searchFilterChipTextStyle,
      searchFilterChipSelectedTextStyle:
          searchFilterChipSelectedTextStyle ??
          this.searchFilterChipSelectedTextStyle,
      searchFilterChipBorder:
          searchFilterChipBorder ?? this.searchFilterChipBorder,
      searchFilterChipSelectedBorder:
          searchFilterChipSelectedBorder ?? this.searchFilterChipSelectedBorder,
      searchFilterChipBorderRadius:
          searchFilterChipBorderRadius ?? this.searchFilterChipBorderRadius,
      searchFilterIconColor:
          searchFilterIconColor ?? this.searchFilterIconColor,
      searchFilterSelectedIconColor:
          searchFilterSelectedIconColor ?? this.searchFilterSelectedIconColor,
      sectionHeaderTextColor:
          sectionHeaderTextColor ?? this.sectionHeaderTextColor,
      sectionHeaderTextStyle:
          sectionHeaderTextStyle ?? this.sectionHeaderTextStyle,
      searchConversationTitleTextColor:
          searchConversationTitleTextColor ??
          this.searchConversationTitleTextColor,
      searchConversationTitleTextStyle:
          searchConversationTitleTextStyle ??
          this.searchConversationTitleTextStyle,
      searchConversationSubtitleTextColor:
          searchConversationSubtitleTextColor ??
          this.searchConversationSubtitleTextColor,
      searchConversationSubtitleTextStyle:
          searchConversationSubtitleTextStyle ??
          this.searchConversationSubtitleTextStyle,
      searchConversationItemBackgroundColor:
          searchConversationItemBackgroundColor ??
          this.searchConversationItemBackgroundColor,
      searchMessageSenderTextColor:
          searchMessageSenderTextColor ?? this.searchMessageSenderTextColor,
      searchMessageSenderTextStyle:
          searchMessageSenderTextStyle ?? this.searchMessageSenderTextStyle,
      searchMessagePreviewTextColor:
          searchMessagePreviewTextColor ?? this.searchMessagePreviewTextColor,
      searchMessagePreviewTextStyle:
          searchMessagePreviewTextStyle ?? this.searchMessagePreviewTextStyle,
      searchMessageDateTextColor:
          searchMessageDateTextColor ?? this.searchMessageDateTextColor,
      searchMessageDateTextStyle:
          searchMessageDateTextStyle ?? this.searchMessageDateTextStyle,
      emptyStateTextColor: emptyStateTextColor ?? this.emptyStateTextColor,
      emptyStateTextStyle: emptyStateTextStyle ?? this.emptyStateTextStyle,
      emptyStateSubTitleTextColor:
          emptyStateSubTitleTextColor ?? this.emptyStateSubTitleTextColor,
      emptyStateSubTitleTextStyle:
          emptyStateSubTitleTextStyle ?? this.emptyStateSubTitleTextStyle,
      errorStateTextColor: errorStateTextColor ?? this.errorStateTextColor,
      errorStateTextStyle: errorStateTextStyle ?? this.errorStateTextStyle,
      errorStateSubTitleTextColor:
          errorStateSubTitleTextColor ?? this.errorStateSubTitleTextColor,
      errorStateSubTitleTextStyle:
          errorStateSubTitleTextStyle ?? this.errorStateSubTitleTextStyle,
      seeMoreTextColor: seeMoreTextColor ?? this.seeMoreTextColor,
      seeMoreTextStyle: seeMoreTextStyle ?? this.seeMoreTextStyle,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      statusIndicatorStyle: statusIndicatorStyle ?? this.statusIndicatorStyle,
      badgeStyle: badgeStyle ?? this.badgeStyle,
      receiptStyle: receiptStyle ?? this.receiptStyle,
      dateStyle: dateStyle ?? this.dateStyle,
    );
  }

  @override
  /// Interpolates every declared prop.
  ///
  /// Previously this rebuilt the style from six of the forty-nine, so any
  /// animated theme transition nulled the other forty-three mid-flight and
  /// the search screen lost its styling until the animation settled.
  /// ENG-39119.
  CometChatSearchStyle lerp(
    ThemeExtension<CometChatSearchStyle>? other,
    double t,
  ) {
    if (other is! CometChatSearchStyle) return this;
    return CometChatSearchStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      searchBackgroundColor: Color.lerp(
        searchBackgroundColor,
        other.searchBackgroundColor,
        t,
      ),
      searchTextColor: Color.lerp(searchTextColor, other.searchTextColor, t),
      searchTextStyle: TextStyle.lerp(
        searchTextStyle,
        other.searchTextStyle,
        t,
      ),
      searchPlaceHolderTextColor: Color.lerp(
        searchPlaceHolderTextColor,
        other.searchPlaceHolderTextColor,
        t,
      ),
      searchPlaceHolderTextStyle: TextStyle.lerp(
        searchPlaceHolderTextStyle,
        other.searchPlaceHolderTextStyle,
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
      searchBackIconColor: Color.lerp(
        searchBackIconColor,
        other.searchBackIconColor,
        t,
      ),
      searchClearIconColor: Color.lerp(
        searchClearIconColor,
        other.searchClearIconColor,
        t,
      ),
      searchFilterChipBackgroundColor: Color.lerp(
        searchFilterChipBackgroundColor,
        other.searchFilterChipBackgroundColor,
        t,
      ),
      searchFilterChipSelectedBackgroundColor: Color.lerp(
        searchFilterChipSelectedBackgroundColor,
        other.searchFilterChipSelectedBackgroundColor,
        t,
      ),
      searchFilterChipTextColor: Color.lerp(
        searchFilterChipTextColor,
        other.searchFilterChipTextColor,
        t,
      ),
      searchFilterChipSelectedTextColor: Color.lerp(
        searchFilterChipSelectedTextColor,
        other.searchFilterChipSelectedTextColor,
        t,
      ),
      searchFilterChipTextStyle: TextStyle.lerp(
        searchFilterChipTextStyle,
        other.searchFilterChipTextStyle,
        t,
      ),
      searchFilterChipSelectedTextStyle: TextStyle.lerp(
        searchFilterChipSelectedTextStyle,
        other.searchFilterChipSelectedTextStyle,
        t,
      ),
      searchFilterChipBorder: BoxBorder.lerp(
        searchFilterChipBorder,
        other.searchFilterChipBorder,
        t,
      ),
      searchFilterChipSelectedBorder: BoxBorder.lerp(
        searchFilterChipSelectedBorder,
        other.searchFilterChipSelectedBorder,
        t,
      ),
      searchFilterChipBorderRadius: BorderRadius.lerp(
        searchFilterChipBorderRadius,
        other.searchFilterChipBorderRadius,
        t,
      ),
      searchFilterIconColor: Color.lerp(
        searchFilterIconColor,
        other.searchFilterIconColor,
        t,
      ),
      searchFilterSelectedIconColor: Color.lerp(
        searchFilterSelectedIconColor,
        other.searchFilterSelectedIconColor,
        t,
      ),
      sectionHeaderTextColor: Color.lerp(
        sectionHeaderTextColor,
        other.sectionHeaderTextColor,
        t,
      ),
      sectionHeaderTextStyle: TextStyle.lerp(
        sectionHeaderTextStyle,
        other.sectionHeaderTextStyle,
        t,
      ),
      searchConversationTitleTextColor: Color.lerp(
        searchConversationTitleTextColor,
        other.searchConversationTitleTextColor,
        t,
      ),
      searchConversationTitleTextStyle: TextStyle.lerp(
        searchConversationTitleTextStyle,
        other.searchConversationTitleTextStyle,
        t,
      ),
      searchConversationSubtitleTextColor: Color.lerp(
        searchConversationSubtitleTextColor,
        other.searchConversationSubtitleTextColor,
        t,
      ),
      searchConversationSubtitleTextStyle: TextStyle.lerp(
        searchConversationSubtitleTextStyle,
        other.searchConversationSubtitleTextStyle,
        t,
      ),
      searchConversationItemBackgroundColor: Color.lerp(
        searchConversationItemBackgroundColor,
        other.searchConversationItemBackgroundColor,
        t,
      ),
      searchMessageSenderTextColor: Color.lerp(
        searchMessageSenderTextColor,
        other.searchMessageSenderTextColor,
        t,
      ),
      searchMessageSenderTextStyle: TextStyle.lerp(
        searchMessageSenderTextStyle,
        other.searchMessageSenderTextStyle,
        t,
      ),
      searchMessagePreviewTextColor: Color.lerp(
        searchMessagePreviewTextColor,
        other.searchMessagePreviewTextColor,
        t,
      ),
      searchMessagePreviewTextStyle: TextStyle.lerp(
        searchMessagePreviewTextStyle,
        other.searchMessagePreviewTextStyle,
        t,
      ),
      searchMessageDateTextColor: Color.lerp(
        searchMessageDateTextColor,
        other.searchMessageDateTextColor,
        t,
      ),
      searchMessageDateTextStyle: TextStyle.lerp(
        searchMessageDateTextStyle,
        other.searchMessageDateTextStyle,
        t,
      ),
      emptyStateTextColor: Color.lerp(
        emptyStateTextColor,
        other.emptyStateTextColor,
        t,
      ),
      emptyStateTextStyle: TextStyle.lerp(
        emptyStateTextStyle,
        other.emptyStateTextStyle,
        t,
      ),
      emptyStateSubTitleTextColor: Color.lerp(
        emptyStateSubTitleTextColor,
        other.emptyStateSubTitleTextColor,
        t,
      ),
      emptyStateSubTitleTextStyle: TextStyle.lerp(
        emptyStateSubTitleTextStyle,
        other.emptyStateSubTitleTextStyle,
        t,
      ),
      errorStateTextColor: Color.lerp(
        errorStateTextColor,
        other.errorStateTextColor,
        t,
      ),
      errorStateTextStyle: TextStyle.lerp(
        errorStateTextStyle,
        other.errorStateTextStyle,
        t,
      ),
      errorStateSubTitleTextColor: Color.lerp(
        errorStateSubTitleTextColor,
        other.errorStateSubTitleTextColor,
        t,
      ),
      errorStateSubTitleTextStyle: TextStyle.lerp(
        errorStateSubTitleTextStyle,
        other.errorStateSubTitleTextStyle,
        t,
      ),
      seeMoreTextColor: Color.lerp(seeMoreTextColor, other.seeMoreTextColor, t),
      seeMoreTextStyle: TextStyle.lerp(
        seeMoreTextStyle,
        other.seeMoreTextStyle,
        t,
      ),
      avatarStyle: avatarStyle?.lerp(other.avatarStyle, t) ?? other.avatarStyle,
      statusIndicatorStyle:
          statusIndicatorStyle?.lerp(other.statusIndicatorStyle, t) ??
          other.statusIndicatorStyle,
      badgeStyle: badgeStyle?.lerp(other.badgeStyle, t) ?? other.badgeStyle,
      receiptStyle:
          receiptStyle?.lerp(other.receiptStyle, t) ?? other.receiptStyle,
      dateStyle: dateStyle?.lerp(other.dateStyle, t) ?? other.dateStyle,
    );
  }
}
