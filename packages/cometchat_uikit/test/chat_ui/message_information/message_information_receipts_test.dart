/// The receipt half of [MessageInformationBloc] — initialization from a parent
/// message, and the realtime read/delivered merge.
///
/// `message_information_bloc_test.dart` covers the fetch path; this file covers
/// what surrounds it: which conversation shape [InitializeMessageInformation]
/// produces, the "is this receipt even for my message?" guard, and the merge
/// rules in `_updateReceiptList` (update in place for 1-on-1, match by sender
/// uid for groups, back-fill `deliveredAt` from `readAt` when a read receipt
/// arrives first).
///
/// The SDK listeners it registers are plain UI-event maps
/// ([CometChatMessageEvents]), so the realtime path is driven end to end by
/// firing those events.
///
///   flutter test test/chat_ui/message_information/message_information_receipts_test.dart
library;

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_information/bloc/message_information_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_information/bloc/message_information_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_information/bloc/message_information_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_information/di/message_information_service_locator.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_information/domain/repositories/message_information_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_information/domain/usecases/fetch_message_receipts_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/domain/events/message_events/cometchat_message_events.dart';

class MockRepo extends Mock implements MessageInformationRepository {}

class FakeUser extends Fake implements User {
  FakeUser([this._uid = 'u1']);
  final String _uid;
  @override
  String get uid => _uid;
  @override
  String get name => 'User $_uid';
}

class FakeGroup extends Fake implements Group {
  FakeGroup([this._guid = 'g1']);
  final String _guid;
  @override
  String get guid => _guid;
  @override
  String get name => 'Group $_guid';
}

class FakeMessage extends Fake implements BaseMessage {
  FakeMessage({
    required AppEntity receiver,
    User? sender,
    this.deliveredAt,
    this.readAt,
  }) : _receiver = receiver,
       _sender = sender ?? FakeUser('sender');

  final AppEntity _receiver;
  final User _sender;
  @override
  final DateTime? deliveredAt;
  @override
  final DateTime? readAt;

  @override
  int get id => 42;
  @override
  AppEntity? get receiver => _receiver;
  @override
  User? get sender => _sender;
  @override
  String get receiverType => _receiver is Group
      ? ReceiverTypeConstants.group
      : ReceiverTypeConstants.user;
  @override
  String get receiverUid {
    final target = _receiver;
    return target is Group ? target.guid : (target as User).uid;
  }

  @override
  DateTime? get sentAt => DateTime.utc(2026, 1, 1);
}

final _t0 = DateTime.utc(2026, 1, 1, 10);
final _t1 = DateTime.utc(2026, 1, 1, 11);
final _t2 = DateTime.utc(2026, 1, 1, 12);

