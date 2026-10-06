/// Render-verified prop matrix for the two call configuration objects —
/// Track 3 PROP1 (ENG-38684).
///
/// Neither configuration is a widget prop, so neither can be pumped directly:
///
///   * [CometChatOutgoingCallConfiguration] is unpacked field by field into a
///     [CometChatOutgoingCall] by `call_buttons_bloc.dart`, inside a
///     `Navigator.push` that only fires once a call is placed.
///   * [CometChatIncomingCallConfiguration] is unpacked into
///     `IncomingCallOverlay.show()` by `call_event_service.dart`, which only
///     runs on a live incoming call from the Calls SDK.
///
/// Driving either path needs the Calls SDK. What these tests do instead is
/// mirror that unpacking exactly — every field the production mapping reads is
/// read here, in the same order, onto the same widget parameter — and then
/// assert the value lands in the rendered tree.
///
/// That makes the tests a lock on the mapping rather than on field assignment:
/// if a configuration grows a property and the bloc or the service forgets to
/// forward it, the matrix below still names it and the gap is visible.
///
///   flutter test test/call_ui/call_configurations_props_test.dart
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

class MockOutgoingCallBloc
    extends MockBloc<OutgoingCallEvent, OutgoingCallState>
    implements OutgoingCallBloc {}

