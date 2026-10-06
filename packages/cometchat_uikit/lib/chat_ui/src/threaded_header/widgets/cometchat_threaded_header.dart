import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../cometchat_chat_uikit.dart';
import '../../../../cometchat_chat_uikit.dart' as cc;
import '../../../../shared_ui/src/clean_architecture/core/utils/thread_toast.dart';

/// [CometChatThreadedHeader] is a widget that displays a parent message
/// and its reply count in a threaded conversation view.
///
/// This widget uses BLoC for state management and follows Clean Architecture
/// patterns. It listens to SDK events for real-time reply count updates
/// and parent message changes (edit/delete).
///
/// ```dart
/// CometChatThreadedHeader(
///   parentMessage: BaseMessage(),
///   loggedInUser: User(),
/// );
/// ```
class CometChatThreadedHeader extends StatefulWidget {
  const CometChatThreadedHeader({
    super.key,
    required this.parentMessage,
    this.messageActionView,
    this.style,
    required this.loggedInUser,
    this.template,
    this.height,
    this.width,
    this.receiptsVisibility = true,
    this.threadSubscriptionVisibility = true,
    this.onThreadSubscriptionChange,
    this.textFormatters,
    // Optional pre-cached theme values for optimization
    this.colorPalette,
    this.typography,
    this.spacing,
    this.threadedHeaderBloc,
  });

  /// [parentMessage] parent message for thread
  final BaseMessage parentMessage;

  /// [messageActionView] custom action view
  final Function(BaseMessage message, BuildContext context)? messageActionView;

  /// [style] style parameter
  final CometChatThreadedHeaderStyle? style;

  /// [loggedInUser] get logged in user
  final User loggedInUser;

  /// [template] to get the message template
  final CometChatMessageTemplate? template;

  /// [height] provides height to the widget
  final double? height;

  /// [width] provides width to the widget
  final double? width;

  /// [receiptsVisibility] controls visibility of receipts
  final bool? receiptsVisibility;

  /// [threadSubscriptionVisibility] controls visibility of the follow/unfollow
  /// control in the reply-count row. Only takes effect when the
  /// thread-subscription feature gate ([UIKitSettings.enableThreadSubscription])
  /// is on — with the gate off the control never renders regardless of this
  /// flag. [messageActionView] keeps winning as the full-replacement escape
  /// hatch: when it is set, the built-in control (and this flag) is bypassed.
  final bool? threadSubscriptionVisibility;

  /// [onThreadSubscriptionChange] called after the follow/unfollow toggle
  /// succeeds, with the parent message id and the new subscribed state.
  final Function(int parentMessageId, bool subscribed)?
  onThreadSubscriptionChange;

  /// [textFormatters] list of text formatters. null = use defaults, empty = no formatters
  final List<CometChatTextFormatter>? textFormatters;

  /// [colorPalette] optional pre-cached color palette for optimization
  final CometChatColorPalette? colorPalette;

  /// [typography] optional pre-cached typography for optimization
  final CometChatTypography? typography;

  /// [spacing] optional pre-cached spacing for optimization
  final CometChatSpacing? spacing;

  ///[threadedHeaderBloc] Optional external ThreadedHeaderBloc instance.
  ///If provided, it is used instead of creating one internally and the widget
  ///does not close it on dispose. Mirrors
  ///[CometChatConversations.conversationsBloc] — the seam that lets a test
  ///supply a reply count without a live SDK.
  final ThreadedHeaderBloc? threadedHeaderBloc;

  @override
  State<CometChatThreadedHeader> createState() =>
      _CometChatThreadedHeaderState();
}

class _CometChatThreadedHeaderState extends State<CometChatThreadedHeader> {
  /// BLoC for managing threaded header state
  late ThreadedHeaderBloc _bloc;
  bool _isExternalBloc = false;

  /// Theme caching - initialized once in didChangeDependencies
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  /// Merged style
  late CometChatThreadedHeaderStyle _threadedHeaderStyle;

  /// Message template for rendering the parent message bubble
  late CometChatMessageTemplate _messageTemplate;

