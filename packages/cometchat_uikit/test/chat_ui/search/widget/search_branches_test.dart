/// The branches of [CometChatSearch] the prop matrix does not reach: the
/// per-section state views, the two paging paths, and the row-content helpers
/// that decide what a search hit is *called*.
///
/// `search_props_test.dart` pins that each prop renders. This pins the logic
/// between the state and the row: which title a message hit gets (the other
/// party, never yourself), when the "You:" prefix appears, which trailing
/// widget a media hit gets, and which bloc event each paging affordance
/// raises. Those are the lines that decide whether a result list is readable,
/// and none of them is visible to a prop matrix.
///
///   flutter test test/chat_ui/search/widget/search_branches_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Unlike the prop matrix's mock, this one lets `add` through so the paging
/// events can be verified.
class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _me = User(uid: 'u-me', name: 'Me');
final _bob = User(uid: 'u-bob', name: 'Bob Smith');
final _team = Group(guid: 'g1', name: 'Design Crew', type: 'public');
final _sentAt = DateTime(2026, 3, 14, 9, 30);

TextMessage _text({
  int id = 1,
  String body = 'pasta',
  User? sender,
  AppEntity? receiver,
  String receiverUid = 'u-me',
  String receiverType = ReceiverTypeConstants.user,
}) => TextMessage(
  id: id,
  text: body,
  sender: sender ?? _bob,
  receiver: receiver,
  receiverUid: receiverUid,
  type: MessageTypeConstants.text,
  receiverType: receiverType,
  category: MessageCategoryConstants.message,
  sentAt: _sentAt,
);

MediaMessage _media({
  int id = 2,
  String type = MessageTypeConstants.image,
  User? sender,
  List<Attachment>? attachments,
  Map<String, dynamic>? metadata,
}) => MediaMessage(
  id: id,
  type: type,
  sender: sender ?? _bob,
  receiver: _me,
  receiverUid: 'u-me',
  receiverType: ReceiverTypeConstants.user,
  category: MessageCategoryConstants.message,
  sentAt: _sentAt,
  attachments: attachments,
  metadata: metadata,
);

Attachment _attachment(String name, String url) =>
    Attachment(url, name, name.split('.').last, 'application/octet-stream', 10);

Conversation _conversation({
  String id = 'user_u-bob',
  BaseMessage? last,
  int unread = 0,
}) => Conversation(
  conversationId: id,
  conversationType: ReceiverTypeConstants.user,
  conversationWith: _bob,
  lastMessage: last,
  unreadMessageCount: unread,
);

SearchState _conversationsState({
  SearchStatus status = SearchStatus.loaded,
  List<Conversation> conversations = const [],
  bool hasMore = false,
  Set<String> filters = const {},
}) => SearchState(
  searchText: 'pas',
  scope: SearchScope.conversations,
  showConversations: true,
  showMessages: false,
  conversationsStatus: status,
  conversations: conversations,
  hasMoreConversations: hasMore,
  selectedFilters: filters,
);

SearchState _messagesState({
  SearchStatus status = SearchStatus.loaded,
  List<BaseMessage> messages = const [],
  bool hasMore = false,
  Set<String> filters = const {},
}) => SearchState(
  searchText: 'pas',
  scope: SearchScope.messages,
  showConversations: false,
  showMessages: true,
  messagesStatus: status,
  messages: messages,
  hasMoreMessages: hasMore,
  selectedFilters: filters,
);

MockSearchBloc _blocIn(SearchState state) {
  final bloc = MockSearchBloc();
  when(() => bloc.state).thenReturn(state);
  when(() => bloc.isClosed).thenReturn(false);
  whenListen(bloc, Stream<SearchState>.value(state), initialState: state);
  return bloc;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: child,
);

Future<void> _pump(WidgetTester tester, Widget child) =>
    mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap(child));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

