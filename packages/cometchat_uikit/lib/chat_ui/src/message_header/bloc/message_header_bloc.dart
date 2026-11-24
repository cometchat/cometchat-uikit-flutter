import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../../../shared_ui/src/offline/offline_group_removal.dart';
import '../../../../shared_ui/src/offline/offline_presence.dart';
import '../di/message_header_service_locator.dart';
import '../domain/usecases/get_user_usecase.dart';
import '../domain/usecases/get_group_usecase.dart';
import '../domain/usecases/get_logged_in_user_usecase.dart';
import 'message_header_event.dart';
import 'message_header_state.dart';

/// BLoC for managing message header state
///
/// This BLoC manages the message header state and handles:
/// - User/Group display information
/// - Online/Offline presence
/// - Typing indicators
/// - Group member count updates
/// - User block/unblock events
/// - Group ownership changes
class MessageHeaderBloc extends Bloc<MessageHeaderEvent, MessageHeaderState> {
  // Use cases
  final GetUserUseCase getUserUseCase;
  final GetGroupUseCase getGroupUseCase;
  final GetMessageHeaderLoggedInUserUseCase getLoggedInUserUseCase;

  // Configuration
  final bool usersStatusVisibility;
  final bool disableSDKListeners;

  // SDK listener IDs
  final String _messageListenerKey =
      'message_header_bloc_message_${DateTime.now().millisecondsSinceEpoch}';
  final String _userListenerKey =
      'message_header_bloc_user_${DateTime.now().millisecondsSinceEpoch}';
  final String _groupListenerKey =
      'message_header_bloc_group_${DateTime.now().millisecondsSinceEpoch}';
  final String _connectionListenerKey =
      'message_header_bloc_connection_${DateTime.now().millisecondsSinceEpoch}';

  // CC UI Event listener IDs
  final String _ccGroupListenerKey =
      'message_header_bloc_cc_group_${DateTime.now().millisecondsSinceEpoch}';
  final String _ccUserListenerKey =
      'message_header_bloc_cc_user_${DateTime.now().millisecondsSinceEpoch}';

  // Typing indicator ValueNotifier for isolated rebuilds
  final ValueNotifier<List<TypingIndicator>> _typingNotifier =
      ValueNotifier<List<TypingIndicator>>([]);

  /// Get typing notifier for isolated rebuilds
  ValueNotifier<List<TypingIndicator>> get typingNotifier => _typingNotifier;

  /// Get current typing indicators
  List<TypingIndicator> get typingIndicators => _typingNotifier.value;

  /// Helper to get initialized service locator
  static MessageHeaderServiceLocator _getServiceLocator() {
    if (!MessageHeaderServiceLocator.instance.isInitialized) {
      MessageHeaderServiceLocator.instance.setup();
    }
    return MessageHeaderServiceLocator.instance;
  }

  /// Creates a MessageHeaderBloc
  MessageHeaderBloc({
    GetUserUseCase? getUserUseCase,
    GetGroupUseCase? getGroupUseCase,
    GetMessageHeaderLoggedInUserUseCase? getLoggedInUserUseCase,
    this.usersStatusVisibility = true,
    this.disableSDKListeners = false,
  }) : getUserUseCase = getUserUseCase ?? _getServiceLocator().getUserUseCase,
       getGroupUseCase =
           getGroupUseCase ?? _getServiceLocator().getGroupUseCase,
       getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           _getServiceLocator().getLoggedInUserUseCase,
       super(const MessageHeaderState()) {
    // Register event handlers
    on<SetUser>(_onSetUser);
    on<SetGroup>(_onSetGroup);
    on<RefreshUser>(_onRefreshUser);
    on<RefreshGroup>(_onRefreshGroup);
    on<UpdateUserStatus>(_onUpdateUserStatus);
    on<UpdateGroupMemberCount>(_onUpdateGroupMemberCount);
    on<UpdateGroupDetails>(_onUpdateGroupDetails);
    on<TypingStarted>(_onTypingStarted);
    on<TypingEnded>(_onTypingEnded);
    on<UserBlocked>(_onUserBlocked);
    on<UserUnblocked>(_onUserUnblocked);
    on<GroupOwnershipChanged>(_onGroupOwnershipChanged);
    on<InitializeLoggedInUser>(_onInitializeLoggedInUser);

    // Initialize logged in user and register SDK listeners
    _initializeAndRegisterListeners();
  }

