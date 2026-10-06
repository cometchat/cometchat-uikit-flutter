/// CometChatStreamService — the AI streaming queue/buffer/reconnect machine.
///
/// The service is a singleton with no SDK dependency of its own: it only holds
/// SDK *model* objects, so the whole state machine runs in a VM test. Because
/// it is a singleton, every test here resets it through `onConnected()` (which
/// restores the connected flag and calls `cleanupAll`) and uses its own run
/// ids, and any controller it opens is closed in a tearDown.
///
///   flutter test test/shared_ui/services/cometchat_stream_service_test.dart
library;

import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show Translations;
import 'package:cometchat_chat_uikit/shared_ui/src/models/ai/stream_message.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/services/cometchat_stream_callback.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/services/cometchat_stream_service.dart';

AIAssistantBaseEvent _event(int id, [String type = 'text_message_content']) =>
    AIAssistantBaseEvent(id: id, type: type);

AIAssistantMessage _aiMessage(int id) => AIAssistantMessage(
  id: id,
  text: 'assistant $id',
  receiverUid: 'agent',
  receiverType: 'user',
  type: 'text',
);

AIToolResultMessage _toolResult(int id) => AIToolResultMessage(
  id: id,
  text: 'result $id',
  receiverUid: 'agent',
  receiverType: 'user',
  type: 'tool_result',
);

AIToolArgumentMessage _toolArgument(int id) => AIToolArgumentMessage(
  id: id,
  receiverUid: 'agent',
  receiverType: 'user',
  type: 'tool_args',
);

StreamMessage _streamMessage(int id) => StreamMessage(
  id: id,
  text: 'stream $id',
  receiverUid: 'agent',
  receiverType: 'user',
);

/// Records what the service hands back when a run's queue drains.
class _RecordingCompletion implements QueueCompletionCallback {
  final calls =
      <(AIAssistantMessage?, AIToolResultMessage?, AIToolArgumentMessage?)>[];

  @override
  void onQueueCompleted(
    AIAssistantMessage? aiAssistantMessage,
    AIToolResultMessage? aiToolResultMessage,
    AIToolArgumentMessage? aiToolArgumentMessage,
  ) {
    calls.add((aiAssistantMessage, aiToolResultMessage, aiToolArgumentMessage));
  }
}

class _RecordingStreamListener with CometChatStreamCallbackListener {
  final completed = <bool>[];
  final interrupted = <bool>[];
  final inProgress = <bool>[];

  @override
  void ccStreamCompleted(bool isCompleted) => completed.add(isCompleted);

  @override
  void ccStreamInterrupted(bool isInterrupted) =>
      interrupted.add(isInterrupted);

  @override
  void ccStreamInProgress(bool value) => inProgress.add(value);
}

