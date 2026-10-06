/// Render-verified prop matrix for CometChatCallButtons and its style —
/// Track 3 PROP1/PROP2 (ENG-38684).
///
///   flutter test test/call_ui/call_buttons_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCallButtonsBloc extends MockBloc<CallButtonsEvent, CallButtonsState>
    implements CallButtonsBloc {}

MockCallButtonsBloc _bloc() {
  const state = CallButtonsState();
  final bloc = MockCallButtonsBloc();
  whenListen(bloc, Stream<CallButtonsState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

final _bob = User(uid: 'u2', name: 'Bob');

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Center(child: child)),
);

void main() {
  // -------------------------------------------------------------------------
  // CometChatCallButtonsStyle — 8 props, all read by the buttons.
  // -------------------------------------------------------------------------
  group('CometChatCallButtonsStyle', () {
    testWidgets('button fills, borders and icon colours all apply', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallButtons(
            user: _bob,
            callButtonsBloc: _bloc(),
            callButtonsStyle: CometChatCallButtonsStyle(
              voiceCallButtonColor: const Color(0xFF101112),
              voiceCallIconColor: const Color(0xFF131415),
              voiceCallButtonBorder: const BorderSide(
                color: Color(0xFF161718),
                width: 2,
              ),
              voiceCallButtonBorderRadius: BorderRadius.circular(13),
              videoCallButtonColor: const Color(0xFF191A1B),
              videoCallIconColor: const Color(0xFF1C1D1E),
              videoCallButtonBorder: const BorderSide(
                color: Color(0xFF1F2021),
                width: 4,
              ),
              videoCallButtonBorderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      );
      await tester.pump();

      final fills = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .map((b) => b.style?.backgroundColor?.resolve(<WidgetState>{}))
          .toList();
      expect(
        fills,
        contains(const Color(0xFF101112)),
        reason: 'voiceCallButtonColor',
      );
      expect(
        fills,
        contains(const Color(0xFF191A1B)),
        reason: 'videoCallButtonColor',
      );

      // The voice button draws an Icon; the video button draws an SvgPicture
      // tinted through a ColorFilter, so each is read where it lands.
      expect(
        tester
            .widgetList<Icon>(find.byType(Icon))
            .map((i) => i.color)
            .contains(const Color(0xFF131415)),
        isTrue,
        reason: 'voiceCallIconColor',
      );
      expect(
        tester
            .widgetList<SvgPicture>(find.byType(SvgPicture))
            .any(
              (p) =>
                  p.colorFilter ==
                  const ColorFilter.mode(Color(0xFF1C1D1E), BlendMode.srcIn),
            ),
        isTrue,
        reason: 'videoCallIconColor',
      );

      final shapes = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .map((b) => b.style?.shape?.resolve(<WidgetState>{}))
          .whereType<RoundedRectangleBorder>()
          .toList();
      expect(
        shapes.any(
          (s) =>
              s.borderRadius == BorderRadius.circular(13) &&
              s.side.color == const Color(0xFF161718),
        ),
        isTrue,
        reason: 'voiceCallButtonBorderRadius + voiceCallButtonBorder',
      );
      expect(
        shapes.any(
          (s) =>
              s.borderRadius == BorderRadius.circular(15) &&
              s.side.color == const Color(0xFF1F2021),
        ),
        isTrue,
        reason: 'videoCallButtonBorderRadius + videoCallButtonBorder',
      );
    });
  });

  // -------------------------------------------------------------------------
  // CometChatCallButtons — 11 props.
  // -------------------------------------------------------------------------
  group('CometChatCallButtons', () {
    testWidgets('user, icons, callbacks and the config all reach the widget', (
      tester,
    ) async {
      final bloc = _bloc();
      await tester.pumpWidget(
        _wrap(
          CometChatCallButtons(
            user: _bob,
            callButtonsBloc: bloc,
            hideVoiceCallButton: false,
            hideVideoCallButton: false,
            voiceCallIcon: const Icon(Icons.phone_in_talk, size: 27),
            videoCallIcon: const Icon(Icons.video_call, size: 28),
            onError: (_) {},
            callSettingsBuilder: (a, b, c) => SessionSettingsBuilder(),
            outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
              height: 321,
              width: 123,
            ),
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<CometChatCallButtons>(
        find.byType(CometChatCallButtons),
      );
      expect(w.user?.uid, 'u2', reason: 'user');
      expect(w.group, isNull, reason: 'group');
      expect(w.hideVoiceCallButton, isFalse);
      expect(w.hideVideoCallButton, isFalse);
      expect(w.onError, isNotNull);
      expect(w.callSettingsBuilder, isNotNull);
      expect(w.outgoingCallConfiguration?.height, 321);
      expect(w.callButtonsBloc, same(bloc), reason: 'callButtonsBloc');

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(
        icons.any((i) => i.icon == Icons.phone_in_talk && i.size == 27),
        isTrue,
        reason: 'voiceCallIcon',
      );
      expect(
        icons.any((i) => i.icon == Icons.video_call && i.size == 28),
        isTrue,
        reason: 'videoCallIcon',
      );
    });

    testWidgets('the hide flags remove each button, and group is accepted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatCallButtons(
            group: Group(guid: 'g1', name: 'Team', type: 'public'),
            callButtonsBloc: _bloc(),
            hideVoiceCallButton: true,
            hideVideoCallButton: true,
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<CometChatCallButtons>(
        find.byType(CometChatCallButtons),
      );
      expect(w.group?.guid, 'g1', reason: 'group');
      expect(w.hideVoiceCallButton, isTrue);
      expect(w.hideVideoCallButton, isTrue);
      expect(
        find.byType(IconButton),
        findsNothing,
        reason: 'both hide flags suppress the buttons',
      );
    });
  });
}
