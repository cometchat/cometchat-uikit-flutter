import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

class AISmartRepliesConfiguration {
  AISmartRepliesConfiguration({
    this.smartRepliesStyle,
    this.theme,
    this.errorStateText,
    this.emptyStateText,
    this.onError,
    this.customView,
    this.onClick,
    this.loadingStateText,
    this.loadingIconUrl,
    this.loadingStateView,
    this.errorIconUrl,
    this.errorStateView,
    this.emptyStateView,
    this.emptyIconUrl,
    this.apiConfiguration,
  });

  ///[smartRepliesStyle] provides styling to the reply view
  final AISmartRepliesStyle? smartRepliesStyle;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[emptyStateText] text to be displayed when the replies are empty
  final String? emptyStateText;

  ///[onError] callback triggered in case any error happens when fetching replies
  final OnError? onError;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[customView] return custom smartReply view
  final Widget Function(List<String> replies, BuildContext context)? customView;

  ///[onClick] function when user wants to send custom ui along with replies
  final Function(
      User? user,
      Group? group,
      Function(Widget, bool isLoading, BuildContext context) onSuccess,
      Function(CometChatException e, bool isError, BuildContext context)
          onError)? onClick;

  ///[loadingStateText] text to be displayed when loading occur
  final String? loadingStateText;

  ///[emptyStateView] returns view fow empty state
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

  ///[apiConfiguration] set the configuration
  final Future<Map<String, dynamic>> Function(User? user, Group? group)?
      apiConfiguration;

  /// Copies current [AISmartRepliesConfiguration] with some changes
  AISmartRepliesConfiguration copyWith(
      {AISmartRepliesStyle? smartRepliesStyle,
      CometChatTheme? theme,
      String? emptyStateText,
      OnError? onError,
      String? errorStateText,
      Widget Function(List<String> replies, BuildContext context)? customView,
      Function(
              User? user,
              Group? group,
              Function(Widget, bool isLoading, BuildContext context) onSuccess,
              Function(CometChatException e, bool isError, BuildContext context)
                  onError)?
          onClick,
      String? loadingStateText,
      WidgetBuilder? emptyStateView,
      WidgetBuilder? loadingStateView,
      WidgetBuilder? errorStateView,
      String? errorIconUrl,
      String? emptyIconUrl,
      String? loadingIconUrl,
      Future<Map<String, dynamic>> Function(User? user, Group? group)?
          apiConfiguration}) {
    return AISmartRepliesConfiguration(
      smartRepliesStyle: smartRepliesStyle ?? this.smartRepliesStyle,
      theme: theme ?? this.theme,
      emptyStateText: emptyStateText ?? this.emptyStateText,
      onError: onError ?? this.onError,
      errorStateText: errorStateText ?? this.errorStateText,
      customView: customView ?? this.customView,
      onClick: onClick ?? this.onClick,
      loadingStateText: loadingStateText ?? this.loadingStateText,
      emptyStateView: emptyStateView ?? this.emptyStateView,
      loadingStateView: loadingStateView ?? this.loadingStateView,
      errorStateView: errorStateView ?? this.errorStateView,
      errorIconUrl: errorIconUrl ?? this.errorIconUrl,
      emptyIconUrl: emptyIconUrl ?? this.emptyIconUrl,
      loadingIconUrl: loadingIconUrl ?? this.loadingIconUrl,
      apiConfiguration: apiConfiguration ?? this.apiConfiguration,
    );
  }

  /// Merges current [AISmartRepliesConfiguration] with [other]
  AISmartRepliesConfiguration merge(AISmartRepliesConfiguration? other) {
    if (other == null) return this;
    return copyWith(
      smartRepliesStyle: other.smartRepliesStyle,
      theme: other.theme,
      emptyStateText: other.emptyStateText,
      onError: other.onError ?? onError,
      errorStateText: other.errorStateText,
      customView: other.customView,
      onClick: other.onClick,
      loadingStateText: other.loadingStateText,
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
