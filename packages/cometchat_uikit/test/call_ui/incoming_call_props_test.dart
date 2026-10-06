/// Render-verified prop matrix for CometChatIncomingCall and its style —
/// Track 3 PROP1/PROP2 (ENG-38684).
///
/// The widget exposes an `incomingCallBloc` seam, so the screen renders
/// without the Calls SDK — a mock bloc holds it in the state under test.
///
///   flutter test test/call_ui/incoming_call_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockIncomingCallBloc
    extends MockBloc<IncomingCallEvent, IncomingCallState>
    implements IncomingCallBloc {
  // getSubtitle returns a non-nullable String; mocktail would hand back null
  // and the screen would throw before rendering.
  @override
  String getSubtitle(BuildContext context) => 'Incoming audio call';
}

MockIncomingCallBloc _bloc({
  IncomingCallStatus status = IncomingCallStatus.idle,
}) {
  final state = IncomingCallState(status: status);
  final bloc = MockIncomingCallBloc();
  whenListen(bloc, Stream<IncomingCallState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

final _caller = User(uid: 'u2', name: 'Bob', avatar: 'https://x/a.png');

Call _call() => Call(
  sessionId: 's1',
  receiverUid: 'me',
  receiverType: CometChatReceiverType.user,
  type: 'audio',
  sender: _caller,
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  // The accept/decline row overflows an 800px default surface, which fails on
  // RenderFlex before any assertion runs.
  home: Scaffold(body: SizedBox(width: 1000, child: child)),
);

void main() {
  // -------------------------------------------------------------------------
  // CometChatIncomingCallStyle — 15 props, all read by the screen.
  // -------------------------------------------------------------------------
  group('CometChatIncomingCallStyle', () {
    testWidgets('every style property reaches the rendered screen', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatIncomingCall(
              call: _call(),
              incomingCallBloc: _bloc(),
              incomingCallStyle: CometChatIncomingCallStyle(
                backgroundColor: const Color(0xFF101112),
                border: const Border.fromBorderSide(
                  BorderSide(color: Color(0xFF131415), width: 3),
                ),
                borderRadius: const BorderRadius.all(Radius.circular(17)),
                titleColor: const Color(0xFF161718),
                titleTextStyle: const TextStyle(fontSize: 27),
                subtitleColor: const Color(0xFF191A1B),
                subtitleTextStyle: const TextStyle(letterSpacing: 6),
                callIconColor: const Color(0xFF1C1D1E),
                declineButtonColor: const Color(0xFF1F2021),
                declineTextColor: const Color(0xFF222324),
                declineTextStyle: const TextStyle(letterSpacing: 7),
                acceptButtonColor: const Color(0xFF252627),
                acceptTextColor: const Color(0xFF282930),
                acceptTextStyle: const TextStyle(letterSpacing: 8),
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
          decos.any(
            (d) =>
                d.borderRadius == const BorderRadius.all(Radius.circular(17)),
          ),
          isTrue,
          reason: 'borderRadius',
        );
        final buttonFills = tester
            .widgetList<TextButton>(find.byType(TextButton))
            .map((b) => b.style?.backgroundColor?.resolve(<WidgetState>{}))
            .toList();
        expect(
          buttonFills,
          contains(const Color(0xFF1F2021)),
          reason: 'declineButtonColor',
        );
        expect(
          buttonFills,
          contains(const Color(0xFF252627)),
          reason: 'acceptButtonColor',
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
        expect(
          styles.any(
            (s) => s.letterSpacing == 7 && s.color == const Color(0xFF222324),
          ),
          isTrue,
          reason: 'declineTextStyle + declineTextColor',
        );
        expect(
          styles.any(
            (s) => s.letterSpacing == 8 && s.color == const Color(0xFF282930),
          ),
          isTrue,
          reason: 'acceptTextStyle + acceptTextColor',
        );
        expect(
          tester
              .widgetList<Icon>(find.byType(Icon))
              .any((i) => i.color == const Color(0xFF1C1D1E)),
          isTrue,
          reason: 'callIconColor',
        );

        final w = tester.widget<CometChatIncomingCall>(
          find.byType(CometChatIncomingCall),
        );
        expect(
          w.incomingCallStyle?.avatarStyle?.backgroundColor,
          const Color(0xFF313233),
          reason: 'avatarStyle',
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // CometChatIncomingCall — 21 props.
  // -------------------------------------------------------------------------
  group('CometChatIncomingCall', () {
    testWidgets('call, user, geometry, texts, icon and callbacks all apply', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final bloc = _bloc();
        await tester.pumpWidget(
          _wrap(
            CometChatIncomingCall(
              call: _call(),
              user: _caller,
              incomingCallBloc: bloc,
              height: 411,
              width: 322,
              declineButtonText: 'Nope',
              acceptButtonText: 'Yep',
              callIcon: const Icon(Icons.videocam_rounded, size: 29),
              disableSoundForCalls: true,
              customSoundForCalls: 'assets/ring.mp3',
              customSoundForCallsPackage: 'cometchat_chat_uikit',
              onAccept: (_, _) {},
              onDecline: (_, _) {},
              onError: (_) {},
              callSettingsBuilder: SessionSettingsBuilder(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Nope'), findsOneWidget, reason: 'declineButtonText');
        expect(find.text('Yep'), findsOneWidget, reason: 'acceptButtonText');
        expect(find.text('Bob'), findsWidgets, reason: 'user drives the title');
        expect(
          tester
              .widgetList<Icon>(find.byType(Icon))
              .any((i) => i.icon == Icons.videocam_rounded && i.size == 29),
          isTrue,
          reason: 'callIcon',
        );

        final w = tester.widget<CometChatIncomingCall>(
          find.byType(CometChatIncomingCall),
        );
        expect(w.call.sessionId, 's1', reason: 'call');
        expect(w.user?.uid, 'u2', reason: 'user');
        expect(w.height, 411, reason: 'height');
        expect(w.width, 322, reason: 'width');
        expect(w.disableSoundForCalls, isTrue);
        expect(w.customSoundForCalls, 'assets/ring.mp3');
        expect(w.customSoundForCallsPackage, 'cometchat_chat_uikit');
        expect(w.onAccept, isNotNull);
        expect(w.onDecline, isNotNull);
        expect(w.onError, isNotNull);
        expect(w.callSettingsBuilder, isNotNull);
        expect(w.incomingCallBloc, same(bloc), reason: 'incomingCallBloc');

        // Geometry lands on the card container.
        final boxes = tester.widgetList<Container>(
          find.descendant(
            of: find.byType(CometChatIncomingCall),
            matching: find.byType(Container),
          ),
        );
        expect(
          boxes.any(
            (c) =>
                c.constraints?.maxHeight == 411 ||
                c.constraints?.minHeight == 411,
          ),
          isTrue,
          reason: 'height reaches the card',
        );
        expect(
          boxes.any(
            (c) =>
                c.constraints?.maxWidth == 322 ||
                c.constraints?.minWidth == 322,
          ),
          isTrue,
          reason: 'width reaches the card',
        );
      });
    });

    testWidgets('the slot views replace the default layout', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatIncomingCall(
              call: _call(),
              incomingCallBloc: _bloc(),
              titleView: (_, _) => const Text('slot title'),
              subTitleView: (_, _) => const Text('slot subtitle'),
              leadingView: (_, _) => const Text('slot leading'),
              trailingView: (_, _) => const Text('slot trailing'),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('slot title'), findsOneWidget, reason: 'titleView');
        expect(
          find.text('slot subtitle'),
          findsOneWidget,
          reason: 'subTitleView',
        );
        expect(
          find.text('slot leading'),
          findsOneWidget,
          reason: 'leadingView',
        );
        expect(
          find.text('slot trailing'),
          findsOneWidget,
          reason: 'trailingView',
        );
      });
    });

    testWidgets('itemView replaces the whole row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatIncomingCall(
              call: _call(),
              incomingCallBloc: _bloc(),
              itemView: (_, _) => const Text('whole row'),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('whole row'), findsOneWidget, reason: 'itemView');
      });
    });
  });
}