void main() {
  late CometChatStreamService service;
  final openedRuns = <int>{};

  setUp(() {
    service = CometChatStreamService();
    // Restores isConnected, clears disconnectedRunIds, and cleans every map.
    service.onConnected();
    service.streamDelay = Duration.zero;
    service.maxConcurrentQueues = 10;
    openedRuns.clear();
  });

  tearDown(() {
    for (final runId in openedRuns) {
      service.stopStreamingForRunId(runId);
    }
    service.onConnected();
  });

  /// Opens a stream and remembers the run so tearDown closes its controller.
  Stream<AIAssistantBaseEvent> open(
    int runId, {
    void Function(AIAssistantBaseEvent)? onEvent,
    void Function(CometChatException)? onError,
  }) {
    openedRuns.add(runId);
    return service.startStreamingForRunId(
      runId,
      onAiAssistantEvent: onEvent,
      onError: onError,
    );
  }

  test('the factory hands back the one shared instance', () {
    expect(CometChatStreamService(), same(service));
  });

  group('queue admission', () {
    test('the first event for a run creates its queue', () {
      expect(service.runExists(1), isFalse);
      expect(service.isQueueEmpty(1), isTrue, reason: 'no queue reads empty');
      expect(service.hasEvents(1), isFalse);

      service.handleIncomingEvent(1, _event(10));

      expect(service.runExists(1), isTrue);
      expect(service.isRunActive(1), isTrue);
      expect(service.hasEvents(1), isTrue);
      expect(service.isQueueEmpty(1), isFalse);
      expect(service.getCurrentQueueCount(), 1);
      expect(service.getAllRunIds(), {1});
    });

    test('maxConcurrentQueues clamps to 1..10', () {
      service.maxConcurrentQueues = 0;
      expect(service.maxConcurrentQueues, 1);
      service.maxConcurrentQueues = 99;
      expect(service.maxConcurrentQueues, 10);
      service.maxConcurrentQueues = 4;
      expect(service.maxConcurrentQueues, 4);
    });

    test('a full queue table drops new runs but still accepts known ones', () {
      service.maxConcurrentQueues = 2;

      service.handleIncomingEvent(1, _event(1));
      service.handleIncomingEvent(2, _event(2));
      expect(service.isQueueFull(), isTrue);

      // Run 3 is new and there is no room — silently dropped.
      service.handleIncomingEvent(3, _event(3));
      expect(service.runExists(3), isFalse);
      expect(service.getCurrentQueueCount(), 2);

      // An existing run keeps accepting.
      service.handleIncomingEvent(1, _event(4));
      expect(service.getAllRunIds(), {1, 2});
    });
  });

  group('startStreamingForRunId', () {
    test('drains the backlog to the callback and keeps streaming', () async {
      final seen = <int?>[];
      service.handleIncomingEvent(7, _event(1));
      service.handleIncomingEvent(7, _event(2));

      final stream = open(7, onEvent: (e) => seen.add(e.id));
      final fromStream = <int?>[];
      final sub = stream.listen((e) => fromStream.add(e.id));
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(seen, [1, 2], reason: 'the backlog reaches the callback');
      expect(service.isQueueEmpty(7), isTrue);

      // Events arriving after a listener exists also reach the stream.
      service.handleIncomingEvent(7, _event(3));
      await pumpEventQueue();
      expect(seen, [1, 2, 3]);
      expect(fromStream, contains(3));
    });

    test('a second call for the same run reuses the one controller', () async {
      final first = open(8);
      final second = service.startStreamingForRunId(8);
      expect(identical(first, second), isFalse, reason: 'broadcast views');

      var firstCount = 0;
      var secondCount = 0;
      final s1 = first.listen((_) => firstCount++);
      final s2 = second.listen((_) => secondCount++);
      addTearDown(s1.cancel);
      addTearDown(s2.cancel);

      service.handleIncomingEvent(8, _event(1));
      await pumpEventQueue();

      // One controller behind both views: every listener sees the event.
      expect(firstCount, 1);
      expect(secondCount, 1);
    });

    test('a throwing consumer stops the drain and reports the error', () async {
      service.handleIncomingEvent(9, _event(1));
      service.handleIncomingEvent(9, _event(2));

      final seen = <int?>[];
      final errors = <CometChatException>[];
      final stream = open(
        9,
        onEvent: (e) {
          seen.add(e.id);
          throw StateError('consumer blew up');
        },
        onError: errors.add,
      );
      final streamErrors = <Object>[];
      final sub = stream.listen((_) {}, onError: streamErrors.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();

      expect(seen, [1], reason: 'the loop breaks on the first throw');
      expect(errors, hasLength(1));
      expect(errors.single.code, 'Error');
      expect(errors.single.details, contains('consumer blew up'));
      // The second event is still queued — the drain stopped, not the queue.
      expect(service.hasEvents(9), isTrue);
    });

    test(
      'a CometChatException from the consumer is passed through as-is',
      () async {
        final thrown = CometChatException('SDK_CODE', 'sdk details', 'sdk msg');
        service.handleIncomingEvent(11, _event(1));

        final errors = <CometChatException>[];
        open(11, onEvent: (_) => throw thrown, onError: errors.add);
        await pumpEventQueue();

        expect(errors.single, same(thrown));
      },
    );
  });

  group('delta buffers', () {
    test('getOrCreateBuffer is idempotent and accumulates', () {
      final buffer = service.getOrCreateBuffer(20);
      expect(service.getOrCreateBuffer(20), same(buffer));

      buffer.write('Hel');
      buffer.write('lo');
      expect(service.getBufferContent(20), 'Hello');

      service.clearBuffer(20);
      expect(service.getBufferContent(20), isEmpty);

      service.removeBuffer(20);
      expect(service.getBufferContent(20), isNull);
    });

    test('clearing or removing an unknown run is harmless', () {
      expect(() => service.clearBuffer(999), returnsNormally);
      expect(() => service.removeBuffer(999), returnsNormally);
      expect(service.getBufferContent(999), isNull);
    });
  });

  test('run id ↔ message id mapping round-trips and can be removed', () {
    expect(service.getMessageIdForRun(30), isNull);
    service.setMessageIdForRun(30, 555);
    expect(service.getMessageIdForRun(30), 555);
    service.removeMessageIdMapping(30);
    expect(service.getMessageIdForRun(30), isNull);
  });

  test('the message map registers, looks up, updates and removes', () {
    final message = _streamMessage(40);
    expect(service.checkMessageExists(40), isFalse);

    service.registerMessage(message);
    expect(service.checkMessageExists(40), isTrue);
    expect(service.getMessageById(40), same(message));

    final replacement = _streamMessage(40);
    service.updateMessage(replacement);
    expect(service.getMessageById(40), same(replacement));

    service.removeMessageById(40);
    expect(service.getMessageById(40), isNull);
    expect(service.checkMessageExists(40), isFalse);
  });

  group('queue completion', () {
    test(
      'queueCompletionCallback removes the queue and returns the message',
      () {
        service.handleIncomingEvent(50, _event(1));
        final message = _aiMessage(50);
        service.aiAssistantMessages[50] = message;

        expect(service.queueCompletionCallback(50), same(message));
        expect(service.runExists(50), isFalse);
        expect(service.aiAssistantMessages.containsKey(50), isFalse);
        // A second call has nothing left to return.
        expect(service.queueCompletionCallback(50), isNull);
      },
    );

    test(
      'registering a callback on an empty queue fires all three kinds',
      () async {
        final callback = _RecordingCompletion();
        service.aiAssistantMessages[51] = _aiMessage(51);
        service.aiToolResultMessages[51] = _toolResult(51);
        service.aiToolArgumentMessages[51] = _toolArgument(51);

        service.setQueueCompletionCallback(51, callback);
        await pumpEventQueue();

        expect(callback.calls, hasLength(3));
        // Each kind is delivered on its own call, in its own slot.
        expect(callback.calls[0].$1, isA<AIAssistantMessage>());
        expect(callback.calls[0].$2, isNull);
        expect(callback.calls[1].$2, isA<AIToolResultMessage>());
        expect(callback.calls[1].$1, isNull);
        expect(callback.calls[2].$3, isA<AIToolArgumentMessage>());
        // Every message is consumed, so a re-check delivers nothing more.
        service.checkAndTriggerQueueCompletion(51);
        await pumpEventQueue();
        expect(callback.calls, hasLength(3));
      },
    );

    test('a non-empty queue defers completion', () async {
      final callback = _RecordingCompletion();
      service.handleIncomingEvent(52, _event(1));
      service.aiAssistantMessages[52] = _aiMessage(52);

      service.setQueueCompletionCallback(52, callback);
      await pumpEventQueue();

      expect(callback.calls, isEmpty, reason: 'events are still pending');
      expect(service.aiAssistantMessages.containsKey(52), isTrue);
    });

    test('completion with no registered callback is a no-op', () async {
      service.aiAssistantMessages[53] = _aiMessage(53);
      service.checkAndTriggerQueueCompletion(53);
      await pumpEventQueue();
      // Without a callback the message is left in place for a later reader.
      expect(service.aiAssistantMessages.containsKey(53), isTrue);
    });

    test('an assistant completion announces ccStreamCompleted', () async {
      final listener = _RecordingStreamListener();
      CometChatStreamCallBackEvents.addStreamCallBackListener(
        'stream_service_test',
        listener,
      );
      addTearDown(
        () => CometChatStreamCallBackEvents.removeStreamCallBackListener(
          'stream_service_test',
        ),
      );

      service.aiAssistantMessages[54] = _aiMessage(54);
      service.setQueueCompletionCallback(54, _RecordingCompletion());
      await pumpEventQueue();

      expect(listener.completed, [true]);
      expect(listener.interrupted, isEmpty);
    });
  });

  group('cleanup', () {
    test(
      'stopStreamingForRunId closes the controller and clears the run',
      () async {
        service.handleIncomingEvent(60, _event(1));
        service.getOrCreateBuffer(60).write('partial');
        service.setMessageIdForRun(60, 600);
        service.aiAssistantMessages[60] = _aiMessage(60);
        service.aiToolResultMessages[60] = _toolResult(60);
        service.aiToolArgumentMessages[60] = _toolArgument(60);
        service.queueCompletionCallbacks[60] = _RecordingCompletion();

        var closed = false;
        final sub = open(60).listen((_) {}, onDone: () => closed = true);
        addTearDown(sub.cancel);

        service.stopStreamingForRunId(60);
        await pumpEventQueue();

        expect(closed, isTrue, reason: 'listeners are told the run ended');
        expect(service.runExists(60), isFalse);
        expect(service.getBufferContent(60), isNull);
        expect(service.getMessageIdForRun(60), isNull);
        expect(service.aiAssistantMessages.containsKey(60), isFalse);
        expect(service.aiToolResultMessages.containsKey(60), isFalse);
        expect(service.aiToolArgumentMessages.containsKey(60), isFalse);
        expect(service.queueCompletionCallbacks.containsKey(60), isFalse);

        // Stopping twice must not throw on the already-closed controller.
        expect(() => service.stopStreamingForRunId(60), returnsNormally);
      },
    );

    test('cleanupAll empties every map', () {
      service.handleIncomingEvent(70, _event(1));
      service.getOrCreateBuffer(70).write('x');
      service.setMessageIdForRun(70, 700);
      service.registerMessage(_streamMessage(70));
      service.aiAssistantMessages[70] = _aiMessage(70);
      service.aiToolResultMessages[70] = _toolResult(70);
      service.aiToolArgumentMessages[70] = _toolArgument(70);
      service.queueCompletionCallbacks[70] = _RecordingCompletion();

      service.cleanupAll();

      expect(service.getCurrentQueueCount(), 0);
      expect(service.getBufferContent(70), isNull);
      expect(service.getMessageIdForRun(70), isNull);
      expect(service.getMessageById(70), isNull);
      expect(service.aiAssistantMessages, isEmpty);
      expect(service.aiToolResultMessages, isEmpty);
      expect(service.aiToolArgumentMessages, isEmpty);
      expect(service.queueCompletionCallbacks, isEmpty);
    });
  });

  test('addSmallDelay yields for at least its 50ms', () async {
    final watch = Stopwatch()..start();
    await service.addSmallDelay();
    watch.stop();
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(40));
  });

  group('connection loss', () {
    /// Runs [body] with a BuildContext that can resolve Translations.
    Future<void> withContext(
      WidgetTester tester,
      void Function(BuildContext context) body,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      body(captured);
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets('onDisconnected errors every open run and stops them', (
      tester,
    ) async {
      service.onConnected();
      service.streamDelay = Duration.zero;

      final listener = _RecordingStreamListener();
      CometChatStreamCallBackEvents.addStreamCallBackListener(
        'stream_service_disconnect',
        listener,
      );
      addTearDown(
        () => CometChatStreamCallBackEvents.removeStreamCallBackListener(
          'stream_service_disconnect',
        ),
      );

      service.handleIncomingEvent(80, _event(1));
      final errors = <CometChatException>[];
      final streamErrors = <Object>[];
      final sub = open(
        80,
        onError: errors.add,
      ).listen((_) {}, onError: streamErrors.add);
      addTearDown(sub.cancel);
      // Flush the drain's `Future.delayed(streamDelay)` before asserting.
      await tester.pump(const Duration(milliseconds: 1));

      await withContext(tester, service.onDisconnected);

      expect(service.isConnected, isFalse);
      expect(service.disconnectedRunIds, contains(80));
      expect(errors.single.code, 'Disconnected');
      expect(errors.single.details, contains('connection was lost'));
      expect(errors.single.message, isNotEmpty, reason: 'localized message');
      expect(streamErrors, hasLength(1));
      expect(listener.interrupted, [true]);
      // The run's queue is torn down with it.
      expect(service.runExists(80), isFalse);

      // While disconnected, new events for that run are refused.
      service.handleIncomingEvent(80, _event(2));
      expect(service.runExists(80), isFalse);

      // A second disconnect is a no-op.
      await withContext(tester, service.onDisconnected);
      expect(listener.interrupted, [true]);
    });

    testWidgets('while disconnected no run may open a queue', (tester) async {
      await withContext(tester, service.onDisconnected);
      expect(service.isConnected, isFalse);

      service.handleIncomingEvent(81, _event(1));
      expect(service.runExists(81), isFalse);
    });

    testWidgets('onConnectionError carries the SDK code and details', (
      tester,
    ) async {
      service.onConnected();
      service.streamDelay = Duration.zero;

      service.handleIncomingEvent(82, _event(1));
      final errors = <CometChatException>[];
      final sub = open(82, onError: errors.add).listen((_) {}, onError: (_) {});
      addTearDown(sub.cancel);
      await tester.pump(const Duration(milliseconds: 1));

      await withContext(
        tester,
        (context) => service.onConnectionError(
          CometChatException('NETWORK_DOWN', 'socket closed', 'Network error'),
          context,
        ),
      );

      expect(service.isConnected, isFalse);
      expect(errors.single.code, 'NETWORK_DOWN');
      expect(errors.single.details, 'socket closed');
      expect(errors.single.message, 'Network error');
      expect(service.runExists(82), isFalse);
    });

    testWidgets(
      'onConnectionError falls back when details and message are null',
      (tester) async {
        service.onConnected();
        service.streamDelay = Duration.zero;

        service.handleIncomingEvent(83, _event(1));
        final errors = <CometChatException>[];
        final sub = open(
          83,
          onError: errors.add,
        ).listen((_) {}, onError: (_) {});
        addTearDown(sub.cancel);
        await tester.pump(const Duration(milliseconds: 1));

        await withContext(
          tester,
          (context) => service.onConnectionError(
            CometChatException('E', null, null),
            context,
          ),
        );

        expect(
          errors.single.details,
          'ConnectionError. Connection error occurred',
        );
        expect(errors.single.message, isNotEmpty);
      },
    );

    testWidgets('onConnected clears the disconnect bookkeeping', (
      tester,
    ) async {
      service.handleIncomingEvent(84, _event(1));
      await withContext(tester, service.onDisconnected);
      expect(service.disconnectedRunIds, isNotEmpty);

      service.onConnected();

      expect(service.isConnected, isTrue);
      expect(service.disconnectedRunIds, isEmpty);
      expect(service.getCurrentQueueCount(), 0);
      // Streaming works again afterwards.
      service.handleIncomingEvent(84, _event(2));
      expect(service.runExists(84), isTrue);
    });
  });
}
