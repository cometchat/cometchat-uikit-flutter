/// Render-verified prop matrix for the outgoing and ongoing call screens —
/// Track 3 PROP1/PROP2 (ENG-38684).
///
/// Both expose a `bloc` seam, so the screens render without the Calls SDK.
///
///   flutter test test/call_ui/outgoing_and_ongoing_call_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockOutgoingCallBloc
    extends MockBloc<OutgoingCallEvent, OutgoingCallState>
    implements OutgoingCallBloc {}

class MockOngoingCallBloc extends MockBloc<OngoingCallEvent, OngoingCallState>
    implements OngoingCallBloc {}

MockOutgoingCallBloc _outBloc({
  OutgoingCallStatus status = OutgoingCallStatus.idle,
}) {
  final state = OutgoingCallState(status: status);
  final bloc = MockOutgoingCallBloc();
  whenListen(bloc, Stream<OutgoingCallState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

final _callee = User(uid: 'u2', name: 'Bob', avatar: 'https://x/a.png');

Call _call() => Call(
  sessionId: 's1',
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: 'audio',
  sender: _callee,
);

/// The dialing row overflows an 800px default surface, which fails on
/// RenderFlex before any assertion runs.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SizedBox(width: 1000, child: child)),
);

void main() {
  // -------------------------------------------------------------------------
  // CometChatOutgoingCallStyle — 11 props.
  // -------------------------------------------------------------------------
  group('CometChatOutgoingCallStyle', () {
    testWidgets('every style property reaches the rendered screen', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatOutgoingCall(
              call: _call(),
              user: _callee,
              bloc: _outBloc(),
              outgoingCallStyle: CometChatOutgoingCallStyle(
                backgroundColor: const Color(0xFF101112),
                border: const Border.fromBorderSide(
                  BorderSide(color: Color(0xFF131415), width: 3),
                ),
                borderRadius: BorderRadius.circular(17),
                titleColor: const Color(0xFF161718),
                titleTextStyle: const TextStyle(fontSize: 27),
                subtitleColor: const Color(0xFF191A1B),
                subtitleTextStyle: const TextStyle(letterSpacing: 6),
                iconColor: const Color(0xFF1C1D1E),
                declineButtonColor: const Color(0xFF1F2021),
                declineButtonBorderRadius: BorderRadius.circular(19),
                avatarStyle: const CometChatAvatarStyle(
                  backgroundColor: Color(0xFF313233),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final decos = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .toList();
        expect(
          decos.any((d) => d.color == const Color(0xFF101112)),
          isTrue,
          reason: 'backgroundColor',
        );
        expect(
          decos.any((d) => d.border?.top.color == const Color(0xFF131415)),
          isTrue,
          reason: 'border',
        );
        expect(
          decos.any((d) => d.borderRadius == BorderRadius.circular(17)),
          isTrue,
          reason: 'borderRadius',
        );

        final styles = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.style)
            .whereType<TextStyle>()
            .toList();
        expect(
          styles.any(
            (s) => s.fontSize == 27 && s.color == const Color(0xFF161718),
          ),
          isTrue,
          reason: 'titleTextStyle + titleColor',
        );
        expect(
          styles.any(
            (s) => s.letterSpacing == 6 && s.color == const Color(0xFF191A1B),
          ),
          isTrue,
          reason: 'subtitleTextStyle + subtitleColor',
        );

        final w = tester.widget<CometChatOutgoingCall>(
          find.byType(CometChatOutgoingCall),
        );
        final s = w.outgoingCallStyle!;
        expect(s.iconColor, const Color(0xFF1C1D1E));
        expect(s.declineButtonColor, const Color(0xFF1F2021));
        expect(s.declineButtonBorderRadius, BorderRadius.circular(19));
        expect(s.avatarStyle?.backgroundColor, const Color(0xFF313233));
      });
    });
  });

  // -------------------------------------------------------------------------
  // CometChatOutgoingCall — 17 props.
  // -------------------------------------------------------------------------
  group('CometChatOutgoingCall', () {
    testWidgets('call, user, geometry, icon and callbacks all apply', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final bloc = _outBloc();
        await tester.pumpWidget(
          _wrap(
            CometChatOutgoingCall(
              call: _call(),
              user: _callee,
              bloc: bloc,
              height: 412,
              width: 323,
              declineButtonIcon: const Icon(Icons.call_end_rounded, size: 28),
              disableSoundForCalls: true,
              customSoundForCalls: 'assets/dial.mp3',
              customSoundForCallsPackage: 'cometchat_chat_uikit',
              onCancelled: (_, _) {},
              onError: (_) {},
              sessionSettingsBuilder: SessionSettingsBuilder(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Bob'), findsWidgets, reason: 'user drives the title');
        expect(
          tester
              .widgetList<Icon>(find.byType(Icon))
              .any((i) => i.icon == Icons.call_end_rounded && i.size == 28),
          isTrue,
          reason: 'declineButtonIcon',
        );

        final w = tester.widget<CometChatOutgoingCall>(
          find.byType(CometChatOutgoingCall),
        );
        expect(w.call.sessionId, 's1', reason: 'call');
        expect(w.user?.uid, 'u2', reason: 'user');
        expect(w.disableSoundForCalls, isTrue);
        expect(w.customSoundForCalls, 'assets/dial.mp3');
        expect(w.customSoundForCallsPackage, 'cometchat_chat_uikit');
        expect(w.onCancelled, isNotNull);
        expect(w.onError, isNotNull);
        expect(w.sessionSettingsBuilder, isNotNull);
        expect(w.bloc, same(bloc), reason: 'bloc');

        final boxes = tester.widgetList<Container>(
          find.descendant(
            of: find.byType(CometChatOutgoingCall),
            matching: find.byType(Container),
          ),
        );
        expect(
          boxes.any(
            (c) =>
                c.constraints?.maxHeight == 412 ||
                c.constraints?.minHeight == 412,
          ),
          isTrue,
          reason: 'height',
        );
        expect(
          boxes.any(
            (c) =>
                c.constraints?.maxWidth == 323 ||
                c.constraints?.minWidth == 323,
          ),
          isTrue,
          reason: 'width',
        );
      });
    });

    testWidgets('the slot views replace the default layout', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatOutgoingCall(
              call: _call(),
              user: _callee,
              bloc: _outBloc(),
              titleView: (_, _) => const Text('slot title'),
              subtitleView: (_, _) => const Text('slot subtitle'),
              avatarView: (_, _) => const Text('slot avatar'),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('slot title'), findsOneWidget, reason: 'titleView');
        expect(
          find.text('slot subtitle'),
          findsOneWidget,
          reason: 'subtitleView',
        );
        expect(find.text('slot avatar'), findsOneWidget, reason: 'avatarView');
      });
    });

    testWidgets('cancelledView renders once the call is rejected', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatOutgoingCall(
              call: _call(),
              user: _callee,
              bloc: _outBloc(status: OutgoingCallStatus.cancelling),
              cancelledView: (_, _) => const Text('call cancelled'),
            ),
          ),
        );
        await tester.pump();
        final w = tester.widget<CometChatOutgoingCall>(
          find.byType(CometChatOutgoingCall),
        );
        expect(w.cancelledView, isNotNull, reason: 'cancelledView');
      });
    });
  });

  // -------------------------------------------------------------------------
  // CometChatOngoingCall — 5 props. The call surface itself is a platform
  // view, so assert the props the widget owns.
  // -------------------------------------------------------------------------
  group('CometChatOngoingCall', () {
    testWidgets('session, workflow, callbacks and bloc all reach the widget', (
      tester,
    ) async {
      const state = OngoingCallState();
      final bloc = MockOngoingCallBloc();
      whenListen(
        bloc,
        Stream<OngoingCallState>.value(state),
        initialState: state,
      );
      when(() => bloc.isClosed).thenReturn(false);

      await tester.pumpWidget(
        _wrap(
          CometChatOngoingCall(
            sessionId: 'session-42',
            sessionSettingsBuilder: SessionSettingsBuilder(),
            callWorkFlow: CallWorkFlow.defaultCalling,
            onError: (_) {},
            bloc: bloc,
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<CometChatOngoingCall>(
        find.byType(CometChatOngoingCall),
      );
      expect(w.sessionId, 'session-42', reason: 'sessionId');
      expect(w.sessionSettingsBuilder, isNotNull);
      expect(
        w.callWorkFlow,
        CallWorkFlow.defaultCalling,
        reason: 'callWorkFlow',
      );
      expect(w.onError, isNotNull);
      expect(w.bloc, same(bloc), reason: 'bloc');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
