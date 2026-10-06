import 'package:flutter/material.dart';

import '../../../shared_ui/cometchat_uikit_shared.dart';
import '../../../shared_ui/src/clean_architecture/core/utils/thread_toast.dart';
import 'cometchat_pinned_messages_style.dart';

///[CometChatPinnedMessages] renders the pinned messages of one conversation
///as a pushed screen that opens inside the chat context — the same
///navigation used for threads: on the nearest [Navigator], so on a desktop
///side-by-side layout it replaces only the chat column, and on mobile it is
///a full-screen route (Pin & Save Message).
///
///Open it via [CometChatPinnedMessages.show], or embed the widget directly.
///Rows are read-only previews ordered newest-pinned-first; each row carries
///an Unpin affordance (permission-gated) and reports taps through
///[onItemTap] so the host screen can jump to the message.
///
///The list stays live without a refetch: it follows the kit events
///(ccMessagePinned/ccMessageUnpinned) for same-screen actions and the SDK's
///[MessageListener.onMessagePinned]/[onMessageUnpinned] broadcast for other
///members' actions.
class CometChatPinnedMessages extends StatefulWidget {
  const CometChatPinnedMessages({
    super.key,
    this.user,
    this.group,
    this.onItemTap,
    this.style,
    this.hideUnpinOption,
    this.showBackButton = true,
    this.hideAppBar = false,
  }) : assert(
         user != null || group != null,
         'One of user or group must be passed',
       );

  ///[user] 1-1 conversation scope. Mutually exclusive with [group].
  final User? user;

  ///[group] group conversation scope. Mutually exclusive with [user].
  final Group? group;

  ///[onItemTap] fires when a row is tapped, after the screen pops — use it
  ///to jump the message list to the tapped message.
  final Function(BaseMessage message)? onItemTap;

  ///[style] styling overrides
  final CometChatPinnedMessagesStyle? style;

  ///[hideUnpinOption] hides the per-row unpin affordance even when the
  ///logged-in user has permission.
  final bool? hideUnpinOption;

  ///[showBackButton] toggles the header's close affordance — turn it off
  ///when the screen is embedded in a host-owned panel that supplies its own.
  final bool showBackButton;

  ///[hideAppBar] drops the header entirely. Set it when the host already
  ///renders a title bar for this content — a desktop side panel does, and
  ///two stacked headers is the result otherwise.
  final bool hideAppBar;

  ///Opens the pinned-messages screen for one conversation, pushed on the
  ///nearest [Navigator] with the same fade+slide transition threads use —
  ///inside a nested chat-panel navigator this replaces only the chat column.
  static Future<void> show(
    BuildContext context, {
    User? user,
    Group? group,
    Function(BaseMessage message)? onItemTap,
    CometChatPinnedMessagesStyle? style,
    bool? hideUnpinOption,
    bool showBackButton = true,
    bool hideAppBar = false,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, _) => CometChatPinnedMessages(
          user: user,
          group: group,
          onItemTap: onItemTap,
          style: style,
          hideUnpinOption: hideUnpinOption,
          showBackButton: showBackButton,
          hideAppBar: hideAppBar,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<CometChatPinnedMessages> createState() =>
      _CometChatPinnedMessagesState();
}

class _CometChatPinnedMessagesState extends State<CometChatPinnedMessages> {
  static int _instanceCounter = 0;
  late final String _listenerId = 'pinned_messages_panel_${++_instanceCounter}';

  final List<BaseMessage> _messages = [];
  bool _loading = true;
  bool _failed = false;

  // Separate delegate listeners: the kit and SDK listener mixins both
  // declare onCardMessageReceived with different CardMessage types, so one
  // class cannot mix in both.
  late final _PinnedKitEventsDelegate _kitEvents;
  late final _PinnedSdkEventsDelegate _sdkEvents;

  @override
  void initState() {
    super.initState();
    _kitEvents = _PinnedKitEventsDelegate(
      onPinned: _applyPinned,
      onUnpinned: _applyUnpinned,
      onUpdated: _applyUpdated,
      onRemoved: _applyRemoved,
    );
    _sdkEvents = _PinnedSdkEventsDelegate(
      onPinned: _applyPinned,
      onUnpinned: _applyUnpinned,
      onUpdated: _applyUpdated,
      onRemoved: _applyRemoved,
    );
    CometChatMessageEvents.addMessagesListener(_listenerId, _kitEvents);
    CometChat.addMessageListener(_listenerId, _sdkEvents);
    _fetchAll();
  }

  @override
  void dispose() {
    CometChatMessageEvents.removeMessagesListener(_listenerId);
    CometChat.removeMessageListener(_listenerId);
    super.dispose();
  }

  /// Page size for the pin fetch. Pins are capped server-side (default 100),
  /// so one page usually returns the whole list.
  static const int _pageSize = 100;

  /// Pins are capped server-side, so the whole list is fetched up front.
  ///
  /// Uses the standard [MessagesRequestBuilder] with `setPinned(true)`;
  /// fetchPrevious walks backwards through the list, which is the direction
  /// the server orders pins in (newest-pinned-first).
  Future<void> _fetchAll() async {
    final builder = MessagesRequestBuilder()
      ..limit = _pageSize
      ..pinned = true;
    if (widget.user != null) builder.uid = widget.user!.uid;
    if (widget.group != null) builder.guid = widget.group!.guid;
    final request = builder.build();

    final collected = <BaseMessage>[];
    var failed = false;
    while (true) {
      final page = await request.fetchPrevious(
        onSuccess: null,
        onError: (_) => failed = true,
      );
      if (failed) break;
      collected.addAll(page);
      // A short page means the list is exhausted; an empty one means it
      // already was.
      if (page.length < _pageSize) break;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = failed && collected.isEmpty;
      _messages
        ..clear()
        ..addAll(collected);
    });
  }

  /// Re-runs the initial fetch after a failure. Returns the view to its
  /// loading state first, so Retry reads as doing something even when the
  /// request fails again.
  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _fetchAll();
  }