void main() {
  setUpAll(() {
    registerFallbackValue(const LoadMoreConversationResults());
  });

  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  // =========================================================================
  group('conversations-only section states', () {
    testWidgets('loading fills the section with the loading view', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _conversationsState(status: SearchStatus.loading),
          ),
          loadingStateView: (_) => const Text('SECTION_LOADING'),
        ),
      );

      expect(find.text('SECTION_LOADING'), findsOneWidget);
    });

    testWidgets('a settled but empty result fills it with the empty view', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(_conversationsState()),
          emptyStateView: (_) => const Text('SECTION_EMPTY'),
        ),
      );

      expect(find.text('SECTION_EMPTY'), findsOneWidget);
    });

    testWidgets('an errored search with no results shows the empty view', (
      tester,
    ) async {
      // An errored-but-empty section is not `allEmpty` (that only counts
      // `loaded`/`empty`), so the aggregate no-results screen does not claim
      // it and the section's own empty branch runs.
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(_conversationsState(status: SearchStatus.error)),
          emptyStateView: (_) => const Text('SECTION_EMPTY_AFTER_ERROR'),
        ),
      );

      expect(find.text('SECTION_EMPTY_AFTER_ERROR'), findsOneWidget);
    });

    testWidgets('an error with results present still shows the error view', (
      tester,
    ) async {
      // The error arm is reached only when the list is non-empty; an empty
      // errored search is indistinguishable from an empty one and takes the
      // empty branch above.
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _conversationsState(
              status: SearchStatus.error,
              conversations: [_conversation()],
            ),
          ),
          errorStateView: (_) => const Text('SECTION_ERROR'),
        ),
      );

      expect(find.text('SECTION_ERROR'), findsOneWidget);
    });
  });

  // =========================================================================
  group('conversations paging', () {
    testWidgets('with a filter on, the trailing row asks for the next page', (
      tester,
    ) async {
      final bloc = _blocIn(
        _conversationsState(
          conversations: [_conversation()],
          hasMore: true,
          filters: const {'unread'},
        ),
      );

      await _pump(tester, CometChatSearch(searchBloc: bloc));

      // The extra slot past the last row is the loader, and building it is
      // what pages.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verify(
        () => bloc.add(any(that: isA<LoadMoreConversationResults>())),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('with a filter on and no more pages there is no loader row', (
      tester,
    ) async {
      final bloc = _blocIn(
        _conversationsState(
          conversations: [_conversation()],
          filters: const {'unread'},
        ),
      );

      await _pump(tester, CometChatSearch(searchBloc: bloc));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      verifyNever(
        () => bloc.add(any(that: isA<LoadMoreConversationResults>())),
      );
    });

    testWidgets('with no filter, three-plus results get a See more button', (
      tester,
    ) async {
      final bloc = _blocIn(
        _conversationsState(
          conversations: [
            _conversation(id: 'c1'),
            _conversation(id: 'c2'),
            _conversation(id: 'c3'),
          ],
          hasMore: true,
        ),
      );

      await _pump(tester, CometChatSearch(searchBloc: bloc));
      verifyNever(
        () => bloc.add(any(that: isA<LoadMoreConversationResults>())),
      );

      await tester.tap(find.text('More'));
      await tester.pump();

      verify(
        () => bloc.add(any(that: isA<LoadMoreConversationResults>())),
      ).called(1);
    });

    testWidgets('fewer than three results get no See more button', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _conversationsState(
              conversations: [_conversation(id: 'c1')],
              hasMore: true,
            ),
          ),
        ),
      );

      expect(find.text('More'), findsNothing);
    });
  });

  // =========================================================================
  group('messages paging', () {
    testWidgets('with a filter on, the trailing row asks for the next page', (
      tester,
    ) async {
      final bloc = _blocIn(
        _messagesState(
          messages: [_text()],
          hasMore: true,
          filters: const {'photos'},
        ),
      );

      await _pump(tester, CometChatSearch(searchBloc: bloc));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verify(
        () => bloc.add(any(that: isA<LoadMoreMessageResults>())),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('with no filter, three-plus results get a See more button', (
      tester,
    ) async {
      final bloc = _blocIn(
        _messagesState(
          messages: [_text(id: 1), _text(id: 2), _text(id: 3)],
          hasMore: true,
        ),
      );

      await _pump(tester, CometChatSearch(searchBloc: bloc));
      await tester.tap(find.text('More'));
      await tester.pump();

      verify(
        () => bloc.add(any(that: isA<LoadMoreMessageResults>())),
      ).called(1);
    });

    testWidgets(
      'an errored message section with results shows the error view',
      (tester) async {
        await _pump(
          tester,
          CometChatSearch(
            searchBloc: _blocIn(
              _messagesState(status: SearchStatus.error, messages: [_text()]),
            ),
            errorStateView: (_) => const Text('MSG_ERROR'),
          ),
        );

        expect(find.text('MSG_ERROR'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  group('row titles', () {
    testWidgets('a group hit is titled with the group name', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [
                _text(
                  receiver: _team,
                  receiverUid: 'g1',
                  receiverType: ReceiverTypeConstants.group,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Design Crew'), findsOneWidget);
    });

    testWidgets('a group hit with no group object falls back to the guid', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [
                _text(
                  receiverUid: 'g-unresolved',
                  receiverType: ReceiverTypeConstants.group,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('g-unresolved'), findsOneWidget);
    });

    testWidgets('a 1:1 hit I received is titled with the sender', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(_messagesState(messages: [_text()])),
        ),
      );

      expect(find.text('Bob Smith'), findsOneWidget);
    });

    testWidgets('a 1:1 hit I sent is titled with the recipient, not me', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [
                _text(sender: _me, receiver: _bob, receiverUid: 'u-bob'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Bob Smith'), findsOneWidget);
      expect(find.text('Me'), findsNothing);
    });

    testWidgets('a 1:1 hit I sent with no receiver object shows the uid', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [_text(sender: _me, receiverUid: 'u-unresolved')],
            ),
          ),
        ),
      );

      expect(find.text('u-unresolved'), findsOneWidget);
    });
  });

  // =========================================================================
  group('card message rows', () {
    CardMessage card(String? text) => CardMessage(
      text: text,
      receiverUid: 'u-me',
      receiverType: ReceiverTypeConstants.user,
      type: MessageTypeConstants.card,
      sender: _bob,
      sentAt: _sentAt,
    );

    testWidgets('a card hit is subtitled with its own text', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(_messagesState(messages: [card('Book a table')])),
        ),
      );

      expect(find.text('Book a table'), findsOneWidget);
    });

    testWidgets('a card with no text falls back to a generic label', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(_messagesState(messages: [card('')])),
        ),
      );

      expect(find.text('Card'), findsOneWidget);
    });
  });

  // =========================================================================
  group('media row subtitle prefix', () {
    testWidgets('a media hit I sent is prefixed with You:', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [_media(type: MessageTypeConstants.file, sender: _me)],
            ),
          ),
        ),
      );

      expect(find.textContaining('You:'), findsOneWidget);
    });

    testWidgets('a media hit from someone else is prefixed with their first '
        'name only', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(messages: [_media(type: MessageTypeConstants.file)]),
          ),
        ),
      );

      expect(find.textContaining('Bob:'), findsOneWidget);
      expect(find.textContaining('Bob Smith:'), findsNothing);
    });

    testWidgets('a nameless sender contributes no prefix', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [
                _media(
                  type: MessageTypeConstants.file,
                  sender: User(uid: 'u-x', name: ''),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining(':'), findsNothing);
    });
  });

  // =========================================================================
  group('media thumbnails', () {
    testWidgets(
      'an image hit with an attachment gets a thumbnail, not a date',
      (tester) async {
        await _pump(
          tester,
          CometChatSearch(
            searchBloc: _blocIn(
              _messagesState(
                messages: [
                  _media(
                    attachments: [
                      _attachment('a.png', 'https://media.test/a.png'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CometChatImageBubble), findsOneWidget);
      },
    );

    testWidgets('an image hit with no attachment falls back to the date', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(_messagesState(messages: [_media()])),
        ),
      );

      expect(find.byType(CometChatImageBubble), findsNothing);
      expect(find.byType(CometChatDate), findsWidgets);
    });

    testWidgets('a second attachment adds a +N overflow scrim', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [
                _media(
                  attachments: [
                    _attachment('a.png', 'https://media.test/a.png'),
                    _attachment('b.png', 'https://media.test/b.png'),
                    _attachment('c.png', 'https://media.test/c.png'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('a single attachment adds no scrim', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [
                _media(
                  attachments: [
                    _attachment('a.png', 'https://media.test/a.png'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('a video hit uses the video bubble', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [
                _media(
                  type: MessageTypeConstants.video,
                  attachments: [
                    _attachment('a.mp4', 'https://media.test/a.mp4'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CometChatVideoBubble), findsOneWidget);
      expect(find.byType(CometChatImageBubble), findsNothing);
    });

    testWidgets('a video with a metadata thumbnail skips the frame extractor', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _messagesState(
              messages: [
                _media(
                  type: MessageTypeConstants.video,
                  attachments: [
                    _attachment('a.mp4', 'https://media.test/a.mp4'),
                  ],
                  metadata: const {
                    '@injected': {
                      'extensions': {
                        'thumbnail-generation': {
                          'url_small': 'https://media.test/thumb.png',
                        },
                      },
                    },
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CometChatVideoBubble), findsOneWidget);
      expect(find.byType(CometChatVideoFirstFrame), findsNothing);
    });
  });

  // =========================================================================
  group('conversation receipt', () {
    testWidgets(
      'a delivered-but-unread own message shows a delivered receipt',
      (tester) async {
        await _pump(
          tester,
          CometChatSearch(
            searchBloc: _blocIn(
              _conversationsState(
                conversations: [
                  _conversation(
                    last: _text(sender: _me, receiverUid: 'u-bob')
                      ..deliveredAt = _sentAt,
                  ),
                ],
              ),
            ),
          ),
        );

        final receipt = tester.widget<CometChatReceipt>(
          find.byType(CometChatReceipt),
        );
        expect(receipt.status, ReceiptStatus.delivered);
      },
    );

    testWidgets('a read own message shows a read receipt', (tester) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _conversationsState(
              conversations: [
                _conversation(
                  last: _text(sender: _me, receiverUid: 'u-bob')
                    ..deliveredAt = _sentAt
                    ..readAt = _sentAt,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.widget<CometChatReceipt>(find.byType(CometChatReceipt)).status,
        ReceiptStatus.read,
      );
    });

    testWidgets('a message from the other side carries no receipt', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatSearch(
          searchBloc: _blocIn(
            _conversationsState(conversations: [_conversation(last: _text())]),
          ),
        ),
      );

      expect(find.byType(CometChatReceipt), findsNothing);
    });
  });
}
