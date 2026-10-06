import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../models/ai/stream_message.dart';
import 'cometchat_stream_callback.dart';
import '../../cometchat_uikit_shared.dart' as cc;
import '../logging/cometchat_log.dart';

/// Manages real-time AI response streaming with event queues, delta buffers,
/// and reconnect handling.
class CometChatStreamService {
  // Singleton
  static final CometChatStreamService _instance =
      CometChatStreamService._internal();
  factory CometChatStreamService() => _instance;
  CometChatStreamService._internal();

  // Core Data Structures
  final Map<int, Queue<AIAssistantBaseEvent>> _eventQueues = {};
  final Map<int, StringBuffer> _deltaBuffers = {};
  final Map<int, int> _runIdToMessageIdMap = {};
  final LinkedHashMap<int, StreamMessage> _messageMap = LinkedHashMap();
  final Map<int, AIAssistantMessage> aiAssistantMessages = {};
  final Map<int, AIToolResultMessage> aiToolResultMessages = {};
  final Map<int, AIToolArgumentMessage> aiToolArgumentMessages = {};
  final Map<int, QueueCompletionCallback> queueCompletionCallbacks = {};
  final Map<int, StreamController<AIAssistantBaseEvent>> _controllers = {};
  final Map<int, Function(CometChatException)> _onErrorCallbacks = {};

  bool _isConnected = true;
  final Set<int> _disconnectedRunIds = {};

  bool get isConnected => _isConnected;
  Set<int> get disconnectedRunIds => _disconnectedRunIds;

  // Config
  int _maxConcurrentQueues = 10;
  Duration streamDelay = const Duration(milliseconds: 30);

  int get maxConcurrentQueues => _maxConcurrentQueues;
  set maxConcurrentQueues(int value) =>
      _maxConcurrentQueues = value.clamp(1, 10);

  int getCurrentQueueCount() => _eventQueues.length;
  bool isQueueEmpty(int runId) => _eventQueues[runId]?.isEmpty ?? true;

  final Map<int, Function(AIAssistantBaseEvent)?> _callbacks = {};

  // Queue Management
  void handleIncomingEvent(int runId, AIAssistantBaseEvent event) {
    if (!_isConnected || _disconnectedRunIds.contains(runId)) {
      ccLog('[AI Stream] Ignoring event for disconnected runId: $runId');
      return;
    }

    if (_eventQueues.containsKey(runId)) {
      _eventQueues[runId]?.add(event);
    } else if (_eventQueues.length < maxConcurrentQueues) {
      _eventQueues[runId] = Queue<AIAssistantBaseEvent>();
      _eventQueues[runId]?.add(event);
    }

    if (_controllers.containsKey(runId)) {
      _emitNext(runId, onAiAssistantEvent: _callbacks[runId]);
    }
  }

  void _emitNext(
    int runId, {
    Function(AIAssistantBaseEvent event)? onAiAssistantEvent,
    Function(CometChatException excep)? onError,
  }) async {
    final queue = _eventQueues[runId];
    final controller = _controllers[runId];
    if (queue == null || controller == null || queue.isEmpty) return;

    while (queue.isNotEmpty) {
      final event = queue.removeFirst();
      try {
        onAiAssistantEvent?.call(event);
        controller.add(event);
        await Future.delayed(streamDelay);
      } catch (e) {
        final ex = e is CometChatException
            ? e
            : CometChatException('Error', e.toString(), '');
        onError?.call(ex);
        controller.addError(ex);
        break;
      }
    }
  }

  Stream<AIAssistantBaseEvent> startStreamingForRunId(
    int runId, {
    Function(AIAssistantBaseEvent event)? onAiAssistantEvent,
    Function(CometChatException excep)? onError,
  }) {
    if (_controllers.containsKey(runId)) {
      return _controllers[runId]!.stream;
    }

    final controller = StreamController<AIAssistantBaseEvent>.broadcast();
    _controllers[runId] = controller;
    _callbacks[runId] = onAiAssistantEvent;
    _onErrorCallbacks[runId] = onError ?? (_) {};
    _emitNext(runId, onAiAssistantEvent: onAiAssistantEvent, onError: onError);

    return controller.stream;
  }

  bool hasEvents(int runId) => _eventQueues[runId]?.isNotEmpty ?? false;
  bool runExists(int runId) => _eventQueues.containsKey(runId);

  // Buffer Management
  StringBuffer getOrCreateBuffer(int runId) =>
      _deltaBuffers.putIfAbsent(runId, () => StringBuffer());

  void clearBuffer(int runId) => _deltaBuffers[runId]?.clear();
  String? getBufferContent(int runId) => _deltaBuffers[runId]?.toString();
  void removeBuffer(int runId) => _deltaBuffers.remove(runId);

  AIAssistantMessage? queueCompletionCallback(int runId) {
    _eventQueues.remove(runId);
    return aiAssistantMessages.remove(runId);
  }

  void setQueueCompletionCallback(int runId, QueueCompletionCallback callback) {
    queueCompletionCallbacks[runId] = callback;
    checkAndTriggerQueueCompletion(runId);
  }

  // Message ID & O(1) Lookup
  void setMessageIdForRun(int runId, int messageId) =>
      _runIdToMessageIdMap[runId] = messageId;
  int? getMessageIdForRun(int runId) => _runIdToMessageIdMap[runId];
  void removeMessageIdMapping(int runId) => _runIdToMessageIdMap.remove(runId);

