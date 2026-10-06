/// MessageListBlocAdapter — the shim that lets legacy templates and
/// extensions drive the BLoC through `CometChatMessageListControllerProtocol`.
///
/// Every method is a one-line delegation, which is exactly why it is worth
/// pinning: a protocol method wired to the wrong event (or to the wrong
/// lookup) fails silently at runtime. The bloc here is a real
/// [MessageListBloc] over a mocked repository with `disableSDKListeners: true`,
/// subclassed only to record what the adapter dispatches.
///
///   flutter test test/chat_ui/message_list/message_list_bloc_adapter_test.dart
library;

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc_adapter.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_newer_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_older_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_unread_usecase.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show
        CometChatMessageTemplate,
        MessageCategoryConstants,
        MessageTypeConstants;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

class MockRepo extends Mock implements MessageListRepository {}

class FakeUser extends Fake implements User {
  FakeUser([this._uid = 'test_user']);
  final String _uid;
  @override
  String get uid => _uid;
}

class FakeGroupModel extends Fake implements Group {
  FakeGroupModel([this._guid = 'test_group']);
  final String _guid;
  @override
  String get guid => _guid;
}

class FakeMsg extends Fake implements TextMessage {
  FakeMsg(this._id, {String? muid}) : _muid = muid ?? 'muid_$_id';
  final int _id;
  final String _muid;
  @override
  int get id => _id;
  @override
  String get muid => _muid;
  @override
  int get parentMessageId => 0;
  @override
  String get type => 'text';
  @override
  String get category => 'message';
  @override
  DateTime? get sentAt => DateTime(2026, 1, 1);
  @override
  DateTime? get readAt => null;
  @override
  DateTime? get deliveredAt => null;
  DateTime? _deletedAt;
  String? _deletedBy;
  @override
  DateTime? get deletedAt => _deletedAt;
  @override
  set deletedAt(DateTime? v) => _deletedAt = v;
  @override
  String? get deletedBy => _deletedBy;
  @override
  set deletedBy(String? v) => _deletedBy = v;
  @override
  User? get sender => FakeUser();
  @override
  int get replyCount => 0;
  @override
  set replyCount(int v) {}
  @override
  String get receiverUid => 'test_user';
  @override
  String get receiverType => 'user';
  @override
  String? get conversationId => 'user_test_user';
  @override
  BaseMessage? get quotedMessage => null;
  @override
  String get text => 'msg $_id';
  @override
  List<ReactionCount> get reactions => const [];
  @override
  Map<String, dynamic>? get metadata => null;
  @override
  int get quotedMessageId => 0;
  @override
  set quotedMessageId(int v) {}
  @override
  ModerationStatusEnum? get moderationStatus => null;
  @override
  set moderationStatus(ModerationStatusEnum? v) {}
}

class FakeBase extends Fake implements BaseMessage {
  @override
  int get id => 0;
}

class FakeMessagesRequest extends Fake implements MessagesRequest {}

class FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'user_test_user';
  @override
  int get unreadMessageCount => 0;
  @override
  int? get lastReadMessageId => 1;
}

/// A bloc that records every event the adapter dispatches while still running
/// the real handlers.
class SpyBloc extends MessageListBloc {
  SpyBloc({
    required MockRepo repo,
    super.user,
    super.group,
    super.parentMessageId,
  }) : super(
         getMessagesUseCase: GetMessagesUseCase(repo),
         loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
         loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
         markAsReadUseCase: MarkAsReadUseCase(repo),
         markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
         markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
         getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
         disableSDKListeners: true,
       );

  final List<MessageListEvent> dispatched = [];

