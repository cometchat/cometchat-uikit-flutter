import 'dart:async';
import 'dart:math';

import 'package:diffutil_dart/diffutil.dart' as diffutil;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:scrollview_observer/scrollview_observer.dart';

import '../../../../chat_ui/src/message_list/bloc/message_list_bloc.dart';
import '../../../../chat_ui/src/message_list/utils/message_operation.dart';
import '../../../../chat_ui/src/message_list/utils/message_list_diff.dart';
import '../utils/composer_height_notifier.dart';
import 'scroll_to_bottom_button.dart';
import 'load_more_indicator.dart';
import 'empty_message_list.dart';
import 'sliver_spacing.dart';

/// Enum controlling the initial scroll behavior of the message list
enum InitialScrollToEndMode {
  /// Do not scroll initially
  none,

  /// Jump directly to the end without animation
  jump,

  /// Animate scrolling to the end
  animate,
}

/// Builder function for creating individual message widgets
typedef MessageItemBuilder =
    Widget Function(
      BuildContext context,
      BaseMessage message,
      int index,
      Animation<double> animation,
    );

/// An animated list widget for displaying chat messages
///
/// This widget handles:
/// - Message insertion/removal animations via [SliverAnimatedList]
/// - Pagination (loading older/newer messages)
/// - Automatic scrolling behavior
/// - Scroll-to-bottom button
/// - Keyboard handling
/// - Scroll anchoring during pagination
///
/// It works with [AnimatedMessageListBloc] for state management and receives
/// [MessageOperation] events for animations.
class CometChatAnimatedMessageList extends StatefulWidget {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Whether to handle the safe area.
  @Deprecated(
    'Has no effect. The list never applied it; wrap the list in a SafeArea or set bottomPadding. Will be removed in 7.0.0.',
  )
  final bool handleSafeArea;

  /// Builder function for creating individual message widgets
  final MessageItemBuilder itemBuilder;

  /// BLoC for message list state management
  final AnimatedMessageListBloc bloc;

  /// Optional scroll controller
  final ScrollController? scrollController;

  /// Whether the list is reversed (newest at bottom, grows upward)
  final bool reversed;

  /// Duration for message insertion animations
  final Duration insertAnimationDuration;

  /// Duration for message removal animations
  final Duration removeAnimationDuration;

  /// Duration for scrolling to the end
  final Duration scrollToEndAnimationDuration;

  /// Delay before scroll-to-bottom button appears
  final Duration scrollToBottomAppearanceDelay;

  /// Threshold for scroll-to-bottom button appearance
  final double scrollToBottomAppearanceThreshold;

  /// Callback when user scrolls near the top (load older messages)
  final Future<void> Function()? onLoadOlder;

  /// Callback when user scrolls near the bottom (load newer messages)
  final Future<void> Function()? onLoadNewer;

  /// Threshold for triggering older message pagination (0.0 to 1.0)
  final double olderPaginationThreshold;

  /// Threshold for triggering newer message pagination (0.0 to 1.0)
  final double newerPaginationThreshold;

  /// Whether to scroll to end when sending a message
  final bool shouldScrollToEndWhenSendingMessage;

  /// Whether to scroll to end when at bottom and new message arrives
  final bool shouldScrollToEndWhenAtBottom;

  /// Initial scroll behavior
  final InitialScrollToEndMode initialScrollToEndMode;

  /// Custom empty state builder
  final EmptyMessageListBuilder? emptyBuilder;

  /// Custom load more indicator builder
  final LoadMoreBuilder? loadMoreBuilder;

  /// Custom scroll-to-bottom button builder
  final ScrollToBottomBuilder? scrollToBottomBuilder;

  /// Optional sliver at the top
  final Widget? topSliver;

  /// Optional sliver at the bottom
  final Widget? bottomSliver;

  /// Padding at the top
  final double? topPadding;

  /// Padding at the bottom
  final double? bottomPadding;

  /// Whether to handle safe area

  /// Keyboard dismiss behavior
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Scroll physics
  final ScrollPhysics? physics;

  /// Notifier for composer height changes
  final ComposerHeightNotifier? composerHeightNotifier;

  /// Optional O(1) message index lookup function
  /// If provided, used instead of O(n) indexWhere in findChildIndexCallback
  final int? Function(int messageId)? findMessageIndex;

  /// Logged-in user ID for determining message ownership
  /// Used to decide auto-scroll behavior (always scroll for own messages)
  final String? loggedInUserId;

  /// Callback when the top-visible message date changes (for sticky date header)
  final ValueChanged<DateTime?>? onTopVisibleDateChanged;

  /// Optional callback when scroll-to-bottom button is tapped.
  /// If provided, called instead of the default scroll behavior.
  /// Use this to check if the list has the latest messages and either
  /// scroll or refresh accordingly.
  final VoidCallback? onScrollToBottomTap;

  /// Whether there are more newer messages to fetch.
  /// When true, the scroll-to-bottom button stays visible even at scroll offset 0
  /// because the list doesn't contain the latest messages yet.
  final bool hasMoreNewer;

  const CometChatAnimatedMessageList({
    super.key,
    required this.itemBuilder,
    required this.bloc,
    this.scrollController,
    this.reversed = true,
    this.insertAnimationDuration = const Duration(milliseconds: 250),
    this.removeAnimationDuration = const Duration(milliseconds: 250),
    this.scrollToEndAnimationDuration = const Duration(milliseconds: 250),
    this.scrollToBottomAppearanceDelay = const Duration(milliseconds: 250),
    this.scrollToBottomAppearanceThreshold = 0,
    this.onLoadOlder,
    this.onLoadNewer,
    this.olderPaginationThreshold = 0.01,
    this.newerPaginationThreshold = 0.8,
    this.shouldScrollToEndWhenSendingMessage = true,
    this.shouldScrollToEndWhenAtBottom = true,
    this.initialScrollToEndMode = InitialScrollToEndMode.jump,
    this.emptyBuilder,
    this.loadMoreBuilder,
    this.scrollToBottomBuilder,
    this.topSliver,
    this.bottomSliver,
    this.topPadding = 8,
    this.bottomPadding = 20,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.physics,
    this.composerHeightNotifier,
    this.findMessageIndex,
    this.loggedInUserId,
    this.onTopVisibleDateChanged,
    this.onScrollToBottomTap,
    this.hasMoreNewer = false,
    this.handleSafeArea = true,
  });

  @override
  State<CometChatAnimatedMessageList> createState() =>
      _CometChatAnimatedMessageListState();
}

