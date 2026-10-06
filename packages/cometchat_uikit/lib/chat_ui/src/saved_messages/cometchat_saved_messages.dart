import 'package:flutter/material.dart';

import '../../../shared_ui/cometchat_uikit_shared.dart';
import '../../../shared_ui/src/clean_architecture/presentation/views/misc/message_preview_subtitle.dart';
import '../../../shared_ui/src/clean_architecture/core/utils/thread_toast.dart';
import 'cometchat_saved_messages_style.dart';

///[CometChatSavedMessages] renders the logged-in user's saved (bookmarked)
///messages across every conversation as a pushed full-screen list (Pin &
///Save Message, §6.9 Flutter container).
///
///Rows are read-only previews ordered newest-saved-first, each with a
///conversation-context line and an Unsave affordance. Taps report through
///[onItemTap] so the host app can open the conversation and jump to the
///message.
///
///The list stays live without a refetch: it follows the kit events
///(ccMessageSaved/ccMessageUnsaved) and the SDK's cross-device
///[MessageListener.onMessageSaved]/[onMessageUnsaved] self-echo.
class CometChatSavedMessages extends StatefulWidget {
  const CometChatSavedMessages({
    super.key,
    this.onItemTap,
    this.style,
    this.hideUnsaveOption,
    this.showBackButton = true,
    this.popOnItemTap = true,
    this.useCloseButton = false,
  });

  ///[onItemTap] fires when a row is tapped — use it to open the message's
  ///conversation and jump to it.
  final Function(BaseMessage message)? onItemTap;

  ///[style] styling overrides
  final CometChatSavedMessagesStyle? style;

  ///[hideUnsaveOption] hides the per-row unsave affordance.
  final bool? hideUnsaveOption;

  ///[popOnItemTap] pops this screen before [onItemTap] fires (default true).
  ///Right for a pushed mobile route, where the row is a jump affordance and
  ///the listing should not stay behind the conversation. Set false when the
  ///list lives in a persistent panel that should survive the jump.
  final bool popOnItemTap;

  ///[showBackButton] shows the app-bar back button (default true).
  final bool showBackButton;

  ///[useCloseButton] swaps the leading back arrow for a trailing ✕, with
  ///the title staying left-aligned — the chrome a desktop panel uses, where
  ///the screen is dismissed rather than navigated back from. Only read when
  ///[showBackButton] is true.
  final bool useCloseButton;

  @override
  State<CometChatSavedMessages> createState() => _CometChatSavedMessagesState();
}

class _CometChatSavedMessagesState extends State<CometChatSavedMessages> {
  static int _instanceCounter = 0;
  late final String _listenerId = 'saved_messages_panel_${++_instanceCounter}';

  final List<BaseMessage> _messages = [];
  bool _loading = true;
  bool _failed = false;

  // Separate delegate listeners: the kit and SDK listener mixins both
  // declare onCardMessageReceived with different CardMessage types, so one
  // class cannot mix in both.
  late final _SavedKitEventsDelegate _kitEvents;
  late final _SavedSdkEventsDelegate _sdkEvents;

  @override
  void initState() {
    super.initState();
    _kitEvents = _SavedKitEventsDelegate(
      onSaved: _applySaved,
      onUnsaved: _applyUnsaved,
      onUpdated: _applyUpdated,
      onRemoved: _applyRemoved,
    );
    _sdkEvents = _SavedSdkEventsDelegate(
      onSaved: _applySaved,
      onUnsaved: _applyUnsaved,
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

  /// Page size for the saved fetch. Saves are capped server-side (default
  /// 100), so one page usually returns the whole list.
  static const int _pageSize = 100;

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

  Future<void> _fetchAll() async {
    // Standard MessagesRequestBuilder with setSaved(true) — unscoped, since
    // saves are per-viewer and span every conversation.
    final request =
        (MessagesRequestBuilder()
              ..limit = _pageSize
              ..saved = true)
            .build();

    final collected = <BaseMessage>[];
    var failed = false;
    while (true) {
      final page = await request.fetchPrevious(
        onSuccess: null,
        onError: (_) => failed = true,
      );
      if (failed) break;
      collected.addAll(page);
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

  // ── live sync ─────────────────────────────────────────────────────────

  void _applySaved(BaseMessage message) {
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((existing) => existing.id == message.id);
      _messages.insert(0, message);
    });
  }

  void _applyUnsaved(BaseMessage message) {
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((existing) => existing.id == message.id);
    });
  }

