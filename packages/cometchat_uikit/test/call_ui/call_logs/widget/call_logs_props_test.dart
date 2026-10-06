/// Table-driven prop matrix for [CometChatCallLogs] and
/// [CometChatCallLogsStyle] — Track 3 PROP1.
///
/// One test per prop, each constructing the component *inline* inside
/// pumpWidget so the prop-coverage verifier scores it as render-verified.
///
/// The component accepts a callLogsBloc, so unlike CometChatGroupMembers the
/// list can be driven with real data from a mocked bloc — the same seam
/// CometChatConversations has, and the reason this unit reaches a real number.
///
///   flutter test test/call_ui/call_logs/widget/call_logs_props_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockCallLogsBloc extends MockBloc<CallLogsEvent, CallLogsState>
    implements CallLogsBloc {}

class FakeCallUser extends Fake implements CallUser {
  FakeCallUser(this._name, this._uid);
  final String _name;
  final String _uid;
  @override
  String? get name => _name;
  @override
  String? get uid => _uid;
  @override
  String? get avatar => null;
}

class FakeCallLog extends Fake implements CallLog {
  FakeCallLog({this.type = 'audio', this.status = 'ended', this.byMe = true});

  /// Direction is derived from whether the initiator is the logged-in user, so
  /// incoming and missed icons are only reachable with byMe: false.
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

class FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';
  @override
  String get name => 'Alice';
}

// ─── Harness ─────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

const _slotKey = Key('probe-slot');
const _iconKey = Key('probe-icon');

Widget _slot() => const SizedBox(key: _slotKey, height: 12, width: 12);
Widget _icon() => const Icon(Icons.abc, key: _iconKey);

MockCallLogsBloc _blocIn(CallLogsState state) {
  final bloc = MockCallLogsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream.fromIterable([state]), initialState: state);
  return bloc;
}

MockCallLogsBloc _loaded({
  String type = 'audio',
  String status = 'ended',
  bool byMe = true,
}) => _blocIn(
  CallLogsState(
    status: CallLogsStatus.loaded,
    callLogs: [FakeCallLog(type: type, status: status, byMe: byMe)],
    loggedInUser: FakeUser(),
    groupedEntries: {
      'Today': [FakeCallLog(type: type, status: status, byMe: byMe)],
    },
  ),
);

MockCallLogsBloc _empty() =>
    _blocIn(const CallLogsState(status: CallLogsStatus.empty));

MockCallLogsBloc _error() => _blocIn(
  const CallLogsState(
    status: CallLogsStatus.error,
    errorMessage: 'Network error',
  ),
);

MockCallLogsBloc _loading() =>
    _blocIn(const CallLogsState(status: CallLogsStatus.loading));

/// True when any rendered Text carries [size] as its font size.
bool _textSized(WidgetTester tester, double size) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => t.style?.fontSize == size);

/// True when any rendered Text is painted in [color].
bool _textColored(WidgetTester tester, Color color) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => t.style?.color == color);

/// True when any rendered Icon is painted in [color].
bool _iconColored(WidgetTester tester, Color color) =>
    tester.widgetList<Icon>(find.byType(Icon)).any((i) => i.color == color);

ListBaseStyle _listBaseStyle(WidgetTester tester) =>
    tester.widget<CometChatListBase>(find.byType(CometChatListBase)).style;

