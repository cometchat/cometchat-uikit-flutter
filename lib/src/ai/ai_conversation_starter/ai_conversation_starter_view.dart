import 'package:cometchat_chat_uikit/src/ai/ai_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[AIConversationStarterView] is a widget that is rendered as the content view for [AIConversationStarterExtension]
///```dart
/// AiConversationStarterTopView(
///   style: AiConversationStarterStyle(),
///   user: User(),
///   emptyStateText: Text("Error occurred"),
///   loadingStateView: Text("Loading..."),
///   theme: CometChatTheme(),
///   )
/// ```

class AIConversationStarterView extends StatefulWidget {
  const AIConversationStarterView(
      {super.key,
      this.user,
      this.group,
      this.aiConversationStarterStyle,
      this.emptyStateText,
      this.errorStateText,
      this.theme,
      this.customView,
      this.loadingStateText,
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

  /// set [User] object, one is mandatory either [user] or [group]
  final User? user;

  ///set [Group] object, one is mandatory either [user] or [group]
  final Group? group;

  ///[aiConversationStarterStyle] provides styling to the reply chips/bubbles
  final AIConversationStarterStyle? aiConversationStarterStyle;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[emptyStateText] text to be displayed when the replies are empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[loadingStateText] text to be displayed when loading occur
  final String? loadingStateText;

  ///[loadingIconPackageName] package name for loading icon to be displayed when loading state
  final String? loadingIconPackageName;

  ///[errorIconPackageName] package name for error icon to be displayed when error occur
  final String? errorIconPackageName;

  ///[emptyIconPackageName] package name for empty icon to be displayed when empty state
  final String? emptyIconPackageName;

  ///[customView] gives conversation starter view
  final Widget Function(List<String> replies, BuildContext context)? customView;

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

  ///[apiConfiguration] sets the api call configuration for ai conversation starter
  final Map<String, dynamic>? apiConfiguration;

  @override
  State<AIConversationStarterView> createState() =>
      _AIConversationStarterViewState();
}

class _AIConversationStarterViewState extends State<AIConversationStarterView>
    with WidgetsBindingObserver {
  List<String> _replies = [];

  bool isLoading = false;

  bool isError = false;

  bool isKeyboardOpen = false;

  CometChatTheme _theme = cometChatTheme;

  @override
  void initState() {
    getReply();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final value = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (value > 0 != isKeyboardOpen) {
      setState(() {
        isKeyboardOpen = !isKeyboardOpen;
      });
    }
  }

  getReply() async {
    _theme = widget.theme ?? cometChatTheme;
    await getReplies();
  }

  Future<void> getReplies() async {
    setState(() {
      isLoading = true;
    });
    _replies.clear();
    String receiverId = "";
    String receiverType = "";
    if (widget.user != null) {
      receiverId = widget.user!.uid;
      receiverType = CometChatReceiverType.user;
    } else if (widget.group != null) {
      receiverId = widget.group!.guid;
      receiverType = CometChatReceiverType.group;
    }
    await CometChat.getConversationStarter(receiverId, receiverType,
        configuration: widget.apiConfiguration, onSuccess: (reply) {
      _replies = reply;
      setState(() {});
    }, onError: (error) {
      if (kDebugMode) {
        debugPrint("Error in AI conversation starter : ${error.message}");
      }
      isError = true;
      setState(() {});
    });
    isLoading = false;
    setState(() {});
  }

  Widget _getOnError(BuildContext context, CometChatTheme theme) {
    if (widget.errorStateView != null) {
      return Center(
        child: widget.errorStateView!(context),
      );
    } else {
      return AIUtils.getOnError(context, theme,
          backgroundColor: widget.aiConversationStarterStyle?.backgroundColor,
          shadowColor: widget.aiConversationStarterStyle?.shadowColor,
          errorIconUrl: widget.errorIconUrl,
          errorIconTint: widget.aiConversationStarterStyle?.errorIconTint,
          errorStateText: widget.errorStateText,
          errorTextStyle: widget.aiConversationStarterStyle?.errorTextStyle,
          errorIconPackageName: widget.errorIconPackageName);
    }
  }

  Widget _getEmptyView(BuildContext context, CometChatTheme theme) {
    if (widget.emptyStateView != null) {
      return widget.emptyStateView!(context);
    } else {
      return AIUtils.getEmptyView(context, theme,
          backgroundColor: widget.aiConversationStarterStyle?.backgroundColor,
          shadowColor: widget.aiConversationStarterStyle?.shadowColor,
          emptyIconUrl: widget.emptyIconUrl,
          emptyIconTint: widget.aiConversationStarterStyle?.emptyIconTint,
          emptyStateText: widget.emptyStateText,
          emptyTextStyle: widget.aiConversationStarterStyle?.emptyTextStyle,
          emptyIconPackageName: widget.emptyIconPackageName);
    }
  }

  Widget _getLoadingIndicator(CometChatTheme theme) {
    if (widget.loadingStateView != null) {
      return widget.loadingStateView!(context);
    } else {
      return AIUtils.getLoadingIndicator(context, theme,
          backgroundColor: widget.aiConversationStarterStyle?.backgroundColor,
          shadowColor: widget.aiConversationStarterStyle?.shadowColor,
          loadingIconUrl: widget.loadingIconUrl,
          loadingIconTint: widget.aiConversationStarterStyle?.loadingIconTint,
          loadingStateText: widget.loadingStateText ??
              Translations.of(context).generatingIceBreakers,
          loadingTextStyle: widget.aiConversationStarterStyle?.loadingTextStyle,
          loadingIconPackageName: widget.loadingIconPackageName);
    }
  }

  onClickReply(String reply) async {
    Map<String, dynamic> id = {};
    String receiverId = "";
    if (widget.user != null) {
      receiverId = widget.user!.uid;
    } else if (widget.group != null) {
      receiverId = widget.group!.guid;
    }
    id['uid'] = receiverId;
    id['guid'] = receiverId;
    CometChatUIEvents.hidePanel(id, CustomUIPosition.composerTop);

    CometChatUIEvents.ccComposeMessage(reply, MessageEditStatus.inProgress);
  }

  @override
  Widget build(BuildContext context) {
    return (!isKeyboardOpen)
        ? isLoading
            ? _getLoadingIndicator(_theme)
            : isError
                ? _getOnError(context, _theme)
                : _replies.isEmpty
                    ? _getEmptyView(context, _theme)
                    : (widget.customView != null)
                        ? widget.customView!(_replies, context)
                        : SizedBox(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListView.separated(
                                    itemCount: _replies.length,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemBuilder: (_, int item) {
                                      return GestureDetector(
                                        onTap: () {
                                          onClickReply(_replies[item]);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: widget
                                                    .aiConversationStarterStyle
                                                    ?.background ??
                                                _theme.palette.getBackground(),
                                            gradient: widget
                                                .aiConversationStarterStyle
                                                ?.gradient,
                                            border: widget
                                                    .aiConversationStarterStyle
                                                    ?.border ??
                                                Border.all(
                                                    color: _theme.palette
                                                        .getAccent700(),
                                                    width: 1),
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(widget
                                                        .aiConversationStarterStyle
                                                        ?.borderRadius ??
                                                    8)),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              _replies[item],
                                              style: widget
                                                      .aiConversationStarterStyle
                                                      ?.replyTextStyle ??
                                                  TextStyle(
                                                    fontSize: _theme.typography
                                                        .title2.fontSize,
                                                    fontWeight: _theme
                                                        .typography
                                                        .title2
                                                        .fontWeight,
                                                    color: _theme.palette
                                                        .getAccent800(),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    separatorBuilder: (_, int i) {
                                      return const SizedBox(
                                        height: 5,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
        : const SizedBox();
  }
}