MessageReceipt receipt({
  String uid = 'u1',
  String receiverType = ReceiverTypeConstants.user,
  String receiverId = 'u1',
  DateTime? deliveredAt,
  DateTime? readAt,
}) {
  return MessageReceipt(
    messageId: 42,
    sender: FakeUser(uid),
    receiverType: receiverType,
    receiverId: receiverId,
    timestamp: _t0,
    receiptType: '',
    deliveredAt: deliveredAt,
    readAt: readAt,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeMessage(receiver: FakeUser()));
  });

  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
    when(
      () => repo.fetchMessageReceipts(any()),
    ).thenAnswer((_) async => const Success(<MessageReceipt>[]));
  });

  MessageInformationBloc makeBloc() => MessageInformationBloc(
    fetchMessageReceiptsUseCase: FetchMessageReceiptsUseCase(repo),
  );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  // =========================================================================
  // InitializeMessageInformation
  // =========================================================================

  group('InitializeMessageInformation', () {
    test('a 1-on-1 message synthesises one receipt from the message', () async {
      final bloc = makeBloc();
      final message = FakeMessage(
        receiver: FakeUser('bob'),
        deliveredAt: _t1,
        readAt: _t2,
      );

      bloc.add(InitializeMessageInformation(parentMessage: message));
      await settle();

      expect(bloc.state.status, MessageInformationStatus.loaded);
      expect(bloc.state.isUserConversation, isTrue);
      expect(bloc.state.user?.uid, 'bob');
      expect(bloc.state.parentMessage, same(message));
      expect(bloc.state.receipts, hasLength(1));

      final r = bloc.state.receipts.single;
      expect(r.messageId, 42);
      expect(r.sender.uid, 'bob', reason: 'the receipt is attributed to them');
      expect(r.receiverType, ReceiverTypeConstants.user);
      expect(r.receiverId, 'bob');
      expect(r.deliveredAt, _t1);
      expect(r.readAt, _t2);
      expect(r.timestamp, message.sentAt);

      verifyNever(() => repo.fetchMessageReceipts(any()));
      await bloc.close();
    });

    test('an undelivered 1-on-1 message yields null timestamps', () async {
      final bloc = makeBloc();
      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(receiver: FakeUser('bob')),
        ),
      );
      await settle();

      final r = bloc.state.receipts.single;
      expect(r.deliveredAt, isNull);
      expect(r.readAt, isNull);
      await bloc.close();
    });

    test('a group message fetches receipts and drops the sender', () async {
      when(() => repo.fetchMessageReceipts(42)).thenAnswer(
        (_) async => Success([
          receipt(uid: 'sender', receiverType: ReceiverTypeConstants.group),
          receipt(uid: 'alice', receiverType: ReceiverTypeConstants.group),
        ]),
      );

      final bloc = makeBloc();
      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(
            receiver: FakeGroup('team'),
            sender: FakeUser('sender'),
          ),
        ),
      );
      await settle();

      expect(bloc.state.status, MessageInformationStatus.loaded);
      expect(bloc.state.isGroupConversation, isTrue);
      expect(bloc.state.group?.guid, 'team');
      expect(bloc.state.receipts.map((r) => r.sender.uid), ['alice']);
      verify(() => repo.fetchMessageReceipts(42)).called(1);
      await bloc.close();
    });

    test('a failed group fetch surfaces the message as an error', () async {
      when(() => repo.fetchMessageReceipts(any())).thenAnswer(
        (_) async => const Failure(message: 'no network', code: 'NET'),
      );

      final bloc = makeBloc();
      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(receiver: FakeGroup('team')),
        ),
      );
      await settle();

      expect(bloc.state.hasError, isTrue);
      expect(bloc.state.errorMessage, 'no network');
      expect(bloc.state.group?.guid, 'team', reason: 'context is kept');
      await bloc.close();
    });
  });

  // =========================================================================
  // _isForSameMessage
  // =========================================================================

  group('the is-this-my-message guard', () {
    test('a receipt before initialization is ignored', () async {
      final bloc = makeBloc();
      bloc.add(ReceiptRead(receipt(readAt: _t2)));
      await settle();

      expect(bloc.state.status, MessageInformationStatus.initial);
      expect(bloc.state.receipts, isEmpty);
      await bloc.close();
    });

    test('a 1-on-1 bloc ignores a receipt from another user', () async {
      final bloc = makeBloc();
      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(receiver: FakeUser('bob')),
        ),
      );
      await settle();

      bloc.add(ReceiptRead(receipt(uid: 'carol', readAt: _t2)));
      await settle();

      expect(bloc.state.receipts.single.readAt, isNull);
      await bloc.close();
    });

    test('a 1-on-1 bloc ignores a group-typed receipt', () async {
      final bloc = makeBloc();
      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(receiver: FakeUser('bob')),
        ),
      );
      await settle();

      bloc.add(
        ReceiptRead(
          receipt(
            uid: 'bob',
            receiverType: ReceiverTypeConstants.group,
            readAt: _t2,
          ),
        ),
      );
      await settle();

      expect(bloc.state.receipts.single.readAt, isNull);
      await bloc.close();
    });

    test('a group bloc ignores a receipt for a different group', () async {
      final bloc = makeBloc();
      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(receiver: FakeGroup('team')),
        ),
      );
      await settle();

      bloc.add(
        ReceiptDelivered(
          receipt(
            uid: 'alice',
            receiverType: ReceiverTypeConstants.group,
            receiverId: 'other_team',
            deliveredAt: _t1,
          ),
        ),
      );
      await settle();

      expect(bloc.state.receipts, isEmpty);
      await bloc.close();
    });
  });

  // =========================================================================
  // _updateReceiptList — 1-on-1
  // =========================================================================

  group('1-on-1 receipt merge', () {
    Future<MessageInformationBloc> loadedUserBloc() async {
      final bloc = makeBloc();
      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(receiver: FakeUser('bob')),
        ),
      );
      await settle();
      return bloc;
    }

    test('a delivered receipt only writes deliveredAt', () async {
      final bloc = await loadedUserBloc();

      bloc.add(
        ReceiptDelivered(
          receipt(uid: 'bob', deliveredAt: _t1, receiverId: 'bob'),
        ),
      );
      await settle();

      expect(bloc.state.receipts, hasLength(1));
      expect(bloc.state.receipts.single.deliveredAt, _t1);
      expect(bloc.state.receipts.single.readAt, isNull);
      await bloc.close();
    });

    test('a read receipt back-fills deliveredAt from readAt', () async {
      final bloc = await loadedUserBloc();

      bloc.add(
        ReceiptRead(receipt(uid: 'bob', readAt: _t2, receiverId: 'bob')),
      );
      await settle();

      final r = bloc.state.receipts.single;
      expect(r.readAt, _t2);
      expect(
        r.deliveredAt,
        _t2,
        reason: 'a message that was read must have been delivered',
      );
      await bloc.close();
    });

    test('a read receipt keeps an earlier deliveredAt', () async {
      final bloc = await loadedUserBloc();

      bloc.add(
        ReceiptDelivered(
          receipt(uid: 'bob', deliveredAt: _t1, receiverId: 'bob'),
        ),
      );
      await settle();
      bloc.add(
        ReceiptRead(receipt(uid: 'bob', readAt: _t2, receiverId: 'bob')),
      );
      await settle();

      final r = bloc.state.receipts.single;
      expect(r.deliveredAt, _t1);
      expect(r.readAt, _t2);
      expect(bloc.state.receipts, hasLength(1), reason: 'still one row');
      await bloc.close();
    });

    test(
      'a timestamp-less delivered receipt keeps the one already held',
      () async {
        final bloc = await loadedUserBloc();

        bloc.add(
          ReceiptDelivered(
            receipt(uid: 'bob', deliveredAt: _t1, receiverId: 'bob'),
          ),
        );
        await settle();
        // A delivered event carrying no timestamp — the merge passes null down,
        // and `_copyReceiptWith` must fall back rather than clear the field.
        bloc.add(ReceiptDelivered(receipt(uid: 'bob', receiverId: 'bob')));
        await settle();

        expect(bloc.state.receipts.single.deliveredAt, _t1);
        await bloc.close();
      },
    );
  });

  // =========================================================================
  // _updateReceiptList — group
  // =========================================================================

  group('group receipt merge', () {
    Future<MessageInformationBloc> loadedGroupBloc(
      List<MessageReceipt> seeded,
    ) async {
      when(
        () => repo.fetchMessageReceipts(any()),
      ).thenAnswer((_) async => Success(seeded));
      final bloc = makeBloc();
      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(
            receiver: FakeGroup('team'),
            sender: FakeUser('sender'),
          ),
        ),
      );
      await settle();
      return bloc;
    }

    MessageReceipt groupReceipt(
      String uid, {
      DateTime? deliveredAt,
      DateTime? readAt,
    }) => receipt(
      uid: uid,
      receiverType: ReceiverTypeConstants.group,
      receiverId: 'team',
      deliveredAt: deliveredAt,
      readAt: readAt,
    );

    test('the first receipt lands in an empty list', () async {
      final bloc = await loadedGroupBloc([]);

      bloc.add(ReceiptDelivered(groupReceipt('alice', deliveredAt: _t1)));
      await settle();

      expect(bloc.state.receipts.map((r) => r.sender.uid), ['alice']);
      expect(bloc.state.receipts.single.deliveredAt, _t1);
      await bloc.close();
    });

    test('the first receipt, if a read, back-fills deliveredAt', () async {
      final bloc = await loadedGroupBloc([]);

      bloc.add(ReceiptRead(groupReceipt('alice', readAt: _t2)));
      await settle();

      expect(bloc.state.receipts.single.deliveredAt, _t2);
      expect(bloc.state.receipts.single.readAt, _t2);
      await bloc.close();
    });

    test('an unknown sender is appended, a known one updated', () async {
      final bloc = await loadedGroupBloc([groupReceipt('alice')]);
      expect(bloc.state.receipts.map((r) => r.sender.uid), ['alice']);

      bloc.add(ReceiptDelivered(groupReceipt('carol', deliveredAt: _t1)));
      await settle();
      expect(bloc.state.receipts.map((r) => r.sender.uid), ['alice', 'carol']);

      bloc.add(ReceiptRead(groupReceipt('alice', readAt: _t2)));
      await settle();
      expect(bloc.state.receipts.map((r) => r.sender.uid), [
        'alice',
        'carol',
      ], reason: 'a known sender must not be duplicated');
      expect(bloc.state.receipts[0].readAt, _t2);
      expect(bloc.state.receipts[0].deliveredAt, _t2);
      expect(bloc.state.receipts[1].readAt, isNull);
      await bloc.close();
    });

    test(
      'a read from an unseen sender is appended, deliveredAt back-filled',
      () async {
        final bloc = await loadedGroupBloc([groupReceipt('alice')]);

        bloc.add(ReceiptRead(groupReceipt('dave', readAt: _t2)));
        await settle();

        expect(bloc.state.receipts.map((r) => r.sender.uid), ['alice', 'dave']);
        final dave = bloc.state.receipts.last;
        expect(dave.readAt, _t2);
        expect(dave.deliveredAt, _t2);
        await bloc.close();
      },
    );

    test('an appended read keeps a deliveredAt it already carried', () async {
      final bloc = await loadedGroupBloc([groupReceipt('alice')]);

      bloc.add(
        ReceiptRead(groupReceipt('dave', deliveredAt: _t1, readAt: _t2)),
      );
      await settle();

      expect(bloc.state.receipts.last.deliveredAt, _t1);
      await bloc.close();
    });

    test('a known sender keeps its existing deliveredAt on read', () async {
      final bloc = await loadedGroupBloc([
        groupReceipt('alice', deliveredAt: _t1),
      ]);

      bloc.add(ReceiptRead(groupReceipt('alice', readAt: _t2)));
      await settle();

      expect(bloc.state.receipts.single.deliveredAt, _t1);
      expect(bloc.state.receipts.single.readAt, _t2);
      await bloc.close();
    });

    test('a delivered receipt for a known sender leaves readAt', () async {
      final bloc = await loadedGroupBloc([groupReceipt('alice', readAt: _t2)]);

      bloc.add(ReceiptDelivered(groupReceipt('alice', deliveredAt: _t1)));
      await settle();

      expect(bloc.state.receipts.single.deliveredAt, _t1);
      expect(
        bloc.state.receipts.single.readAt,
        _t2,
        reason: 'a delivered event must not un-read a receipt',
      );
      await bloc.close();
    });
  });

  // =========================================================================
  // SDK listener wiring
  // =========================================================================

  group('UI event listeners', () {
    test('onMessagesRead / onMessagesDelivered reach the bloc', () async {
      final before = CometChatMessageEvents.messagesListener.length;
      final bloc = makeBloc();
      expect(
        CometChatMessageEvents.messagesListener.length,
        before + 1,
        reason: 'the bloc registers exactly one messages listener',
      );

      bloc.add(
        InitializeMessageInformation(
          parentMessage: FakeMessage(receiver: FakeUser('bob')),
        ),
      );
      await settle();

      CometChatMessageEvents.onMessagesDelivered(
        receipt(uid: 'bob', receiverId: 'bob', deliveredAt: _t1),
      );
      await settle();
      expect(bloc.state.receipts.single.deliveredAt, _t1);

      CometChatMessageEvents.onMessagesRead(
        receipt(uid: 'bob', receiverId: 'bob', readAt: _t2),
      );
      await settle();
      expect(bloc.state.receipts.single.readAt, _t2);

      await bloc.close();
      expect(
        CometChatMessageEvents.messagesListener.length,
        before,
        reason: 'close() must deregister, or the bloc leaks',
      );
    });

    test('two blocs get distinct listener keys', () async {
      final before = CometChatMessageEvents.messagesListener.length;
      final a = makeBloc();
      final b = makeBloc();

      expect(CometChatMessageEvents.messagesListener.length, before + 2);

      await a.close();
      await b.close();
      expect(CometChatMessageEvents.messagesListener.length, before);
    });

    test('the default constructor falls back to the service locator', () async {
      final locator = MessageInformationServiceLocator.instance;
      await locator.reset();
      expect(locator.isInitialized, isFalse);

      // No use case passed: the bloc must set the locator up and take its one.
      final bloc = MessageInformationBloc();
      expect(locator.isInitialized, isTrue);
      expect(
        bloc.fetchMessageReceiptsUseCase,
        same(locator.fetchMessageReceiptsUseCase),
      );

      // A second bloc reuses the already-initialized locator.
      final other = MessageInformationBloc();
      expect(
        other.fetchMessageReceiptsUseCase,
        same(bloc.fetchMessageReceiptsUseCase),
      );

      await bloc.close();
      await other.close();
    });

    test(
      'an event after close() is dropped, not added to a closed bloc',
      () async {
        final bloc = makeBloc();
        bloc.add(
          InitializeMessageInformation(
            parentMessage: FakeMessage(receiver: FakeUser('bob')),
          ),
        );
        await settle();
        await bloc.close();

        // Firing again must not throw even though the bloc is gone.
        expect(
          () => CometChatMessageEvents.onMessagesRead(
            receipt(uid: 'bob', receiverId: 'bob', readAt: _t2),
          ),
          returnsNormally,
        );
      },
    );
  });
}