  /// Initialize logged in user and register all SDK listeners
  Future<void> _initializeAndRegisterListeners() async {
    // Use cached logged-in user from UIKit level (avoids redundant platform channel calls)
    final cachedUser = CometChatUIKit.loggedInUser;
    if (cachedUser != null && !isClosed) {
      add(InitializeLoggedInUser(cachedUser));
    }

    // Skip SDK listeners if disabled
    if (!disableSDKListeners) {
      _registerSDKListeners();
    }

    // Offline (W5, G7/B2): a self kick, ban or leave found by the reconnect
    // sweep reaches no group listener; route it into the live handlers. Only
    // the offline hub feeds this, so with offline off it never fires.
    _sweptRemovalSub = SweptSelfRemoval.listen(
      () => state.loggedInUser?.uid ?? CometChatUIKit.loggedInUser?.uid,
      _handleSweptSelfRemoval,
    );
  }

  StreamSubscription<Object?>? _sweptRemovalSub;

  void _handleSweptSelfRemoval(SweptSelfRemoval r) {
    switch (r.kind) {
      case SweptSelfRemoval.kicked:
        _handleGroupMemberKicked(r.action, r.removedUser, r.by, r.group);
      case SweptSelfRemoval.banned:
        _handleGroupMemberBanned(r.action, r.removedUser, r.by, r.group);
      case SweptSelfRemoval.left:
        _handleGroupMemberLeft(r.action, r.removedUser, r.group);
    }
  }

  /// Register all CometChat SDK listeners
  void _registerSDKListeners() {
    // Message listener for typing indicators
    CometChat.addMessageListener(
      _messageListenerKey,
      _MessageHeaderMessageListener(
        onTypingStartedCallback: _handleTypingStarted,
        onTypingEndedCallback: _handleTypingEnded,
      ),
    );

    // User listener for online/offline status
    if (usersStatusVisibility) {
      CometChat.addUserListener(
        _userListenerKey,
        _MessageHeaderUserListener(
          onUserOnlineCallback: _handleUserOnline,
          onUserOfflineCallback: _handleUserOffline,
        ),
      );
    }

    // Group listener for member events
    CometChat.addGroupListener(
      _groupListenerKey,
      _MessageHeaderGroupListener(
        onGroupMemberJoinedCallback: _handleGroupMemberJoined,
        onGroupMemberLeftCallback: _handleGroupMemberLeft,
        onGroupMemberKickedCallback: _handleGroupMemberKicked,
        onGroupMemberBannedCallback: _handleGroupMemberBanned,
        onMemberAddedToGroupCallback: _handleMemberAddedToGroup,
        onGroupMemberScopeChangedCallback: _handleGroupMemberScopeChanged,
        loggedInUserId: state.loggedInUser?.uid,
      ),
    );

    // Connection listener
    CometChat.addConnectionListener(
      _connectionListenerKey,
      _MessageHeaderConnectionListener(
        onConnectedCallback: _handleConnected,
        onDisconnectedCallback: OfflinePresence.disconnected,
      ),
    );
    unawaited(OfflinePresence.sync());

    // CC UI Event listeners
    _registerCCEventListeners();
  }