  @override
  void add(MessageListEvent event) {
    dispatched.add(event);
    super.add(event);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBase());
    registerFallbackValue(FakeConversation());
    registerFallbackValue(FakeMessagesRequest());
  });

  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(FakeUser()));
    when(
      () => repo.getMessages(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
        limit: any(named: 'limit'),
        parentMessageId: any(named: 'parentMessageId'),
        types: any(named: 'types'),
        categories: any(named: 'categories'),
        hideReplies: any(named: 'hideReplies'),
        withParent: any(named: 'withParent'),
      ),
    ).thenAnswer((_) async => Success(<BaseMessage>[FakeMsg(1), FakeMsg(2)]));
    when(
      () => repo.getConversation(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
      ),
    ).thenAnswer((_) async => Success(FakeConversation()));
    when(
      () => repo.markMessageAsUnread(any()),
    ).thenAnswer((_) async => Success(FakeConversation()));
    when(
      () => repo.markAsRead(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.markAsDelivered(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.fetchPreviousMessages(request: any(named: 'request')),
    ).thenAnswer((_) async => const Success(<BaseMessage>[]));
    when(
      () => repo.fetchNextMessages(request: any(named: 'request')),
    ).thenAnswer((_) async => const Success(<BaseMessage>[]));
  });

  /// Builds an adapter over a seeded, loaded bloc and hands both to [body]
  /// with a live BuildContext.
  Future<void> withAdapter(
    WidgetTester tester,
    Future<void> Function(
      SpyBloc bloc,
      MessageListBlocAdapter adapter,
      BuildContext context,
    )
    body, {
    User? user,
    Group? group,
    int? parentMessageId,
    Map<String, CometChatMessageTemplate>? templates,
    ScrollController? scrollController,
    bool seed = true,
  }) async {
    final bloc = SpyBloc(
      repo: repo,
      user: user,
      group: group,
      parentMessageId: parentMessageId,
    );
    addTearDown(bloc.close);

    if (seed) {
      bloc.add(
        const LoadMessages(
          conversationWith: 'test_user',
          conversationType: 'user',
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      bloc.dispatched.clear();
    }

    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final controller = scrollController ?? ScrollController();
    if (scrollController == null) addTearDown(controller.dispose);

    final adapter = MessageListBlocAdapter(
      bloc: bloc,
      templateMap: templates ?? const {},
      scrollController: controller,
      context: captured,
    );

    await body(bloc, adapter, captured);
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the accessors read straight off the bloc', (tester) async {
    final user = FakeUser('u_42');
    final template = CometChatMessageTemplate(
      type: MessageTypeConstants.text,
      category: MessageCategoryConstants.message,
    );
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await withAdapter(
      tester,
      (bloc, adapter, context) async {
        expect(adapter.getUser(), same(user));
        expect(adapter.getGroup(), isNull);
        expect(adapter.getParentMessageId(), 99);
        expect(adapter.getConversationId(), 'user_u_42');
        expect(adapter.getScrollController(), same(controller));
        expect(adapter.getTemplateMap()['text'], same(template));
        expect(adapter.getCurrentContext(), same(context));
        // A documented no-op: the widget owns header/footer under the BLoC.
        expect(adapter.initializeHeaderAndFooterView, returnsNormally);
        adapter.initializeHeaderAndFooterView();
        // Search is not a message-list concern — the protocol method is inert.
        adapter.onSearch('anything');
        expect(bloc.dispatched, isEmpty);
      },
      user: user,
      parentMessageId: 99,
      templates: {'text': template},
      scrollController: controller,
    );
  });

  testWidgets('a group bloc reports the group and its conversation id', (
    tester,
  ) async {
    final group = FakeGroupModel('g_7');
    await withAdapter(
      tester,
      (bloc, adapter, _) async {
        expect(adapter.getGroup(), same(group));
        expect(adapter.getUser(), isNull);
        expect(adapter.getConversationId(), 'group_g_7');
      },
      group: group,
      seed: false,
    );
  });

  testWidgets('a bloc with no user and no group yields an empty id', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      // `conversationId` is null there; the protocol demands a String.
      expect(adapter.getConversationId(), '');
    }, seed: false);
  });

  testWidgets('updateContext swaps the context handed to templates', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, context) async {
      expect(adapter.getCurrentContext(), same(context));
      final other = tester.element(find.byType(MaterialApp));
      adapter.updateContext(other);
      expect(adapter.getCurrentContext(), same(other));
      expect(adapter.getCurrentContext(), isNot(same(context)));
    }, seed: false);
  });

  testWidgets('the mutation methods dispatch the matching events', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      final msg = FakeMsg(50);

      adapter.addMessage(msg);
      adapter.deleteMessage(msg);
      adapter.addElement(msg);
      adapter.removeElement(msg);
      adapter.updateElement(msg);
      adapter.loadMoreElements();
      adapter.markMessageAsUnread(msg);
      adapter.resetUnreadState();

      expect(bloc.dispatched.map((e) => e.runtimeType).toList(), [
        MessageReceived,
        MessageDeleted,
        MessageReceived,
        MessageDeleted,
        MessageEdited,
        LoadOlderMessages,
        MarkMessageAsUnread,
        ResetUnreadState,
      ]);
      expect((bloc.dispatched.first as MessageReceived).message, same(msg));
    }, user: FakeUser());
  });

  testWidgets('updateMessageWithMuid edits a known muid, adds an unknown one', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      // muid_1 was seeded by the load, so it resolves to an index.
      expect(bloc.findMessageIndexByMuid('muid_1'), isNotNull);
      adapter.updateMessageWithMuid(FakeMsg(1, muid: 'muid_1'));
      expect(bloc.dispatched.single, isA<MessageEdited>());

      bloc.dispatched.clear();
      adapter.updateMessageWithMuid(FakeMsg(999, muid: 'muid_unknown'));
      expect(
        bloc.dispatched.single,
        isA<MessageReceived>(),
        reason: 'an unknown muid is treated as a new message',
      );
    }, user: FakeUser());
  });

  testWidgets('match compares ids, not identity', (tester) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(adapter.match(FakeMsg(3), FakeMsg(3)), isTrue);
      expect(adapter.match(FakeMsg(3), FakeMsg(4)), isFalse);
    }, seed: false);
  });

  testWidgets('index lookups fall back to -1 when nothing matches', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(adapter.getMatchingIndex(FakeMsg(1)), 0);
      expect(adapter.getMatchingIndex(FakeMsg(2)), 1);
      expect(adapter.getMatchingIndex(FakeMsg(404)), -1);

      // A numeric key is resolved by id...
      expect(adapter.getMatchingIndexFromKey('2'), 1);
      expect(adapter.getMatchingIndexFromKey('404'), -1);
      // ...and a non-numeric key falls through to the muid map.
      expect(adapter.getMatchingIndexFromKey('muid_1'), 0);
      expect(adapter.getMatchingIndexFromKey('not-a-muid'), -1);
    }, user: FakeUser());
  });

  testWidgets('removeElementAt only fires for an in-range index', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(adapter.getList().length, 2);

      adapter.removeElementAt(-1);
      adapter.removeElementAt(2);
      expect(bloc.dispatched, isEmpty, reason: 'out of range is a no-op');

      adapter.removeElementAt(0);
      expect(bloc.dispatched.single, isA<MessageDeleted>());
      expect(
        (bloc.dispatched.single as MessageDeleted).message.id,
        bloc.state.messages[0].id,
      );
    }, user: FakeUser());
  });

  testWidgets('getList exposes the bloc state list', (tester) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(adapter.getList(), same(bloc.state.messages));
      expect(adapter.getList().map((m) => m.id), [1, 2]);
    }, user: FakeUser());
  });

  testWidgets('updateMessageThreadCount increments the tracked count', (
    tester,
  ) async {
    await withAdapter(tester, (bloc, adapter, _) async {
      expect(bloc.getThreadReplyCount(1), 0);
      adapter.updateMessageThreadCount(1);
      expect(bloc.getThreadReplyCount(1), 1);
      adapter.updateMessageThreadCount(1);
      expect(bloc.getThreadReplyCount(1), 2);
      // Other parents are unaffected.
      expect(bloc.getThreadReplyCount(2), 0);
    }, user: FakeUser());
  });
}
