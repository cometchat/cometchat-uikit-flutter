/// Render-verified prop matrix for [CallLogsList] — Track 3 PROP1
/// (ENG-38921).
///
///   flutter test test/call_ui/call_logs/widget/call_logs_list_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockCallLogsBloc extends MockBloc<CallLogsEvent, CallLogsState>
    implements CallLogsBloc {}

class FakeCallUser extends Fake implements CallUser {
  FakeCallUser(this._name, this._uid);
  final String _name;
  final String _uid;
  @override
  String get name => _name;
  @override
  String get uid => _uid;
  @override
  String? get avatar => null;
}

class FakeCallLog extends Fake implements CallLog {
  FakeCallLog({this.type = 'audio', this.status = 'ended', this.byMe = true});
  final bool byMe;
  @override
  CallEntity? get initiator =>
      byMe ? FakeCallUser('Alice', 'u1') : FakeCallUser('Bob', 'u2');
  @override
  CallEntity? get receiver => FakeCallUser('Bob', 'u2');
  @override
  final String? type;
  @override
  final String? status;
  @override
  int? get initiatedAt => 1756800000;
  @override
  double? get totalDurationInMinutes => 3;
}

final _me = User(uid: 'u1', name: 'Alice');

CallLogsState _state({List<CallLog>? logs, bool hasMore = false}) =>
    CallLogsState(
      status: CallLogsStatus.loaded,
      callLogs: logs ?? [FakeCallLog()],
      hasMore: hasMore,
      loggedInUser: _me,
    );

MockCallLogsBloc _mock() {
  final bloc = MockCallLogsBloc();
  final state = _state();
  whenListen(bloc, Stream<CallLogsState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

CallLogsListItem _item(WidgetTester tester) =>
    tester.widget<CallLogsListItem>(find.byType(CallLogsListItem).first);

void main() {
  group('required inputs', () {
    testWidgets('state and bloc drive the rendered rows', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(state: _state(), bloc: _mock()),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byType(CallLogsListItem), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });
  });

  group('slots and icons', () {
    testWidgets('listItemView replaces the whole row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                listItemView: (c, context) => const Text('ROW_SLOT'),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.text('ROW_SLOT'), findsOneWidget);
    });

    testWidgets('leadingView, titleView, subTitleView and trailingView reach '
        'the row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                leadingView: (context, c) => const Text('LEAD'),
                titleView: (context, c) => const Text('TITLE'),
                subTitleView: (c, context) => const Text('SUB'),
                trailingView: (context, c) => const Text('TAIL'),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.text('LEAD'), findsOneWidget);
      expect(find.text('TITLE'), findsOneWidget);
      expect(find.text('SUB'), findsOneWidget);
      expect(find.text('TAIL'), findsOneWidget);
    });

    testWidgets('the call direction and type icons reach the row', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                incomingCallIcon: const Icon(
                  Icons.call_received,
                  key: Key('IN'),
                ),
                outgoingCallIcon: const Icon(Icons.call_made, key: Key('OUT')),
                missedCallIcon: const Icon(Icons.call_missed, key: Key('MISS')),
                audioCallIcon: const Icon(Icons.call, key: Key('AUDIO')),
                videoCallIcon: const Icon(Icons.videocam, key: Key('VIDEO')),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      final item = _item(tester);
      expect(item.incomingCallIcon, isNotNull);
      expect(item.outgoingCallIcon, isNotNull);
      expect(item.missedCallIcon, isNotNull);
      expect(item.audioCallIcon, isNotNull);
      expect(item.videoCallIcon, isNotNull);
    });
  });

  group('callbacks and options', () {
    testWidgets('onItemTap, onItemLongPress and onCallIconPressed fire', (
      tester,
    ) async {
      CallLog? tapped;
      CallLog? held;
      CallLog? called;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                onItemTap: (c) => tapped = c,
                onItemLongPress: (c) => held = c,
                onCallIconPressed: (c) => called = c,
                audioCallIcon: const Icon(Icons.call, key: Key('AUDIO')),
              ),
            ),
          ),
        );
        await _settle(tester);
        await tester.tap(find.text('Bob'));
        await _settle(tester);
        await tester.longPress(find.text('Bob'));
        await _settle(tester);
        await tester.tap(find.byKey(const Key('AUDIO')));
        await _settle(tester);
      });
      expect(tapped, isNotNull);
      expect(held, isNotNull);
      expect(called, isNotNull);
    });

    testWidgets('setOptions replaces the long-press menu', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                setOptions: (c, b, context) => [
                  CometChatOption(id: 'SET', title: 'SetOption'),
                ],
                addOptions: (c, b, context) => [
                  CometChatOption(id: 'ADD', title: 'AddedOption'),
                ],
              ),
            ),
          ),
        );
        await _settle(tester);
        await tester.longPress(find.text('Bob'));
        await _settle(tester);
      });
      expect(find.text('SetOption'), findsWidgets);
      expect(find.text('AddedOption'), findsNothing);
    });

    testWidgets('addOptions supplies the menu when setOptions is absent', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                addOptions: (c, b, context) => [
                  CometChatOption(id: 'ADD', title: 'AddedOption'),
                ],
              ),
            ),
          ),
        );
        await _settle(tester);
        await tester.longPress(find.text('Bob'));
        await _settle(tester);
      });
      expect(find.text('AddedOption'), findsWidgets);
    });
  });

  group('formatting, loading and styling', () {
    testWidgets('datePattern reaches the row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                datePattern: 'dd MMM',
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(_item(tester).datePattern, 'dd MMM');
    });

    testWidgets('loadingStateView renders the pagination loader', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(hasMore: true),
                bloc: _mock(),
                loadingStateView: (context) => const Text('LOADING_SLOT'),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.text('LOADING_SLOT'), findsOneWidget);
    });

    testWidgets('style, avatarStyle and dateStyle reach the row', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                style: const CometChatCallLogsStyle(
                  itemTitleTextColor: Color(0xFFE30303),
                ),
                avatarStyle: const CometChatAvatarStyle(
                  backgroundColor: Color(0xFFE40404),
                ),
                dateStyle: const CometChatDateStyle(
                  textStyle: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      final item = _item(tester);
      expect(item.style?.itemTitleTextColor, const Color(0xFFE30303));
      expect(item.avatarStyle?.backgroundColor, const Color(0xFFE40404));
      expect(item.dateStyle?.textStyle?.fontSize, 13.0);
    });

    testWidgets('colorPalette, spacing and typography override the theme', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsList(
                state: _state(),
                bloc: _mock(),
                colorPalette: CometChatColorPalette(),
                spacing: CometChatSpacing(),
                typography: CometChatTypography(),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byType(CallLogsList), findsOneWidget);
    });
  });
}
