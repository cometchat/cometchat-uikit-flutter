import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../cometchat_uikit_shared.dart';
import '../../logging/cometchat_log.dart';

/// Displays an AI-generated conversation summary.
///
/// Fetches a summary from the SDK and renders it in a decorated container
/// above the composer. Hides when the keyboard is open.
class CometChatAIConversationSummaryView extends StatefulWidget {
  const CometChatAIConversationSummaryView({
    super.key,
    this.user,
    this.group,
    this.aiConversationSummaryStyle,
    this.title,
    this.customView,
    this.loadingStateView,
    this.errorStateView,
    this.emptyStateView,
    this.onCloseIconTap,
    this.emptyStateText,
    this.errorStateText,
    this.apiConfiguration,
  });

  final User? user;
  final Group? group;
  final String? title;
  final CometChatAIConversationSummaryStyle? aiConversationSummaryStyle;
  final Widget Function(String summary, BuildContext context)? customView;
  final WidgetBuilder? emptyStateView;
  final WidgetBuilder? loadingStateView;
  final WidgetBuilder? errorStateView;
  final Function(Map<String, dynamic> id)? onCloseIconTap;
  final String? errorStateText;
  final String? emptyStateText;
  final Map<String, dynamic>? apiConfiguration;

  @override
  State<CometChatAIConversationSummaryView> createState() =>
      _CometChatAIConversationSummaryViewState();
}

class _CometChatAIConversationSummaryViewState
    extends State<CometChatAIConversationSummaryView>
    with WidgetsBindingObserver {
  String _summary = '';
  bool _isLoading = false;
  bool _isError = false;
  bool _isKeyboardOpen = false;

  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;
  late CometChatAIConversationSummaryStyle _style;
  bool _themeInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchSummary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final value = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    final keyboardOpen = value > 0;
    if (keyboardOpen != _isKeyboardOpen) {
      setState(() => _isKeyboardOpen = keyboardOpen);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      _style =
          CometChatThemeHelper.getTheme<CometChatAIConversationSummaryStyle>(
            context: context,
            defaultTheme: CometChatAIConversationSummaryStyle.of,
          ).merge(widget.aiConversationSummaryStyle);
      _colorPalette = CometChatThemeHelper.getColorPalette(context);
      _spacing = CometChatThemeHelper.getSpacing(context);
      _typography = CometChatThemeHelper.getTypography(context);
      _themeInitialized = true;
    }
  }

  Future<void> _fetchSummary() async {
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

    await CometChat.getConversationSummary(
      receiverId,
      receiverType,
      configuration: widget.apiConfiguration,
      onSuccess: (summary) {
        if (mounted) setState(() => _summary = summary);
      },
      onError: (error) {
        if (kDebugMode) {
          ccLog('Error in AI conversation summary: ${error.details}');
        }
        if (mounted) setState(() => _isError = true);
      },
    );

    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildLoading() {
    if (widget.loadingStateView != null) {
      return Center(child: widget.loadingStateView!(context));
    }
    return CometChatShimmerEffect(
      colorPalette: _colorPalette,
      child: ListView.builder(
        itemCount: 6,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: _spacing.padding5 ?? 0,
              vertical: _spacing.padding2 ?? 0,
            ),
            margin: EdgeInsets.only(bottom: _spacing.margin2 ?? 0),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(_spacing.radiusMax ?? 0),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    if (widget.errorStateView != null) {
      return Center(child: widget.errorStateView!(context));
    }
    return AIUtils.getErrorText(
      context,
      _colorPalette,
      _typography,
      _spacing,
      errorStateText: widget.errorStateText,
      errorTextStyle: _style.errorTextStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isKeyboardOpen) return const SizedBox.shrink();

    return CometChatDecoratedContainer(
      title: Translations.of(context).conversationSummary,
      content: _isLoading
          ? _buildLoading()
          : _isError
          ? _buildError()
          : (widget.customView != null)
          ? widget.customView!(_summary, context)
          : Padding(
              padding: EdgeInsets.symmetric(vertical: _spacing.padding1 ?? 0),
              child: Text(
                _summary,
                style: TextStyle(
                  color: _colorPalette.textPrimary,
                  fontSize: _typography.body?.regular?.fontSize,
                  fontWeight: _typography.body?.regular?.fontWeight,
                ).merge(_style.summaryTextStyle),
              ),
            ),
      style: DecoratedContainerStyle(
        backgroundColor: _style.backgroundColor,
        borderRadius: _style.borderRadius,
        border: _style.border,
        titleStyle: _style.titleStyle,
        closeIconColor: _style.closeIconColor,
      ),
      colorPalette: _colorPalette,
      typography: _typography,
      spacing: _spacing,
      padding: EdgeInsets.symmetric(
        horizontal: _spacing.padding4 ?? 0,
        vertical: _spacing.padding3 ?? 0,
      ),
      onCloseIconTap: () {
        final idMap = UIEventUtils.createMap(
          widget.user?.uid,
          widget.group?.guid,
          0,
        );
        if (widget.onCloseIconTap != null) {
          widget.onCloseIconTap!(idMap);
        } else {
          idMap[AIUtils.extensionKey] =
              AIFeatureConstants.aiConversationSummary;
          CometChatUIEvents.hidePanel(idMap, CustomUIPosition.composerTop);
        }
      },
    );
  }
}