  /// Register CometChat UI Event listeners
  void _registerCCEventListeners() {
    CometChatGroupEvents.addGroupsListener(
      _ccGroupListenerKey,
      _CCMessageHeaderGroupEventListener(
        onCCGroupMemberAddedCallback: _handleCCGroupMemberAdded,
        onCCGroupMemberKickedCallback: _handleCCGroupMemberKicked,
        onCCGroupMemberBannedCallback: _handleCCGroupMemberBanned,
        onCCOwnershipChangedCallback: _handleCCOwnershipChanged,
      ),
    );

    CometChatUserEvents.addUsersListener(
      _ccUserListenerKey,
      _CCMessageHeaderUserEventListener(
        onCCUserBlockedCallback: _handleCCUserBlocked,
        onCCUserUnblockedCallback: _handleCCUserUnblocked,
      ),
    );
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Set user for the message header
  void _onSetUser(SetUser event, Emitter<MessageHeaderState> emit) {
    emit(
      state.copyWith(
        status: MessageHeaderStatus.loaded,
        user: event.user,
        group: null,
        memberCount: 0,
        isTyping: false,
        clearTypingUser: true,
      ),
    );
    _typingNotifier.value = [];
  }

  /// Handle internal logged in user initialization
  void _onInitializeLoggedInUser(
    InitializeLoggedInUser event,
    Emitter<MessageHeaderState> emit,
  ) {
    emit(state.copyWith(loggedInUser: event.user));
  }

  /// Set group for the message header
  void _onSetGroup(SetGroup event, Emitter<MessageHeaderState> emit) {
    emit(
      state.copyWith(
        status: MessageHeaderStatus.loaded,
        user: null,
        group: event.group,
        memberCount: event.group.membersCount,
        isTyping: false,
        clearTypingUser: true,
      ),
    );
    _typingNotifier.value = [];
  }

  /// Refresh user data from SDK
  Future<void> _onRefreshUser(
    RefreshUser event,
    Emitter<MessageHeaderState> emit,
  ) async {
    if (state.user == null) return;

    emit(state.copyWith(status: MessageHeaderStatus.loading));

    final result = await getUserUseCase(state.user!.uid);

    if (result is Success<User>) {
      emit(
        state.copyWith(status: MessageHeaderStatus.loaded, user: result.data),
      );
    } else if (result is Failure) {
      emit(
        state.copyWith(
          status: MessageHeaderStatus.error,
          errorMessage: result.message,
        ),
      );
    }
  }

  /// Refresh group data from SDK
  Future<void> _onRefreshGroup(
    RefreshGroup event,
    Emitter<MessageHeaderState> emit,
  ) async {
    if (state.group == null) return;

    emit(state.copyWith(status: MessageHeaderStatus.loading));

    final result = await getGroupUseCase(state.group!.guid);

    if (result is Success<Group>) {
      emit(
        state.copyWith(
          status: MessageHeaderStatus.loaded,
          group: result.data,
          memberCount: result.data.membersCount,
        ),
      );
    } else if (result is Failure) {
      emit(
        state.copyWith(
          status: MessageHeaderStatus.error,
          errorMessage: result.message,
        ),
      );
    }
  }

  /// Update user status (online/offline)
  void _onUpdateUserStatus(
    UpdateUserStatus event,
    Emitter<MessageHeaderState> emit,
  ) {
    if (state.user == null || state.user!.uid != event.userId) {
      return;
    }

    final updatedUser = User(
      uid: state.user!.uid,
      name: state.user!.name,
      avatar: state.user!.avatar,
      status: event.status,
      role: state.user!.role,
      blockedByMe: state.user!.blockedByMe,
      hasBlockedMe: state.user!.hasBlockedMe,
      lastActiveAt: event.lastActiveAt ?? state.user!.lastActiveAt,
      link: state.user!.link,
      metadata: state.user!.metadata,
      statusMessage: state.user!.statusMessage,
      tags: state.user!.tags,
    );

    emit(state.copyWith(user: updatedUser));
  }

  /// Update group member count
  void _onUpdateGroupMemberCount(
    UpdateGroupMemberCount event,
    Emitter<MessageHeaderState> emit,
  ) {
    if (state.group == null || state.group!.guid != event.groupId) return;

    emit(state.copyWith(memberCount: event.memberCount));
  }

  /// Update group details
  void _onUpdateGroupDetails(
    UpdateGroupDetails event,
    Emitter<MessageHeaderState> emit,
  ) {
    if (state.group == null || state.group!.guid != event.group.guid) return;

    emit(
      state.copyWith(group: event.group, memberCount: event.group.membersCount),
    );
  }

  /// Handle typing started
  void _onTypingStarted(TypingStarted event, Emitter<MessageHeaderState> emit) {
    final typingIndicator = event.typingIndicator;

    // Check if typing is relevant to current conversation
    bool isRelevant = false;

    if (state.user != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.user &&
        typingIndicator.sender.uid == state.user!.uid &&
        state.userIsNotBlocked) {
      isRelevant = true;
    } else if (state.group != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.group &&
        typingIndicator.receiverId == state.group!.guid) {
      isRelevant = true;
    }

    if (isRelevant) {
      emit(state.copyWith(isTyping: true, typingUser: typingIndicator.sender));

      // Update ValueNotifier for isolated rebuilds
      final currentTyping = List<TypingIndicator>.from(_typingNotifier.value);
      final existingIndex = currentTyping.indexWhere(
        (t) => t.sender.uid == typingIndicator.sender.uid,
      );
      if (existingIndex == -1) {
        currentTyping.add(typingIndicator);
        _typingNotifier.value = currentTyping;
      }
    }
  }

  /// Handle typing ended
  void _onTypingEnded(TypingEnded event, Emitter<MessageHeaderState> emit) {
    final typingIndicator = event.typingIndicator;

    // Check if typing is relevant to current conversation
    bool isRelevant = false;

    if (state.user != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.user &&
        typingIndicator.sender.uid == state.user!.uid) {
      isRelevant = true;
    } else if (state.group != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.group &&
        typingIndicator.receiverId == state.group!.guid) {
      isRelevant = true;
    }

    if (isRelevant) {
      // Update ValueNotifier
      final currentTyping = List<TypingIndicator>.from(_typingNotifier.value);
      currentTyping.removeWhere(
        (t) => t.sender.uid == typingIndicator.sender.uid,
      );
      _typingNotifier.value = currentTyping;

      // Update state
      if (currentTyping.isEmpty) {
        emit(state.copyWith(isTyping: false, clearTypingUser: true));
      } else {
        emit(state.copyWith(typingUser: currentTyping.last.sender));
      }
    }
  }

  /// Handle user blocked
  void _onUserBlocked(UserBlocked event, Emitter<MessageHeaderState> emit) {
    if (state.user == null || state.user!.uid != event.user.uid) return;

    final updatedUser = User(
      uid: state.user!.uid,
      name: state.user!.name,
      avatar: state.user!.avatar,
      status: state.user!.status,
      role: state.user!.role,
      blockedByMe: true,
      hasBlockedMe: state.user!.hasBlockedMe,
      lastActiveAt: state.user!.lastActiveAt,
      link: state.user!.link,
      metadata: state.user!.metadata,
      statusMessage: state.user!.statusMessage,
      tags: state.user!.tags,
    );

    emit(state.copyWith(user: updatedUser));
  }

  /// Handle user unblocked
  void _onUserUnblocked(UserUnblocked event, Emitter<MessageHeaderState> emit) {
    if (state.user == null || state.user!.uid != event.user.uid) return;

    final updatedUser = User(
      uid: state.user!.uid,
      name: state.user!.name,
      avatar: state.user!.avatar,
      status: state.user!.status,
      role: state.user!.role,
      blockedByMe: false,
      hasBlockedMe: state.user!.hasBlockedMe,
      lastActiveAt: state.user!.lastActiveAt,
      link: state.user!.link,
      metadata: state.user!.metadata,
      statusMessage: state.user!.statusMessage,
      tags: state.user!.tags,
    );

    emit(state.copyWith(user: updatedUser));
  }

  /// Handle group ownership changed
  void _onGroupOwnershipChanged(
    GroupOwnershipChanged event,
    Emitter<MessageHeaderState> emit,
  ) {
    if (state.group == null || state.group!.guid != event.group.guid) return;

    emit(state.copyWith(group: event.group));
  }

  // ============================================================
  // SDK LISTENER CALLBACKS
  // ============================================================

  void _handleTypingStarted(TypingIndicator typingIndicator) {
    if (!isClosed) {
      add(TypingStarted(typingIndicator));
    }
  }

  void _handleTypingEnded(TypingIndicator typingIndicator) {
    if (!isClosed) {
      add(TypingEnded(typingIndicator));
    }
  }

  void _handleUserOnline(User user) {
    if (!isClosed) {
      add(
        UpdateUserStatus(userId: user.uid, status: UserStatusConstants.online),
      );
    }
  }

  void _handleUserOffline(User user) {
    if (!isClosed) {
      add(
        UpdateUserStatus(
          userId: user.uid,
          status: UserStatusConstants.offline,
          lastActiveAt: user.lastActiveAt,
        ),
      );
    }
  }

  void _handleGroupMemberJoined(Action action, User joinedUser, Group group) {
    if (!isClosed) {
      add(
        UpdateGroupMemberCount(
          groupId: group.guid,
          memberCount: group.membersCount,
        ),
      );
    }
  }

  void _handleGroupMemberLeft(Action action, User leftUser, Group group) {
    if (!isClosed) {
      add(
        UpdateGroupMemberCount(
          groupId: group.guid,
          memberCount: group.membersCount,
        ),
      );
    }
  }

  void _handleGroupMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group group,
  ) {
    if (!isClosed) {
      add(
        UpdateGroupMemberCount(
          groupId: group.guid,
          memberCount: group.membersCount,
        ),
      );
    }
  }

