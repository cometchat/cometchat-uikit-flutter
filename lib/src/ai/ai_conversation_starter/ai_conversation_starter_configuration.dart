import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

///[AIConversationStarterConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [AIConversationStarterExtension]
///
/// ```dart
///   AiConversationStarterConfiguration(
///    style: AiConversationStarterStyle(),
///    theme: CometChatTheme(palette: Palette(),typography: Typography())
///  );
/// ```
class AIConversationStarterConfiguration {
  AIConversationStarterConfiguration(
      {this.conversationStarterStyle,
      this.theme,
      this.loadingStateText,
      this.errorStateText,
      this.emptyStateText,
      this.customView,
      this.loadingIconUrl,
      this.loadingStateView,
      this.errorIconUrl,
      this.errorStateView,
      this.emptyStateView,
      this.emptyIconUrl,
      this.loadingIconPackageName,
      this.emptyIconPackageName,
      this.errorIconPackageName,
      this.apiConfiguration});

  ///[conversationStarterStyle] provides styling to the reply view
  final AIConversationStarterStyle? conversationStarterStyle;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[emptyStateText] text to be displayed when the replies are empty
  final String? emptyStateText;

  ///[loadingStateText] text to be displayed when loading occur
  final String? loadingStateText;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[customView] gives conversation starter view
  final Widget Function(List<String> replies, BuildContext context)? customView;

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

  ///[loadingIconPackageName] package name for loading icon to be displayed when in loading state
  final String? loadingIconPackageName;

  ///[errorIconPackageName] package name for error icon to be displayed when in error occur
  final String? errorIconPackageName;

  ///[emptyIconPackageName] package name for empty icon to be displayed when in empty state
  final String? emptyIconPackageName;

  ///[apiConfiguration] set the configuration
  final Future<Map<String, dynamic>> Function(User? user, Group? group)?
      apiConfiguration;

  /// Copies current [AIConversationStarterConfiguration] with some changes
  AIConversationStarterConfiguration copyWith(
      {AIConversationStarterStyle? conversationStarterStyle,
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
      String? loadingIconPackageName,
      String? emptyIconPackageName,
      String? errorIconPackageName,
      Future<Map<String, dynamic>> Function(User? user, Group? group)?
          apiConfiguration}) {
    return AIConversationStarterConfiguration(
      conversationStarterStyle:
          conversationStarterStyle ?? this.conversationStarterStyle,
      theme: theme ?? this.theme,
      emptyStateText: emptyStateText ?? this.emptyStateText,
      loadingStateText: loadingStateText ?? this.loadingStateText,
      errorStateText: errorStateText ?? this.errorStateText,
      customView: customView ?? this.customView,
      emptyStateView: emptyStateView ?? this.emptyStateView,
      loadingStateView: loadingStateView ?? this.loadingStateView,
      errorStateView: errorStateView ?? this.errorStateView,
      errorIconUrl: errorIconUrl ?? this.errorIconUrl,
      emptyIconUrl: emptyIconUrl ?? this.emptyIconUrl,
      loadingIconUrl: loadingIconUrl ?? this.loadingIconUrl,
      loadingIconPackageName:
          loadingIconPackageName ?? this.loadingIconPackageName,
      emptyIconPackageName: emptyIconPackageName ?? this.emptyIconPackageName,
      errorIconPackageName: errorIconPackageName ?? this.errorIconPackageName,
      apiConfiguration: apiConfiguration ?? this.apiConfiguration,
    );
  }

  /// Merges current [AIConversationStarterConfiguration] with [other]
  AIConversationStarterConfiguration merge(
      AIConversationStarterConfiguration? other) {
    if (other == null) return this;
    return copyWith(
      conversationStarterStyle: other.conversationStarterStyle,
      theme: other.theme,
      emptyStateText: other.emptyStateText,
      loadingStateText: other.loadingStateText,
      errorStateText: other.errorStateText,
      customView: other.customView,
      emptyStateView: other.emptyStateView,
      loadingStateView: other.loadingStateView,
      errorStateView: other.errorStateView,
      errorIconUrl: other.errorIconUrl,
      emptyIconUrl: other.emptyIconUrl,
      loadingIconUrl: other.loadingIconUrl,
      loadingIconPackageName: other.loadingIconPackageName,
      errorIconPackageName: other.errorIconPackageName,
      emptyIconPackageName: other.emptyIconPackageName,
      apiConfiguration: other.apiConfiguration,
    );
  }
}