  /// Whether to offer the per-row unpin affordance.
  ///
  /// Unpin permission is deliberately NOT decided here — the server owns it,
  /// exactly as for the pin option in the message list. This used to require
  /// group owner/admin/moderator scope, but no permission data is served for
  /// pinning (no capability on Group, no scope key in the /me
  /// `features.ux.messages.pinned.*` family — only `enabled` and `limit`), so
  /// that rule hardcoded a policy the backend never stated and silently hid
  /// unpin from users their server may well allow. It also contradicted the
  /// message list, which now offers pin/unpin to everyone.
  ///
  /// An unauthorized unpin returns ERR_UNAUTHORIZED / ERR_FORBIDDEN /
  /// ERR_PERMISSION_DENIED, which surfaces as a visible error instead.
  bool get _canUnpin {
    if (widget.hideUnpinOption == true) return false;
    return CometChatUIKit.loggedInUser != null;
  }

  // ── live sync ─────────────────────────────────────────────────────────

  /// Whether a live pin event belongs to the conversation this screen lists.
  ///
  /// Matched exactly on the receiver fields: a substring test on the
  /// conversation id let a screen for user `e` take pins from `me_user_bob`,
  /// and group `g1` take them from `group_g10`. A message without receiver
  /// fields falls back to the SDK's conversation-id shapes, `group_<guid>`
  /// and `<uid>_user_<uid>`, and one carrying neither is kept, as before.
  bool _inScope(BaseMessage message) {
    final group = widget.group;
    final user = widget.user;
    if (group == null && user == null) return true;
    final conversationId = message.conversationId;
    final hasReceiver = message.receiverUid.isNotEmpty;
    if (!hasReceiver && conversationId == null) return true;

    if (group != null) {
      if (hasReceiver) {
        return message.receiverType == ReceiverTypeConstants.group &&
            message.receiverUid == group.guid;
      }
      return conversationId == 'group_${group.guid}';
    }

    final peer = user!.uid;
    final me = CometChatUIKit.loggedInUser?.uid;
    if (hasReceiver) {
      if (message.receiverType != ReceiverTypeConstants.user) return false;
      final participants = {message.sender?.uid, message.receiverUid};
      return participants.contains(peer) &&
          (me == null || participants.contains(me));
    }
    if (me == null) {
      return conversationId!.startsWith('${peer}_user_') ||
          conversationId.endsWith('_user_$peer');
    }
    return conversationId == '${me}_user_$peer' ||
        conversationId == '${peer}_user_$me';
  }

  void _applyPinned(BaseMessage message) {
    if (!mounted || !_inScope(message)) return;
    setState(() {
      _messages.removeWhere((existing) => existing.id == message.id);
      _messages.insert(0, message);
    });
  }

