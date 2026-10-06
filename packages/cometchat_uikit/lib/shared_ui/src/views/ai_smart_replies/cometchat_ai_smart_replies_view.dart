import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../cometchat_uikit_shared.dart';
import '../../logging/cometchat_log.dart';
import '../../clean_architecture/core/utils/ui_event_target.dart';

/// Displays AI-generated smart reply suggestions as tappable chips.
///
/// Fetches positive, negative, and neutral replies from the SDK and
/// inserts the selected reply into the composer.
class CometChatAISmartRepliesView extends StatefulWidget {
  const CometChatAISmartRepliesView({
    super.key,
    this.user,
    this.group,
    this.style,
    this.apiConfiguration,
  });

  final CometChatAISmartRepliesStyle? style;
  final User? user;
  final Group? group;
  final Map<String, dynamic>? apiConfiguration;

  @override
  State<CometChatAISmartRepliesView> createState() =>
      _CometChatAISmartRepliesViewState();
}

class _CometChatAISmartRepliesViewState
    extends State<CometChatAISmartRepliesView> {
  List<String> _replies = [];
  bool _isLoading = false;
  bool _isError = false;

  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;
  late CometChatAISmartRepliesStyle _style;
  bool _themeInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchReplies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      _style = CometChatThemeHelper.getTheme<CometChatAISmartRepliesStyle>(
        context: context,
        defaultTheme: CometChatAISmartRepliesStyle.of,
      ).merge(widget.style);
      _colorPalette = CometChatThemeHelper.getColorPalette(context);
      _spacing = CometChatThemeHelper.getSpacing(context);
      _typography = CometChatThemeHelper.getTypography(context);
      _themeInitialized = true;
    }
  }

  Future<void> _fetchReplies() async {
    setState(() => _isLoading = true);

    String receiverId = '';
    String receiverType = '';
    if (widget.user != null) {
      receiverId = widget.user!.uid;
      receiverType = CometChatReceiverType.user;
    } else if (widget.group != null) {
      receiverId = widget.group!.guid;
      receiverType = CometChatReceiverType.group;
    }

    final List<String> aiReplies = [];
    await CometChat.getSmartReplies(
      receiverId,
      receiverType,
      configuration: widget.apiConfiguration,
      onSuccess: (reply) {
        if (reply.containsKey('negative')) aiReplies.add(reply['negative']!);
        if (reply.containsKey('positive')) aiReplies.add(reply['positive']!);
        if (reply.containsKey('neutral')) aiReplies.add(reply['neutral']!);
      },
      onError: (error) {
        if (kDebugMode) {
          ccLog('Error in AI smart replies: ${error.message}');
        }
        setState(() => _isError = true);
      },
    );

    if (mounted) {
      setState(() {
        _replies = aiReplies;
        _isLoading = false;
      });
    }
  }

  void _onReplyTapped(String reply) {
    // Previously this set BOTH uid and guid to the same value, so a group's
    // guid was also published as a uid. Nothing caught it while matching only
    // compared keys both sides happened to carry.
    final id = buildUiEventId(uid: widget.user?.uid, guid: widget.group?.guid);
    id[AIUtils.extensionKey] = AIFeatureConstants.aiSmartReplies;
    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
    CometChatUIEvents.ccComposeMessage(reply, MessageEditStatus.inProgress);
  }

  Widget _buildLoading() {
    return CometChatShimmerEffect(
      colorPalette: _colorPalette,
      child: ListView.builder(
        itemCount: 3,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          return Container(
            height: 51,
            padding: EdgeInsets.symmetric(
              horizontal: _spacing.padding3 ?? 0,
              vertical: _spacing.padding2 ?? 0,
            ),
            margin: EdgeInsets.only(bottom: _spacing.margin2 ?? 0),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(_spacing.radius2 ?? 0),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return AIUtils.getErrorText(
      context,
      _colorPalette,
      _typography,
      _spacing,
      errorTextStyle: _style.errorTextStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CometChatDecoratedContainer(
      title: Translations.of(context).suggestAReply,
      onCloseIconTap: () {
        final idMap = UIEventUtils.createMap(
          widget.user?.uid,
          widget.group?.guid,
          0,
        );
        idMap[AIUtils.extensionKey] = AIFeatureConstants.aiSmartReplies;
        CometChatUIEvents.hidePanel(idMap, CustomUIPosition.messageListBottom);
      },
      colorPalette: _colorPalette,
      spacing: _spacing,
      typography: _typography,
      padding: EdgeInsets.all(_spacing.padding3 ?? 0),
      style: DecoratedContainerStyle(
        borderRadius:
            _style.borderRadius ?? BorderRadius.circular(_spacing.radius4 ?? 0),
        border: _style.border,
        backgroundColor: _style.backgroundColor,
        titleStyle: _style.titleStyle,
        closeIconColor: _style.closeIconColor,
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 217),
        child: _isLoading
            ? _buildLoading()
            : _isError
            ? _buildError()
            : SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.separated(
                      itemCount: _replies.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemBuilder: (_, int index) {
                        return GestureDetector(
                          onTap: () => _onReplyTapped(_replies[index]),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: _spacing.padding2 ?? 0,
                              horizontal: _spacing.padding3 ?? 0,
                            ),
                            decoration: BoxDecoration(
                              border:
                                  _style.itemBorder ??
                                  Border.all(
                                    color:
                                        _colorPalette.borderLight ??
                                        Colors.transparent,
                                    width: 1,
                                  ),
                              borderRadius:
                                  _style.itemBorderRadius ??
                                  BorderRadius.circular(_spacing.radius2 ?? 0),
                              color: _style.itemBackgroundColor,
                            ),
                            child: Text(
                              _replies[index],
                              style: TextStyle(
                                fontSize: _typography.body?.regular?.fontSize,
                                fontWeight:
                                    _typography.body?.regular?.fontWeight,
                                color: _colorPalette.textPrimary,
                              ).merge(_style.itemTextStyle),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