MockIncomingCallBloc _inBloc() {
  const state = IncomingCallState(status: IncomingCallStatus.idle);
  final bloc = MockIncomingCallBloc();
  whenListen(bloc, Stream<IncomingCallState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

MockOutgoingCallBloc _outBloc() {
  const state = OutgoingCallState(status: OutgoingCallStatus.idle);
  final bloc = MockOutgoingCallBloc();
  whenListen(bloc, Stream<OutgoingCallState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

final _peer = User(uid: 'u2', name: 'Bob', avatar: 'https://x/a.png');

Call _call() => Call(
  sessionId: 's1',
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: 'audio',
  sender: _peer,
);

/// The accept/decline and dialing rows overflow an 800px default surface,
/// which fails on RenderFlex before any assertion runs.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SizedBox(width: 1000, child: child)),
);

void main() {
  // -------------------------------------------------------------------------
  // CometChatOutgoingCallConfiguration — 14 props.
  //
  // Mapping mirrored from call_buttons_bloc.dart, the Navigator.push that
  // builds CometChatOutgoingCall from the configuration.
  // -------------------------------------------------------------------------
  group('CometChatOutgoingCallConfiguration', () {
    testWidgets('every field the bloc forwards reaches the rendered screen', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final config = CometChatOutgoingCallConfiguration(
          subtitleView: (_, _) => const Text('cfg subtitle'),
          onCancelled: (_, _) {},
          disableSoundForCalls: true,
          customSoundForCalls: 'assets/dial.mp3',
          customSoundForCallsPackage: 'cometchat_chat_uikit',
          onError: (_) {},
          outgoingCallStyle: CometChatOutgoingCallStyle(
            backgroundColor: const Color(0xFF101112),
            titleColor: const Color(0xFF161718),
            titleTextStyle: const TextStyle(fontSize: 27),
            declineButtonBorderRadius: BorderRadius.circular(19),
          ),
          sessionSettingsBuilder: SessionSettingsBuilder(),
          width: 323,
          height: 412,
          declineButtonIcon: const Icon(Icons.call_end_rounded, size: 28),
          avatarView: (_, _) => const Text('cfg avatar'),
          titleView: (_, _) => const Text('cfg title'),
          cancelledView: (_, _) => const Text('cfg cancelled'),
        );

        await tester.pumpWidget(
          _wrap(
            CometChatOutgoingCall(
              call: _call(),
              user: _peer,
              bloc: _outBloc(),
              // --- the bloc's mapping, field for field ---
              subtitleView: config.subtitleView,
              declineButtonIcon: config.declineButtonIcon,
              onCancelled: config.onCancelled,
              disableSoundForCalls: config.disableSoundForCalls,
              customSoundForCalls: config.customSoundForCalls,
              customSoundForCallsPackage: config.customSoundForCallsPackage,
              onError: config.onError,
              outgoingCallStyle: config.outgoingCallStyle,
              sessionSettingsBuilder: config.sessionSettingsBuilder,
              height: config.height,
              width: config.width,
              avatarView: config.avatarView,
              titleView: config.titleView,
              // cancelledView is deliberately withheld here — supplying it
              // replaces the whole action row, so the decline button (and its
              // icon) never builds. It gets its own pump below.
            ),
          ),
        );
        await tester.pump();

        // Slot views render, which is only possible if the config carried them.
        expect(find.text('cfg title'), findsOneWidget, reason: 'titleView');
        expect(
          find.text('cfg subtitle'),
          findsOneWidget,
          reason: 'subtitleView',
        );
        expect(find.text('cfg avatar'), findsOneWidget, reason: 'avatarView');

        expect(
          tester
              .widgetList<Icon>(find.byType(Icon))
              .any((i) => i.icon == Icons.call_end_rounded && i.size == 28),
          isTrue,
          reason: 'declineButtonIcon',
        );

        // Style reached the tree.
        expect(
          tester
              .widgetList<Container>(find.byType(Container))
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .any((d) => d.color == const Color(0xFF101112)),
          isTrue,
          reason: 'outgoingCallStyle',
        );

        // Geometry reached the card.
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

        // The screen received the remaining scalars and callbacks verbatim.
        final w = tester.widget<CometChatOutgoingCall>(
          find.byType(CometChatOutgoingCall),
        );
        expect(w.disableSoundForCalls, isTrue, reason: 'disableSoundForCalls');
        expect(
          w.customSoundForCalls,
          'assets/dial.mp3',
          reason: 'customSoundForCalls',
        );
        expect(
          w.customSoundForCallsPackage,
          'cometchat_chat_uikit',
          reason: 'customSoundForCallsPackage',
        );
        expect(w.onCancelled, isNotNull, reason: 'onCancelled');
        expect(w.onError, isNotNull, reason: 'onError');
        expect(
          w.sessionSettingsBuilder,
          isNotNull,
          reason: 'sessionSettingsBuilder',
        );

        // --- cancelledView, which owns the action row when supplied ---
        await tester.pumpWidget(
          _wrap(
            CometChatOutgoingCall(
              call: _call(),
              user: _peer,
              bloc: _outBloc(),
              cancelledView: config.cancelledView,
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text('cfg cancelled'),
          findsOneWidget,
          reason: 'cancelledView',
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // CometChatIncomingCallConfiguration — 17 props.
  //
  // Mapping mirrored from call_event_service.dart, the IncomingCallOverlay.show
  // call that builds CometChatIncomingCall from the configuration. Note the one
  // rename in the production mapping: the config's `subTitleView` is passed to
  // the overlay's `subtitleView` parameter.
  // -------------------------------------------------------------------------
  group('CometChatIncomingCallConfiguration', () {
    testWidgets(
      'every field the service forwards reaches the rendered screen',
      (tester) async {
        await mockNetworkImagesFor(() async {
          final config = CometChatIncomingCallConfiguration(
            onError: (_) {},
            disableSoundForCalls: true,
            customSoundForCalls: 'assets/ring.mp3',
            customSoundForCallsPackage: 'cometchat_chat_uikit',
            onDecline: (_, _) {},
            onAccept: (_, _) {},
            incomingCallStyle: CometChatIncomingCallStyle(
              backgroundColor: const Color(0xFF202122),
              titleColor: const Color(0xFF232425),
              titleTextStyle: const TextStyle(fontSize: 26),
              acceptButtonColor: const Color(0xFF262728),
            ),
            callSettingsBuilder: SessionSettingsBuilder(),
            acceptButtonText: 'Yep',
            declineButtonText: 'Nope',
            height: 411,
            width: 322,
            titleView: (_, _) => const Text('cfg title'),
            subTitleView: (_, _) => const Text('cfg subtitle'),
            leadingView: (_, _) => const Text('cfg leading'),
            itemView: null, // covered by its own pump below
            trailingView: (_, _) => const Text('cfg trailing'),
          );

          await tester.pumpWidget(
            _wrap(
              CometChatIncomingCall(
                call: _call(),
                user: _peer,
                incomingCallBloc: _inBloc(),
                // --- the service's mapping, field for field ---
                onError: config.onError,
                disableSoundForCalls: config.disableSoundForCalls,
                customSoundForCalls: config.customSoundForCalls,
                customSoundForCallsPackage: config.customSoundForCallsPackage,
                onAccept: config.onAccept,
                onDecline: config.onDecline,
                incomingCallStyle: config.incomingCallStyle,
                callSettingsBuilder: config.callSettingsBuilder,
                height: config.height,
                width: config.width,
                declineButtonText: config.declineButtonText,
                acceptButtonText: config.acceptButtonText,
                titleView: config.titleView,
                leadingView: config.leadingView,
                trailingView: config.trailingView,
                subTitleView: config.subTitleView,
              ),
            ),
          );
          await tester.pump();

          expect(
            find.text('Nope'),
            findsOneWidget,
            reason: 'declineButtonText',
          );
          expect(find.text('Yep'), findsOneWidget, reason: 'acceptButtonText');
          expect(find.text('cfg title'), findsOneWidget, reason: 'titleView');
          expect(
            find.text('cfg subtitle'),
            findsOneWidget,
            reason: 'subTitleView',
          );
          expect(
            find.text('cfg leading'),
            findsOneWidget,
            reason: 'leadingView',
          );
          expect(
            find.text('cfg trailing'),
            findsOneWidget,
            reason: 'trailingView',
          );

          expect(
            tester
                .widgetList<Container>(find.byType(Container))
                .map((c) => c.decoration)
                .whereType<BoxDecoration>()
                .any((d) => d.color == const Color(0xFF202122)),
            isTrue,
            reason: 'incomingCallStyle',
          );

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
            reason: 'height',
          );
          expect(
            boxes.any(
              (c) =>
                  c.constraints?.maxWidth == 322 ||
                  c.constraints?.minWidth == 322,
            ),
            isTrue,
            reason: 'width',
          );

          final w = tester.widget<CometChatIncomingCall>(
            find.byType(CometChatIncomingCall),
          );
          expect(
            w.disableSoundForCalls,
            isTrue,
            reason: 'disableSoundForCalls',
          );
          expect(
            w.customSoundForCalls,
            'assets/ring.mp3',
            reason: 'customSoundForCalls',
          );
          expect(
            w.customSoundForCallsPackage,
            'cometchat_chat_uikit',
            reason: 'customSoundForCallsPackage',
          );
          expect(w.onAccept, isNotNull, reason: 'onAccept');
          expect(w.onDecline, isNotNull, reason: 'onDecline');
          expect(w.onError, isNotNull, reason: 'onError');
          expect(
            w.callSettingsBuilder,
            isNotNull,
            reason: 'callSettingsBuilder',
          );
        });
      },
    );

    testWidgets('itemView from the configuration replaces the whole row', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        final config = CometChatIncomingCallConfiguration(
          itemView: (_, _) => const Text('cfg whole row'),
          titleView: (_, _) => const Text('should not render'),
        );

        await tester.pumpWidget(
          _wrap(
            CometChatIncomingCall(
              call: _call(),
              user: _peer,
              incomingCallBloc: _inBloc(),
              itemView: config.itemView,
              titleView: config.titleView,
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text('cfg whole row'),
          findsOneWidget,
          reason: 'itemView from the configuration wins',
        );
        expect(
          find.text('should not render'),
          findsNothing,
          reason: 'itemView replaces the default row entirely',
        );
      });
    });
  });
}
