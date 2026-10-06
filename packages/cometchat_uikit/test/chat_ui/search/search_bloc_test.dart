/// [SearchBloc] — filter chips, scope sections, pagination and the two
/// request pipelines behind them.
///
/// The bloc builds its own `ConversationsRequestBuilder` /
/// `MessagesRequestBuilder` internally, so the only seam below it is the SDK
/// itself: a fake client registered through `SdkRegistry` answers every
/// `fetchNext` / `fetchPrevious` from a script and records the query the bloc
/// asked for. That makes the SDK-level filter translation (searchKeyword,
/// unread, conversationType, attachmentTypes, hasLinks) assertable, which is
/// the whole point of the filter chips.
///
///   flutter test test/chat_ui/search/search_bloc_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these; `SdkRegistry` is the documented seam (see
// test/helpers/golden_fake_sdk.dart).
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/conversations/conversation_repository.dart'
    as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';

/// One recorded call into the fake SDK.
class Query {
  Query(this.member, this.named);
  final Symbol member;
  final Map<Symbol, Object?> named;

  T? arg<T>(Symbol name) => named[name] as T?;
}

/// Every query the bloc made, in order.
final List<Query> queries = [];

/// Answers for `messages.*`, consumed one per call; the last repeats.
late List<List<BaseMessage>> messagePages;

/// Answers for `conversations.getConversations`, consumed one per call.
late List<List<Conversation>> conversationPages;

/// When set, the next matching call throws instead of answering.
bool failConversations = false;
bool failMessages = false;

List<T> _next<T>(List<List<T>> pages, int callIndex) =>
    pages[callIndex < pages.length ? callIndex : pages.length - 1];