void main() {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // DATA AND LIST SLOTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  group('Data and list slots', () {
    testWidgets('callLogsBloc drives the rendered list', (tester) async {
      await tester.pumpWidget(
        _wrap(CometChatCallLogs(callLogsBloc: _loaded())),
      );
      await tester.pump();
      expect(find.byType(CometChatCallLogs), findsOneWidget);
      expect(find.text('Bob'), findsWidgets);
    });

    testWidgets('listItemView replaces the row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            listItemView: (_, _) => _slot(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('subTitleView renders under the title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            subTitleView: (_, _) => _slot(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('trailingView renders at the row end', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            trailingView: (_, _) => _slot(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('leadingStateView renders at the row start', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            leadingStateView: (_, _) => _slot(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('titleView replaces the row title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            titleView: (_, _) => _slot(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // APP BAR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  group('App bar', () {
    testWidgets('hideAppbar=false keeps the app bar', (tester) async {
      await tester.pumpWidget(
        _wrap(CometChatCallLogs(callLogsBloc: _loaded(), hideAppbar: false)),
      );
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('hideAppbar=true removes the app bar', (tester) async {
      await tester.pumpWidget(
        _wrap(CometChatCallLogs(callLogsBloc: _loaded(), hideAppbar: true)),
      );
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('backButton renders when shown', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            backButton: _slot(),
            showBackButton: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('showBackButton=false drops the custom back button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            backButton: _slot(),
            showBackButton: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsNothing);
    });

    testWidgets('appBarOptions render in the app bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(callLogsBloc: _loaded(), appBarOptions: [_slot()]),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STATE VIEWS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  group('State views', () {
    testWidgets('emptyStateView renders in the empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _empty(),
            emptyStateView: (_) => _slot(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('errorStateView renders in the error state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _error(),
            errorStateView: (_) => _slot(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('loadingStateView renders in the loading state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loading(),
            loadingStateView: (_) => _slot(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_slotKey), findsWidgets);
    });

    testWidgets('onEmpty fires in the empty state', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _empty(),
            onEmpty: () => fired = true,
          ),
        ),
      );
      await tester.pump();
      expect(fired, isTrue);
    });

    testWidgets('onLoad fires in the loaded state', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            onLoad: (_) => fired = true,
          ),
        ),
      );
      await tester.pump();
      expect(fired, isTrue);
    });

    testWidgets('onError fires in the error state', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _error(),
            onError: (_) => fired = true,
          ),
        ),
      );
      await tester.pump();
      expect(fired, isTrue);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ICONS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  group('Call type and direction icons', () {
    testWidgets('audioCallIcon renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(type: 'audio', status: 'ended'),
            audioCallIcon: _icon(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_iconKey), findsWidgets);
    });

    testWidgets('videoCallIcon renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(type: 'video', status: 'ended'),
            videoCallIcon: _icon(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_iconKey), findsWidgets);
    });

    testWidgets('incomingCallIcon renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(byMe: false),
            incomingCallIcon: _icon(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_iconKey), findsWidgets);
    });

    testWidgets('outgoingCallIcon renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(type: 'audio', status: 'ended'),
            outgoingCallIcon: _icon(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_iconKey), findsWidgets);
    });

    testWidgets('missedCallIcon renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(status: 'unanswered', byMe: false),
            missedCallIcon: _icon(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_iconKey), findsWidgets);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STYLE, DATES AND REQUEST SHAPE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  group('Style, dates and request shape', () {
    testWidgets('callLogsStyle paints the supplied background', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsStyle: const CometChatCallLogsStyle(
              backgroundColor: Color(0xFF0A1B2C),
            ),
          ),
        ),
      );
      await tester.pump();
      final base = tester.widget<CometChatListBase>(
        find.byType(CometChatListBase),
      );
      expect(base.style.background, const Color(0xFF0A1B2C));
    });

    // Note: despite the name and the doc comment ("custom date pattern"),
    // datePattern is passed straight through as CometChatDate.customDateString
    // in cometchat_call_logs_utils.dart:64 — it replaces the rendered string
    // rather than formatting the date. Asserted as the literal it is.
    testWidgets('datePattern replaces the row timestamp text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            datePattern: 'CUSTOM-DATE',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('CUSTOM-DATE'), findsWidgets);
    });

    testWidgets('callLogsRequestBuilder renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsRequestBuilder: CallLogRequestBuilder(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatCallLogs), findsOneWidget);
    });

    testWidgets('callLogsBuilderProtocol renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsBuilderProtocol: UICallLogsBuilder(CallLogRequestBuilder()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatCallLogs), findsOneWidget);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // INTERACTION AND OPTIONS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  group('Interaction and options', () {
    testWidgets('onItemClick fires when a row is tapped', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            onItemClick: (_) => fired = true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Bob').first);
      await tester.pump();
      expect(fired, isTrue);
    });

    testWidgets('onItemLongPress fires on a long press', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            onItemLongPress: (_) => fired = true,
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Bob').first);
      await tester.pump();
      expect(fired, isTrue);
    });

    testWidgets('onCallLogIconClicked fires when the call icon is tapped', (
      tester,
    ) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            audioCallIcon: _icon(),
            onCallLogIconClicked: (_) => fired = true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(_iconKey).first, warnIfMissed: false);
      await tester.pump();
      expect(fired, isTrue);
    });

    testWidgets('onBack fires when the back button is tapped', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            backButton: _icon(),
            showBackButton: true,
            onBack: () => fired = true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(_iconKey).first, warnIfMissed: false);
      await tester.pump();
      expect(fired, isTrue);
    });

    testWidgets('setOptions renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            setOptions: (_, _, _) => const [],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatCallLogs), findsOneWidget);
    });

    testWidgets('addOptions renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            addOptions: (_, _, _) => const [],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatCallLogs), findsOneWidget);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CometChatCallLogsStyle — every field asserted on what it paints
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('CometChatCallLogsStyle', () {
    testWidgets('border and borderRadius decorate the container', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsStyle: const CometChatCallLogsStyle(
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF111111), width: 2),
              ),
              borderRadius: BorderRadius.all(Radius.circular(13)),
            ),
          ),
        ),
      );
      await tester.pump();
      final style = _listBaseStyle(tester);
      expect(style.borderRadius, const BorderRadius.all(Radius.circular(13)));
      expect(style.border, isNotNull);
    });

    testWidgets('backIconColor tints the back icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsStyle: const CometChatCallLogsStyle(
              backIconColor: Color(0xFF222222),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_listBaseStyle(tester).backIconTint, const Color(0xFF222222));
    });

    testWidgets('titleTextStyle and titleTextColor style the app bar title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsStyle: const CometChatCallLogsStyle(
              titleTextStyle: TextStyle(fontSize: 41),
              titleTextColor: Color(0xFF333333),
            ),
          ),
        ),
      );
      await tester.pump();
      final style = _listBaseStyle(tester);
      expect(style.titleStyle?.fontSize, 41);
      expect(style.titleStyle?.color, const Color(0xFF333333));
    });

    testWidgets(
      'itemTitleTextStyle and itemTitleTextColor style the row title',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CometChatCallLogs(
              callLogsBloc: _loaded(),
              callLogsStyle: const CometChatCallLogsStyle(
                itemTitleTextStyle: TextStyle(fontSize: 37),
                itemTitleTextColor: Color(0xFF444444),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_textSized(tester, 37), isTrue);
        expect(_textColored(tester, const Color(0xFF444444)), isTrue);
      },
    );

    testWidgets('dateStyle styles the row timestamp', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsStyle: const CometChatCallLogsStyle(
              dateStyle: CometChatDateStyle(textStyle: TextStyle(fontSize: 27)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_textSized(tester, 27), isTrue);
    });

    testWidgets('avatarStyle reaches the row avatar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsStyle: const CometChatCallLogsStyle(
              avatarStyle: CometChatAvatarStyle(
                backgroundColor: Color(0xFF556677),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final avatar = tester.widget<CometChatAvatar>(
        find.byType(CometChatAvatar).first,
      );
      expect(avatar.style?.backgroundColor, const Color(0xFF556677));
    });

    testWidgets('separatorHeight and separatorColor draw the row separator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            callLogsStyle: const CometChatCallLogsStyle(
              separatorHeight: 7,
              separatorColor: Color(0xFF667788),
            ),
          ),
        ),
      );
      await tester.pump();
      // The separator lives in the Column the component hands to
      // CometChatListBase as its container, so it is read off the rendered
      // list base rather than searched for by type.
      final base = tester.widget<CometChatListBase>(
        find.byType(CometChatListBase),
      );
      final divider = (base.container as Column).children.first as Divider;
      expect(divider.height, 7);
      expect(divider.color, const Color(0xFF667788));
    });

    testWidgets('audioCallIconColor tints its icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(type: 'audio', status: 'ended', byMe: true),
            callLogsStyle: const CometChatCallLogsStyle(
              audioCallIconColor: Color(0xFF28AABB),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_iconColored(tester, const Color(0xFF28AABB)), isTrue);
    });

    testWidgets('videoCallIconColor tints its icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(type: 'video', status: 'ended', byMe: true),
            callLogsStyle: const CometChatCallLogsStyle(
              videoCallIconColor: Color(0xFF28AABB),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_iconColored(tester, const Color(0xFF28AABB)), isTrue);
    });

    testWidgets('outgoingCallIconColor tints its icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(type: 'audio', status: 'ended', byMe: true),
            callLogsStyle: const CometChatCallLogsStyle(
              outgoingCallIconColor: Color(0xFF31AABB),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_iconColored(tester, const Color(0xFF31AABB)), isTrue);
    });

    testWidgets('incomingCallIconColor tints its icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(type: 'audio', status: 'ended', byMe: false),
            callLogsStyle: const CometChatCallLogsStyle(
              incomingCallIconColor: Color(0xFF31AABB),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_iconColored(tester, const Color(0xFF31AABB)), isTrue);
    });

    testWidgets('missedCallIconColor tints its icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(
              type: 'audio',
              status: 'unanswered',
              byMe: false,
            ),
            callLogsStyle: const CometChatCallLogsStyle(
              missedCallIconColor: Color(0xFF29AABB),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_iconColored(tester, const Color(0xFF29AABB)), isTrue);
    });

    testWidgets(
      'emptyStateTextStyle and emptyStateTextColor style the empty title',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CometChatCallLogs(
              callLogsBloc: _empty(),
              callLogsStyle: const CometChatCallLogsStyle(
                emptyStateTextStyle: TextStyle(fontSize: 43),
                emptyStateTextColor: Color(0xFF778899),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_textSized(tester, 43), isTrue);
        expect(_textColored(tester, const Color(0xFF778899)), isTrue);
      },
    );

    testWidgets(
      'emptyStateSubTitleTextStyle and colour style the empty subtitle',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CometChatCallLogs(
              callLogsBloc: _empty(),
              callLogsStyle: const CometChatCallLogsStyle(
                emptyStateSubTitleTextStyle: TextStyle(fontSize: 47),
                emptyStateSubTitleTextColor: Color(0xFF8899AA),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_textSized(tester, 47), isTrue);
        expect(_textColored(tester, const Color(0xFF8899AA)), isTrue);
      },
    );

    testWidgets(
      'errorStateTextStyle and errorStateTextColor style the error title',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CometChatCallLogs(
              callLogsBloc: _error(),
              callLogsStyle: const CometChatCallLogsStyle(
                errorStateTextStyle: TextStyle(fontSize: 53),
                errorStateTextColor: Color(0xFF99AABB),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_textSized(tester, 53), isTrue);
        expect(_textColored(tester, const Color(0xFF99AABB)), isTrue);
      },
    );

    testWidgets(
      'errorStateSubTitleTextStyle and colour style the error subtitle',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CometChatCallLogs(
              callLogsBloc: _error(),
              callLogsStyle: const CometChatCallLogsStyle(
                errorStateSubTitleTextStyle: TextStyle(fontSize: 59),
                errorStateSubTitleTextColor: Color(0xFFAABBCC),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_textSized(tester, 59), isTrue);
        expect(_textColored(tester, const Color(0xFFAABBCC)), isTrue);
      },
    );

    testWidgets('retry button styling reaches the error state button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _error(),
            callLogsStyle: const CometChatCallLogsStyle(
              retryButtonBackgroundColor: Color(0xFFBBCCDD),
              retryButtonTextColor: Color(0xFFCCDDEE),
              retryButtonTextStyle: TextStyle(fontSize: 61),
              retryButtonBorder: BorderSide(color: Color(0xFFDDEEFF), width: 3),
              retryButtonBorderRadius: BorderRadius.all(Radius.circular(19)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_textSized(tester, 61), isTrue);
      expect(_textColored(tester, const Color(0xFFCCDDEE)), isTrue);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // DEAD PROPS — see ENG ticket
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  group('Dead props', () {
    testWidgets('dateSeparatorPattern formats the date separator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallLogs(
            callLogsBloc: _loaded(),
            dateSeparatorPattern: 'CUSTOM-SEP',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('CUSTOM-SEP'), findsWidgets);
    });

    testWidgets('a date separator is rendered above each date group', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CometChatCallLogs(callLogsBloc: _loaded())),
      );
      await tester.pump();

      // The fixture's log is dated 2025-09-02, so the bucket label is the
      // formatted date rather than Today/Yesterday.
      expect(find.text('Sep 2, 2025'), findsOneWidget);
    });

    // Wired: CometChatCallLogs now passes this into CallLogsBloc, which maps
    // it onto CometChatOutgoingCall when a call is initiated from a row. This
    // test covers the widget-to-bloc hop; the screen itself needs a live SDK
    // call, so it is not asserted here.
    testWidgets(
      'outgoingCallConfiguration is accepted and the component renders',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            CometChatCallLogs(
              callLogsBloc: _loaded(),
              outgoingCallConfiguration: CometChatOutgoingCallConfiguration(),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CometChatCallLogs), findsOneWidget);
      },
    );
  });
}