  /// Key for measuring bubble height
  final _bubbleKey = GlobalKey();

  /// Cached screen height — avoids MediaQuery subscription in build()
  double _cachedScreenHeight = 0;

  /// Cached bubble widget — avoids expensive recreation on every keyboard frame
  Widget? _cachedBubble;
  BaseMessage? _cachedBubbleMessage;

  @override
  void initState() {
    super.initState();

    // Resolve message template from data source based on message category/type
    _resolveMessageTemplate();

    // Create BLoC and dispatch initialization event
    if (widget.threadedHeaderBloc != null) {
      _bloc = widget.threadedHeaderBloc!;
      _isExternalBloc = true;
    } else {
      _bloc = ThreadedHeaderBloc();
      _bloc.add(
        InitializeThreadedHeader(
          parentMessage: widget.parentMessage,
          loggedInUser: widget.loggedInUser,
        ),
      );
    }
  }

  /// Resolve the message template from data source or use custom template
  void _resolveMessageTemplate() {
    // If custom template is provided, use it
    if (widget.template != null) {
      _messageTemplate = widget.template!;
      return;
    }

    // Get all templates from data source
    final templates = MessageTemplateUtils.getAllMessageTemplates();

    // Find matching template based on message category and type
    CometChatMessageTemplate? resolvedTemplate;
    for (final template in templates) {
      if (widget.parentMessage.category == template.category &&
          widget.parentMessage.type == template.type) {
        resolvedTemplate = template;
        break;
      }
    }

    // Use resolved template or fallback to first template
    _messageTemplate = resolvedTemplate ?? templates.first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize theme once to avoid expensive lookups during rebuilds
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (!_themeInitialized || brightnessChanged) {
      _cachedBrightness = currentBrightness;
      // Use passed values or fallback to lookups (for standalone usage)
      _colorPalette =
          widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
      _typography =
          widget.typography ?? CometChatThemeHelper.getTypography(context);
      _spacing = widget.spacing ?? CometChatThemeHelper.getSpacing(context);

      // Merge style with theme
      _threadedHeaderStyle =
          CometChatThemeHelper.getTheme<CometChatThreadedHeaderStyle>(
            context: context,
            defaultTheme: CometChatThreadedHeaderStyle.of,
          ).merge(widget.style);

      // Cache screen height so build() doesn't subscribe to MediaQuery
      _cachedScreenHeight = MediaQuery.sizeOf(context).height;

      _themeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(CometChatThreadedHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update cached theme values if they changed
    if (widget.colorPalette != oldWidget.colorPalette &&
        widget.colorPalette != null) {
      _colorPalette = widget.colorPalette!;
    }
    if (widget.typography != oldWidget.typography &&
        widget.typography != null) {
      _typography = widget.typography!;
    }
    if (widget.spacing != oldWidget.spacing && widget.spacing != null) {
      _spacing = widget.spacing!;
    }

    // Update style if it changed
    if (widget.style != oldWidget.style) {
      _threadedHeaderStyle =
          CometChatThemeHelper.getTheme<CometChatThreadedHeaderStyle>(
            context: context,
            defaultTheme: CometChatThreadedHeaderStyle.of,
          ).merge(widget.style);
    }

    // Re-resolve template if parent message or custom template changed
    if (widget.parentMessage != oldWidget.parentMessage ||
        widget.template != oldWidget.template) {
      _resolveMessageTemplate();
    }

    // A new root is a different thread. The header's own bloc is
    // re-initialized so the bubble, reply count and follow control describe
    // it; an injected bloc belongs to its owner, who re-initializes it.
    if (widget.parentMessage.id != oldWidget.parentMessage.id) {
      _lastSubscriptionToggleAt = null;
      if (!_isExternalBloc) {
        _bloc.add(
          InitializeThreadedHeader(
            parentMessage: widget.parentMessage,
            loggedInUser: widget.loggedInUser,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // an injected bloc belongs to its owner, so only close what we created
    if (!_isExternalBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  /// Debounce + one-in-flight guard for the follow toggle (§7.6): no queue,
  /// no retry, no persistence — a failed toggle reverts visibly.
  bool _subscriptionToggleInFlight = false;
  DateTime? _lastSubscriptionToggleAt;

  static const Duration _toggleDebounce = Duration(milliseconds: 400);

  /// Whether the follow control should render: feature gate on (default off)
  /// AND the per-component visibility flag not disabled.
  bool get _showThreadSubscriptionControl =>
      CometChatUIKit.authenticationSettings?.enableThreadSubscription == true &&
      widget.threadSubscriptionVisibility != false;

  /// Shows one of the thread toasts as a dark pill centered within the
  /// enclosing chat/thread panel (the right-hand panel in a web side-by-side
  /// layout), floating above the composer.
  void _showThreadToast(String text) {
    if (!mounted) return;
    CometChatThreadToast.show(context, text);
  }

  /// Handle a tap on the mute/unmute control: optimistic flip, then the
  /// idempotent SDK call; revert + failure snackbar on error.
  Future<void> _onThreadSubscriptionTap(bool wasSubscribed) async {
    final now = DateTime.now();
    if (_subscriptionToggleInFlight) return;
    if (_lastSubscriptionToggleAt != null &&
        now.difference(_lastSubscriptionToggleAt!) < _toggleDebounce) {
      return;
    }
    _lastSubscriptionToggleAt = now;
    _subscriptionToggleInFlight = true;

    // Act on the thread the header shows: the bloc's root. An injected bloc
    // can lag widget.parentMessage until its owner re-initializes it, and the
    // display, the SDK call and the report must all name the same thread.
    final parentMessageId =
        (_bloc.state.parentMessage ?? widget.parentMessage).id;
    final target = !wasSubscribed;

    // Optimistic flip — the bloc stamps the parent message object; the
    // server call below is the acknowledgement (stateless redesign).
    _bloc.add(UpdateThreadSubscription(target));

    try {
      final result = target
          ? await CometChat.subscribeToThread(parentMessageId)
          : await CometChat.unsubscribeFromThread(parentMessageId);

      if (result != null) {
        // Keep the action-sheet surface (and integrator lists) in agreement.
        CometChatMessageEvents.ccThreadSubscriptionChanged(
          parentMessageId,
          target,
        );
        widget.onThreadSubscriptionChange?.call(parentMessageId, target);
        if (mounted) {
          _showThreadToast(
            target
                ? cc.Translations.of(context).threadUnmutedToast
                : cc.Translations.of(context).threadMutedToast,
          );
        }
      } else {
        // Revert only while the header still shows that thread.
        if (!_bloc.isClosed &&
            (_bloc.state.parentMessage ?? widget.parentMessage).id ==
                parentMessageId) {
          _bloc.add(UpdateThreadSubscription(wasSubscribed));
        }
        if (mounted) {
          _showThreadToast(
            cc.Translations.of(context).threadSubscriptionFailed,
          );
        }
      }
    } finally {
      _subscriptionToggleInFlight = false;
    }
  }

  /// Build the mute/unmute control. Action-labelled per the landed design:
  /// bell + "Mute thread" while notifications are on, bell-off +
  /// "Unmute thread" while muted. An un-told state reads `false` and renders
  /// as the muted affordance, enabled — an unnecessary subscribe is harmless
  /// (idempotent endpoint). IconButton supplies the ≥40dp target,
  /// ripple/hover, cursor, tooltip and the accessible name in one widget
  /// (no manual Semantics — it would double-announce).
  Widget _buildThreadSubscriptionControl(
    bool isSubscribed,
    BuildContext context,
  ) {
    final label = isSubscribed
        ? cc.Translations.of(context).threadMute
        : cc.Translations.of(context).threadUnmute;

    return IconButton(
      onPressed: () => _onThreadSubscriptionTap(isSubscribed),
      tooltip: label,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      icon: Icon(
        isSubscribed
            ? Icons.notifications_outlined
            : Icons.notifications_off_outlined,
        color:
            _threadedHeaderStyle.countTextColor ?? _colorPalette.iconSecondary,
      ),
    );
  }

  /// Build the action view showing reply count
  Widget _buildActionView(
    int replyCount,
    bool threadSubscribed,
    BuildContext context,
  ) {
    if (widget.messageActionView != null) {
      return widget.messageActionView!(widget.parentMessage, context);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            _threadedHeaderStyle.countContainerBackGroundColor ??
            _colorPalette.extendedPrimary100,
        border:
            _threadedHeaderStyle.countContainerBorder ??
            Border(
              bottom: BorderSide(
                width: 1.0,
                color: _colorPalette.borderDefault ?? Colors.transparent,
                style: BorderStyle.solid,
              ),
            ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: _spacing.padding1 ?? 0,
        horizontal: _spacing.padding4 ?? 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "$replyCount ${replyCount > 1 ? cc.Translations.of(context).replies : cc.Translations.of(context).reply}",
              style:
                  TextStyle(
                        color:
                            _threadedHeaderStyle.countTextColor ??
                            _colorPalette.textSecondary,
                        fontSize: _typography.body?.regular?.fontSize,
                        fontFamily: _typography.body?.regular?.fontFamily,
                        fontWeight: _typography.body?.regular?.fontWeight,
                      )
                      .merge(_threadedHeaderStyle.countTextStyle)
                      .copyWith(color: _threadedHeaderStyle.countTextColor),
            ),
          ),
          if (_showThreadSubscriptionControl)
            _buildThreadSubscriptionControl(threadSubscribed, context),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThreadedHeaderBloc, ThreadedHeaderState>(
      bloc: _bloc,
      builder: (context, state) {
        // Use parent message from state if available, otherwise use widget's
        final parentMessage = state.parentMessage ?? widget.parentMessage;
        final replyCount = state.replyCount;

        // Only rebuild the bubble widget when the message actually changes,
        // not on every keyboard animation frame
        if (_cachedBubble == null || _cachedBubbleMessage != parentMessage) {
          _cachedBubbleMessage = parentMessage;
          _cachedBubble = MessageUtils.getMessageBubble(
            context: context,
            colorPalette: _colorPalette,
            spacing: _spacing,
            typography: _typography,
            bubbleAlignment:
                parentMessage.sender?.uid == widget.loggedInUser.uid
                ? BubbleAlignment.right
                : BubbleAlignment.left,
            message: parentMessage,
            template: _messageTemplate,
            outgoingMessageBubbleStyle:
                _threadedHeaderStyle.outgoingMessageBubbleStyle,
            incomingMessageBubbleStyle:
                _threadedHeaderStyle.incomingMessageBubbleStyle,
            textFormatters:
                widget.textFormatters ??
                MessageTemplateUtils.getDefaultTextFormatters(),
            key: _bubbleKey,
            receiptsVisibility: widget.receiptsVisibility,
          );
        }

        // Use cached screen height instead of MediaQuery.sizeOf(context)
        // to avoid subscribing to MediaQuery changes during keyboard animation
        final maxHeight = widget.height ?? _cachedScreenHeight * 0.30;
        final minHeight = (_cachedScreenHeight * 0.10)
            .clamp(0.0, maxHeight)
            .toDouble();

        return Container(
          width: widget.width ?? double.infinity,
          constraints:
              _threadedHeaderStyle.constraints ??
              BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
          // The preview sizes to its content, clamped between 10% and 30%
          // of screen (10:90 floor, 30:70 ceiling). IntrinsicHeight makes
          // the clamp content-aware; Expanded hands any floor-forced extra
          // space to the bubble area rather than leaving a dead strip.
          child: IntrinsicHeight(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          _threadedHeaderStyle.bubbleContainerBackGroundColor ??
                          _colorPalette.background3,
                      borderRadius:
                          _threadedHeaderStyle.bubbleContainerBorderRadius,
                      border: _threadedHeaderStyle.bubbleContainerBorder,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.only(top: _spacing.padding4 ?? 0),
                        child: IgnorePointer(child: _cachedBubble),
                      ),
                    ),
                  ),
                ),
                _buildActionView(replyCount, state.threadSubscribed, context),
              ],
            ),
          ),
        );
      },
    );
  }
}
