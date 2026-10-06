/// Behaviour of [CometChatAIAssistantChatHistory] — the parts of the widget
/// that no prop exercises.
///
/// `ai_assistant_chat_history_props_test.dart` pins the prop matrix; this
/// covers what the component *does*: the built-in loading and error affordances
/// and the events they raise, the pagination row, the date separator's
/// same-day/deleted rules, the sticky date the scroll listener publishes, and
/// the delete confirmation's two exits.
///
///   flutter test test/chat_ui/ai_assistant_chat_history/widget/ai_assistant_chat_history_behaviour_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_sdk_chat_history.dart';

class _MockBloc
    extends MockBloc<AIAssistantChatHistoryEvent, AIAssistantChatHistoryState>
    implements AIAssistantChatHistoryBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');

/// 15 Nov 2023 and 16 Nov 2023, fixed so no test depends on the clock.
final _day1 = DateTime(2023, 11, 15, 9);
final _day1Later = DateTime(2023, 11, 15, 18);
final _day2 = DateTime(2023, 11, 16, 9);

TextMessage _message(int id, String text, DateTime sentAt) => TextMessage(
  id: id,
  text: text,
  sender: _them,
  receiverUid: 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: sentAt,
);

_MockBloc _bloc(
  AIAssistantChatHistoryStatus status, {
  List<BaseMessage> messages = const [],
  bool hasMore = false,
  ValueNotifier<DateTime?>? sticky,
}) {
  final state = AIAssistantChatHistoryState(
    status: status,
    loggedInUser: _me,
    messages: messages,
    hasMore: hasMore,
  );
  final b = _MockBloc();
  whenListen(
    b,
    Stream<AIAssistantChatHistoryState>.value(state),
    initialState: state,
  );
  when(
    () => b.stickyDateNotifier,
  ).thenReturn(sticky ?? ValueNotifier<DateTime?>(null));
  when(() => b.items).thenReturn(messages);
  return b;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // =========================================================================
  group('the built-in loading state', () {
    testWidgets('an initial bloc shows the shimmer, not the list', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: _bloc(
            AIAssistantChatHistoryStatus.initial,
          ),
        ),
      );

      expect(find.byType(CometChatShimmerEffect), findsOneWidget);
    });

    testWidgets('loading shows the shimmer too', (tester) async {
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: _bloc(
            AIAssistantChatHistoryStatus.loading,
          ),
        ),
      );

      expect(find.byType(CometChatShimmerEffect), findsOneWidget);
    });
  });

  // =========================================================================
  group('the built-in error state', () {
    testWidgets('its retry control asks the bloc to load again', (
      tester,
    ) async {
      final bloc = _bloc(AIAssistantChatHistoryStatus.error);
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: bloc,
        ),
      );

      // The bloc is handed to the widget already loaded, so nothing has been
      // asked of it yet.
      verifyNever(() => bloc.add(const LoadChatHistory()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pump();

      verify(() => bloc.add(const LoadChatHistory())).called(1);
    });
  });

  // =========================================================================
  group('pagination', () {
    testWidgets('hasMore appends a spinner row and asks for the next page', (
      tester,
    ) async {
      final bloc = _bloc(
        AIAssistantChatHistoryStatus.loaded,
        messages: [_message(1, 'first', _day1)],
        hasMore: true,
      );
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: bloc,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verify(() => bloc.add(const LoadMoreChatHistory())).called(1);
    });

    testWidgets('without hasMore there is no spinner and no page request', (
      tester,
    ) async {
      final bloc = _bloc(
        AIAssistantChatHistoryStatus.loaded,
        messages: [_message(1, 'first', _day1)],
      );
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: bloc,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      verifyNever(() => bloc.add(const LoadMoreChatHistory()));
    });
  });

  // =========================================================================
  group('the date separator', () {
    testWidgets('two messages on the same day share one separator', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: _bloc(
            AIAssistantChatHistoryStatus.loaded,
            messages: [
              _message(1, 'morning', _day1),
              _message(2, 'evening', _day1Later),
            ],
          ),
        ),
      );

      expect(find.text('15 Nov, 2023'), findsOneWidget);
    });

    testWidgets('a message on the next day gets its own separator', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: _bloc(
            AIAssistantChatHistoryStatus.loaded,
            messages: [
              _message(1, 'monday', _day1),
              _message(2, 'tuesday', _day2),
            ],
          ),
        ),
      );

      expect(find.text('15 Nov, 2023'), findsOneWidget);
      expect(find.text('16 Nov, 2023'), findsOneWidget);
    });

    testWidgets('a deleted message carries no separator, even on a new day', (
      tester,
    ) async {
      final deleted = _message(2, 'gone', _day2)..deletedAt = _day2;
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: _bloc(
            AIAssistantChatHistoryStatus.loaded,
            messages: [_message(1, 'monday', _day1), deleted],
          ),
        ),
      );

      expect(find.text('15 Nov, 2023'), findsOneWidget);
      expect(find.text('16 Nov, 2023'), findsNothing);
    });

    testWidgets('dateSeparatorPattern replaces the rendered date', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: _bloc(
            AIAssistantChatHistoryStatus.loaded,
            messages: [_message(1, 'monday', _day1)],
          ),
          dateSeparatorPattern: (date) => 'day ${date.day}',
        ),
      );

      expect(find.text('day 15'), findsOneWidget);
    });
  });

  // =========================================================================
  group('the sticky date header', () {
    testWidgets('scrolling publishes the date of the first visible message', (
      tester,
    ) async {
      final sticky = ValueNotifier<DateTime?>(null);
      final messages = [
        for (var i = 0; i < 30; i++)
          _message(i, 'row $i', i < 15 ? _day1 : _day2),
      ];
      final bloc = _bloc(
        AIAssistantChatHistoryStatus.loaded,
        messages: messages,
        sticky: sticky,
      );
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          dateSeparatorPattern: (date) => 'day ${date.day}',
          aiAssistantChatHistoryBloc: bloc,
        ),
      );

      // Nothing is published until the list actually moves.
      expect(sticky.value, isNull);

      await tester.drag(find.text('row 0'), const Offset(0, -1000));
      await tester.pump();

      // offset / 60 picks the row the header should name.
      expect(sticky.value, isNotNull);
      expect(sticky.value, messages.first.sentAt);
      // And the pattern the caller gave is formatted into the header's
      // custom string rather than the default date format.
      verify(() => bloc.stickyDateString = 'day 15').called(greaterThan(0));
    });

    testWidgets('hideStickyDate stops the scroll listener publishing', (
      tester,
    ) async {
      final sticky = ValueNotifier<DateTime?>(null);
      final messages = [
        for (var i = 0; i < 30; i++) _message(i, 'row $i', _day1),
      ];
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          hideStickyDate: true,
          aiAssistantChatHistoryBloc: _bloc(
            AIAssistantChatHistoryStatus.loaded,
            messages: messages,
            sticky: sticky,
          ),
        ),
      );

      await tester.drag(find.text('row 0'), const Offset(0, -1000));
      await tester.pump();

      expect(sticky.value, isNull);
    });

    testWidgets('a sticky date the bloc already carries renders straight away', (
      tester,
    ) async {
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: _bloc(
            AIAssistantChatHistoryStatus.loaded,
            messages: [_message(1, 'row', _day1)],
            sticky: ValueNotifier<DateTime?>(_day2),
          ),
          hideDateSeparator: true,
        ),
      );

      // The separator is hidden, so this date can only be the floating header.
      expect(find.text('16 Nov, 2023'), findsOneWidget);
    });
  });

  // =========================================================================
  group('the delete confirmation', () {
    testWidgets('confirming asks the bloc to delete that message and closes', (
      tester,
    ) async {
      final message = _message(1, 'prior chat', _day1);
      final bloc = _bloc(
        AIAssistantChatHistoryStatus.loaded,
        messages: [message],
      );
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: bloc,
        ),
      );

      await tester.longPress(find.text('prior chat'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this conversation?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(DeleteChatHistoryMessage(message))).called(1);
      expect(find.text('Delete this conversation?'), findsNothing);
    });

    testWidgets('cancelling closes the dialog and deletes nothing', (
      tester,
    ) async {
      final message = _message(1, 'prior chat', _day1);
      final bloc = _bloc(
        AIAssistantChatHistoryStatus.loaded,
        messages: [message],
      );
      await _pump(
        tester,
        CometChatAIAssistantChatHistory(
          user: _them,
          aiAssistantChatHistoryBloc: bloc,
        ),
      );

      await tester.longPress(find.text('prior chat'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this conversation?'), findsNothing);
      verifyNever(() => bloc.add(DeleteChatHistoryMessage(message)));
    });
  });

  // =========================================================================
  group('with no bloc injected', () {
    setUp(registerFakeChatHistoryBackend);
    tearDown(clearFakeChatHistoryBackend);

    testWidgets('it builds its own bloc and loads through it', (tester) async {
      fakeLoggedInUser = () => _me;
      var page = 0;
      // One page, then nothing — otherwise the list keeps paginating.
      fakeMessagePage = () =>
          page++ == 0 ? [_message(1, 'from the SDK', _day1)] : const [];

      await _pump(tester, CometChatAIAssistantChatHistory(user: _them));
      await tester.pumpAndSettle();

      expect(find.text('from the SDK'), findsOneWidget);
    });

    testWidgets('an empty page lands in the empty state', (tester) async {
      fakeLoggedInUser = () => _me;
      fakeMessagePage = () => const <BaseMessage>[];

      await _pump(tester, CometChatAIAssistantChatHistory(user: _them));
      await tester.pumpAndSettle();

      expect(find.text('No conversation history found.'), findsOneWidget);
    });

    testWidgets('disposing closes the bloc it made', (tester) async {
      fakeLoggedInUser = () => _me;
      var page = 0;
      fakeMessagePage = () =>
          page++ == 0 ? [_message(1, 'from the SDK', _day1)] : const [];

      await _pump(tester, CometChatAIAssistantChatHistory(user: _them));
      await tester.pumpAndSettle();

      // Replacing the widget tears it down; a bloc left open would raise on
      // the emit that follows, and a double close would throw here.
      await _pump(tester, const SizedBox());
      await tester.pumpAndSettle();

      expect(find.byType(CometChatAIAssistantChatHistory), findsNothing);
    });
  });
}
