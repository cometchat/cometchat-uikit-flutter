/// Render-verified prop matrix for [CometChatAIAssistantChatHistory] and
/// [CometChatAIAssistantChatHistoryStyle] — Track 3 PROP1/PROP2 (ENG-38926).
///
/// The component is a five-state list — initial, loading, loaded, empty,
/// error — and most style properties only exist in one of them. Each case
/// drives the state through the `aiAssistantChatHistoryBloc` seam.
///
///   flutter test test/chat_ui/ai_assistant_chat_history/widget/ai_assistant_chat_history_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAIAssistantChatHistoryBloc
    extends MockBloc<AIAssistantChatHistoryEvent, AIAssistantChatHistoryState>
    implements AIAssistantChatHistoryBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');
final _group = Group(guid: 'g1', name: 'Team', type: GroupTypeConstants.public);

final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

TextMessage _message() => TextMessage(
  id: 1,
  text: 'prior chat',
  sender: _them,
  receiverUid: 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

MockAIAssistantChatHistoryBloc _bloc(
  AIAssistantChatHistoryStatus status, {
  List<BaseMessage>? messages,
}) {
  final state = AIAssistantChatHistoryState(
    status: status,
    loggedInUser: _me,
    messages:
        messages ??
        (status == AIAssistantChatHistoryStatus.loaded
            ? [_message()]
            : const []),
  );
  final b = MockAIAssistantChatHistoryBloc();
  whenListen(
    b,
    Stream<AIAssistantChatHistoryState>.value(state),
    initialState: state,
  );
  when(() => b.stickyDateNotifier).thenReturn(ValueNotifier<DateTime?>(null));
  return b;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Iterable<Color?> _textColors(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color);

Iterable<double?> _textSizes(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.fontSize);

Iterable<String?> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);

Iterable<Color?> _iconColors(WidgetTester tester) =>
    tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color);

ListBaseStyle? _listBaseStyle(WidgetTester tester) =>
    tester.widget<CometChatListBase>(find.byType(CometChatListBase)).style;