  void registerMessage(StreamMessage message) =>
      _messageMap[message.id] = message;
  StreamMessage? getMessageById(int messageId) => _messageMap[messageId];
  bool checkMessageExists(int messageId) => _messageMap.containsKey(messageId);
  void removeMessageById(int messageId) => _messageMap.remove(messageId);
  void updateMessage(StreamMessage message) =>
      _messageMap[message.id] = message;

  // Run/Queue Helpers
  bool isQueueFull() => getCurrentQueueCount() >= _maxConcurrentQueues;
  bool isRunActive(int runId) => _eventQueues.containsKey(runId);

  // Cleanup
  void stopStreamingForRunId(int runId) {
    _deltaBuffers.remove(runId);
    _runIdToMessageIdMap.remove(runId);
    _eventQueues.remove(runId);
    aiAssistantMessages.remove(runId);
    aiToolResultMessages.remove(runId);
    aiToolArgumentMessages.remove(runId);
    queueCompletionCallbacks.remove(runId);

    // Close the stream controller to prevent memory leaks
    final controller = _controllers.remove(runId);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    _callbacks.remove(runId);
    _onErrorCallbacks.remove(runId);
  }

  void cleanupAll() {
    _deltaBuffers.clear();
    _runIdToMessageIdMap.clear();
    _eventQueues.clear();
    _messageMap.clear();
    aiAssistantMessages.clear();
    aiToolResultMessages.clear();
    aiToolArgumentMessages.clear();
    queueCompletionCallbacks.clear();
  }

  void checkAndTriggerQueueCompletion(int runId) {
    final queue = _eventQueues[runId];
    if (queue == null || queue.isEmpty) {
      final callback = queueCompletionCallbacks[runId];
      if (callback != null) {
        final aiMsg = aiAssistantMessages[runId];
        final toolResult = aiToolResultMessages[runId];
        final toolArg = aiToolArgumentMessages[runId];

        if (aiMsg != null) {
          aiAssistantMessages.remove(runId);
          Future.microtask(() => callback.onQueueCompleted(aiMsg, null, null));
          CometChatStreamCallBackEvents.ccStreamCompleted(true);
        }
        if (toolResult != null) {
          aiToolResultMessages.remove(runId);
          Future.microtask(
            () => callback.onQueueCompleted(null, toolResult, null),
          );
        }
        if (toolArg != null) {
          aiToolArgumentMessages.remove(runId);
          Future.microtask(
            () => callback.onQueueCompleted(null, null, toolArg),
          );
        }
      }
    }
  }

  void onConnected() {
    _isConnected = true;
    _disconnectedRunIds.clear();
    cleanupAll();
    ccLog('[AI Stream] Connected');
    CometChatStreamCallBackEvents.ccStreamCompleted(true);
  }

  void onDisconnected(BuildContext context) {
    if (!_isConnected) return;
    _isConnected = false;
    _disconnectedRunIds.addAll(_eventQueues.keys);

    final error = CometChatException(
      'Disconnected',
      'Disconnected. The connection was lost while streaming events.',
      cc.Translations.of(context).somethingWentWrongTryAgain,
    );

    for (final runId in _disconnectedRunIds.toList()) {
      final controller = _controllers[runId];
      if (controller != null && !controller.isClosed) {
        _onErrorCallbacks[runId]?.call(error);
        controller.addError(error);
        controller.close();
      }
      _controllers.remove(runId);
      _onErrorCallbacks.remove(runId);
    }

    _stopAllActiveRuns();
    ccLog('[AI Stream] Disconnected');
    CometChatStreamCallBackEvents.ccStreamInterrupted(true);
  }

  void onConnectionError(CometChatException e, BuildContext context) {
    if (!_isConnected) return;
    _isConnected = false;
    _disconnectedRunIds.addAll(_eventQueues.keys);

    final error = CometChatException(
      e.code,
      e.details ?? 'ConnectionError. Connection error occurred',
      e.message ?? cc.Translations.of(context).somethingWentWrongTryAgain,
    );

    for (final runId in _disconnectedRunIds.toList()) {
      final controller = _controllers[runId];
      if (controller != null && !controller.isClosed) {
        _onErrorCallbacks[runId]?.call(error);
        controller.addError(error);
        controller.close();
      }
      _controllers.remove(runId);
      _onErrorCallbacks.remove(runId);
    }

    _stopAllActiveRuns();
    ccLog('[AI Stream] Connection error: ${e.message}');
    CometChatStreamCallBackEvents.ccStreamInterrupted(true);
  }

  void _stopAllActiveRuns() {
    for (final runId in _eventQueues.keys.toList()) {
      stopStreamingForRunId(runId);
    }
  }

  // Utility
  Set<int> getAllRunIds() => {..._eventQueues.keys};

  Future<void> addSmallDelay() async =>
      await Future.delayed(const Duration(milliseconds: 50));
}

abstract class QueueCompletionCallback {
  void onQueueCompleted(
    AIAssistantMessage? aiAssistantMessage,
    AIToolResultMessage? aiToolResultMessage,
    AIToolArgumentMessage? aiToolArgumentMessage,
  );
}
