/// The ongoing call screen shows "Connecting" until the call view arrives,
/// on Android as well as iOS.
///
/// Android used to render an empty widget while loading, on the belief that
/// the Calls SDK draws a native Activity over Flutter. It returns an embedded
/// view there too, so the screen was simply blank until the view arrived.
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_connecting_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOngoingCallBloc extends MockBloc<OngoingCallEvent, OngoingCallState>
    implements OngoingCallBloc {}

_MockOngoingCallBloc _bloc(OngoingCallState state) {
  final bloc = _MockOngoingCallBloc();
  whenListen(bloc, Stream<OngoingCallState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

Future<void> _pumpCall(WidgetTester tester, OngoingCallBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: CometChatOngoingCall(
        sessionId: 'session-1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
        bloc: bloc,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final platforms = TargetPlatformVariant(const {
    TargetPlatform.android,
    TargetPlatform.iOS,
  });

  testWidgets('shows Connecting while the call view loads', (tester) async {
    await _pumpCall(tester, _bloc(const OngoingCallState()));

    expect(find.text('Connecting...'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: platforms);

  testWidgets('shows the call view once it arrives', (tester) async {
    await _pumpCall(
      tester,
      _bloc(
        const OngoingCallState(
          status: OngoingCallStatus.active,
          callingWidget: Text('call view'),
        ),
      ),
    );

    expect(find.text('call view'), findsOneWidget);
    expect(find.text('Connecting...'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: platforms);
}
