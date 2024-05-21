import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

///[AIConversationSummaryConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [AIConversationSummaryConfiguration]
///
class AIConversationSummaryConfiguration {
  AIConversationSummaryConfiguration(
      {this.customView,
      this.conversationSummaryStyle,
      this.title,
      this.apiConfiguration,
      this.unreadMessageThreshold = 30,
      this.theme,
      this.loadingStateText,
      this.errorStateText,
      this.emptyStateText,
      this.loadingIconUrl,
      this.loadingStateView,
      this.errorIconUrl,
      this.errorStateView,
      this.emptyStateView,
      this.emptyIconUrl,
      this.onCloseIconTap,
      this.emptyIconPackageName,
      this.errorIconPackageName,
      this.loadingIconPackageName});

  ///[conversationStarterStyle] provides styling to the reply view
  final AIConversationSummaryStyle? conversationSummaryStyle;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[emptyStateText] text to be displayed when the replies are empty
  final String? emptyStateText;

  ///[loadingStateText] text to be displayed when loading occur
  final String? loadingStateText;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[emptyStateView] returns view for empty state
  final WidgetBuilder? emptyStateView;

  ///[loadingStateView] returns view for loading state
  final WidgetBuilder? loadingStateView;

  ///[errorStateView] returns view for error state
  final WidgetBuilder? errorStateView;

  ///[errorIconUrl] used to set the error icon
  final String? errorIconUrl;

  ///[emptyIconUrl] used to set the empty icon
  final String? emptyIconUrl;

  ///[loadingIconUrl] used to set the loading icon
  final String? loadingIconUrl;

  ///[onCloseIconTap] used to set the close icon function
  final Function(Map<String, dynamic> id)? onCloseIconTap;

  ///[errorIconPackageName] used to set the error icon package name
  final String? errorIconPackageName;

  ///[loadingIconPackageName] used to set the error icon package name
  final String? loadingIconPackageName;

  ///[emptyIconPackageName] used to set the empty icon package name
  final String? emptyIconPackageName;

  ///[title] set the title
  final String? title;

  ///[apiConfiguration] set the api configuration
  final Future<Map<String, dynamic>> Function(User? user, Group? group)?
      apiConfiguration;

  ///[unreadMessageThreshold] set the unread message count threshold
  final int? unreadMessageThreshold;

  ///[customView] set the custom view
  final Widget Function(String summary, BuildContext context)? customView;

  /// Copies current [AIConversationSummaryConfiguration] with some changes
  AIConversationSummaryConfiguration copyWith(
      {AIConversationSummaryStyle? conversationSummaryStyle,
      CometChatTheme? theme,
      String? emptyStateText,
      String? loadingStateText,
      String? errorStateText,
      Widget Function(List<String> replies, BuildContext context)? customView,
      Widget Function(List<String> replies, BuildContext context)?
          conversationStarterEmptyView,
      WidgetBuilder? emptyStateView,
      WidgetBuilder? loadingStateView,
      WidgetBuilder? errorStateView,
      String? errorIconUrl,
      String? emptyIconUrl,
      String? loadingIconUrl,
      final String? errorIconPackageName,
      final String? loadingIconPackageName,
      final String? emptyIconPackageName,
      Future<Map<String, dynamic>> Function(User? user, Group? group)?
          apiConfiguration}) {
    return AIConversationSummaryConfiguration(
      conversationSummaryStyle:
          conversationSummaryStyle ?? this.conversationSummaryStyle,
      theme: theme ?? this.theme,
      emptyStateText: emptyStateText ?? this.emptyStateText,
      loadingStateText: loadingStateText ?? this.loadingStateText,
      errorStateText: errorStateText ?? this.errorStateText,
      emptyStateView: emptyStateView ?? this.emptyStateView,
      loadingStateView: loadingStateView ?? this.loadingStateView,
      errorStateView: errorStateView ?? this.errorStateView,
      errorIconUrl: errorIconUrl ?? this.errorIconUrl,
      emptyIconUrl: emptyIconUrl ?? this.emptyIconUrl,
      loadingIconUrl: loadingIconUrl ?? this.loadingIconUrl,
      errorIconPackageName: errorIconPackageName ?? this.errorIconPackageName,
      emptyIconPackageName: emptyIconPackageName ?? this.emptyIconPackageName,
      loadingIconPackageName:
          loadingIconPackageName ?? this.loadingIconPackageName,
      apiConfiguration: apiConfiguration ?? this.apiConfiguration,
    );
  }

  /// Merges current [AIConversationSummaryConfiguration] with [other]
  AIConversationSummaryConfiguration merge(
      AIConversationSummaryConfiguration? other) {
    if (other == null) return this;
    return copyWith(
      conversationSummaryStyle: other.conversationSummaryStyle,
      theme: other.theme,
      emptyStateText: other.emptyStateText,
      loadingStateText: other.loadingStateText,
      errorStateText: other.errorStateText,
      emptyStateView: other.emptyStateView,
      loadingStateView: other.loadingStateView,
      errorStateView: other.errorStateView,
      errorIconUrl: other.errorIconUrl,
      emptyIconUrl: other.emptyIconUrl,
      loadingIconUrl: other.loadingIconUrl,
      errorIconPackageName: other.errorIconPackageName,
      loadingIconPackageName: other.loadingIconPackageName,
      emptyIconPackageName: other.emptyIconPackageName,
      apiConfiguration: other.apiConfiguration,
    );
  }
}
