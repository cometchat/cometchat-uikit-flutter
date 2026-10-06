/// Call-log rows for group calls, and rows with no logged-in user (round 5,
/// P5-C13), in [CometChatCallLogs], the public [CallLogsList] and
/// [CallLogsListItem].
///
/// A group call somebody else started showed its initiator as the row (the
/// call logs hide group calls by default since P5-C12, so only a host that
/// asks for them sees these rows). And a row dereferenced
/// `state.loggedInUser!`, so a list whose logged-in user could not be read
/// threw instead of rendering.
///
///   flutter test test/call_ui/call_logs/widget/call_logs_group_rows_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockCallLogsBloc extends MockBloc<CallLogsEvent, CallLogsState>
    implements CallLogsBloc {}

final _me = User(uid: 'me', name: 'Me');

/// A group call Them started in Team.
CallLog _groupLog() => CallLog(
  sessionId: 'g-session',
  receiverType: 'group',
  type: CallTypeConstants.audioCall,
  status: CallStatusConstants.ended,
  initiatedAt: 1756800000,
  initiator: CallUser(uid: 'them', name: 'Them'),
  receiver: CallGroup(guid: 'team', name: 'Team'),
);

/// A 1:1 call Bob placed to me.
CallLog _bobLog() => CallLog(
  sessionId: 'u-session',
  receiverType: 'user',
  type: CallTypeConstants.audioCall,
  status: CallStatusConstants.ended,
  initiatedAt: 1756800000,
  initiator: CallUser(uid: 'bob', name: 'Bob'),
  receiver: CallUser(uid: 'me', name: 'Me'),
);

CallLogsState _state({User? loggedInUser}) => CallLogsState(
  status: CallLogsStatus.loaded,
  callLogs: [_groupLog(), _bobLog()],
  loggedInUser: loggedInUser,
);

_MockCallLogsBloc _bloc(CallLogsState state) {
  final bloc = _MockCallLogsBloc();
  when(() => bloc.state).thenReturn(state);
  when(() => bloc.isClosed).thenReturn(false);
  whenListen(bloc, Stream<CallLogsState>.value(state), initialState: state);
  return bloc;
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

/// The titles the rows render, in order.
List<String> _titles(WidgetTester tester) => tester
    .widgetList<CometChatListItem>(find.byType(CometChatListItem))
    .map((item) => item.title ?? '')
    .toList();

void main() {
  group('CometChatCallLogs', () {
    testWidgets('P5-C13: a group call somebody else started shows the group, '
        'not its initiator', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _app(
            CometChatCallLogs(callLogsBloc: _bloc(_state(loggedInUser: _me))),
          ),
        );
        await tester.pump();
      });
      expect(_titles(tester), ['Team', 'Bob']);
      expect(find.text('Them'), findsNothing);
    });

    testWidgets('P5-C13: with no logged-in user the rows render, a 1:1 one '
        'with an empty title', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _app(CometChatCallLogs(callLogsBloc: _bloc(_state()))),
        );
        await tester.pump();
      });
      expect(tester.takeException(), isNull);
      expect(_titles(tester), ['Team', '']);
    });
  });

  group('CallLogsList', () {
    testWidgets('P5-C13: with no logged-in user the rows render, a 1:1 one '
        'with an empty title', (tester) async {
      final state = _state();
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _app(CallLogsList(state: state, bloc: _bloc(state))),
        );
        await tester.pump();
      });
      expect(tester.takeException(), isNull);
      expect(_titles(tester), ['Team', '']);
    });

    testWidgets('P5-C13: a group call somebody else started shows the group', (
      tester,
    ) async {
      final state = _state(loggedInUser: _me);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _app(CallLogsList(state: state, bloc: _bloc(state))),
        );
        await tester.pump();
      });
      expect(_titles(tester), ['Team', 'Bob']);
    });
  });

  testWidgets('P5-C13: CallLogsListItem shows the group of a group call', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _app(CallLogsListItem(callLog: _groupLog(), loggedInUser: _me)),
      );
      await tester.pump();
    });
    expect(_titles(tester), ['Team']);
  });
}