  void _applyUnpinned(BaseMessage message) {
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((existing) => existing.id == message.id);
    });
  }

  /// Refreshes a row in place, keeping its position. Ignores messages that
  /// are not pinned here.
  ///
  /// The incoming payload speaks only for its own change, so the pin fields
  /// are carried over: an edit or save frame carries none, and dropping them
  /// would strip the row of the very state this screen lists it for.
  void _applyUpdated(BaseMessage message) {
    if (!mounted) return;
    final index = _messages.indexWhere((existing) => existing.id == message.id);
    if (index == -1) return;
    message.pinnedAt ??= _messages[index].pinnedAt;
    message.pinnedBy ??= _messages[index].pinnedBy;
    setState(() => _messages[index] = message);
  }

  /// Drops a row whose message is gone. Silently does nothing when the
  /// message was not pinned.
  void _applyRemoved(BaseMessage message) {
    if (!mounted) return;
    if (!_messages.any((existing) => existing.id == message.id)) return;
    setState(() {
      _messages.removeWhere((existing) => existing.id == message.id);
    });
  }

  // ── actions ───────────────────────────────────────────────────────────

  /// Compact Material-style dialog chrome (filled primary confirm button,
  /// reduced sizes) — mirrors the message list's pin/save dialogs.
  CometChatConfirmDialogStyle _confirmDialogStyle(BuildContext context) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    return CometChatConfirmDialogStyle(
      confirmButtonBackground: colorPalette.primary,
      confirmButtonTextColor: colorPalette.white,
      titleTextStyle: TextStyle(
        color: colorPalette.textPrimary,
        fontSize: typography.heading4?.medium?.fontSize,
        fontWeight: typography.heading4?.medium?.fontWeight,
        fontFamily: typography.heading4?.medium?.fontFamily,
      ),
      messageTextStyle: TextStyle(
        color: colorPalette.textSecondary,
        fontSize: typography.caption1?.regular?.fontSize,
        fontWeight: typography.caption1?.regular?.fontWeight,
        fontFamily: typography.caption1?.regular?.fontFamily,
      ),
    );
  }

  /// Maps an unpin failure to its toast text. Permission rejections get their
  /// own copy: now that unpin is offered to everyone and the server arbitrates,
  /// "no permission" is the expected refusal, not a generic failure.
  String _unpinErrorText(CometChatException error) {
    switch (error.code) {
      case 'ERR_UNAUTHORIZED':
      case 'ERR_FORBIDDEN':
      case 'ERR_PERMISSION_DENIED':
        return Translations.of(context).actionPermissionDenied;
      default:
        return Translations.of(context).pinSaveFailed;
    }
  }

  Future<void> _unpin(BaseMessage message) async {
    final translations = Translations.of(context);
    CometChatConfirmDialog(
      context: context,
      style: _confirmDialogStyle(context),
      intentPadding: const EdgeInsets.symmetric(horizontal: 40),
      iconPadding: const EdgeInsets.only(top: 16, bottom: 4),
      titlePadding: const EdgeInsets.only(left: 24, right: 24, bottom: 4),
      contentPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 4),
      actionsPadding: const EdgeInsets.only(left: 24, right: 24),
      icon: Icon(
        Icons.push_pin,
        color:
            const CometChatPinnedMessagesStyle()
                .merge(widget.style)
                .unpinIconColor ??
            CometChatThemeHelper.getColorPalette(context).iconHighlight,
        size: 32,
      ),
      title: Text(translations.unpinConfirmTitle, textAlign: TextAlign.center),
      messageText: Text(
        translations.unpinConfirmMessage,
        textAlign: TextAlign.center,
      ),
      confirmButtonText: translations.unpinButton,
      cancelButtonText: translations.cancel,
      onConfirm: (dialogContext) async {
        Navigator.of(dialogContext).pop();
        final updated = await CometChat.unpinMessage(
          message.id,
          onError: (error) {
            if (mounted) {
              CometChatThreadToast.show(context, _unpinErrorText(error));
            }
          },
        );
        if (updated != null) {
          CometChatMessageEvents.ccMessageUnpinned(updated);
          if (mounted) {
            CometChatThreadToast.show(
              context,
              Translations.of(context).messageUnpinnedToast,
            );
          }
        }
      },
    ).show();
  }

  // ── rendering ─────────────────────────────────────────────────────────

  /// Templates resolved once — same source the message list uses, so rows
  /// render with identical bubbles.
  late final List<CometChatMessageTemplate> _templates =
      MessageTemplateUtils.getAllMessageTemplates();

  CometChatMessageTemplate _templateFor(BaseMessage message) {
    return _templates.firstWhere(
      (template) =>
          template.category == message.category &&
          template.type == message.type,
      orElse: () => _templates.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final spacing = CometChatThemeHelper.getSpacing(context);
    final style = const CometChatPinnedMessagesStyle().merge(widget.style);
    final translations = Translations.of(context);

    // Pushed-screen chrome (thread-style): back arrow + title bar, matching
    // the thread screen's top-bar idiom.
    return Scaffold(
      backgroundColor: style.backgroundColor ?? colorPalette.background1,
      // Message-header chrome: back arrow on the left, title left-aligned
      // beside it, hairline underneath. centerTitle is spelled out because
      // AppBar centres by default on iOS, which would break the alignment
      // on one platform only.
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              backgroundColor: style.appBarColor ?? colorPalette.background1,
              elevation: 0,
              automaticallyImplyLeading: false,
              centerTitle: false,
              titleSpacing: widget.showBackButton ? 0 : 16,
              leading: widget.showBackButton
                  ? IconButton(
                      tooltip: Translations.of(context).back,
                      icon: Icon(
                        Icons.arrow_back,
                        color: style.iconColor ?? colorPalette.iconPrimary,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null,
              title: Text(
                translations.pinnedMessagesTitle,
                style: TextStyle(
                  color: colorPalette.textPrimary,
                  fontSize: typography.heading2?.bold?.fontSize,
                  fontFamily: typography.heading2?.bold?.fontFamily,
                  fontWeight: typography.heading2?.bold?.fontWeight,
                ).merge(style.titleTextStyle),
              ),
              // borderDefault, not borderLight: at 1dp the light tone all but
              // disappears against the header, and this rule is what separates the
              // header from the list.
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color:
                      style.separatorColor ??
                      colorPalette.borderDefault ??
                      colorPalette.borderLight,
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildBody(colorPalette, typography, spacing, style),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatPinnedMessagesStyle style,
  ) {
    final translations = Translations.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      // The kit's standard error state — illustration, "Oops!", explainer and
      // a Retry button — the same one the conversations, groups and user
      // listings show, rather than a bare line of text with no way out.
      return UIStateUtils.getDefaultErrorStateView(
        context,
        colorPalette,
        typography,
        spacing,
        _retry,
      );
    }
    if (_messages.isEmpty) {
      // Filled pin, bold headline, muted one-sentence explainer — the empty
      // state carries the "what is this screen for" that a bare label can't.
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.padding8 ?? 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mirrored on the X axis, then tilted — the stock glyph leans
              // the wrong way for this composition.
              Transform.flip(
                flipX: true,
                child: Transform.rotate(
                  angle: -0.35,
                  child: Icon(
                    Icons.push_pin,
                    size: 64,
                    color: colorPalette.iconSecondary,
                  ),
                ),
              ),
              SizedBox(height: spacing.padding5 ?? 20),
              Text(
                translations.noPinnedMessages,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorPalette.textPrimary,
                  fontSize: typography.heading4?.bold?.fontSize,
                  fontWeight: FontWeight.w700,
                  fontFamily: typography.heading4?.bold?.fontFamily,
                ),
              ),
              SizedBox(height: spacing.padding2 ?? 8),
              Text(
                translations.noPinnedMessagesSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorPalette.textSecondary,
                  fontSize: typography.body?.regular?.fontSize,
                  fontWeight: typography.body?.regular?.fontWeight,
                  fontFamily: typography.body?.regular?.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Rows render as REAL message bubbles — the exact widgets the message
    // list produces (same templates, alignment, avatar/name rules), made
    // read-only with IgnorePointer; a whole-row tap jumps to the message.
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: spacing.padding1 ?? 4),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final bool isOutgoing =
            message.sender?.uid == CometChatUIKit.loggedInUser?.uid;
        final alignment = isOutgoing
            ? BubbleAlignment.right
            : BubbleAlignment.left;

        final bubble = MessageUtils.getMessageBubble(
          context: context,
          colorPalette: colorPalette,
          spacing: spacing,
          typography: typography,
          bubbleAlignment: alignment,
          message: message,
          template: _templateFor(message),
          textFormatters: [
            MarkdownTextFormatter(),
            ...MessageTemplateUtils.getDefaultTextFormatters(),
          ],
          // Every pinned row reads as one left-aligned list; own messages
          // keep their outgoing colour but are attributed to "You".
          forceLeftLayout: true,
          senderNameOverride: isOutgoing
              ? Translations.of(context).youLabel
              : null,
          // Row header reads "Name • dd/MM/yy": the list spans days and has
          // no date separators of its own.
          showSentDateInHeader: true,
          // Every row here is pinned, and the pin glyph is what makes that
          // legible once the row is lifted out of the chat.
          showPinIndicator: true,
          // Also flag rows the reader has saved.
          showSaveIndicator: true,
          // Delivery/read ticks belong to the live chat, not to a pin digest.
          receiptsVisibility: false,
        );

        return Padding(
          // Tighter than the chat list: this is a scan-the-pins view, so
          // rows sit closer together.
          padding: EdgeInsets.fromLTRB(
            spacing.padding3 ?? 12,
            1,
            spacing.padding3 ?? 12,
            1,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Only pop when this screen owns its route. Embedded in a
              // host-owned panel (showBackButton: false) there is nothing of
              // ours on the stack, and popping would close the host's route.
              if (widget.showBackButton) Navigator.of(context).maybePop();
              widget.onItemTap?.call(message);
            },
            // The row carries no unpin icon — the chat list has none either.
            // Long-press keeps unpin reachable.
            onLongPress: _canUnpin ? () => _unpin(message) : null,
            // The bubble's own Row now hands its child bounded width
            // (MessageUtils.getMessageBubble wraps it in a Flexible), so this
            // cap actually binds and long text wraps instead of running off
            // the right edge. 82% leaves the usual chat-bubble gutter.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.82,
              ),
              child: IgnorePointer(child: bubble),
            ),
          ),
        );
      },
    );
  }
}