  void _handleGroupMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group group,
  ) {
    if (!isClosed) {
      add(
        UpdateGroupMemberCount(
          groupId: group.guid,
          memberCount: group.membersCount,
        ),
      );
    }
  }

  void _handleMemberAddedToGroup(
    Action action,
    User addedBy,
    User userAdded,
    Group group,
  ) {
    if (!isClosed) {
      add(
        UpdateGroupMemberCount(
          groupId: group.guid,
          memberCount: group.membersCount,
        ),
      );
    }
  }

  void _handleGroupMemberScopeChanged(
    Action action,
    User updatedBy,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) {
    if (!isClosed &&
        state.group != null &&
        state.group!.guid == group.guid &&
        updatedUser.uid == state.loggedInUser?.uid) {
      final updatedGroup = Group(
        guid: state.group!.guid,
        name: state.group!.name,
        type: state.group!.type,
        icon: state.group!.icon,
        description: state.group!.description,
        owner: state.group!.owner,
        membersCount: state.group!.membersCount,
        createdAt: state.group!.createdAt,
        joinedAt: state.group!.joinedAt,
        hasJoined: state.group!.hasJoined,
        scope: scopeChangedTo,
        tags: state.group!.tags,
        metadata: state.group!.metadata,
        password: state.group!.password,
      );
      add(UpdateGroupDetails(updatedGroup));
    }
  }

  void _handleConnected() {
    OfflinePresence.connected();
    if (!isClosed) {
      if (state.user != null) {
        add(const RefreshUser());
      } else if (state.group != null) {
        add(const RefreshGroup());
      }
    }
  }

  // CC Event callbacks
  void _handleCCGroupMemberAdded(
    List<Action> messages,
    List<User> usersAdded,
    Group group,
    User addedBy,
  ) {
    if (!isClosed && state.group != null && state.group!.guid == group.guid) {
      add(
        UpdateGroupMemberCount(
          groupId: group.guid,
          memberCount: group.membersCount,
        ),
      );
    }
  }

  void _handleCCGroupMemberKicked(
    Action message,
    User kickedUser,
    User kickedBy,
    Group group,
  ) {
    if (!isClosed) {
      add(
        UpdateGroupMemberCount(
          groupId: group.guid,
          memberCount: group.membersCount,
        ),
      );
    }
  }

  void _handleCCGroupMemberBanned(
    Action message,
    User bannedUser,
    User bannedBy,
    Group group,
  ) {
    if (!isClosed) {
      add(
        UpdateGroupMemberCount(
          groupId: group.guid,
          memberCount: group.membersCount,
        ),
      );
    }
  }

  void _handleCCOwnershipChanged(Group group, GroupMember newOwner) {
    if (!isClosed && state.group != null && state.group!.guid == group.guid) {
      add(GroupOwnershipChanged(group: group, newOwner: newOwner));
    }
  }

  void _handleCCUserBlocked(User user) {
    if (!isClosed) {
      add(UserBlocked(user));
    }
  }

  void _handleCCUserUnblocked(User user) {
    if (!isClosed) {
      add(UserUnblocked(user));
    }
  }

  @override
  Future<void> close() {
    _sweptRemovalSub?.cancel();

    // Remove SDK listeners
    CometChat.removeMessageListener(_messageListenerKey);
    CometChat.removeUserListener(_userListenerKey);
    CometChat.removeGroupListener(_groupListenerKey);
    CometChat.removeConnectionListener(_connectionListenerKey);

    // Remove CC Event listeners
    CometChatGroupEvents.removeGroupsListener(_ccGroupListenerKey);
    CometChatUserEvents.removeUsersListener(_ccUserListenerKey);

    // Dispose ValueNotifier
    _typingNotifier.dispose();

    return super.close();
  }
}