class _CometChatAnimatedMessageListState
    extends State<CometChatAnimatedMessageList>
    with TickerProviderStateMixin {
  // Keys and controllers
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();
  late final ScrollController _scrollController;
  late final SliverObserverController _observerController;

  // Animation controllers
  late final AnimationController _scrollAnimationController;
  late final AnimationController _scrollToBottomController;
  late final Animation<double> _scrollToBottomAnimation;

  // Timers
  Timer? _scrollToBottomShowTimer;

  // State tracking
  late List<BaseMessage> _messages;
  late ValueNotifier<bool> _isEmptyNotifier;
  late StreamSubscription<MessageOperation> _operationsSubscription;

  // Notifier to trigger targeted rebuilds of the animated list sliver only
  // (not the entire widget including scroll-to-bottom, empty state, load indicators)
  final ValueNotifier<int> _messageUpdateNotifier = ValueNotifier<int>(0);

  // Operation queue
  final List<MessageOperation> _operationsQueue = [];
  bool _isProcessingOperations = false;
  bool _isDisposed = false;

  // Scroll state
  bool _userHasScrolled = false;
  bool _isScrollingToBottom = false;
  late bool _needsInitialScrollPositionAdjustment;
  int _lastInsertedMessageId = 0;

  // Pagination flags
  bool _olderPaginationShouldTrigger = false;
  bool _newerPaginationShouldTrigger = false;

  // Guard flag: true while we're inserting newer messages + rebuilding + scrolling
  // Prevents the UserScrollNotification handler from re-enabling newer pagination
  // during the rebuild+scroll cycle, which would cause an infinite loop.
  bool _isProcessingNewerInsert = false;

  // Opacity notifier: set to 0 during newer insert rebuild to hide the jank
  // (list rebuilds at offset 0 then jumps to anchor), set back to 1 after scroll.
  final ValueNotifier<double> _newerInsertOpacity = ValueNotifier<double>(1.0);

  // Loading notifier for pagination indicators
  late final LoadMoreNotifier _loadMoreNotifier;

  @override
  void initState() {
    super.initState();

    // Initialize scroll controller
    _scrollController = widget.scrollController ?? ScrollController();
    _observerController = SliverObserverController(
      controller: _scrollController,
    )..cacheJumpIndexOffset = false;

    // Add scroll listener for sticky date tracking fallback
    _scrollController.addListener(_onScrollForDateTracking);

    // Initialize animation controllers
    _scrollAnimationController = AnimationController(
      vsync: this,
      duration: Duration.zero,
    );
    _scrollAnimationController.addListener(_linkAnimationToScroll);

    _scrollToBottomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scrollToBottomAnimation = CurvedAnimation(
      parent: _scrollToBottomController,
      curve: Curves.linearToEaseOut,
    );

    // Initialize message list from bloc state
    _messages = List.from(widget.bloc.state.messages);
    _isEmptyNotifier = ValueNotifier(_messages.isEmpty);

    // Initialize load more notifier
    _loadMoreNotifier = LoadMoreNotifier();

    // Subscribe to operations stream
    _operationsSubscription = widget.bloc.operationsStream.listen((operation) {
      _operationsQueue.add(operation);
      _processOperationsQueue();
    });

    // Setup initial scroll position
    if (widget.reversed) {
      _needsInitialScrollPositionAdjustment = false;
    } else {
      if (widget.initialScrollToEndMode == InitialScrollToEndMode.animate) {
        _handleScrollToBottom();
        _needsInitialScrollPositionAdjustment = false;
      } else {
        _needsInitialScrollPositionAdjustment =
            widget.initialScrollToEndMode == InitialScrollToEndMode.jump;
      }
    }

    // Attach scroll methods to bloc
    widget.bloc.attachScrollMethods(
      scrollToMessage: _scrollToMessageId,
      scrollToIndex: _scrollToIndex,
    );
  }

  /// Process queued operations sequentially
  Future<void> _processOperationsQueue() async {
    if (_isProcessingOperations || _operationsQueue.isEmpty) return;

    // Wait for widget to be mounted and built
    if (!mounted || _isDisposed) return;

    // Wait for the list state to be available
    await Future.delayed(Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isDisposed || _isProcessingOperations) return;

      _isProcessingOperations = true;

      while (_operationsQueue.isNotEmpty && mounted && !_isDisposed) {
        final operation = _operationsQueue.removeAt(0);
        await _processOperation(operation);
      }

      _isProcessingOperations = false;
    });
  }

  /// Process a single operation
  Future<void> _processOperation(MessageOperation operation) async {
    switch (operation.type) {
      case MessageOperationType.insert:
        await _onInserted(operation);
        break;
      case MessageOperationType.insertAll:
        await _onInsertedAll(operation);
        break;
      case MessageOperationType.update:
        _onUpdated(operation);
        break;
      case MessageOperationType.remove:
        await _onRemoved(operation);
        break;
      case MessageOperationType.set:
        await _onSet(operation);
        break;
    }
  }

  /// Handle single message insertion
  Future<void> _onInserted(MessageOperation operation) async {
    final message = operation.message;
    final index = operation.index;
    if (message == null || index == null) return;

    // Update local list
    _messages.insert(index, message);
    _isEmptyNotifier.value = _messages.isEmpty;

    // Track last inserted message for auto-scroll
    _lastInsertedMessageId = message.id;

    // Ensure widget is mounted and not disposed before animating
    if (!mounted || _isDisposed) return;

    // Animate insertion
    final visualIndex = visualPosition(index);
    final listState = _listKey.currentState;

    if (listState != null) {
      try {
        if (operation.animated) {
          listState.insertItem(
            visualIndex,
            duration: widget.insertAnimationDuration,
          );
        } else {
          listState.insertItem(visualIndex, duration: Duration.zero);
        }
      } catch (_) {
        // Widget was deactivated between the null check and insertItem call.
        // This can happen during route transitions when the element tree is
        // being torn down. Safe to ignore — the list is being disposed anyway.
        return;
      }
    }

    // Handle auto-scroll
    if (operation.animated) {
      _scrollToEnd(message);
    }
  }

  /// Handle batch message insertion
  Future<void> _onInsertedAll(MessageOperation operation) async {
    final messages = operation.messages;
    final index = operation.index;
    if (messages == null || messages.isEmpty || index == null) return;

    final oldLength = _messages.length;
    final isNewerInsert = widget.reversed && index == oldLength;

    // For newer inserts in reversed list, use the last message in the current
    // list as the anchor. This is the newest message the user was looking at
    // (they're at the bottom = offset 0 in reversed list). We DON'T use the
    // SliverViewObserver here because it returns 0 items when offset is 0.0.
    int? anchorMessageId;
    if (isNewerInsert && _messages.isNotEmpty) {
      anchorMessageId = _messages[oldLength - 1].id;
    }

    // Update local list
    _messages.insertAll(index, messages);
    _isEmptyNotifier.value = _messages.isEmpty;

    // Track last inserted message
    if (messages.isNotEmpty) {
      _lastInsertedMessageId = messages.last.id;
    }

    // Animate insertions - ensure widget is mounted
    if (!mounted || _isDisposed) return;

    final listState = _listKey.currentState;
    if (listState != null) {
      if (widget.reversed) {
        if (isNewerInsert && anchorMessageId != null) {
          // Newer pagination in reversed list: rebuild with new key to avoid
          // the visual jump, then restore scroll position to anchor message.
          // Hide the list during the rebuild+scroll to prevent visible jank.
          _isProcessingNewerInsert = true;
          _olderPaginationShouldTrigger = false;
          _newerPaginationShouldTrigger = false;
          _newerInsertOpacity.value = 0.0;

          if (mounted) {
            setState(() {
              _listKey = GlobalKey<SliverAnimatedListState>();
            });
          }
          // Restore scroll position after rebuild. Retry the scroll-to-anchor
          // until the new SliverAnimatedList context is ready (up to a max
          // number of frames) to avoid the opacity staying at 0 for too long.
          _restoreScrollAfterNewerInsert(anchorMessageId);
        } else {
          // Older pagination or non-newer inserts: animate normally
          final visualIndex = oldLength - index;

          for (int i = 0; i < messages.length; i++) {
            if (!mounted || _isDisposed) return;
            try {
              if (operation.animated) {
                listState.insertItem(
                  visualIndex,
                  duration: widget.insertAnimationDuration,
                );
                await Future.delayed(const Duration(milliseconds: 16));
              } else {
                listState.insertItem(visualIndex, duration: Duration.zero);
              }
            } catch (_) {
              // Widget deactivated during insertion — safe to bail out
              return;
            }
          }
        }
      } else {
        // For normal lists, insert from start to end
        for (int i = 0; i < messages.length; i++) {
          if (!mounted || _isDisposed) return;
          final visualIndex = index + i;
          try {
            if (operation.animated) {
              listState.insertItem(
                visualIndex,
                duration: widget.insertAnimationDuration,
              );
              // Small delay between insertions for staggered effect
              await Future.delayed(const Duration(milliseconds: 16));
            } else {
              listState.insertItem(visualIndex, duration: Duration.zero);
            }
          } catch (_) {
            // Widget deactivated during insertion — safe to bail out
            return;
          }
        }
      }
    }
  }

  /// Restore scroll position after a newer-insert rebuild.
  ///
  /// The new [SliverAnimatedList] (created with a fresh GlobalKey) needs at
  /// least one frame to lay out before we can scroll to the anchor message.
  /// This method retries the scroll each frame up to [maxAttempts] times,
  /// then unconditionally reveals the list so the user never stares at a
  /// blank screen.
  void _restoreScrollAfterNewerInsert(
    int anchorMessageId, {
    int maxAttempts = 8,
  }) {
    int attempt = 0;

    void tryScroll() {
      if (!mounted || !_scrollController.hasClients) {
        _revealAfterNewerInsert();
        return;
      }

      attempt++;

      final anchorIndex = _messages.indexWhere((m) => m.id == anchorMessageId);
      if (anchorIndex == -1) {
        // Anchor message gone — just reveal at current position
        _revealAfterNewerInsert();
        return;
      }

      // Check if the sliver context is ready for scrolling
      if (_listKey.currentContext == null && attempt < maxAttempts) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
        return;
      }

      _scrollToIndex(anchorIndex, duration: Duration.zero, alignment: 0).then((
        success,
      ) {
        if (success || attempt >= maxAttempts) {
          _revealAfterNewerInsert();
        } else {
          // Scroll failed (context not ready yet) — retry next frame
          WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
        }
      });
    }

    // Start after one frame so setState has a chance to rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) => tryScroll());
  }

  /// Reveal the list and reset the newer-insert processing guard.
  void _revealAfterNewerInsert() {
    _newerInsertOpacity.value = 1.0;
    _isProcessingNewerInsert = false;
    _triggerDateObservation();
  }

  /// Handle message removal
  Future<void> _onRemoved(MessageOperation operation) async {
    final message = operation.message;
    final index = operation.index;
    if (message == null || index == null) return;

    // Get visual index before removing
    final visualIndex = visualPosition(index);

    // Remove from local list
    if (index < _messages.length) {
      _messages.removeAt(index);
    }
    _isEmptyNotifier.value = _messages.isEmpty;

    // Animate removal
    final listState = _listKey.currentState;
    if (listState != null) {
      listState.removeItem(
        visualIndex,
        (context, animation) => _buildRemovedItem(message, animation),
        duration: operation.animated
            ? widget.removeAnimationDuration
            : Duration.zero,
      );
    }
  }

  /// Build widget for removed item animation
  Widget _buildRemovedItem(BaseMessage message, Animation<double> animation) {
    return RepaintBoundary(
      child: SizeTransition(
        sizeFactor: animation,
        child: FadeTransition(
          opacity: animation,
          child: widget.itemBuilder(
            context,
            message,
            -1, // Index is no longer valid
            animation,
          ),
        ),
      ),
    );
  }

  /// Handle message update (no animation, just rebuild the list sliver)
  void _onUpdated(MessageOperation operation) {
    final newMessage = operation.message;
    final index = operation.index;
    if (newMessage == null || index == null) return;

    // Update local list
    if (index < _messages.length) {
      _messages[index] = newMessage;
    }

    // Trigger targeted rebuild of the animated list sliver only
    _messageUpdateNotifier.value++;
  }

  /// Handle set messages (replace entire list with diff-based updates)
  Future<void> _onSet(MessageOperation operation) async {
    final newMessages = operation.messages;
    if (newMessages == null) return;

    final listState = _listKey.currentState;

    // If no list state yet, just update the local list
    if (listState == null) {
      _messages = List.from(newMessages);
      _isEmptyNotifier.value = _messages.isEmpty;
      if (mounted) _messageUpdateNotifier.value++;
      _triggerDateObservation();
      return;
    }

    final oldLength = _messages.length;

    // For non-animated updates or when starting from empty, reset the key
    // to force a fresh SliverAnimatedListState. This avoids the fragile
    // remove-all/insert-all dance that causes Widget.canUpdate assertion
    // failures when the internal _itemsCount gets out of sync.
    if (!operation.animated || oldLength == 0) {
      _messages = List.from(newMessages);
      _isEmptyNotifier.value = _messages.isEmpty;

      // Reset pagination flags to prevent immediate re-triggering
      // after the list rebuilds at offset 0
      _olderPaginationShouldTrigger = false;
      _newerPaginationShouldTrigger = false;

      // Reset sticky date so the next observation always notifies,
      // even if the new data has the same date as before the reset.
      _lastReportedDate = null;

      if (mounted) {
        setState(() {
          _listKey = GlobalKey<SliverAnimatedListState>();
        });
        // For reversed lists, jump to offset 0 (bottom/newest) after the
        // list rebuilds. The scroll controller retains the old offset from
        // when the user was scrolled up, which can land at the top (oldest)
        // of the new shorter list.
        if (widget.reversed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _scrollController.hasClients &&
                _scrollController.offset != 0) {
              _scrollController.jumpTo(0);
            }
          });
        }
      }
      _triggerDateObservation();
      return;
    }

    // For animated updates, use diff algorithm
    final oldMessages = operation.oldMessages ?? List.from(_messages);

    // Update local list first
    _messages = List.from(newMessages);
    _isEmptyNotifier.value = _messages.isEmpty;

    // Calculate diff
    final updates = diffutil
        .calculateDiff<BaseMessage>(
          MessageListDiff(oldMessages, newMessages),
          detectMoves: false,
        )
        .getUpdatesWithData();

    // Track the current list length as we apply updates
    int currentLength = oldMessages.length;

    // Apply diff updates
    for (final update in updates) {
      update.when<void>(
        insert: (pos, data) {
          // For reversed list, visual index is inverted
          final visualIndex = widget.reversed
              ? max(currentLength - pos, 0)
              : min(pos, currentLength);
          listState.insertItem(
            visualIndex.clamp(0, currentLength),
            duration: widget.insertAnimationDuration,
          );
          currentLength++;
        },
        remove: (pos, data) {
          final visualIndex = widget.reversed
              ? max(currentLength - 1 - pos, 0)
              : pos;
          if (visualIndex >= 0 && visualIndex < currentLength) {
            listState.removeItem(
              visualIndex,
              (context, animation) => _buildRemovedItem(data, animation),
              duration: widget.removeAnimationDuration,
            );
            currentLength--;
          }
        },
        change: (pos, oldData, newData) {
          // Changes don't affect the animated list, just trigger rebuild
        },
        move: (oldPos, newPos, data) {
          // Moves are disabled, but handle gracefully if they occur
        },
      );
    }

    if (mounted) _messageUpdateNotifier.value++;
    _triggerDateObservation();
  }

  // ============================================================
  // VISUAL POSITION MAPPING
  // ============================================================

  /// Maps content index to visual index for SliverAnimatedList
  ///
  /// For reversed lists, the visual order is opposite to content order.
  int visualPosition(int contentIndex) {
    return widget.reversed
        ? max(_messages.length - contentIndex - 1, 0)
        : contentIndex;
  }

  // ============================================================
  // SCROLL HELPERS
  // ============================================================

  /// Check if at the end of the chat list
  bool get _isAtChatEndScrollPosition {
    return widget.reversed
        ? _scrollController.offset <= _chatEndScrollPosition
        : _scrollController.offset >= _chatEndScrollPosition;
  }

  /// The scroll position representing the end of the chat
  double get _chatEndScrollPosition {
    return widget.reversed ? 0 : _scrollController.position.maxScrollExtent;
  }

  /// Whether scroll-to-bottom button should be shown
  bool get _shouldShowScrollToBottomButton {
    // Always show if the list doesn't have the latest messages
    if (widget.hasMoreNewer) return true;

    final scrollOffsetFromBottom = widget.reversed
        ? _scrollController.offset
        : _chatEndScrollPosition - _scrollController.offset;
    return scrollOffsetFromBottom > widget.scrollToBottomAppearanceThreshold;
  }

  /// Link animation controller to scroll for smooth scrolling
  void _linkAnimationToScroll() {
    if (widget.reversed) return;
    _scrollController.jumpTo(
      _scrollAnimationController.value *
          _scrollController.position.maxScrollExtent,
    );
  }

  // ============================================================
  // SCROLL-TO-BOTTOM BUTTON
  // ============================================================

  /// Handle scroll-to-bottom button press
  void _handleScrollToBottom() {
    // If a custom callback is provided, delegate to it.
    // The parent widget can check hasMoreNewer and either scroll or refresh.
    if (widget.onScrollToBottomTap != null) {
      widget.onScrollToBottomTap!();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;

      _isScrollingToBottom = true;
      _scrollToBottomController.reverse();

      if (widget.reversed) {
        if (widget.scrollToEndAnimationDuration == Duration.zero) {
          _scrollController.jumpTo(_chatEndScrollPosition);
        } else {
          _scrollController.animateTo(
            _chatEndScrollPosition,
            duration: widget.scrollToEndAnimationDuration,
            curve: Curves.linearToEaseOut,
          );
        }
      } else {
        _scrollAnimationController.value =
            _scrollController.offset /
            _scrollController.position.maxScrollExtent;
        _scrollAnimationController.fling();
      }

      _userHasScrolled = false;
      _isScrollingToBottom = false;
      _newerPaginationShouldTrigger = true;
    });
  }

  /// Toggle scroll-to-bottom button visibility
  void _handleToggleScrollToBottom() {
    if (!_isScrollingToBottom) {
      _scrollToBottomShowTimer?.cancel();
      if (_shouldShowScrollToBottomButton) {
        _scrollToBottomShowTimer = Timer(
          widget.scrollToBottomAppearanceDelay,
          () {
            if (mounted) {
              _userHasScrolled = true;
              _scrollToBottomController.forward();
            }
          },
        );
      } else {
        if (_scrollToBottomController.status == AnimationStatus.completed ||
            _scrollToBottomController.status == AnimationStatus.forward) {
          _scrollToBottomController.reverse();
        }
      }
    }
  }

  // ============================================================
  // AUTO-SCROLL BEHAVIOR
  // ============================================================

  /// Handle auto-scroll when new message is inserted
  void _scrollToEnd(BaseMessage message) {
    if (_loadMoreNotifier.isLoadingNewer) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;

      if (!widget.reversed && _scrollController.position.maxScrollExtent == 0) {
        _initialScrollToEnd();
      } else {
        _subsequentScrollToEnd(message);
      }
    });
  }

  /// Initial scroll to end for non-reversed lists
  Future<void> _initialScrollToEnd() async {
    await Future.delayed(widget.insertAnimationDuration);
    if (!_scrollController.hasClients ||
        !mounted ||
        _isAtChatEndScrollPosition) {
      return;
    }
    _scrollController.jumpTo(_chatEndScrollPosition);
  }

  /// Subsequent scroll to end based on configuration
  ///
  /// For reversed lists (chat default):
  /// - Always scroll when user sends a message (if shouldScrollToEndWhenSendingMessage)
  /// - Only scroll for incoming messages if user is at bottom (if shouldScrollToEndWhenAtBottom)
  void _subsequentScrollToEnd(BaseMessage message) {
    if (message.id != _lastInsertedMessageId) {
      return;
    }

    // Already at bottom, no need to scroll
    if (_isAtChatEndScrollPosition) {
      return;
    }

    // Check if this message was sent by the logged-in user
    final isOwnMessage =
        widget.loggedInUserId != null &&
        message.sender?.uid == widget.loggedInUserId;

    if (widget.reversed) {
      // For reversed lists (chat default - newest at bottom)
      if (isOwnMessage && widget.shouldScrollToEndWhenSendingMessage) {
        // Always scroll to bottom when user sends a message
        _scrollController.jumpTo(_chatEndScrollPosition);
      } else if (!isOwnMessage &&
          widget.shouldScrollToEndWhenAtBottom &&
          !_userHasScrolled) {
        // For incoming messages, only scroll if user hasn't scrolled up
        _scrollController.jumpTo(_chatEndScrollPosition);
      }
      // If user has scrolled up and it's an incoming message, don't scroll
    } else {
      // For non-reversed lists
      if (widget.shouldScrollToEndWhenAtBottom && !_userHasScrolled) {
        _scrollController.jumpTo(_chatEndScrollPosition);
        return;
      }

      // Auto-scroll when user sends a message
      if (isOwnMessage && widget.shouldScrollToEndWhenSendingMessage) {
        if (_userHasScrolled) {
          _scrollAnimationController.value =
              _scrollController.offset /
              _scrollController.position.maxScrollExtent;
          _scrollAnimationController.fling();
        } else {
          _scrollController.jumpTo(_chatEndScrollPosition);
        }
      }
    }
  }

  // ============================================================
  // INITIAL SCROLL POSITION
  // ============================================================

  /// Adjust initial scroll position for non-reversed lists
  void _adjustInitialScrollPosition() {
    if (widget.reversed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;
      if (_messages.isEmpty) {
        _needsInitialScrollPositionAdjustment = false;
        return;
      }

      if (_needsInitialScrollPositionAdjustment) {
        if (_scrollController.position.maxScrollExtent == 0) return;
        if (_scrollController.offset == _chatEndScrollPosition) {
          _needsInitialScrollPositionAdjustment = false;
        } else {
          _scrollController.jumpTo(_chatEndScrollPosition);
        }
      }
    });
  }

  // ============================================================
  // PAGINATION
  // ============================================================

  /// Handle older pagination based on scroll position
  Future<void> _handleOlderPagination() async {
    if (!_scrollController.hasClients ||
        !mounted ||
        _needsInitialScrollPositionAdjustment) {
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent == 0) return;

    final scrollPosition = widget.reversed
        ? 1 - (_scrollController.offset / maxExtent)
        : _scrollController.offset / maxExtent;

    // Load older messages (near top)
    if (scrollPosition <= widget.olderPaginationThreshold &&
        _olderPaginationShouldTrigger &&
        widget.onLoadOlder != null &&
        !_loadMoreNotifier.isLoadingOlder) {
      _olderPaginationShouldTrigger = false;
      await _handleLoadOlder();
    }
  }

  /// Handle newer pagination — only called from UserScrollNotification
  Future<void> _handleNewerPagination() async {
    if (!_scrollController.hasClients ||
        !mounted ||
        _needsInitialScrollPositionAdjustment ||
        _isProcessingNewerInsert) {
      return;
    }

    // Load newer messages only when user reaches the very bottom
    if (_isAtChatEndScrollPosition &&
        _newerPaginationShouldTrigger &&
        widget.onLoadNewer != null &&
        !_loadMoreNotifier.isLoadingNewer) {
      _newerPaginationShouldTrigger = false;
      await _handleLoadNewer();
    }
  }

  /// Handle loading older messages with scroll anchoring
  Future<void> _handleLoadOlder() async {
    if (widget.onLoadOlder == null) return;

    _loadMoreNotifier.setLoadingOlder(true);

    // Get anchor message before loading — use the visually topmost message
    // so the user's scroll position is preserved when older messages are
    // prepended above.
    String? anchorMessageId;
    if (_listKey.currentContext != null && _messages.isNotEmpty) {
      final result = await _observerController.dispatchOnceObserve(
        sliverContext: _listKey.currentContext!,
        isForce: true,
      );
      final displayingList =
          result.observeResult?.innerDisplayingChildModelList;
      if (displayingList != null && displayingList.isNotEmpty) {
        // In a reversed list, the last item in displayingList is the visually
        // topmost message (trailing edge). In a normal list, the first item is
        // the topmost. We anchor to the topmost so the viewport stays stable.
        final anchorItem = widget.reversed
            ? displayingList.last
            : displayingList.first;
        if (anchorItem.index < _messages.length) {
          final visualIndex = anchorItem.index;
          final contentIndex = widget.reversed
              ? _messages.length - 1 - visualIndex
              : visualIndex;
          if (contentIndex >= 0 && contentIndex < _messages.length) {
            anchorMessageId = _messages[contentIndex].id.toString();
          }
        }
      }
    }

    await widget.onLoadOlder!();

    // Restore scroll position to anchor — pin the topmost visible message
    // back to the top of the viewport (alignment 1.0 for reversed lists,
    // 0.0 for normal lists).
    if (anchorMessageId != null) {
      final newIndex = _messages.indexWhere(
        (m) => m.id.toString() == anchorMessageId,
      );
      if (newIndex != -1) {
        final anchorAlignment = widget.reversed ? 1.0 : 0.0;
        await _scrollToIndex(
          newIndex,
          duration: Duration.zero,
          alignment: anchorAlignment,
        );
      }
    }

    _loadMoreNotifier.setLoadingOlder(false);
  }

  /// Handle loading newer messages — show circular indicator at bottom, fetch, done.
  /// Scroll anchoring is handled by _onInsertedAll which rebuilds the list
  /// and scrolls back to the anchor message.
  Future<void> _handleLoadNewer() async {
    if (widget.onLoadNewer == null) return;

    final countBefore = _messages.length;
    _loadMoreNotifier.setLoadingNewer(true);

    await widget.onLoadNewer!();

    _loadMoreNotifier.setLoadingNewer(false);

    // If no new messages were inserted, there are no more newer messages.
    // Keep _newerPaginationShouldTrigger false to stop further attempts.
    if (_messages.length == countBefore) {
      _newerPaginationShouldTrigger = false;
    }
  }

  // ============================================================
  // SCROLL TO MESSAGE/INDEX
  // ============================================================

  /// Scroll to a specific message by ID
  Future<bool> _scrollToMessageId(
    int messageId, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
  }) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      return await _scrollToIndex(
        index,
        alignment: alignment,
        duration: duration,
      );
    }
    return false;
  }

  /// Scroll to a specific index
  /// Returns true if the scroll was initiated, false if context wasn't ready.
  ///
  /// [alignment] controls where the item appears in the viewport:
  /// [alignment] controls where the item appears in the viewport:
  /// - 0.0 = leading edge (bottom in reversed list, top in normal list)
  /// - Higher values push the item further from the leading edge
  ///
  /// For reversed lists, the observer's native alignment doesn't respect the
  /// reversed direction, so we jump to alignment 0 then manually adjust offset.
  /// Both jumpTo calls execute in the same frame — no visible flicker.
  Future<bool> _scrollToIndex(
    int index, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
  }) async {
    if (!_scrollController.hasClients || !mounted) return false;
    if (index < 0 || index >= _messages.length) return false;
    if (_listKey.currentContext == null) return false;

    final visualIndex = visualPosition(index);

    // Reset cached date so the post-scroll observation always reports
    // the correct sticky date (avoids same-day dedup blocking the update)
    _lastReportedDate = null;

    if (duration > Duration.zero) {
      // Animated scroll — use observer's animateTo for smooth animation
      if (widget.reversed && alignment > 0 && _scrollController.hasClients) {
        // Two-step: jump to leading edge, then animate offset for alignment
        await _observerController.jumpTo(
          sliverContext: _listKey.currentContext,
          index: visualIndex,
          alignment: 0,
        );
        final viewportHeight = _scrollController.position.viewportDimension;
        final targetOffset =
            (_scrollController.offset + alignment * viewportHeight).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
        await _scrollController.animateTo(
          targetOffset,
          duration: duration,
          curve: Curves.easeInOut,
        );
      } else {
        await _observerController.animateTo(
          sliverContext: _listKey.currentContext,
          index: visualIndex,
          duration: duration,
          alignment: alignment,
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Instant scroll — jump without animation
      await _observerController.jumpTo(
        sliverContext: _listKey.currentContext,
        index: visualIndex,
        alignment: 0,
      );

      // For reversed lists with alignment > 0, push item toward top
      if (widget.reversed && alignment > 0 && _scrollController.hasClients) {
        final viewportHeight = _scrollController.position.viewportDimension;
        final targetOffset =
            (_scrollController.offset + alignment * viewportHeight).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
        _scrollController.jumpTo(targetOffset);
      }
    }

    // Update sticky date header directly from the target message.
    // We can't rely on _triggerDateObservation() here because after a
    // JumpToMessage list replacement, the SliverViewObserver may have a
    // stale controller reference and dispatchOnceObserve returns null.
    _reportDateForIndex(index);

    // Also trigger observer-based observation for subsequent scroll tracking
    _triggerDateObservation();

    return true;
  }

  // ============================================================
  // KEYBOARD HANDLING
  // ============================================================

  /// Directly report the date for a message at the given content index.
  /// Used after programmatic scrolls where the observer may not be ready.
  void _reportDateForIndex(int contentIndex) {
    if (widget.onTopVisibleDateChanged == null) return;
    if (contentIndex < 0 || contentIndex >= _messages.length) return;

    final message = _messages[contentIndex];
    final date = message.sentAt ?? message.updatedAt;
    if (date == null) return;

    final dateOnly = DateTime(date.year, date.month, date.day);
    _lastReportedDate = dateOnly;
    widget.onTopVisibleDateChanged!(dateOnly);
  }

  /// Handle keyboard height changes (for non-reversed lists)
  void _onKeyboardHeightChanged(double height) {
    if (widget.reversed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients || height == 0) return;

      if (widget.scrollToEndAnimationDuration == Duration.zero) {
        _scrollController.jumpTo(
          min(
            _scrollController.offset + height,
            _scrollController.position.maxScrollExtent,
          ),
        );
      } else {
        await _scrollController.animateTo(
          min(
            _scrollController.offset + height,
            _scrollController.position.maxScrollExtent,
          ),
          duration: widget.scrollToEndAnimationDuration,
          curve: Curves.linearToEaseOut,
        );
      }
      _scrollToBottomShowTimer?.cancel();
    });
  }

  // ============================================================
  // STICKY DATE TRACKING
  // ============================================================

  DateTime? _lastReportedDate;

  /// ScrollController listener that finds the top-visible message directly
  /// from the SliverAnimatedList's render object. This is the primary
  /// mechanism for updating the sticky date during manual scrolling.
  /// It works reliably even after _listKey replacement because it reads
  /// the render object from the current _listKey context each time.
  void _onScrollForDateTracking() {
    if (widget.onTopVisibleDateChanged == null) return;
    final ctx = _listKey.currentContext;
    if (ctx == null) return;

    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderSliver) return;

    // Walk the parent chain to find the RenderViewport
    RenderObject? current = renderObject;
    RenderViewportBase? viewport;
    while (current != null) {
      if (current is RenderViewportBase) {
        viewport = current;
        break;
      }
      current = current.parent;
    }
    if (viewport == null) return;

    // Get the scroll offset relative to this sliver
    final constraints = renderObject.constraints;
    final scrollOffset = constraints.scrollOffset;
    final viewportHeight = constraints.viewportMainAxisExtent;

    // For a reversed list, the "top" of the screen is at the far end
    // of the scroll extent. We need to find the child whose paint offset
    // places it at the top of the viewport.
    //
    // Walk the children of the SliverMultiBoxAdaptor to find the one
    // closest to the top of the viewport.
    if (renderObject is RenderSliverMultiBoxAdaptor) {
      RenderBox? child = renderObject.lastChild;
      int? topVisualIndex;
      double topEdge = double.infinity;

      while (child != null) {
        final parentData = child.parentData;
        if (parentData is SliverMultiBoxAdaptorParentData) {
          // layoutOffset is relative to the sliver's scroll offset
          final childOffset = parentData.layoutOffset ?? 0;
          // Distance from the top of the viewport
          final distFromTop = widget.reversed
              ? (scrollOffset + viewportHeight) -
                    (childOffset + child.size.height)
              : childOffset - scrollOffset;

          // The child closest to the top edge of the viewport
          if (distFromTop >= -1 && distFromTop < topEdge) {
            topEdge = distFromTop;
            topVisualIndex = parentData.index;
          }
        }
        child = renderObject.childBefore(child);
      }

      if (topVisualIndex != null) {
        final contentIndex = widget.reversed
            ? _messages.length - 1 - topVisualIndex
            : topVisualIndex;
        if (contentIndex >= 0 && contentIndex < _messages.length) {
          final message = _messages[contentIndex];
          final date = message.sentAt ?? message.updatedAt;
          if (date != null) {
            final dateOnly = DateTime(date.year, date.month, date.day);
            if (_lastReportedDate == null ||
                _lastReportedDate!.year != dateOnly.year ||
                _lastReportedDate!.month != dateOnly.month ||
                _lastReportedDate!.day != dateOnly.day) {
              _lastReportedDate = dateOnly;
              widget.onTopVisibleDateChanged!(dateOnly);
            }
          }
        }
      }
    }
  }

  /// Trigger a manual observation to update the sticky date header.
  /// Called after list rebuilds (new GlobalKey) since the observer's
  /// onObserve only fires during scroll events.
  void _triggerDateObservation() {
    // Try multiple frames — the list context may not be ready on the first frame
    _triggerDateObservationWithRetry(0);
  }

  void _triggerDateObservationWithRetry(int attempt) {
    if (attempt > 5) return; // Give up after 5 frames
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_listKey.currentContext == null) {
        _triggerDateObservationWithRetry(attempt + 1);
        return;
      }
      // Use the scroll listener's render-object-based approach
      _onScrollForDateTracking();
    });
  }

  /// Update the top-visible date based on the observer result
  void _updateTopVisibleDate(ObserveModel result) {
    if (widget.onTopVisibleDateChanged == null) return;
    final displayingList = result.innerDisplayingChildModelList;
    if (displayingList.isEmpty) return;

    // In a reversed list, the last item in displayingList is visually at the top
    // In a normal list, the first item is at the top
    final topItem = widget.reversed
        ? displayingList.last
        : displayingList.first;
    final visualIndex = topItem.index;
    final contentIndex = widget.reversed
        ? _messages.length - 1 - visualIndex
        : visualIndex;

    if (contentIndex < 0 || contentIndex >= _messages.length) return;

    final message = _messages[contentIndex];
    final date = message.sentAt ?? message.updatedAt;
    if (date == null) return;

    final dateOnly = DateTime(date.year, date.month, date.day);
    // Skip if same day AND we've already reported (not first time)
    if (_lastReportedDate != null &&
        _lastReportedDate!.year == dateOnly.year &&
        _lastReportedDate!.month == dateOnly.month &&
        _lastReportedDate!.day == dateOnly.day) {
      return;
    }
    _lastReportedDate = dateOnly;
    widget.onTopVisibleDateChanged!(dateOnly);
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: (notification) {
        if (notification is ScrollMetricsNotification) {
          _adjustInitialScrollPosition();
          _handleToggleScrollToBottom();
          // Only check older pagination from metrics changes
          // Newer pagination is checked from UserScrollNotification only
          _handleOlderPagination();
        }

        if (notification is UserScrollNotification) {
          if (notification.direction ==
              (widget.reversed
                  ? ScrollDirection.reverse
                  : ScrollDirection.forward)) {
            _olderPaginationShouldTrigger = true;
            _userHasScrolled = true;
          } else {
            if (notification.direction ==
                (widget.reversed
                    ? ScrollDirection.forward
                    : ScrollDirection.reverse)) {
              // Only re-enable newer pagination if we're not in the middle
              // of processing a newer insert (rebuild + scroll restoration).
              // Otherwise this causes an infinite pagination loop.
              if (!_isProcessingNewerInsert) {
                _newerPaginationShouldTrigger = true;
                // Check newer pagination immediately on user scroll toward bottom
                _handleNewerPagination();
              }
            }
            if (_isAtChatEndScrollPosition) {
              _userHasScrolled = false;
            }
          }
        }

        if (notification is ScrollUpdateNotification) {
          _handleToggleScrollToBottom();
          if (_newerPaginationShouldTrigger && !_isProcessingNewerInsert) {
            _handleNewerPagination();
          }
        }

        return false;
      },
      child: Stack(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _newerInsertOpacity,
            builder: (context, opacity, child) {
              return Opacity(opacity: opacity, child: child!);
            },
            child: RepaintBoundary(
              child: SliverViewObserver(
                controller: _observerController,
                sliverContexts: () {
                  final context = _listKey.currentContext;
                  return [?context];
                },
                onObserve: (result) {
                  _updateTopVisibleDate(result);
                },
                child: Scrollbar(
                  controller: _scrollController,
                  child: CustomScrollView(
                    key: const ValueKey('cometchat_message_list_scroll_view'),
                    controller: _scrollController,
                    reverse: widget.reversed,
                    physics: widget.physics,
                    // `scrollCacheExtent` needs Flutter 3.41; the package floor stays at 3.38.9 (DEPR1).
                    // ignore: deprecated_member_use
                    cacheExtent:
                        500, // Pre-render 500px above/below viewport for smoother scrolling
                    keyboardDismissBehavior: widget.keyboardDismissBehavior,
                    slivers: _buildSlivers(),
                  ),
                ),
              ),
            ),
          ),
          // Scroll-to-bottom button
          widget.scrollToBottomBuilder?.call(
                context,
                _scrollToBottomAnimation,
                _handleScrollToBottom,
              ) ??
              ScrollToBottomButton(
                animation: _scrollToBottomAnimation,
                onPressed: _handleScrollToBottom,
              ),
          // Empty state
          ValueListenableBuilder<bool>(
            valueListenable: _isEmptyNotifier,
            builder: (context, isEmpty, child) {
              if (isEmpty) {
                return Positioned.fill(
                  child:
                      widget.emptyBuilder?.call(context) ??
                      const EmptyMessageList(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  /// Build slivers for the CustomScrollView
  List<Widget> _buildSlivers() {
    if (widget.reversed) {
      return <Widget>[
        _buildComposerHeightSliver(),
        if (widget.bottomSliver != null) widget.bottomSliver!,
        if (widget.onLoadNewer != null) _buildNewerLoadMoreSliver(),
        _buildAnimatedList(),
        if (widget.onLoadOlder != null) _buildOlderLoadMoreSliver(),
        if (widget.topSliver != null) widget.topSliver!,
        if (widget.topPadding != null)
          SliverPadding(padding: EdgeInsets.only(top: widget.topPadding!)),
      ];
    } else {
      return <Widget>[
        if (widget.topPadding != null)
          SliverPadding(padding: EdgeInsets.only(top: widget.topPadding!)),
        if (widget.topSliver != null) widget.topSliver!,
        if (widget.onLoadOlder != null) _buildOlderLoadMoreSliver(),
        _buildAnimatedList(),
        if (widget.onLoadNewer != null) _buildNewerLoadMoreSliver(),
        if (widget.bottomSliver != null) widget.bottomSliver!,
        _buildComposerHeightSliver(),
      ];
    }
  }

  /// Build the SliverAnimatedList wrapped in ValueListenableBuilder
  /// so message updates only rebuild the list sliver, not the entire widget
  Widget _buildAnimatedList() {
    return ValueListenableBuilder<int>(
      valueListenable: _messageUpdateNotifier,
      builder: (context, _, _) {
        return _buildAnimatedListContent();
      },
    );
  }

  /// Stable identity for a message across its whole life in the list.
  ///
  /// muid first, deliberately: it is assigned before the send leaves the
  /// device and survives the acknowledgement, whereas `id` is 0 until the
  /// server answers. Keying on `id` would re-key the sender's own message the
  /// moment it was acknowledged and rebuild that bubble for nothing — the
  /// same reason the voice-note bubble derives its cache tag from muid.
  static String _identityOf(BaseMessage message) =>
      message.muid.isNotEmpty ? 'muid:${message.muid}' : 'id:${message.id}';

  /// Resolves a child's key back to its visual index so the framework can keep
  /// elements paired with their message when the list shifts.
  ///
  /// Also accepts the two older key shapes — a bare `ValueKey<int>` id and the
  /// `"$id-$hash-..."` composite — so a caller that keys its own items by
  /// either still reorders rather than rebuilding.
  int? _findChildIndex(Key key) {
    int index = -1;

    if (key is ValueKey<String>) {
      final value = key.value;
      if (value.startsWith('muid:')) {
        final muid = value.substring(5);
        index = _messages.indexWhere((m) => m.muid == muid);
      } else {
        final idPart = value.startsWith('id:')
            ? value.substring(3)
            : value.split('-').first;
        final id = int.tryParse(idPart);
        if (id != null) index = _indexOfId(id);
      }
    } else if (key is ValueKey<int>) {
      index = _indexOfId(key.value);
    }

    return index == -1 ? null : visualPosition(index);
  }

  /// O(1) where the caller supplied a lookup, O(n) otherwise.
  int _indexOfId(int id) =>
      widget.findMessageIndex?.call(id) ??
      _messages.indexWhere((m) => m.id == id);

  /// Build the actual SliverAnimatedList content
  Widget _buildAnimatedListContent() {
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: _messages.length,
      findChildIndexCallback: _findChildIndex,
      itemBuilder: (context, index, animation) {
        if (index < 0 || index >= _messages.length) {
          return const SizedBox.shrink();
        }

        final contentIndex = widget.reversed
            ? _messages.length - 1 - index
            : index;
        if (contentIndex < 0 || contentIndex >= _messages.length) {
          return const SizedBox.shrink();
        }

        final message = _messages[contentIndex];
        return RepaintBoundary(
          // The identity key belongs on the widget the delegate hands back,
          // not somewhere further down the item's own subtree.
          //
          // This list is reversed, so inserting one message shifts every
          // visual index by one and each slot comes to hold a *different*
          // message. Whatever key the framework sees at a slot then no longer
          // matches the element's, Widget.canUpdate says false, and the
          // element is thrown away and re-inflated — every bubble's State
          // recreated, on every send, including a plain text one. Audio
          // bubbles showed it worst because a fresh State starts on a
          // placeholder waveform with no duration and re-runs an async
          // file-exists check before it can paint the real thing (ENG-39490).
          //
          // With the key here instead, the framework can pair each element
          // with its message across the shift and leave the rest alone. The
          // per-message composite key further down still does its own job:
          // rebuilding that one item when it is edited, deleted or pinned.
          key: ValueKey<String>(_identityOf(message)),
          child: widget.itemBuilder(context, message, contentIndex, animation),
        );
      },
    );
  }

  /// Build composer height sliver
  Widget _buildComposerHeightSliver() {
    return SliverSpacing(
      bottomPadding: widget.bottomPadding,
      handleSafeArea: false, // SafeArea is handled by parent
      composerHeightNotifier: widget.composerHeightNotifier,
      composerHeight: 0, // Composer is outside the list in Column layout
      includeKeyboardHeight:
          false, // Scaffold handles keyboard with resizeToAvoidBottomInset
      scrollController: _scrollController,
      onKeyboardHeightChanged: widget.reversed
          ? null
          : _onKeyboardHeightChanged,
    );
  }

  /// Build load more indicator for older messages
  Widget _buildOlderLoadMoreSliver() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _loadMoreNotifier,
        builder: (context, child) {
          if (!_loadMoreNotifier.isLoadingOlder) {
            return const SizedBox.shrink();
          }
          return widget.loadMoreBuilder?.call(context) ??
              const LoadMoreIndicator();
        },
      ),
    );
  }

  /// Build load more indicator for newer messages
  Widget _buildNewerLoadMoreSliver() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _loadMoreNotifier,
        builder: (context, child) {
          if (!_loadMoreNotifier.isLoadingNewer) {
            return const SizedBox.shrink();
          }
          return widget.loadMoreBuilder?.call(context) ??
              const LoadMoreIndicator();
        },
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.removeListener(_onScrollForDateTracking);
    _isEmptyNotifier.dispose();
    _newerInsertOpacity.dispose();
    _messageUpdateNotifier.dispose();
    _scrollToBottomShowTimer?.cancel();
    _scrollToBottomController.dispose();
    _scrollAnimationController.removeListener(_linkAnimationToScroll);
    _scrollAnimationController.dispose();
    _operationsSubscription.cancel();
    _loadMoreNotifier.dispose();

    if (widget.scrollController == null) {
      _scrollController.dispose();
    }

    widget.bloc.detachScrollMethods();

    super.dispose();
  }
}
