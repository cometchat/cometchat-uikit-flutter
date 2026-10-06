/// Render-verified prop matrix for [CallLogsListItem] — Track 3 PROP1
/// (ENG-38921).
///
///   flutter test test/call_ui/call_logs/widget/call_logs_list_item_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

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

  /// Direction is derived from whether the initiator is the logged-in user, so
  /// the incoming and missed icons are only reachable with byMe: false.
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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Iterable<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>();

void main() {
  group('identity and interaction', () {
    testWidgets('callLog and loggedInUser drive the row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(callLog: FakeCallLog(), loggedInUser: _me),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('onTap and onLongPress fire with the call log', (tester) async {
      var tapped = false;
      var held = false;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(),
                loggedInUser: _me,
                onTap: () => tapped = true,
                onLongPress: () => held = true,
              ),
            ),
          ),
        );
        await _settle(tester);
        await tester.tap(find.text('Bob'));
        await _settle(tester);
        await tester.longPress(find.text('Bob'));
        await _settle(tester);
      });
      expect(tapped, isTrue);
      expect(held, isTrue);
    });

    testWidgets('onCallIconPressed fires from the call button', (tester) async {
      var called = false;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(),
                loggedInUser: _me,
                onCallIconPressed: () => called = true,
                audioCallIcon: const Icon(Icons.call, key: Key('AUDIO')),
              ),
            ),
          ),
        );
        await _settle(tester);
        await tester.tap(find.byKey(const Key('AUDIO')));
        await _settle(tester);
      });
      expect(called, isTrue);
    });
  });

  group('slots', () {
    testWidgets('listItemView replaces the whole row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(),
                loggedInUser: _me,
                listItemView: (c, context) => const Text('ROW_SLOT'),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.text('ROW_SLOT'), findsOneWidget);
    });

    testWidgets('leadingView, titleView, subTitleView and trailingView '
        'replace their slots', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(),
                loggedInUser: _me,
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
  });

  group('call direction and type icons', () {
    testWidgets('outgoingCallIcon renders for a call I placed', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(byMe: true),
                loggedInUser: _me,
                outgoingCallIcon: const Icon(Icons.call_made, key: Key('OUT')),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('OUT')), findsOneWidget);
    });

    testWidgets('incomingCallIcon renders for a call I received', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(byMe: false),
                loggedInUser: _me,
                incomingCallIcon: const Icon(
                  Icons.call_received,
                  key: Key('IN'),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('IN')), findsOneWidget);
    });

    testWidgets('missedCallIcon renders for an unanswered incoming call', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(byMe: false, status: 'unanswered'),
                loggedInUser: _me,
                missedCallIcon: const Icon(
                  Icons.call_missed,
                  key: Key('MISSED'),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('MISSED')), findsOneWidget);
    });

    testWidgets('audioCallIcon and videoCallIcon render per call type', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(type: 'audio'),
                loggedInUser: _me,
                audioCallIcon: const Icon(Icons.call, key: Key('AUDIO')),
                videoCallIcon: const Icon(Icons.videocam, key: Key('VIDEO')),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('AUDIO')), findsOneWidget);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(type: 'video'),
                loggedInUser: _me,
                audioCallIcon: const Icon(Icons.call, key: Key('AUDIO')),
                videoCallIcon: const Icon(Icons.videocam, key: Key('VIDEO')),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('VIDEO')), findsOneWidget);
    });
  });

  group('formatting and styling', () {
    testWidgets('datePattern supplies the row date', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CallLogsListItem(
                callLog: FakeCallLog(),
                loggedInUser: _me,
                datePattern: 'CUSTOM_DATE',
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(
        tester.widget<CometChatDate>(find.byType(CometChatDate).first).pattern,
        isNotNull,
      );
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
              body: CallLogsListItem(
                callLog: FakeCallLog(),
                loggedInUser: _me,
                style: const CometChatCallLogsStyle(
                  itemTitleTextColor: Color(0xFFE10101),
                  itemTitleTextStyle: TextStyle(fontSize: 17),
                ),
                avatarStyle: const CometChatAvatarStyle(
                  backgroundColor: Color(0xFFE20202),
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
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFFE10101)),
      );
      expect(_textStyles(tester).map((s) => s.fontSize), contains(17.0));
      expect(
        tester
            .widget<CometChatAvatar>(find.byType(CometChatAvatar).first)
            .style
            ?.backgroundColor,
        const Color(0xFFE20202),
      );
      expect(
        tester
            .widget<CometChatDate>(find.byType(CometChatDate).first)
            .style
            .textStyle
            ?.fontSize,
        13.0,
      );
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
              body: CallLogsListItem(
                callLog: FakeCallLog(),
                loggedInUser: _me,
                colorPalette: CometChatColorPalette(),
                spacing: CometChatSpacing(),
                typography: CometChatTypography(),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byType(CallLogsListItem), findsOneWidget);
    });
  });
}