// ============================================================
// SDK LISTENER CLASSES
// ============================================================

/// Message listener for typing indicators
class _MessageHeaderMessageListener with MessageListener {
  final void Function(TypingIndicator) onTypingStartedCallback;
  final void Function(TypingIndicator) onTypingEndedCallback;

  _MessageHeaderMessageListener({
    required this.onTypingStartedCallback,
    required this.onTypingEndedCallback,
  });

  @override
  void onTypingStarted(TypingIndicator typingIndicator) {
    onTypingStartedCallback(typingIndicator);
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {
    onTypingEndedCallback(typingIndicator);
  }
}

/// User listener for online/offline status
class _MessageHeaderUserListener with UserListener {
  final void Function(User) onUserOnlineCallback;
  final void Function(User) onUserOfflineCallback;

  _MessageHeaderUserListener({
    required this.onUserOnlineCallback,
    required this.onUserOfflineCallback,
  });

  @override
  void onUserOnline(User user) {
    onUserOnlineCallback(user);
  }

  @override
  void onUserOffline(User user) {
    onUserOfflineCallback(user);
  }
}

/// Group listener for member events
class _MessageHeaderGroupListener with GroupListener {
  final void Function(Action, User, Group) onGroupMemberJoinedCallback;
  final void Function(Action, User, Group) onGroupMemberLeftCallback;
  final void Function(Action, User, User, Group) onGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onGroupMemberBannedCallback;
  final void Function(Action, User, User, Group) onMemberAddedToGroupCallback;
  final void Function(Action, User, User, String, String, Group)
  onGroupMemberScopeChangedCallback;
  final String? loggedInUserId;