/// Kit-event delegate: reacts to pin/unpin actions taken on this device.
class _PinnedKitEventsDelegate with CometChatMessageEventListener {
  _PinnedKitEventsDelegate({
    required this.onPinned,
    required this.onUnpinned,
    required this.onUpdated,
    required this.onRemoved,
  });

  final void Function(BaseMessage message) onPinned;
  final void Function(BaseMessage message) onUnpinned;

  /// Refreshes a row already in the list, leaving membership alone.
  final void Function(BaseMessage message) onUpdated;

  /// Drops a row — a message that no longer exists cannot stay pinned.
  final void Function(BaseMessage message) onRemoved;

  @override
  void ccMessagePinned(BaseMessage message) => onPinned(message);

  @override
  void ccMessageUnpinned(BaseMessage message) => onUnpinned(message);

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (status == MessageEditStatus.success) onUpdated(message);
  }

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    if (messageStatus == EventStatus.success) onRemoved(message);
  }

  // Pinned rows carry a save glyph, so save changes refresh them in place —
  // they never add or remove a row here.
  @override
  void ccMessageSaved(BaseMessage message) => onUpdated(message);

  @override
  void ccMessageUnsaved(BaseMessage message) => onUpdated(message);
}

/// SDK-event delegate: pin/unpin broadcasts from other members, plus the
/// events that change what an already-pinned row should show.
class _PinnedSdkEventsDelegate with MessageListener {
  _PinnedSdkEventsDelegate({
    required this.onPinned,
    required this.onUnpinned,
    required this.onUpdated,
    required this.onRemoved,
  });

  final void Function(BaseMessage message) onPinned;
  final void Function(BaseMessage message) onUnpinned;
  final void Function(BaseMessage message) onUpdated;
  final void Function(BaseMessage message) onRemoved;

  @override
  void onMessagePinned(BaseMessage message) => onPinned(message);

  @override
  void onMessageUnpinned(BaseMessage message) => onUnpinned(message);

  @override
  void onMessageEdited(BaseMessage message) => onUpdated(message);

  @override
  void onMessageDeleted(BaseMessage message) => onRemoved(message);

  @override
  void onMessageModerated(BaseMessage message) => onUpdated(message);

  @override
  void onMessageSaved(BaseMessage message) => onUpdated(message);

  @override
  void onMessageUnsaved(BaseMessage message) => onUpdated(message);
}