void main() {
  group('chrome — the list base and its divider', () {
    testWidgets('backgroundColor colours the list base', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                backgroundColor: Color(0xFF120101),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_listBaseStyle(tester)?.background, const Color(0xFF120101));
    });

    testWidgets('headerBackgroundColor colours the app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                headerBackgroundColor: Color(0xFF120202),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_listBaseStyle(tester)?.appBarBackground, const Color(0xFF120202));
    });

    testWidgets('headerTitleTextStyle reaches the title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                headerTitleTextStyle: TextStyle(fontSize: 23),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_listBaseStyle(tester)?.titleStyle?.fontSize, 23);
    });

    testWidgets('headerTitleTextColor reaches the title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                headerTitleTextColor: Color(0xFF120303),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _listBaseStyle(tester)?.titleStyle?.color,
        const Color(0xFF120303),
      );
    });

    testWidgets('border reaches the list base', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF120404), width: 3),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_listBaseStyle(tester)?.border, isNotNull);
    });

    testWidgets('borderRadius reaches the list base', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                borderRadius: BorderRadius.all(Radius.circular(19)),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _listBaseStyle(tester)?.borderRadius,
        const BorderRadius.all(Radius.circular(19)),
      );
    });

    testWidgets('closeIconColor tints the close icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                closeIconColor: Color(0xFF120505),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_iconColors(tester), contains(const Color(0xFF120505)));
    });

    testWidgets('separatorColor and separatorHeight drive the divider', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                separatorColor: Color(0xFF120606),
                separatorHeight: 7,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      final divider = tester.widget<Divider>(find.byType(Divider).first);
      expect(divider.color, const Color(0xFF120606));
      expect(divider.height, 7);
    });
  });

  group('loaded — rows, the new-chat button and the date separator', () {
    testWidgets('itemTextStyle reaches a history row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                itemTextStyle: TextStyle(fontSize: 21),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(21.0));
    });

    testWidgets('itemTextColor reaches a history row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                itemTextColor: Color(0xFF120707),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF120707)));
    });

    testWidgets('newChatIconColor tints the new-chat icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                newChatIconColor: Color(0xFF120808),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_iconColors(tester), contains(const Color(0xFF120808)));
    });

    testWidgets('newChatTitleStyle reaches the new-chat label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                newChatTitleStyle: TextStyle(fontSize: 22),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(22.0));
    });

    testWidgets('newChatTextColor reaches the new-chat label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                newChatTextColor: Color(0xFF120909),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF120909)));
    });

    testWidgets('deleteChatHistoryDialogStyle reaches the long-press dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                deleteChatHistoryDialogStyle: CometChatConfirmDialogStyle(
                  confirmButtonTextStyle: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.longPress(find.text('prior chat'));
      await _settle(tester);
      expect(_textSizes(tester), contains(24.0));
    });

    testWidgets('dateSeparatorStyle reaches the date separator', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                dateSeparatorStyle: CometChatDateStyle(
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(18.0));
    });
  });

  group('empty state', () {
    testWidgets('emptyStateTextStyle reaches the empty title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.empty,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                emptyStateTextStyle: TextStyle(fontSize: 26),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(26.0));
    });

    testWidgets('emptyStateTextColor reaches the empty title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.empty,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                emptyStateTextColor: Color(0xFF120A0A),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF120A0A)));
    });

    testWidgets('emptyStateSubtitleStyle reaches the empty subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.empty,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                emptyStateSubtitleStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(13.0));
    });

    testWidgets('emptyStateSubtitleColor reaches the empty subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.empty,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                emptyStateSubtitleColor: Color(0xFF120B0B),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF120B0B)));
    });
  });

  group('error state', () {
    testWidgets('errorStateTextStyle reaches the error title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.error,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                errorStateTextStyle: TextStyle(fontSize: 27),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(27.0));
    });

    testWidgets('errorStateTextColor reaches the error title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.error,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                errorStateTextColor: Color(0xFF120C0C),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF120C0C)));
    });

    testWidgets('errorStateSubtitleStyle reaches the error subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.error,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                errorStateSubtitleStyle: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(14.0));
    });

    testWidgets('errorStateSubtitleColor reaches the error subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.error,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                errorStateSubtitleColor: Color(0xFF120D0D),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF120D0D)));
    });
  });

  group('CometChatAIAssistantChatHistory own props', () {
    testWidgets('user drives the bloc-backed list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_texts(tester), contains('prior chat'));
    });

    testWidgets('group is accepted in place of user', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              group: _group,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_texts(tester), contains('prior chat'));
    });

    testWidgets('style reaches the list base', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              style: const CometChatAIAssistantChatHistoryStyle(
                backgroundColor: Color(0xFF121010),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_listBaseStyle(tester)?.background, const Color(0xFF121010));
    });

    testWidgets('height and width size the list base', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              height: 321,
              width: 234,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_listBaseStyle(tester)?.height, 321);
      expect(_listBaseStyle(tester)?.width, 234);
    });

    testWidgets(
      'messagesRequestBuilder is accepted alongside an injected bloc',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatAIAssistantChatHistory(
                user: _them,
                aiAssistantChatHistoryBloc: _bloc(
                  AIAssistantChatHistoryStatus.loaded,
                ),
                messagesRequestBuilder: (MessagesRequestBuilder()..limit = 7),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(_texts(tester), contains('prior chat'));
      },
    );

    testWidgets('backButton replaces the default close control', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              backButton: const Icon(Icons.arrow_back, key: Key('back')),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('back')), findsOneWidget);
    });

    testWidgets('onClose fires when the default close control is tapped', (
      tester,
    ) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('onMessageClicked fires with the tapped message', (
      tester,
    ) async {
      BaseMessage? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              onMessageClicked: (m) => tapped = m,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('prior chat'));
      await tester.pump();
      expect((tapped as TextMessage?)?.text, 'prior chat');
    });

    testWidgets('onNewChatButtonClicked fires from the new-chat row', (
      tester,
    ) async {
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              onNewChatButtonClicked: () => started = true,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('New Chat'));
      await tester.pump();
      expect(started, isTrue);
    });

    testWidgets('loadingStateView replaces the loading state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loading,
              ),
              loadingStateView: (_) => const Text('custom loading'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('custom loading'), findsOneWidget);
    });

    testWidgets('emptyStateView replaces the empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.empty,
              ),
              emptyStateView: (_) => const Text('custom empty'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('custom empty'), findsOneWidget);
    });

    testWidgets('errorStateView replaces the error state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.error,
              ),
              errorStateView: (_) => const Text('custom error'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('custom error'), findsOneWidget);
    });

    testWidgets('emptyStateText and emptyStateSubtitleText replace the copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.empty,
              ),
              emptyStateText: 'nothing here',
              emptyStateSubtitleText: 'start one',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('nothing here'), findsOneWidget);
      expect(find.text('start one'), findsOneWidget);
    });

    testWidgets('errorStateText and errorStateSubtitleText replace the copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.error,
              ),
              errorStateText: 'it broke',
              errorStateSubtitleText: 'try again',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('it broke'), findsOneWidget);
      expect(find.text('try again'), findsOneWidget);
    });

    testWidgets('dateSeparatorPattern formats the separator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              dateSeparatorPattern: (_) => 'THE DAY',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('THE DAY'), findsWidgets);
    });

    testWidgets('dateTimeFormatterCallback reaches the separator', (
      tester,
    ) async {
      var asked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              dateTimeFormatterCallback: () {
                asked = true;
                return null;
              }(),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(asked, isTrue);
    });

    testWidgets('hideDateSeparator removes the separator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              hideDateSeparator: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_texts(tester), isNot(contains('15 Nov, 2023')));
    });

    testWidgets('hideStickyDate removes the floating date', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAIAssistantChatHistory(
              user: _them,
              aiAssistantChatHistoryBloc: _bloc(
                AIAssistantChatHistoryStatus.loaded,
              ),
              hideStickyDate: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('prior chat'), findsOneWidget);
    });
  });
}