  _MessageHeaderGroupListener({
    required this.onGroupMemberJoinedCallback,
    required this.onGroupMemberLeftCallback,
    required this.onGroupMemberKickedCallback,
    required this.onGroupMemberBannedCallback,
    required this.onMemberAddedToGroupCallback,
    required this.onGroupMemberScopeChangedCallback,
    this.loggedInUserId,
  });

  @override
  void onGroupMemberJoined(Action action, User joinedUser, Group joinedGroup) {
    onGroupMemberJoinedCallback(action, joinedUser, joinedGroup);
  }

  @override
  void onGroupMemberLeft(Action action, User leftUser, Group leftGroup) {
    onGroupMemberLeftCallback(action, leftUser, leftGroup);
  }

  @override
  void onGroupMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    onGroupMemberKickedCallback(action, kickedUser, kickedBy, kickedFrom);
  }

  @override
  void onGroupMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    onGroupMemberBannedCallback(action, bannedUser, bannedBy, bannedFrom);
  }

  @override
  void onMemberAddedToGroup(
    Action action,
    User addedby,
    User userAdded,
    Group addedTo,
  ) {
    onMemberAddedToGroupCallback(action, addedby, userAdded, addedTo);
  }

  @override
  void onGroupMemberScopeChanged(
    Action action,
    User updatedBy,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) {
    onGroupMemberScopeChangedCallback(
      action,
      updatedBy,
      updatedUser,
      scopeChangedTo,
      scopeChangedFrom,
      group,
    );
  }
}

/// Connection listener
class _MessageHeaderConnectionListener with ConnectionListener {
  final void Function() onConnectedCallback;
  final void Function() onDisconnectedCallback;

  _MessageHeaderConnectionListener({
    required this.onConnectedCallback,
    required this.onDisconnectedCallback,
  });

  @override
  void onConnected() {
    onConnectedCallback();
  }

  @override
  void onDisconnected() {
    onDisconnectedCallback();
  }
}

/// CC Group event listener
class _CCMessageHeaderGroupEventListener with CometChatGroupEventListener {
  final void Function(List<Action>, List<User>, Group, User)
  onCCGroupMemberAddedCallback;
  final void Function(Action, User, User, Group) onCCGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onCCGroupMemberBannedCallback;
  final void Function(Group, GroupMember) onCCOwnershipChangedCallback;

  _CCMessageHeaderGroupEventListener({
    required this.onCCGroupMemberAddedCallback,
    required this.onCCGroupMemberKickedCallback,
    required this.onCCGroupMemberBannedCallback,
    required this.onCCOwnershipChangedCallback,
  });

  @override
  void ccGroupMemberAdded(
    List<Action> messages,
    List<User> usersAdded,
    Group groupAddedIn,
    User addedBy,
  ) {
    onCCGroupMemberAddedCallback(messages, usersAdded, groupAddedIn, addedBy);
  }

  @override
  void ccGroupMemberKicked(
    Action message,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    onCCGroupMemberKickedCallback(message, kickedUser, kickedBy, kickedFrom);
  }

  @override
  void ccGroupMemberBanned(
    Action message,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    onCCGroupMemberBannedCallback(message, bannedUser, bannedBy, bannedFrom);
  }

  @override
  void ccOwnershipChanged(Group group, GroupMember newOwner) {
    onCCOwnershipChangedCallback(group, newOwner);
  }
}

/// CC User event listener
class _CCMessageHeaderUserEventListener with CometChatUserEventListener {
  final void Function(User) onCCUserBlockedCallback;
  final void Function(User) onCCUserUnblockedCallback;

  _CCMessageHeaderUserEventListener({
    required this.onCCUserBlockedCallback,
    required this.onCCUserUnblockedCallback,
  });

  @override
  void ccUserBlocked(User user) {
    onCCUserBlockedCallback(user);
  }

  @override
  void ccUserUnblocked(User user) {
    onCCUserUnblockedCallback(user);
  }
}
