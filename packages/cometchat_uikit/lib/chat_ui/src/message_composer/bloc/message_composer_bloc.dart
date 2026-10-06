import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../shared_ui/src/clean_architecture/core/utils/platform_utils/platform_file_utils.dart'
    as platform;
import '../../../../shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import '../../../../shared_ui/src/clean_architecture/core/utils/ui_event_target.dart';

/// BLoC for managing message composer state and business logic
/// Handles message sending, editing, replying, and typing indicators
class MessageComposerBloc
    extends Bloc<MessageComposerEvent, MessageComposerState>
    with
        CometChatMessageEventListener,
        CometChatUIEventListener,
        CometChatUserEventListener,
        CometChatStreamCallbackListener {
  // ============================================================================
  // Use Cases
  // ============================================================================
  final SendTextMessageUseCase _sendTextMessageUseCase;
  final SendMediaMessageUseCase _sendMediaMessageUseCase;
  final SendCustomMessageUseCase _sendCustomMessageUseCase;
  final EditMessageUseCase _editMessageUseCase;
  final StartTypingUseCase _startTypingUseCase;
  final EndTypingUseCase _endTypingUseCase;
  final GetMessageComposerLoggedInUserUseCase _getLoggedInUserUseCase;

  // ============================================================================
  // Configuration
  // ============================================================================
  final bool disableTypingEvents;
  final bool disableSoundForMessages;
  final String? customSoundForMessage;
  final String? customSoundForMessagePackage;
  final int parentMessageId;
  final BuildContext context;

  // ============================================================================
  // Callbacks
  // ============================================================================
  final Function(BuildContext, BaseMessage, PreviewMessageMode?)?
  onSendButtonTap;
  final OnError? errorCallback;

  // ============================================================================
  // SDK Listener IDs
  // ============================================================================
  late final String _messageListenerKey;
  late final String _uiEventListenerKey;
  late final String _userEventListenerKey;

  // ============================================================================
  // Typing Debouncer
  // ============================================================================
  final Debouncer _typingDebouncer = Debouncer(milliseconds: 1000);
  bool _isTyping = false;

  // ============================================================================
  // ValueNotifier for isolated rebuilds
  // ============================================================================
  final ValueNotifier<bool> _typingNotifier = ValueNotifier<bool>(false);

  /// Get typing notifier for isolated UI rebuilds
  ValueNotifier<bool> get typingNotifier => _typingNotifier;

  /// Callback for when focus is requested on the composer text field.
  /// Set by the widget to avoid coupling BLoC to FocusNode.
  VoidCallback? onFocusRequested;

  // ============================================================================
  // Constructor
  // ============================================================================
  MessageComposerBloc({
    required this.context,
    this.disableTypingEvents = false,
    this.disableSoundForMessages = false,
    this.customSoundForMessage,
    this.customSoundForMessagePackage,
    this.parentMessageId = 0,
    this.onSendButtonTap,
    this.errorCallback,
    User? user,
    Group? group,
    SendTextMessageUseCase? sendTextMessageUseCase,
    SendMediaMessageUseCase? sendMediaMessageUseCase,
    SendCustomMessageUseCase? sendCustomMessageUseCase,
    EditMessageUseCase? editMessageUseCase,
    StartTypingUseCase? startTypingUseCase,
    EndTypingUseCase? endTypingUseCase,
    GetMessageComposerLoggedInUserUseCase? getLoggedInUserUseCase,
  }) : _sendTextMessageUseCase =
           sendTextMessageUseCase ??
           MessageComposerServiceLocator.instance.sendTextMessageUseCase,
       _sendMediaMessageUseCase =
           sendMediaMessageUseCase ??
           MessageComposerServiceLocator.instance.sendMediaMessageUseCase,
       _sendCustomMessageUseCase =
           sendCustomMessageUseCase ??
           MessageComposerServiceLocator.instance.sendCustomMessageUseCase,
       _editMessageUseCase =
           editMessageUseCase ??
           MessageComposerServiceLocator.instance.editMessageUseCase,
       _startTypingUseCase =
           startTypingUseCase ??
           MessageComposerServiceLocator.instance.startTypingUseCase,
       _endTypingUseCase =
           endTypingUseCase ??
           MessageComposerServiceLocator.instance.endTypingUseCase,
       _getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           MessageComposerServiceLocator.instance.getLoggedInUserUseCase,
       super(
         MessageComposerState(
           user: user,
           group: group,
           parentMessageId: parentMessageId,
           composerId: _buildComposerId(user, group, parentMessageId),
         ),
       ) {
    // Register event handlers
    on<InitializeComposer>(_onInitializeComposer);
    on<ComposerSetUser>(_onSetUser);
    on<ComposerSetGroup>(_onSetGroup);
    on<UpdateComposeText>(_onUpdateComposeText);
    on<ClearComposer>(_onClearComposer);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendMediaMessage>(_onSendMediaMessage);
    on<SendCustomMessage>(_onSendCustomMessage);
    on<SetEditMessage>(_onSetEditMessage);
    on<ClearEditMessage>(_onClearEditMessage);
    on<EditTextMessage>(_onEditTextMessage);
    on<SetReplyMessage>(_onSetReplyMessage);
    on<ClearReplyMessage>(_onClearReplyMessage);
    on<StartTyping>(_onStartTyping);
    on<EndTyping>(_onEndTyping);
    on<ShowPanel>(_onShowPanel);
    on<HidePanel>(_onHidePanel);
    on<MessageEditedExternally>(_onMessageEditedExternally);
    on<ComposeMessageReceived>(_onComposeMessageReceived);
    on<ClearComposeText>(_onClearComposeText);
    on<SetStreamingState>(_onSetStreamingState);
    on<UserBlockedStatusChanged>(_onUserBlockedStatusChanged);
    on<StartAudioRecording>(_onStartAudioRecording);
    on<CancelAudioRecording>(_onCancelAudioRecording);
    on<SubmitAudioRecording>(_onSubmitAudioRecording);
    on<LockBottomPadding>(_onLockBottomPadding);
    on<UnlockBottomPadding>(_onUnlockBottomPadding);
    on<UpdateParentMessageId>(_onUpdateParentMessageId);

    // Initialize listeners
    _initializeListeners();

    // Initialize composer
    add(const InitializeComposer());
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Returns a NEW [MediaMessage] identical to [original] except for its
  /// [caption]. Editing works on a copy (never the original) so BLoC's
  /// Equatable dedup doesn't suppress the re-render when the SDK echoes the
  /// edited message back; all id/attachments/metadata/timestamps are preserved
  /// so batch grouping and server thumbnails survive the edit.
  static MediaMessage cloneMediaWithCaption(
    MediaMessage original,
    String caption,
  ) {
    return MediaMessage(
      id: original.id,
      muid: original.muid,
      sender: original.sender,
      receiver: original.receiver,
      receiverUid: original.receiverUid,
      receiverType: original.receiverType,
      type: original.type,
      category: original.category,
      caption: caption,
      attachment: original.attachment,
      attachments: original.attachments,
      file: original.file,
      files: original.files,
      tags: original.tags,
      metadata: original.metadata != null
          ? Map<String, dynamic>.from(original.metadata!)
          : null,
      sentAt: original.sentAt,
      deliveredAt: original.deliveredAt,
      readAt: original.readAt,
      readByMeAt: original.readByMeAt,
      deliveredToMeAt: original.deliveredToMeAt,
      editedAt: original.editedAt,
      editedBy: original.editedBy,
      updatedAt: original.updatedAt,
      conversationId: original.conversationId,
      parentMessageId: original.parentMessageId,
      replyCount: original.replyCount,
      mentionedUsers: original.mentionedUsers,
      hasMentionedMe: original.hasMentionedMe,
      reactions: original.reactions,
      quotedMessage: original.quotedMessage,
      quotedMessageId: original.quotedMessageId,
    );
  }

  static Map<String, dynamic> _buildComposerId(
    User? user,
    Group? group,
    int parentMessageId,
  ) => buildUiEventId(
    uid: user?.uid,
    guid: group?.guid,
    parentMessageId: parentMessageId,
  );

  /// A null id stays a broadcast here: `CometChatUIKitHelper.showPanel` lets an
  /// integrator raise a panel without naming a conversation, and single-composer
  /// apps rely on that.
  bool _isForThisWidget(Map<String, dynamic>? id) =>
      uiEventTargets(id, state.composerId, nullTargetsAll: true);

  /// True when [message] belongs to the conversation this composer is bound to.
  ///
  /// The `sender` arm is what lets an **incoming** 1:1 message match — there the
  /// `receiverUid` is the logged-in user, not the peer. It is gated on
  /// `receiverType` so a *group* message that merely happens to be sent by the
  /// 1:1 peer cannot match a 1:1 composer.
  ///
  /// Conversation identity only — callers that also care about threads must
  /// compare `parentMessageId` themselves.
  bool _isForThisConversation(BaseMessage message) {
    final user = state.user;
    final group = state.group;
    final isForUser =
        user != null &&
        (message.receiverUid == user.uid ||
            (message.receiverType == ReceiverTypeConstants.user &&
                message.sender?.uid == user.uid));
    final isForGroup = group != null && message.receiverUid == group.guid;
    return isForUser || isForGroup;
  }

  /// Subscribes the sender to the thread of the message they just sent, so
  /// replies to it notify them.
  ///
  /// The server does not stamp `threadSubscribed` on your own outgoing
  /// message, and the UI Kit otherwise only ever subscribes from an explicit
  /// Follow tap — so a message you sent read as un-followed and its replies
  /// went unannounced (ENG-39487).
  ///
  /// [MessageTemplateUtils.resolveThreadId] gives the parent id for a reply
  /// and the message's own id for a root, so replying subscribes you to the
  /// thread you replied in rather than starting a new one.
  ///
  /// Fire-and-forget by design: subscribing is a courtesy, and a failure must
  /// not fail or delay a message that has already been delivered. Gated on
  /// [UIKitSettings.enableThreadSubscription] so an app that does not ship
  /// follow/unfollow doesn't quietly start creating subscriptions.
  void _subscribeSenderToOwnThread(BaseMessage sentMessage) {
    if (CometChatUIKit.authenticationSettings?.enableThreadSubscription !=
        true) {
      return;
    }
    if (sentMessage.threadSubscribed) return;

    final threadId = MessageTemplateUtils.resolveThreadId(sentMessage);
    if (threadId <= 0) return;

    unawaited(
      CometChat.subscribeToThread(threadId)
          .then((result) {
            if (result == null) return;
            sentMessage.threadSubscribed = true;
            // Restamp the bells, the threaded header and the list bloc's copy
            // of the thread root, the same way the manual toggle does.
            CometChatMessageEvents.ccThreadSubscriptionChanged(threadId, true);
          })
          .catchError((Object e) {
            // The message is sent; the user can still follow it by hand.
            ccLog('Auto-subscribe to thread $threadId failed: $e');
          }),
    );
  }

  void _playSound() {
    if (!disableSoundForMessages) {
      CometChatUIKit.soundManager.play(
        sound: Sound.outgoingMessage,
        customSound: customSoundForMessage,
        packageName:
            customSoundForMessage == null || customSoundForMessage == ""
            ? UIConstants.packageName
            : customSoundForMessagePackage,
      );
    }
  }

  // ============================================================================
  // SDK Listener Registration
  // ============================================================================

  void _initializeListeners() {
    final dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _messageListenerKey = '${dateString}bloc_message_listener';
    _uiEventListenerKey = '${dateString}bloc_ui_event_listener';
    _userEventListenerKey = '${dateString}bloc_user_event_listener';

    CometChatMessageEvents.addMessagesListener(_messageListenerKey, this);
    CometChatUIEvents.addUiListener(_uiEventListenerKey, this);
    CometChatUserEvents.addUsersListener(_userEventListenerKey, this);
    CometChatStreamCallBackEvents.addStreamCallBackListener(
      _uiEventListenerKey,
      this,
    );
  }

  // ============================================================================
  // Event Handlers
  // ============================================================================

  Future<void> _onInitializeComposer(
    InitializeComposer event,
    Emitter<MessageComposerState> emit,
  ) async {
    final result = await _getLoggedInUserUseCase();
    result.fold(
      (failure) {
        if (kDebugMode) {
          ccLog('Failed to get logged in user: ${failure.message}');
        }
      },
      (user) {
        emit(state.copyWith(loggedInUser: user));
      },
    );
  }

  void _onSetUser(ComposerSetUser event, Emitter<MessageComposerState> emit) {
    final newComposerId = _buildComposerId(event.user, null, parentMessageId);
    emit(
      state.copyWith(
        user: event.user,
        clearGroup: true,
        composeText: '',
        clearEditMessage: true,
        clearReplyMessage: true,
        status: MessageComposerStatus.idle,
        composerId: newComposerId,
      ),
    );
  }

  void _onSetGroup(ComposerSetGroup event, Emitter<MessageComposerState> emit) {
    final newComposerId = _buildComposerId(null, event.group, parentMessageId);
    emit(
      state.copyWith(
        group: event.group,
        clearUser: true,
        composeText: '',
        clearEditMessage: true,
        clearReplyMessage: true,
        status: MessageComposerStatus.idle,
        composerId: newComposerId,
      ),
    );
  }

  void _onUpdateComposeText(
    UpdateComposeText event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(state.copyWith(composeText: event.text));
  }

  void _onClearComposer(
    ClearComposer event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(
      state.copyWith(
        composeText: '',
        clearEditMessage: true,
        clearReplyMessage: true,
        status: MessageComposerStatus.idle,
      ),
    );
  }

  Future<void> _onSendTextMessage(
    SendTextMessage event,
    Emitter<MessageComposerState> emit,
  ) async {
    // Use processed message if provided (from widget with formatter processing)
    // Otherwise create a new message from state.composeText
    TextMessage textMessage;

    if (event.processedMessage != null) {
      textMessage = event.processedMessage!;
      // Merge any additional metadata from event
      if (event.metadata != null) {
        textMessage.metadata = {...?textMessage.metadata, ...event.metadata!};
      }
    } else {
      final text = state.composeText.trim();
      if (text.isEmpty) return;

      Map<String, dynamic>? metadata = event.metadata;

      textMessage = TextMessage(
        sender: state.loggedInUser,
        text: text,
        receiverUid: state.receiverId,
        receiverType: state.receiverType,
        type: MessageTypeConstants.text,
        metadata: metadata,
        parentMessageId: state.parentMessageId,
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        category: CometChatMessageCategory.message,
        sentAt: DateTime.now(),
      );

      // Set quoted message fields if in reply mode
      if (state.isReplyMode && state.replyMessage != null) {
        textMessage.quotedMessage = state.replyMessage;
        if (state.replyMessage!.id > 0) {
          textMessage.quotedMessageId = state.replyMessage!.id;
        }
      }
    }

    // Clear composer state
    ccLog(
      '[ComposerBloc] _onSendTextMessage: emitting sending state, clearReplyMessage=true, current isReplyMode=${state.isReplyMode}, replyMessage=${state.replyMessage}',
    );
    emit(
      state.copyWith(
        status: MessageComposerStatus.sending,
        composeText: '',
        clearReplyMessage: true,
      ),
    );

    // Check if custom send handler is provided
    if (onSendButtonTap != null) {
      onSendButtonTap!(context, textMessage, PreviewMessageMode.none);
      emit(state.copyWith(status: MessageComposerStatus.idle));
      return;
    }

    // Emit in-progress event
    CometChatMessageEvents.ccMessageSent(
      textMessage,
      core_enums.MessageStatus.inProgress,
    );

    final result = await _sendTextMessageUseCase(textMessage);
    result.fold(
      (failure) {
        // Add error to metadata
        if (textMessage.metadata != null) {
          textMessage.metadata!['error'] = failure.message;
        } else {
          textMessage.metadata = {'error': failure.message};
        }
        CometChatMessageEvents.ccMessageSent(
          textMessage,
          core_enums.MessageStatus.error,
        );
        errorCallback?.call(
          CometChatException(
            failure.code ?? 'SEND_ERROR',
            failure.message,
            failure.message,
          ),
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (sentMessage) {
        _playSound();
        // Preserve muid from the original message so the message list bloc
        // can match the sent message to the pending (inProgress) one.
        // The SDK response may not include the muid field.
        if (sentMessage.muid.isEmpty && textMessage.muid.isNotEmpty) {
          sentMessage.muid = textMessage.muid;
        }
        _subscribeSenderToOwnThread(sentMessage);
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.success,
            sentMessage: sentMessage,
          ),
        );
      },
    );
  }

  Future<void> _onSendMediaMessage(
    SendMediaMessage event,
    Emitter<MessageComposerState> emit,
  ) async {
    final muid = DateTime.now().microsecondsSinceEpoch.toString();

    // Use raw filesystem path — file:// prefix breaks MultipartFile.fromFile()
    final filePath = event.path;
    ccLog(
      '[MessageComposerBloc] sendMedia — path: $filePath, type: ${event.messageType}',
    );
    if (!kIsWeb) {
      ccLog(
        '[MessageComposerBloc] sendMedia — file exists: ${platform.fileExistsSync(filePath)}',
      );
    }

    // Web has no `dart:io`, so the SDK's local-file multipart send
    // (`MultipartFile.fromFile`) cannot read a recording's `blob:` path and
    // throws "MultipartFile is only supported where dart:io is available".
    // When the caller hands us the raw bytes (voice notes recorded on web do),
    // upload them straight to storage through the web-safe `UploadFileRequest`
    // and send the hosted attachment as a URL-based media message — no local
    // file, so the send goes out as a plain JSON POST. Every other platform
    // keeps the classic local-file multipart path unchanged.
    final MediaMessage mediaMessage;
    if (kIsWeb && event.fileBytes != null && event.fileBytes!.isNotEmpty) {
      final Attachment attachment;
      try {
        attachment = await _uploadRecordingBytes(event);
      } catch (e) {
        final message = e is CometChatException
            ? (e.message ?? e.details ?? e.code)
            : e.toString();
        errorCallback?.call(
          e is CometChatException
              ? e
              : CometChatException('SEND_ERROR', message, message),
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.error,
            errorMessage: message,
          ),
        );
        return;
      }
      mediaMessage = MediaMessage(
        receiverType: state.receiverType,
        type: event.messageType,
        receiverUid: state.receiverId,
        attachments: [attachment],
        metadata: event.metadata,
        sender: state.loggedInUser,
        parentMessageId: state.parentMessageId,
        muid: muid,
        category: CometChatMessageCategory.message,
        sentAt: DateTime.now(),
      )..attachment = attachment;
    } else {
      mediaMessage = MediaMessage(
        receiverType: state.receiverType,
        type: event.messageType,
        receiverUid: state.receiverId,
        file: filePath,
        metadata: event.metadata,
        sender: state.loggedInUser,
        parentMessageId: state.parentMessageId,
        muid: muid,
        category: CometChatMessageCategory.message,
        sentAt: DateTime.now(),
      );
    }

    // Set quoted message fields if in reply mode
    if (state.isReplyMode && state.replyMessage != null) {
      mediaMessage.quotedMessage = state.replyMessage;
      if (state.replyMessage!.id > 0) {
        mediaMessage.quotedMessageId = state.replyMessage!.id;
      }
    }

    emit(
      state.copyWith(
        status: MessageComposerStatus.sending,
        clearReplyMessage: true,
      ),
    );

    // Emit in-progress event
    CometChatMessageEvents.ccMessageSent(
      mediaMessage,
      core_enums.MessageStatus.inProgress,
    );

    final result = await _sendMediaMessageUseCase(mediaMessage);
    result.fold(
      (failure) {
        if (mediaMessage.metadata != null) {
          mediaMessage.metadata!['error'] = failure.message;
        } else {
          mediaMessage.metadata = {'error': failure.message};
        }
        CometChatMessageEvents.ccMessageSent(
          mediaMessage,
          core_enums.MessageStatus.error,
        );
        errorCallback?.call(
          CometChatException(
            failure.code ?? 'SEND_ERROR',
            failure.message,
            failure.message,
          ),
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (sentMessage) {
        // Preserve original local path on sent message
        sentMessage.file = event.path;
        _playSound();
        // Preserve muid from the original message
        if (sentMessage.muid.isEmpty && mediaMessage.muid.isNotEmpty) {
          sentMessage.muid = mediaMessage.muid;
        }
        // Preserve locally-stamped metadata (localPath, audioType/voiceNote
        // marker) if the server echo omitted any of it — server-provided keys
        // win on conflict.
        if (event.metadata != null) {
          sentMessage.metadata = {...event.metadata!, ...?sentMessage.metadata};
        }
        _subscribeSenderToOwnThread(sentMessage);
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.success,
            sentMessage: sentMessage,
          ),
        );
      },
    );
  }

  /// Uploads a recording's in-memory bytes straight to storage through the
  /// web-safe [UploadFileRequest] and resolves with the hosted [Attachment].
  ///
  /// Used on web, where the classic local-file multipart send cannot run (no
  /// `dart:io`). The returned attachment is sent as a URL-based media message,
  /// so there is no second upload. Throws the SDK's [CometChatException] on a
  /// rejected or failed upload.
  Future<Attachment> _uploadRecordingBytes(SendMediaMessage event) {
    final request = CometChat.createUploadFileRequest(
      state.receiverId,
      state.receiverType,
    );
    final bytes = event.fileBytes!;
    final name = (event.fileName != null && event.fileName!.isNotEmpty)
        ? event.fileName!
        : 'audio.webm';
    // Force an audio MIME type so the stored object's Content-Type is correct:
    // the browser records webm/opus, which would otherwise infer to video/webm.
    final lower = name.toLowerCase();
    final mimeType = lower.endsWith('.m4a') || lower.endsWith('.mp4')
        ? 'audio/mp4'
        : 'audio/webm';
    final completer = Completer<Attachment>();
    request.uploadAttachment(
      'voice_note',
      UploadFile.fromBytes(
        bytes,
        name: name,
        size: bytes.length,
        mimeType: mimeType,
      ),
      _OneShotUploadListener(
        onUploaded: (attachment) {
          if (!completer.isCompleted) completer.complete(attachment);
        },
        onFailed: (error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
      ),
    );
    // Release the batch once the single upload settles — the hosted attachment
    // is already captured and is all the send needs.
    return completer.future.whenComplete(request.clearAll);
  }

  Future<void> _onSendCustomMessage(
    SendCustomMessage event,
    Emitter<MessageComposerState> emit,
  ) async {
    final customMessage = CustomMessage(
      receiverUid: state.receiverId,
      type: event.type,
      customData: event.customData,
      receiverType: state.receiverType,
      sender: state.loggedInUser,
      parentMessageId: state.parentMessageId,
      muid: DateTime.now().microsecondsSinceEpoch.toString(),
      category: CometChatMessageCategory.custom,
      sentAt: DateTime.now(),
    );

    // Set quoted message fields if in reply mode
    if (state.isReplyMode && state.replyMessage != null) {
      customMessage.quotedMessage = state.replyMessage;
      if (state.replyMessage!.id > 0) {
        customMessage.quotedMessageId = state.replyMessage!.id;
      }
    }

    emit(
      state.copyWith(
        status: MessageComposerStatus.sending,
        clearReplyMessage: true,
      ),
    );

    // Emit in-progress event
    CometChatMessageEvents.ccMessageSent(
      customMessage,
      core_enums.MessageStatus.inProgress,
    );

    final result = await _sendCustomMessageUseCase(customMessage);
    result.fold(
      (failure) {
        if (customMessage.metadata != null) {
          customMessage.metadata!['error'] = failure.message;
        } else {
          customMessage.metadata = {'error': failure.message};
        }
        CometChatMessageEvents.ccMessageSent(
          customMessage,
          core_enums.MessageStatus.error,
        );
        errorCallback?.call(
          CometChatException(
            failure.code ?? 'SEND_ERROR',
            failure.message,
            failure.message,
          ),
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (sentMessage) {
        _playSound();
        // Preserve muid from the original message
        if (sentMessage.muid.isEmpty && customMessage.muid.isNotEmpty) {
          sentMessage.muid = customMessage.muid;
        }
        _subscribeSenderToOwnThread(sentMessage);
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.success,
            sentMessage: sentMessage,
          ),
        );
      },
    );
  }

  void _onSetEditMessage(
    SetEditMessage event,
    Emitter<MessageComposerState> emit,
  ) {
    String composeText = '';
    if (event.message is TextMessage) {
      composeText = (event.message as TextMessage).text;
    } else if (event.message is MediaMessage) {
      // Editing text sent alongside attachments: the text lives in the caption.
      composeText = (event.message as MediaMessage).caption ?? '';
    }
    emit(
      state.copyWith(
        status: MessageComposerStatus.editing,
        editMessage: event.message,
        composeText: composeText,
        clearReplyMessage: true,
      ),
    );
  }

  void _onClearEditMessage(
    ClearEditMessage event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(
      state.copyWith(
        status: MessageComposerStatus.idle,
        clearEditMessage: true,
        composeText: '',
      ),
    );
  }

  Future<void> _onEditTextMessage(
    EditTextMessage event,
    Emitter<MessageComposerState> emit,
  ) async {
    final original = state.editMessage;
    if (original == null ||
        (original is! TextMessage && original is! MediaMessage)) {
      return;
    }

    // Use processed message if provided (from widget with formatter processing)
    // Otherwise create a new message from state.composeText. A caption-bearing
    // MediaMessage is edited by changing its caption (the text sent alongside
    // attachments); a plain TextMessage by changing its text.
    BaseMessage editedMessage;

    if (event.processedMessage != null) {
      editedMessage = event.processedMessage!;
    } else if (original is TextMessage) {
      final newText = state.composeText.trim();
      final oldText = original.text.trim();

      // Check if there's any meaningful difference
      if (newText == oldText) return;

      editedMessage = TextMessage(
        id: original.id,
        sender: original.sender,
        text: newText,
        receiverUid: original.receiverUid,
        receiverType: original.receiverType,
        type: original.type,
        metadata: original.metadata,
        parentMessageId: original.parentMessageId,
        muid: original.muid,
        category: original.category,
        sentAt: original.sentAt,
        mentionedUsers: original.mentionedUsers,
      );
    } else {
      final media = original as MediaMessage;
      final oldCaption = (media.caption ?? '').trim();
      final newCaption = state.composeText.trim();

      // Caption edit only applies when the message already has a caption, and
      // the new caption must be a non-empty, meaningful change.
      if (oldCaption.isEmpty ||
          newCaption.isEmpty ||
          newCaption == oldCaption) {
        return;
      }

      editedMessage = cloneMediaWithCaption(media, newCaption);
    }

    emit(
      state.copyWith(
        status: MessageComposerStatus.sending,
        composeText: '',
        clearEditMessage: true,
      ),
    );

    // Check if custom send handler is provided
    if (onSendButtonTap != null) {
      onSendButtonTap!(context, editedMessage, PreviewMessageMode.edit);
      emit(state.copyWith(status: MessageComposerStatus.idle));
      return;
    }

    // Optimistic update: stamp editedAt now (drives the "edited" tag) and push
    // the edit to the list immediately as `success`, so the user sees the new
    // text and the tag without waiting for the server round-trip. The real
    // success branch below reconciles with the authoritative server message;
    // on failure we revert the list back to the original message.
    // (We fire `success`, not `inProgress` — `inProgress` means "populate the
    // composer to edit this message", which would re-enter edit mode here.)
    editedMessage.editedAt = DateTime.now();
    CometChatMessageEvents.ccMessageEdited(
      editedMessage,
      MessageEditStatus.success,
    );

    final result = await _editMessageUseCase(editedMessage);
    result.fold(
      (failure) {
        // Revert the optimistic edit — restore the original message in the list.
        CometChatMessageEvents.ccMessageEdited(
          original,
          MessageEditStatus.success,
        );
        if (editedMessage.metadata != null) {
          editedMessage.metadata!['error'] = failure.message;
        } else {
          editedMessage.metadata = {'error': failure.message};
        }
        CometChatMessageEvents.ccMessageSent(
          editedMessage,
          core_enums.MessageStatus.error,
        );
        errorCallback?.call(
          CometChatException(
            failure.code ?? 'EDIT_ERROR',
            failure.message,
            failure.message,
          ),
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (updatedMessage) {
        _playSound();
        ccLog(
          '[MessageComposerBloc] Edit success, firing ccMessageEdited with message.id=${updatedMessage.id}',
        );
        CometChatMessageEvents.ccMessageEdited(
          updatedMessage,
          MessageEditStatus.success,
        );
        emit(
          state.copyWith(
            status: MessageComposerStatus.success,
            sentMessage: updatedMessage,
          ),
        );
      },
    );
  }

  void _onSetReplyMessage(
    SetReplyMessage event,
    Emitter<MessageComposerState> emit,
  ) {
    ccLog(
      '[ComposerBloc] _onSetReplyMessage: message=${event.message}, current status=${state.status}',
    );
    emit(
      state.copyWith(
        status: MessageComposerStatus.replying,
        replyMessage: event.message,
        clearEditMessage: true,
      ),
    );
  }

  void _onClearReplyMessage(
    ClearReplyMessage event,
    Emitter<MessageComposerState> emit,
  ) {
    ccLog(
      '[ComposerBloc] _onClearReplyMessage: current status=${state.status}, replyMessage=${state.replyMessage}',
    );
    emit(
      state.copyWith(
        status: MessageComposerStatus.idle,
        clearReplyMessage: true,
      ),
    );
  }

  Future<void> _onStartTyping(
    StartTyping event,
    Emitter<MessageComposerState> emit,
  ) async {
    if (disableTypingEvents) return;
    if (!state.userIsNotBlocked) return;

    if (!_isTyping) {
      _isTyping = true;
      _typingNotifier.value = true;
      await _startTypingUseCase(
        receiverUid: state.receiverId,
        receiverType: state.receiverType,
      );
    }

    // Reset debouncer to end typing after delay
    _typingDebouncer.run(() {
      add(const EndTyping());
    });
  }

  Future<void> _onEndTyping(
    EndTyping event,
    Emitter<MessageComposerState> emit,
  ) async {
    if (!_isTyping) return;

    _isTyping = false;
    _typingNotifier.value = false;
    await _endTypingUseCase(
      receiverUid: state.receiverId,
      receiverType: state.receiverType,
    );
  }

  void _onShowPanel(ShowPanel event, Emitter<MessageComposerState> emit) {
    if (!_isForThisWidget(event.id)) return;

    final widget = event.builder(context);
    final position = event.position;

    if (position == CustomUIPosition.composerTop) {
      emit(state.copyWith(headerPanel: widget));
    } else if (position == CustomUIPosition.composerBottom) {
      emit(state.copyWith(footerPanel: widget));
    } else if (position == CustomUIPosition.composerPreview) {
      emit(state.copyWith(previewPanel: widget));
    }
  }

  void _onHidePanel(HidePanel event, Emitter<MessageComposerState> emit) {
    if (!_isForThisWidget(event.id)) return;

    final position = event.position;

    if (position == CustomUIPosition.composerTop) {
      emit(state.copyWith(clearHeaderPanel: true));
    } else if (position == CustomUIPosition.composerBottom) {
      // Clear both footer panel AND locked bottom padding
      // This ensures no extra padding is shown when sticker keyboard is closed
      emit(
        state.copyWith(clearFooterPanel: true, clearLockedBottomPadding: true),
      );
    } else if (position == CustomUIPosition.composerPreview) {
      emit(state.copyWith(clearPreviewPanel: true));
    }
  }

  void _onMessageEditedExternally(
    MessageEditedExternally event,
    Emitter<MessageComposerState> emit,
  ) {
    if (event.message.parentMessageId == state.parentMessageId) {
      emit(
        state.copyWith(
          status: MessageComposerStatus.editing,
          editMessage: event.message,
          composeText: event.message is TextMessage
              ? (event.message as TextMessage).text
              : event.message is MediaMessage
              ? ((event.message as MediaMessage).caption ?? '')
              : '',
        ),
      );
    }
  }

  void _onComposeMessageReceived(
    ComposeMessageReceived event,
    Emitter<MessageComposerState> emit,
  ) {
    if (!_isForThisWidget(event.id)) return;
    emit(state.copyWith(composeText: event.text));
  }

  void _onClearComposeText(
    ClearComposeText event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(state.copyWith(composeText: ''));
  }

  void _onSetStreamingState(
    SetStreamingState event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(state.copyWith(isActiveStreaming: event.isStreaming));
  }

  void _onUserBlockedStatusChanged(
    UserBlockedStatusChanged event,
    Emitter<MessageComposerState> emit,
  ) {
    if (state.user?.uid == event.user.uid) {
      emit(state.copyWith(user: event.user));
    }
  }

  // ============================================================================
  // Audio Recording Event Handlers
  // ============================================================================

  void _onStartAudioRecording(
    StartAudioRecording event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(state.copyWith(status: MessageComposerStatus.recording));
  }

  void _onCancelAudioRecording(
    CancelAudioRecording event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(state.copyWith(status: MessageComposerStatus.idle));
  }

  Future<void> _onSubmitAudioRecording(
    SubmitAudioRecording event,
    Emitter<MessageComposerState> emit,
  ) async {
    // First exit recording mode
    emit(state.copyWith(status: MessageComposerStatus.idle));

    // Determine correct filename based on platform
    // Web records as webm/opus, native records as m4a/AAC
    // Use generic "audio" name to avoid format-specific tags in UI
    const defaultFileName = kIsWeb ? 'audio.webm' : 'audio.m4a';

    // Then send the audio message. The audioType marker distinguishes a
    // recorded voice note (waveform VoiceNoteBubble) from an audio *file*
    // (AudiosBubble player rows) at render time — on both sender and receiver.
    add(
      SendMediaMessage(
        path: event.filePath,
        messageType: MessageTypeConstants.audio,
        metadata: {
          'localPath': event.filePath,
          CometChatVoiceNoteBubble.audioTypeKey:
              CometChatVoiceNoteBubble.audioTypeVoiceNote,
        },
        fileBytes: event.fileBytes,
        fileName: event.fileName ?? defaultFileName,
      ),
    );
  }

  // ============================================================================
  // Bottom Padding Lock Event Handlers (for sticker/emoji keyboard)
  // ============================================================================

  void _onLockBottomPadding(
    LockBottomPadding event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(state.copyWith(lockedBottomPadding: event.height));
  }

  void _onUnlockBottomPadding(
    UnlockBottomPadding event,
    Emitter<MessageComposerState> emit,
  ) {
    emit(state.copyWith(clearLockedBottomPadding: true));
  }

  /// Handle UpdateParentMessageId event.
  ///
  /// Updates the composer's parentMessageId and composerId at runtime.
  /// This is triggered when the MessageList BLoC resolves the thread
  /// parentMessageId for an AI agent conversation after the Composer
  /// was already constructed (with parentMessageId=0).
  void _onUpdateParentMessageId(
    UpdateParentMessageId event,
    Emitter<MessageComposerState> emit,
  ) {
    final newComposerId = _buildComposerId(
      state.user,
      state.group,
      event.parentMessageId,
    );
    emit(
      state.copyWith(
        parentMessageId: event.parentMessageId,
        composerId: newComposerId,
      ),
    );
  }

  // ============================================================================
  // SDK Listener Callbacks
  // ============================================================================

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    // Thread identity alone is not enough: every main-conversation composer
    // shares parentMessageId 0, so an edit raised in one conversation used to
    // load its text into every other mounted composer. Match the conversation
    // too, exactly as ccReplyToMessage does.
    if (status == MessageEditStatus.inProgress &&
        message.parentMessageId == state.parentMessageId &&
        _isForThisConversation(message)) {
      add(MessageEditedExternally(message));
    }
  }

  @override
  void ccReplyToMessage(BaseMessage message) {
    // Also check parentMessageId so thread replies don't leak into the
    // main conversation composer (and vice versa).
    final isForSameThread = message.parentMessageId == state.parentMessageId;

    if (_isForThisConversation(message) && isForSameThread) {
      add(SetReplyMessage(message));
    }
  }

  /// Clears reply state when any message is sent successfully.
  /// This handles the case where an extension (stickers, polls, etc.)
  /// sends a message while the reply preview is showing — the composer
  /// needs to dismiss the preview even though it didn't initiate the send.
  @override
  void ccMessageSent(
    BaseMessage message,
    core_enums.MessageStatus messageStatus,
  ) {
    // Only clear reply if message belongs to current conversation
    if (state.isReplyMode &&
        _isForThisConversation(message) &&
        (messageStatus == core_enums.MessageStatus.inProgress ||
            messageStatus == core_enums.MessageStatus.sent ||
            messageStatus == core_enums.MessageStatus.error)) {
      add(const ClearReplyMessage());
    }
  }

  @override
  void ccComposeMessage(String text, MessageEditStatus status) {
    add(ComposeMessageReceived(text: text));
  }

  // ============================================================
  // Stream Callback Overrides (AI streaming state)
  // ============================================================

  @override
  void ccStreamInProgress(bool isInProgress) {
    add(const SetStreamingState(isStreaming: true));
  }

  @override
  void ccStreamCompleted(bool isCompleted) {
    if (isCompleted) {
      add(const SetStreamingState(isStreaming: false));
    }
  }

  @override
  void ccStreamInterrupted(bool isInterrupted) {
    if (isInterrupted) {
      add(const SetStreamingState(isStreaming: false));
    }
  }

  @override
  void showPanel(
    Map<String, dynamic>? id,
    CustomUIPosition uiPosition,
    WidgetBuilder child,
  ) {
    add(ShowPanel(id: id, position: uiPosition, builder: child));
  }

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) {
    add(HidePanel(id: id, position: uiPosition));
  }

  @override
  void lockBottomPadding(Map<String, dynamic>? id, double height) {
    if (!_isForThisWidget(id)) return;
    add(LockBottomPadding(height));
  }

  @override
  void unlockBottomPadding(Map<String, dynamic>? id) {
    if (!_isForThisWidget(id)) return;
    add(const UnlockBottomPadding());
  }

  @override
  void requestComposerFocus(Map<String, dynamic>? id) {
    if (!_isForThisWidget(id)) return;
    onFocusRequested?.call();
  }

  @override
  void ccAgentChatThreadResolved({
    required String receiverId,
    required int parentMessageId,
  }) {
    // Only handle if this composer is for the same agent (receiverId match)
    // and it's an AI/agent chat (user-based, not group)
    if (state.user == null) return;
    if (state.user!.uid != receiverId) return;
    add(UpdateParentMessageId(parentMessageId));
  }

  @override
  void ccUserBlocked(User user) {
    add(UserBlockedStatusChanged(user: user, isBlocked: true));
  }

  @override
  void ccUserUnblocked(User user) {
    add(UserBlockedStatusChanged(user: user, isBlocked: false));
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  @override
  Future<void> close() {
    // Remove SDK listeners
    CometChatMessageEvents.removeMessagesListener(_messageListenerKey);
    CometChatUIEvents.removeUiListener(_uiEventListenerKey);
    CometChatUserEvents.removeUsersListener(_userEventListenerKey);
    CometChatStreamCallBackEvents.removeStreamCallBackListener(
      _uiEventListenerKey,
    );

    // Dispose typing notifier
    _typingNotifier.dispose();

    return super.close();
  }
}

/// One-shot [UploadFileListener] that completes a future on the first terminal
/// event of a single upload: success delivers the hosted [Attachment], while
/// both a rejection (`onFileError`, not retryable) and a transfer failure
/// (`onFileFailure`, retryable) surface as an error. Used by
/// [MessageComposerBloc] to upload a web voice note before sending it.
class _OneShotUploadListener extends UploadFileListener {
  _OneShotUploadListener({required this.onUploaded, required this.onFailed});

  final void Function(Attachment attachment) onUploaded;
  final void Function(CometChatException error) onFailed;

  @override
  void onFileUploaded(String fileId, Attachment attachment) =>
      onUploaded(attachment);

  @override
  void onFileError(String fileId, CometChatException error) => onFailed(error);

  @override
  void onFileFailure(String fileId, CometChatException error) =>
      onFailed(error);
}
