import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../cometchat_uikit_shared.dart';
import '../../logging/cometchat_log.dart';
import '../../clean_architecture/core/utils/ui_event_target.dart';

/// Displays AI-generated conversation starter suggestions as tappable chips.
///
/// Shown when the chat is empty to help users begin a conversation with the AI.
class CometChatAIConversationStarterView extends StatefulWidget {
  const CometChatAIConversationStarterView({
    super.key,
    this.user,
    this.group,
    this.style,
    this.apiConfiguration,
  });

  final User? user;
  final Group? group;
  final CometChatAIConversationStarterStyle? style;
  final Map<String, dynamic>? apiConfiguration;

  @override
  State<CometChatAIConversationStarterView> createState() =>
      _CometChatAIConversationStarterViewState();
}

class _CometChatAIConversationStarterViewState
    extends State<CometChatAIConversationStarterView> {
  List<String> _replies = [];
  bool _isLoading = false;
  bool _isError = false;

  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;
  late CometChatAIConversationStarterStyle _style;
  bool _themeInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchStarters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      _style =
          CometChatThemeHelper.getTheme<CometChatAIConversationStarterStyle>(
            context: context,
            defaultTheme: CometChatAIConversationStarterStyle.of,
          ).merge(widget.style);
      _colorPalette = CometChatThemeHelper.getColorPalette(context);
      _spacing = CometChatThemeHelper.getSpacing(context);
      _typography = CometChatThemeHelper.getTypography(context);
      _themeInitialized = true;
    }
  }

  Future<void> _fetchStarters() async {
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

    await CometChat.getConversationStarter(
      receiverId,
      receiverType,
      configuration: widget.apiConfiguration,
      onSuccess: (reply) {
        if (mounted) setState(() => _replies = reply);
      },
      onError: (error) {
        if (kDebugMode) {
          ccLog('Error in AI conversation starter: ${error.details}');
        }
        if (mounted) setState(() => _isError = true);
      },
    );

    if (mounted) setState(() => _isLoading = false);
  }

  void _onReplyTapped(String reply) {
    // Previously this set BOTH uid and guid to the same value, so a group's
    // guid was also published as a uid. Nothing caught it while matching only
    // compared keys both sides happened to carry.
    final id = buildUiEventId(uid: widget.user?.uid, guid: widget.group?.guid);
    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
    CometChatUIEvents.ccComposeMessage(reply, MessageEditStatus.inProgress);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isError || _replies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _spacing.padding2 ?? 0,
        vertical: _spacing.padding1 ?? 0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListView.separated(
              itemCount: _replies.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (_, int index) {
                return GestureDetector(
                  onTap: () => _onReplyTapped(_replies[index]),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _spacing.padding5 ?? 0,
                        vertical: _spacing.padding2 ?? 0,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _style.backgroundColor ?? _colorPalette.background1,
                        border:
                            _style.border ??
                            Border.all(
                              color:
                                  _colorPalette.borderLight ??
                                  Colors.transparent,
                              width: 1,
                            ),
                        borderRadius:
                            _style.borderRadius ??
                            BorderRadius.all(
                              Radius.circular(_spacing.radiusMax ?? 0),
                            ),
                      ),
                      child: Text(
                        _replies[index],
                        style:
                            _style.itemTextStyle ??
                            TextStyle(
                              fontSize: _typography.body?.regular?.fontSize,
                              fontWeight: _typography.body?.regular?.fontWeight,
                              color: _colorPalette.textPrimary,
                            ),
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 8),
            ),
          ],
        ),
      ),
    );
  }
}