class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #getUserMessages ||
        name == #getGroupMessages ||
        name == #getMessages) {
      queries.add(Query(name, invocation.namedArguments));
      final index = calls++;
      return Future<sdk.MessagesResult>.sync(() {
        if (failMessages) throw StateError('messages blew up');
        final page = _next(messagePages, index);
        return sdk.MessagesResult(messages: page, hasMore: false);
      });
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeConversationRepository extends Fake
    implements sdk.ConversationRepository {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getConversations) {
      queries.add(Query(#getConversations, invocation.namedArguments));
      final index = calls++;
      return Future<sdk.ConversationsResult>.sync(() {
        if (failConversations) throw StateError('conversations blew up');
        return sdk.ConversationsResult(
          conversations: _next(conversationPages, index),
          hasMore: true,
          totalPages: 5,
          currentPage: index + 1,
        );
      });
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  @override
  final sdk.MessageRepository messages = _FakeMessageRepository();

  @override
  final sdk.ConversationRepository conversations =
      _FakeConversationRepository();

  @override
  Future<void> dispose() async {}
}

Conversation conversation(String id) => Conversation(
  conversationId: id,
  conversationType: 'user',
  conversationWith: User(uid: id, name: 'User $id'),
);

TextMessage textMessage(int id, {DateTime? sentAt}) => TextMessage(
  id: id,
  text: 'm$id',
  sender: User(uid: 'u1', name: 'Alice'),
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
)..sentAt = sentAt ?? DateTime.utc(2026, 1, 1);

void main() {
  setUp(() async {
    queries.clear();
    messagePages = [const []];
    conversationPages = [const []];
    failConversations = false;
    failMessages = false;
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient());
  });

  tearDown(() => sdk.SdkRegistry.clear());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  SearchBloc makeBloc({
    SearchScope scope = SearchScope.both,
    List<SearchFilter>? searchFilters,
    List<SearchScope>? searchScopes,
    User? user,
    Group? group,
  }) => SearchBloc(
    initialScope: scope,
    searchFilters: searchFilters,
    searchScopes: searchScopes,
    user: user,
    group: group,
  );

  List<String> labels(List<SearchFilter> filters) =>
      filters.map((f) => f.label).toList();

  Query lastQuery(Symbol member) =>
      queries.lastWhere((q) => q.member == member);

  // =========================================================================
  // Filter chips
  // =========================================================================

  group('filter chips', () {
    test(
      'selecting one collapses the row to its own group, tapped first',
      () async {
        final bloc = makeBloc();

        // 'Groups' is second in group 1, so it has to be moved to the front.
        bloc.add(const SearchFilterToggled('Groups'));
        await settle();

        expect(bloc.state.selectedFilters, {'Groups'});
        expect(labels(bloc.state.visibleFilters), ['Groups', 'Unread']);
        await bloc.close();
      },
    );

    test('a filter that is already first is not reordered', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();

      expect(labels(bloc.state.visibleFilters), ['Unread', 'Groups']);
      await bloc.close();
    });

    test('deselecting the last chip restores the whole row', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Photos'));
      await settle();
      expect(labels(bloc.state.visibleFilters), ['Photos', 'Videos']);

      bloc.add(const SearchFilterToggled('Photos'));
      await settle();

      expect(bloc.state.selectedFilters, isEmpty);
      expect(labels(bloc.state.visibleFilters), labels(bloc.allFilters));
      await bloc.close();
    });

    test('two chips in the same group coexist', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Photos'));
      await settle();
      bloc.add(const SearchFilterToggled('Videos'));
      await settle();

      expect(bloc.state.selectedFilters, {'Photos', 'Videos'});
      await bloc.close();
    });

    test('a chip from another group evicts the current selection', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();
      bloc.add(const SearchFilterToggled('Photos'));
      await settle();

      expect(bloc.state.selectedFilters, {
        'Photos',
      }, reason: 'only one group may be active at a time');
      expect(labels(bloc.state.visibleFilters), ['Photos', 'Videos']);
      await bloc.close();
    });

    test(
      'a conversation chip shows conversations only, and back again',
      () async {
        final bloc = makeBloc();
        expect(bloc.state.showConversations, isTrue);
        expect(bloc.state.showMessages, isTrue);

        bloc.add(const SearchFilterToggled('Unread'));
        await settle();
        expect(bloc.state.showConversations, isTrue);
        expect(bloc.state.showMessages, isFalse);

        bloc.add(const SearchFilterToggled('Unread'));
        await settle();
        expect(bloc.state.showConversations, isTrue);
        expect(bloc.state.showMessages, isTrue);
        await bloc.close();
      },
    );

    test('a message chip shows messages only', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Links'));
      await settle();

      expect(bloc.state.showConversations, isFalse);
      expect(bloc.state.showMessages, isTrue);
      await bloc.close();
    });

    test(
      'a messages-locked bloc never turns the conversations section on',
      () async {
        // The scope filter would normally hide the conversation chips; passing
        // them explicitly is the only way a group-1 chip can be tapped here.
        final bloc = makeBloc(
          scope: SearchScope.messages,
          searchFilters: SearchBloc.defaultFilters,
        );
        expect(bloc.state.showConversations, isFalse);

        bloc.add(const SearchFilterToggled('Unread'));
        await settle();

        expect(
          bloc.state.showConversations,
          isFalse,
          reason: 'searchIn: [messages] wins over the chip',
        );
        expect(bloc.state.showMessages, isTrue);
        await bloc.close();
      },
    );

    test(
      'a conversations-locked bloc never turns the messages section on',
      () async {
        final bloc = makeBloc(
          scope: SearchScope.conversations,
          searchFilters: SearchBloc.defaultFilters,
        );
        expect(bloc.state.showMessages, isFalse);

        bloc.add(const SearchFilterToggled('Photos'));
        await settle();

        expect(bloc.state.showMessages, isFalse);
        expect(bloc.state.showConversations, isTrue);
        await bloc.close();
      },
    );

    test('scope narrows which chips exist at all', () {
      expect(labels(makeBloc(scope: SearchScope.messages).allFilters), [
        'Photos',
        'Videos',
        'Audio',
        'Documents',
        'Links',
      ]);
      expect(labels(makeBloc(scope: SearchScope.conversations).allFilters), [
        'Unread',
        'Groups',
      ]);
      expect(
        labels(makeBloc(searchScopes: [SearchScope.messages]).allFilters),
        ['Photos', 'Videos', 'Audio', 'Documents', 'Links'],
      );
      expect(labels(makeBloc().allFilters), labels(SearchBloc.defaultFilters));
    });

    test(
      'untoggling the last chip with no text resets both sections',
      () async {
        conversationPages = [
          [conversation('c1')],
        ];
        final bloc = makeBloc();

        bloc.add(const SearchFilterToggled('Unread'));
        await settle();
        expect(bloc.state.conversations, isNotEmpty);

        bloc.add(const SearchFilterToggled('Unread'));
        await settle();

        expect(bloc.state.conversationsStatus, SearchStatus.initial);
        expect(bloc.state.conversations, isEmpty);
        expect(bloc.state.hasMoreConversations, isFalse);
        expect(bloc.state.messagesStatus, SearchStatus.initial);
        expect(bloc.state.messages, isEmpty);
        expect(bloc.state.errorMessage, isNull);
        await bloc.close();
      },
    );
  });

  // =========================================================================
  // SDK-level query translation
  // =========================================================================

  group('query translation', () {
    test('Unread sets the unread flag and the filtered page size', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();

      final q = lastQuery(#getConversations);
      expect(q.arg<bool>(#unread), isTrue);
      expect(q.arg<String>(#conversationType), isNull);
      expect(q.arg<int>(#limit), 30, reason: 'filtered searches page by 30');
      await bloc.close();
    });

    test('Groups sets the conversation type', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Groups'));
      await settle();

      final q = lastQuery(#getConversations);
      expect(q.arg<String>(#conversationType), ConversationType.group);
      expect(
        q.arg<bool>(#unread),
        isFalse,
        reason: 'the Groups chip must not also narrow to unread',
      );
      await bloc.close();
    });

    test('each media chip maps to its attachment type', () async {
      final expected = {
        'Photos': AttachmentType.IMAGE.value,
        'Videos': AttachmentType.VIDEO.value,
        'Audio': AttachmentType.AUDIO.value,
        'Documents': AttachmentType.FILE.value,
      };

      for (final entry in expected.entries) {
        queries.clear();
        final bloc = makeBloc();
        bloc.add(SearchFilterToggled(entry.key));
        await settle();

        final q = lastQuery(#getMessages);
        expect(q.arg<List<String>>(#attachmentTypes), [
          entry.value,
        ], reason: entry.key);
        expect(q.arg<bool>(#hasLinks), isNull, reason: entry.key);
        await bloc.close();
      }
    });

    test('Links sets hasLinks and no attachment type', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Links'));
      await settle();

      final q = lastQuery(#getMessages);
      expect(q.arg<bool>(#hasLinks), isTrue);
      expect(q.arg<List<String>>(#attachmentTypes), isNull);
      await bloc.close();
    });

    test('a caller-supplied conversations builder is carried across', () async {
      final supplied = ConversationsRequestBuilder()
        ..withUserAndGroupTags = true
        ..withTags = true
        ..tags = ['vip']
        ..includeBlockedUsers = true
        ..withBlockedInfo = true
        ..userTags = ['staff']
        ..groupTags = ['internal']
        // Deliberately different from what the bloc will use: the bloc must
        // set its own page size rather than honour this one.
        ..limit = 99;

      final bloc = SearchBloc(conversationsRequestBuilder: supplied);
      bloc.add(const SearchFilterToggled('Unread'));
      await settle();

      final q = lastQuery(#getConversations);
      expect(q.arg<bool>(#withUserAndGroupTags), isTrue);
      expect(q.arg<bool>(#withTags), isTrue);
      expect(q.arg<List<String>>(#tags), ['vip']);
      expect(q.arg<bool>(#includeBlockedUsers), isTrue);
      expect(q.arg<bool>(#withBlockedInfo), isTrue);
      expect(q.arg<List<String>>(#userTags), ['staff']);
      expect(q.arg<List<String>>(#groupTags), ['internal']);
      expect(q.arg<int>(#limit), 30, reason: 'the bloc owns the page size');
      await bloc.close();
    });

    test('a caller-supplied messages builder is carried across', () async {
      final supplied = MessagesRequestBuilder()
        ..guid = 'g_supplied'
        ..categories = [MessageCategoryConstants.custom]
        ..types = ['my_type'];

      final bloc = SearchBloc(messagesRequestBuilder: supplied);
      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final q = lastQuery(#getGroupMessages);
      expect(q.arg<List<String>>(#categories), [
        MessageCategoryConstants.custom,
      ]);
      expect(q.arg<List<String>>(#types), [
        'my_type',
      ], reason: 'a caller-supplied builder suppresses the default type list');
      await bloc.close();
    });

    test('with no supplied builder, card messages are searchable', () async {
      final bloc = makeBloc();

      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final q = lastQuery(#getMessages);
      expect(
        q.arg<List<String>>(#categories),
        contains(MessageCategoryConstants.card),
      );
      expect(q.arg<List<String>>(#types), contains(MessageTypeConstants.card));
      await bloc.close();
    });

    test('a user-scoped bloc queries that user', () async {
      final bloc = makeBloc(
        user: User(uid: 'u9', name: 'Zed'),
      );

      bloc.add(const SearchFilterToggled('Links'));
      await settle();

      expect(lastQuery(#getUserMessages).member, #getUserMessages);
      await bloc.close();
    });

    test('a group-scoped bloc queries that group', () async {
      final bloc = makeBloc(
        group: Group(guid: 'g9', name: 'G', type: 'public'),
      );

      bloc.add(const SearchFilterToggled('Links'));
      await settle();

      expect(lastQuery(#getGroupMessages).member, #getGroupMessages);
      await bloc.close();
    });
  });

  // =========================================================================
  // Multi-attachment merge
  // =========================================================================

  group('multiple attachment chips', () {
    test(
      'fire one request each and merge, newest first, without duplicates',
      () async {
        messagePages = [
          // The single-filter search that sets the scene consumes page 0; the
          // merged search that follows consumes pages 1 and 2.
          const [],
          [
            textMessage(1, sentAt: DateTime.utc(2026, 1, 1)),
            textMessage(3, sentAt: DateTime.utc(2026, 1, 3)),
          ],
          [
            textMessage(3, sentAt: DateTime.utc(2026, 1, 3)), // duplicate id
            textMessage(2, sentAt: DateTime.utc(2026, 1, 2)),
          ],
        ];
        final bloc = makeBloc();

        bloc.add(const SearchFilterToggled('Photos'));
        await settle();
        final beforeSecond = queries
            .where((q) => q.member == #getMessages)
            .length;

        bloc.add(const SearchFilterToggled('Videos'));
        await settle();

        final messageQueries = queries
            .where((q) => q.member == #getMessages)
            .toList();
        expect(
          messageQueries.length - beforeSecond,
          2,
          reason: 'the server takes one attachmentType per request',
        );
        expect(
          messageQueries[messageQueries.length - 2].arg<List<String>>(
            #attachmentTypes,
          ),
          [AttachmentType.IMAGE.value],
        );
        expect(messageQueries.last.arg<List<String>>(#attachmentTypes), [
          AttachmentType.VIDEO.value,
        ]);

        expect(bloc.state.messages.map((m) => m.id), [3, 2, 1]);
        expect(
          bloc.state.hasMoreMessages,
          isFalse,
          reason: 'merged results are not paginated',
        );
        expect(bloc.state.messagesStatus, SearchStatus.loaded);
        await bloc.close();
      },
    );

    test('Links rides along with every attachment request', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Photos'));
      await settle();
      bloc.add(const SearchFilterToggled('Videos'));
      await settle();
      queries.clear();
      bloc.add(const SearchFilterToggled('Links'));
      await settle();

      // Links is group 4, so it evicts the group-2 chips entirely.
      expect(bloc.state.selectedFilters, {'Links'});
      expect(lastQuery(#getMessages).arg<bool>(#hasLinks), isTrue);
      await bloc.close();
    });

    test('a merged search that fails surfaces one error', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Photos'));
      await settle();
      failMessages = true;
      bloc.add(const SearchFilterToggled('Videos'));
      await settle();

      expect(bloc.state.messagesStatus, SearchStatus.error);
      expect(bloc.state.errorMessage, isNotNull);
      await bloc.close();
    });

    test('an empty merged result reads as empty, not loaded', () async {
      messagePages = [const []];
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Photos'));
      await settle();
      bloc.add(const SearchFilterToggled('Videos'));
      await settle();

      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.messagesStatus, SearchStatus.empty);
      await bloc.close();
    });
  });

  // =========================================================================
  // Results, errors, pagination
  // =========================================================================

  group('results and pagination', () {
    test('a full page of conversations leaves room for more', () async {
      conversationPages = [
        [conversation('c1'), conversation('c2'), conversation('c3')],
        [conversation('c4')],
      ];
      final bloc = makeBloc();

      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(bloc.state.conversations.map((c) => c.conversationId), [
        'c1',
        'c2',
        'c3',
      ]);
      expect(bloc.state.conversationsStatus, SearchStatus.loaded);
      expect(
        bloc.state.hasMoreConversations,
        isTrue,
        reason: 'an unfiltered page is 3, so a full page means there is more',
      );

      bloc.add(const LoadMoreConversationResults());
      await settle();

      expect(bloc.state.conversations.map((c) => c.conversationId), [
        'c1',
        'c2',
        'c3',
        'c4',
      ]);
      expect(bloc.state.hasMoreConversations, isFalse);
      await bloc.close();
    });

    test('a full page of messages pages in more and appends', () async {
      messagePages = [
        [textMessage(1), textMessage(2), textMessage(3)],
        [textMessage(4)],
      ];
      final bloc = makeBloc();

      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(bloc.state.messages.map((m) => m.id), [3, 2, 1]);
      expect(bloc.state.hasMoreMessages, isTrue);

      bloc.add(const LoadMoreMessageResults());
      await settle();

      expect(bloc.state.messages.map((m) => m.id), [
        3,
        2,
        1,
        4,
      ], reason: 'the next page is appended, not substituted');
      expect(bloc.state.hasMoreMessages, isFalse);
      await bloc.close();
    });

    test('load-more is a no-op once the list is exhausted', () async {
      conversationPages = [
        [conversation('c1')],
      ];
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();
      expect(bloc.state.hasMoreConversations, isFalse);

      final before = queries.length;
      bloc.add(const LoadMoreConversationResults());
      bloc.add(const LoadMoreMessageResults());
      await settle();

      expect(queries.length, before, reason: 'nothing more was requested');
      await bloc.close();
    });

    test('an empty result reads as empty', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();

      expect(bloc.state.conversationsStatus, SearchStatus.empty);
      expect(bloc.state.conversations, isEmpty);
      await bloc.close();
    });

    test('a conversations failure is reported and keeps the section', () async {
      failConversations = true;
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();

      expect(bloc.state.conversationsStatus, SearchStatus.error);
      expect(bloc.state.errorMessage, isNotNull);
      await bloc.close();
    });

    test('a messages failure is reported', () async {
      failMessages = true;
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Links'));
      await settle();

      expect(bloc.state.messagesStatus, SearchStatus.error);
      expect(bloc.state.errorMessage, isNotNull);
      await bloc.close();
    });

    test(
      'messages come back newest-last from the SDK and are reversed',
      () async {
        messagePages = [
          [textMessage(1), textMessage(2), textMessage(3)],
        ];
        final bloc = makeBloc();

        bloc.add(const SearchFilterToggled('Links'));
        await settle();

        expect(bloc.state.messages.map((m) => m.id), [3, 2, 1]);
        await bloc.close();
      },
    );
  });

  // =========================================================================
  // Text search, clear and refresh
  // =========================================================================

  group('text search', () {
    test('typing debounces: nothing is requested before 500ms', () async {
      final bloc = makeBloc();

      bloc.add(const SearchTextChanged('he'));
      await settle();
      expect(bloc.state.searchText, 'he');
      expect(bloc.state.conversationsStatus, SearchStatus.loading);
      expect(queries, isEmpty);

      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(
        queries.where((q) => q.member == #getConversations),
        hasLength(1),
        reason: 'the first keystroke was cancelled by the second',
      );
      expect(lastQuery(#getConversations).arg<String>(#searchKeyword), 'hello');
      await bloc.close();
    });

    test('the text is trimmed before it reaches the SDK', () async {
      final bloc = makeBloc();

      bloc.add(const SearchTextChanged('   spaced   '));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(bloc.state.searchText, 'spaced');
      expect(
        lastQuery(#getConversations).arg<String>(#searchKeyword),
        'spaced',
      );
      await bloc.close();
    });

    test('clearing the text with no filters resets to initial', () async {
      conversationPages = [
        [conversation('c1')],
      ];
      final bloc = makeBloc();

      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(bloc.state.conversations, isNotEmpty);

      bloc.add(const SearchTextChanged(''));
      await settle();

      expect(bloc.state.searchText, '');
      expect(bloc.state.conversationsStatus, SearchStatus.initial);
      expect(bloc.state.conversations, isEmpty);
      expect(bloc.state.messagesStatus, SearchStatus.initial);
      await bloc.close();
    });

    test('clearing the text while a filter is up keeps searching', () async {
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();
      queries.clear();

      bloc.add(const SearchTextChanged(''));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(bloc.state.conversationsStatus, isNot(SearchStatus.initial));
      expect(queries, isNotEmpty);
      await bloc.close();
    });

    test('ClearSearch wipes everything back to construction', () async {
      conversationPages = [
        [conversation('c1')],
      ];
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();
      bloc.add(const SearchTextChanged('hello'));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(bloc.state.conversations, isNotEmpty);

      bloc.add(const ClearSearch());
      await settle();

      expect(bloc.state.searchText, '');
      expect(bloc.state.selectedFilters, isEmpty);
      expect(labels(bloc.state.visibleFilters), labels(bloc.allFilters));
      expect(bloc.state.conversations, isEmpty);
      expect(bloc.state.conversationsStatus, SearchStatus.initial);
      expect(bloc.state.showConversations, isTrue);
      expect(bloc.state.showMessages, isTrue);
      await bloc.close();
    });

    test('RefreshCurrentSearch re-runs an active search', () async {
      conversationPages = [
        [conversation('c1')],
        [conversation('c2')],
      ];
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      await settle();
      expect(bloc.state.conversations.map((c) => c.conversationId), ['c1']);

      bloc.add(const RefreshCurrentSearch());
      await settle();

      expect(bloc.state.conversations.map((c) => c.conversationId), [
        'c2',
      ], reason: 'a refresh replaces rather than appends');
      await bloc.close();
    });

    test('RefreshCurrentSearch is inert with nothing to refresh', () async {
      final bloc = makeBloc();

      bloc.add(const RefreshCurrentSearch());
      await settle();

      expect(queries, isEmpty);
      expect(bloc.state.conversationsStatus, SearchStatus.initial);
      await bloc.close();
    });

    test('a late response for a superseded search is discarded', () async {
      conversationPages = [
        [conversation('stale')],
        [conversation('fresh')],
      ];
      final bloc = makeBloc();

      bloc.add(const SearchFilterToggled('Unread'));
      bloc.add(const SearchFilterToggled('Groups'));
      await settle();

      expect(bloc.state.conversations.map((c) => c.conversationId), [
        'fresh',
      ], reason: 'the version counter drops the first response');
      await bloc.close();
    });

    test('close() cancels a pending debounce', () async {
      final bloc = makeBloc();

      bloc.add(const SearchTextChanged('hello'));
      await settle();
      await bloc.close();

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(queries, isEmpty, reason: 'the debounced search never fired');
    });
  });
}