  /// Refreshes a row in place, keeping its position. Ignores messages that
  /// are not in the list — an edit elsewhere is not this screen's business.
  ///
  /// The incoming payload speaks only for its own change, so savedAt is
  /// carried over: an edit or pin frame carries none, and dropping it would
  /// leave the row without the date it is sorted and stamped by.
  void _applyUpdated(BaseMessage message) {
    if (!mounted) return;
    final index = _messages.indexWhere((existing) => existing.id == message.id);
    if (index == -1) return;
    message.savedAt ??= _messages[index].savedAt;
    setState(() => _messages[index] = message);
  }

  /// Drops a row whose message is gone. Silently does nothing when the
  /// message was not saved.
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

  /// Maps an unsave failure to its toast text. Mirrors the unpin mapper in
  /// the pinned panel: a permission rejection is an expected refusal the
  /// server arbitrates, not a generic failure, so it gets its own copy.
  String _unsaveErrorText(CometChatException error) {
    switch (error.code) {
      case 'ERR_UNAUTHORIZED':
      case 'ERR_FORBIDDEN':
      case 'ERR_PERMISSION_DENIED':
        return Translations.of(context).actionPermissionDenied;
      default:
        return Translations.of(context).pinSaveFailed;
    }
  }

  Future<void> _unsave(BaseMessage message) async {
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
        Icons.bookmark_remove_outlined,
        color:
            const CometChatSavedMessagesStyle()
                .merge(widget.style)
                .unsaveIconColor ??
            CometChatThemeHelper.getColorPalette(context).iconHighlight,
        size: 32,
      ),
      title: Text(translations.unsaveConfirmTitle, textAlign: TextAlign.center),
      messageText: Text(
        translations.unsaveConfirmMessage,
        textAlign: TextAlign.center,
      ),
      confirmButtonText: translations.unsaveButton,
      cancelButtonText: translations.cancel,
      onConfirm: (dialogContext) async {
        Navigator.of(dialogContext).pop();
        final updated = await CometChat.unsaveMessage(
          message.id,
          onError: (error) {
            if (mounted) {
              CometChatThreadToast.show(context, _unsaveErrorText(error));
            }
          },
        );
        if (updated != null) {
          CometChatMessageEvents.ccMessageUnsaved(updated);
          if (mounted) {
            CometChatThreadToast.show(
              context,
              Translations.of(context).messageUnsavedToast,
            );
          }
        }
      },
    ).show();
  }

  // ── rendering ─────────────────────────────────────────────────────────

  /// Conversation-context line: the counterpart the message lives with.
  /// The conversation a saved message belongs to — its name and avatar, so
  /// each row is presented like a conversation-list row.
  ({String name, String? avatar, bool isThreadReply}) _conversationIdentity(
    BuildContext context,
    BaseMessage message,
  ) {
    final receiver = message.receiver;
    final sender = message.sender;
    final loggedInUid = CometChatUIKit.loggedInUser?.uid;

    // Thread replies are NOT titled by their parent conversation — a reply
    // buried in a thread isn't "a message in #group", so showing the group
    // name reads as if it were a main-conversation message. Title it by the
    // author instead (the subtitle then drops the redundant name prefix).
    if (message.parentMessageId != 0) {
      if (sender != null) {
        final isOwn = sender.uid == loggedInUid;
        return (
          name: isOwn ? Translations.of(context).youLabel : sender.name,
          avatar: sender.avatar,
          isThreadReply: true,
        );
      }
      return (name: '', avatar: null, isThreadReply: true);
    }

    if (message.receiverType == ReceiverTypeConstants.group) {
      if (receiver is Group) {
        return (
          name: receiver.name,
          avatar: receiver.icon,
          isThreadReply: false,
        );
      }
    } else {
      // 1-1: the row belongs to the OTHER participant, which is the sender
      // for incoming messages and the receiver for our own.
      if (sender != null && sender.uid != loggedInUid) {
        return (name: sender.name, avatar: sender.avatar, isThreadReply: false);
      }
      if (receiver is User) {
        return (
          name: receiver.name,
          avatar: receiver.avatar,
          isThreadReply: false,
        );
      }
    }
    return (name: message.receiverUid, avatar: null, isThreadReply: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final style = const CometChatSavedMessagesStyle().merge(widget.style);
    final translations = Translations.of(context);

    return Scaffold(
      backgroundColor: style.backgroundColor ?? colorPalette.background1,
      appBar: AppBar(
        backgroundColor: style.appBarColor ?? colorPalette.background1,
        elevation: 0,
        automaticallyImplyLeading: false,
        // Message-header chrome, same as the pinned list: back arrow on the
        // left, title left-aligned beside it, hairline underneath, no count.
        // centerTitle is spelled out because AppBar centres by default on
        // iOS, which would break the alignment on one platform only.
        centerTitle: false,
        titleSpacing: widget.showBackButton && !widget.useCloseButton ? 0 : 16,
        leading: widget.showBackButton && !widget.useCloseButton
            ? IconButton(
                tooltip: Translations.of(context).back,
                icon: Icon(
                  Icons.arrow_back,
                  color: style.iconColor ?? colorPalette.iconPrimary,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          if (widget.showBackButton && widget.useCloseButton)
            IconButton(
              tooltip: Translations.of(context).close,
              icon: Icon(
                Icons.close,
                color: style.iconColor ?? colorPalette.iconPrimary,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
        ],
        title: Text(
          translations.savedMessagesTitle,
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
      body: _buildBody(colorPalette, typography, style),
    );
  }

  Widget _buildBody(
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSavedMessagesStyle style,
  ) {
    final spacing = CometChatThemeHelper.getSpacing(context);
    final translations = Translations.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      // Matches the pinned listing and the rest of the kit: illustration,
      // "Oops!", explainer and a Retry, rather than a dead-end line of text.
      return UIStateUtils.getDefaultErrorStateView(
        context,
        colorPalette,
        typography,
        spacing,
        _retry,
      );
    }
    if (_messages.isEmpty) {
      // Same empty-state shape as the pinned list.
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.padding8 ?? 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rounded variant in a light neutral, per design — the sharp
              // default bookmark reads too heavy at this size.
              Icon(
                Icons.bookmark_rounded,
                size: 72,
                color: colorPalette.neutral400 ?? colorPalette.iconSecondary,
              ),
              SizedBox(height: spacing.padding5 ?? 20),
              Text(
                translations.noSavedMessages,
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
                translations.noSavedMessagesSubtitle,
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

    // Rows mirror CometChatConversationListItem structurally, so Saved reads
    // exactly like the conversations list: same 16/12 padding, 48px avatar
    // with a 12px gutter, heading4 title over a body-sized subtitle, and the
    // date in its own trailing column (top-aligned, caption sizing) — not
    // inline with the title.
    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final conversation = _conversationIdentity(context, message);
        final savedAt = message.savedAt ?? message.sentAt;

        return InkWell(
          // Pops first, like the pinned list: the row is a jump affordance,
          // so the host lands on the message with this screen already gone
          // rather than stacked behind the chat.
          onTap: () {
            if (widget.popOnItemTap) Navigator.of(context).maybePop();
            widget.onItemTap?.call(message);
          },
          // The row carries no unsave icon (design); long-press keeps the
          // action reachable so this screen isn't a dead end for removing
          // items. Suppressed when hideUnsaveOption is set.
          onLongPress: widget.hideUnsaveOption != true
              ? () => _unsave(message)
              : null,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.padding4 ?? 16,
              vertical: spacing.padding3 ?? 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: spacing.padding3 ?? 12),
                  child: CometChatAvatar(
                    name: conversation.name,
                    image: conversation.avatar,
                    height: 48,
                    width: 48,
                    style: CometChatAvatarStyle(
                      placeHolderTextStyle: TextStyle(
                        fontSize: typography.heading2?.bold?.fontSize,
                        fontWeight: typography.heading2?.bold?.fontWeight,
                        fontFamily: typography.heading2?.bold?.fontFamily,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        conversation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (typography.heading4?.medium ?? const TextStyle())
                                .copyWith(color: colorPalette.textPrimary)
                                .merge(style.itemTitleTextStyle),
                      ),
                      const SizedBox(height: 2),
                      // Same preview treatment as a search row: rich text
                      // (markdown / links / resolved @mentions), media type
                      // glyph + attachment label, card fallback, ↳ for
                      // thread replies.
                      MessagePreviewSubtitle(
                        message: message,
                        textStyle: TextStyle(
                          color: colorPalette.textSecondary,
                          fontSize: typography.body?.regular?.fontSize,
                          fontWeight: typography.body?.regular?.fontWeight,
                          fontFamily: typography.body?.regular?.fontFamily,
                        ).merge(style.itemSubtitleTextStyle),
                        iconColor: colorPalette.iconSecondary,
                        // A thread row is already titled by its author, so
                        // the ↳ and the name prefix would be redundant.
                        showThreadIndicator: !conversation.isThreadReply,
                        // Group rows name the sender ("John:" / "You:") for
                        // every message type; a 1-1 row is already titled by
                        // the counterpart, so it carries no prefix at all.
                        showSenderPrefix:
                            !conversation.isThreadReply &&
                            message.receiverType == ReceiverTypeConstants.group,
                        prefixAllTypes: true,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: spacing.padding2 ?? 8),
                  child: savedAt == null
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // No state glyphs here (design): every row in
                            // this screen is saved, and its pin state shows
                            // in the conversation instead. The trailing
                            // caption is just the saved date.
                            CometChatDate(
                              date: savedAt,
                              padding: EdgeInsets.zero,
                              isTransparentBackground: true,
                              pattern: DateTimePattern.dayDateTimeFormat,
                              style: CometChatDateStyle(
                                backgroundColor: colorPalette.transparent,
                                border: Border.all(
                                  width: 0,
                                  color: Colors.transparent,
                                ),
                                textStyle: TextStyle(
                                  color: colorPalette.textSecondary,
                                  fontSize:
                                      typography.caption1?.regular?.fontSize,
                                  fontWeight:
                                      typography.caption1?.regular?.fontWeight,
                                  fontFamily:
                                      typography.caption1?.regular?.fontFamily,
                                ).merge(style.itemDateTextStyle),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kit-event delegate: reacts to save/unsave actions taken on this device.
class _SavedKitEventsDelegate with CometChatMessageEventListener {
  _SavedKitEventsDelegate({
    required this.onSaved,
    required this.onUnsaved,
    required this.onUpdated,
    required this.onRemoved,
  });

  final void Function(BaseMessage message) onSaved;
  final void Function(BaseMessage message) onUnsaved;

  /// Refreshes a row already in the list, leaving membership alone.
  final void Function(BaseMessage message) onUpdated;

  /// Drops a row — a message that no longer exists cannot stay saved.
  final void Function(BaseMessage message) onRemoved;

  @override
  void ccMessageSaved(BaseMessage message) => onSaved(message);

  @override
  void ccMessageUnsaved(BaseMessage message) => onUnsaved(message);

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (status == MessageEditStatus.success) onUpdated(message);
  }

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    if (messageStatus == EventStatus.success) onRemoved(message);
  }

  // A saved row shows a pin glyph, so pin changes have to reach it too —
  // as an in-place refresh, never as a membership change.
  @override
  void ccMessagePinned(BaseMessage message) => onUpdated(message);

  @override
  void ccMessageUnpinned(BaseMessage message) => onUpdated(message);
}

/// SDK-event delegate: the cross-device save/unsave self-echo, plus the
/// broadcast events that change what a saved row should show.
class _SavedSdkEventsDelegate with MessageListener {
  _SavedSdkEventsDelegate({
    required this.onSaved,
    required this.onUnsaved,
    required this.onUpdated,
    required this.onRemoved,
  });

  final void Function(BaseMessage message) onSaved;
  final void Function(BaseMessage message) onUnsaved;
  final void Function(BaseMessage message) onUpdated;
  final void Function(BaseMessage message) onRemoved;

  @override
  void onMessageSaved(BaseMessage message) => onSaved(message);

  @override
  void onMessageUnsaved(BaseMessage message) => onUnsaved(message);

  @override
  void onMessageEdited(BaseMessage message) => onUpdated(message);

  @override
  void onMessageDeleted(BaseMessage message) => onRemoved(message);

  @override
  void onMessageModerated(BaseMessage message) => onUpdated(message);

  @override
  void onMessagePinned(BaseMessage message) => onUpdated(message);

  @override
  void onMessageUnpinned(BaseMessage message) => onUpdated(message);
}
