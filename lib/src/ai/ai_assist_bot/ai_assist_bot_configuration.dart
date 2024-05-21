import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

///[AIAssistBotConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [AIAssistBotExtension]
///
/// ```dart
///   AIAssistBotConfiguration(
///    style: AiConversationAssistBotStyle(),
///    theme: CometChatTheme(palette: Palette(),typography: Typography())
///  );
/// ```
///
///
class AIAssistBotConfiguration {
  AIAssistBotConfiguration(
      {this.aiAssistBotStyle,
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
      this.onCloseIconTap});

  ///[aiAssistBotStyle] provides styling to the reply view
  final AIAssistBotStyle? aiAssistBotStyle;

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

  ///[onCloseIconTap] used to set callback for close icon
  final Function()? onCloseIconTap;

  ///[title] set the title
  final String? title;

  ///[apiConfiguration] set the configuration
  final Future<Map<String, dynamic>> Function(
      User aiBot, User? user, Group? group)? apiConfiguration;

  ///[unreadMessageThreshold] set the unread message count
  final int? unreadMessageThreshold;

  /// Copies current [AIAssistBotConfiguration] with some changes
  AIAssistBotConfiguration copyWith(
      {AIAssistBotStyle? aiAssistBotStyle,
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
      Future<Map<String, dynamic>> Function(
              User aiBot, User? user, Group? group)?
          apiConfiguration}) {
    return AIAssistBotConfiguration(
      aiAssistBotStyle: aiAssistBotStyle ?? aiAssistBotStyle,
      theme: theme ?? theme,
      emptyStateText: emptyStateText ?? this.emptyStateText,
      loadingStateText: loadingStateText ?? this.loadingStateText,
      errorStateText: errorStateText ?? this.errorStateText,
      emptyStateView: emptyStateView ?? this.emptyStateView,
      loadingStateView: loadingStateView ?? this.loadingStateView,
      errorStateView: errorStateView ?? this.errorStateView,
      errorIconUrl: errorIconUrl ?? this.errorIconUrl,
      emptyIconUrl: emptyIconUrl ?? this.emptyIconUrl,
      loadingIconUrl: loadingIconUrl ?? this.loadingIconUrl,
      apiConfiguration: apiConfiguration ?? this.apiConfiguration,
    );
  }

  /// Merges current [AIAssistBotConfiguration] with [other]
  AIAssistBotConfiguration merge(AIAssistBotConfiguration? other) {
    if (other == null) return this;
    return copyWith(
      aiAssistBotStyle: other.aiAssistBotStyle,
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
      apiConfiguration: other.apiConfiguration,
    );
  }
}
