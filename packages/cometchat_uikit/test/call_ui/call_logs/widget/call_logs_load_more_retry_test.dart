/// The retry row a call-log list ends with when its next page failed
/// (round 5, P5-C15; owner's P5-D14 A), in [CometChatCallLogs] and the
/// public [CallLogsList].
///
/// A failed page used to replace the whole list with the error view (or, in
/// CallLogsList, ask for the page again on every build). Now the rows stay,
/// the last row says the next ones could not be loaded, Retry asks for the
/// same page again, and CometChatCallLogs reports the failure to onError
/// once per failure.
///
///   flutter test test/call_ui/call_logs/widget/call_logs_load_more_retry_test.dart
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

import '../../helpers/fake_call_logs_remote.dart';

class _MockCallLogsBloc extends MockBloc<CallLogsEvent, CallLogsState>
    implements CallLogsBloc {}

final _me = User(uid: 'me', name: 'Me');

CallLog _log(String id) => CallLog(
  sessionId: id,
  type: CallTypeConstants.audioCall,
  status: CallStatusConstants.ended,
  initiatedAt: 1756800000,
  initiator: CallUser(uid: 'me', name: 'Me'),
  receiver: CallUser(uid: 'bob', name: 'Bob $id'),
);

CallLogsState _loaded({String? loadMoreError, bool isLoadingMore = false}) =>
    CallLogsState(
      status: CallLogsStatus.loaded,
      callLogs: [_log('a'), _log('b')],
      hasMore: true,
      isLoadingMore: isLoadingMore,
      loggedInUser: _me,
      loadMoreError: loadMoreError,
    );

_MockCallLogsBloc _bloc(
  CallLogsState initial, {
  Stream<CallLogsState>? states,
}) {
  final bloc = _MockCallLogsBloc();
  when(() => bloc.isClosed).thenReturn(false);
  whenListen(
    bloc,
    states ?? Stream<CallLogsState>.value(initial),
    initialState: initial,
  );
  return bloc;
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

Finder get _retry => find.widgetWithText(TextButton, 'Retry');

void main() {
  setUpAll(() => registerFallbackValue(const LoadMoreCallLogs()));

  group('CometChatCallLogs', () {
    testWidgets('P5-E27: a failed next page ends the list with a retry row, '
        'not a loading row; the rows stay', (tester) async {
      final bloc = _bloc(_loaded(loadMoreError: 'offline'));
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_app(CometChatCallLogs(callLogsBloc: bloc)));
        await tester.pump();
      });

      expect(find.text('Bob a'), findsOneWidget);
      expect(find.text('Bob b'), findsOneWidget);
      expect(_retry, findsOneWidget);
      expect(find.byType(CometChatShimmerEffect), findsNothing);
      // Building the row did not ask for the page again.
      verifyNever(() => bloc.add(const LoadMoreCallLogs()));
    });

    testWidgets('P5-E27: Retry asks for the page again', (tester) async {
      final bloc = _bloc(_loaded(loadMoreError: 'offline'));
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_app(CometChatCallLogs(callLogsBloc: bloc)));
        await tester.pump();
        await tester.tap(_retry);
        await tester.pump();
      });

      verify(() => bloc.add(const LoadMoreCallLogs())).called(1);
    });

    testWidgets('P5-E27: onError hears each failed page once, not on every '
        'state that still carries it', (tester) async {
      final errors = <Exception>[];
      final states = StreamController<CallLogsState>();
      final bloc = _bloc(_loaded(), states: states.stream);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _app(CometChatCallLogs(callLogsBloc: bloc, onError: errors.add)),
        );
        await tester.pump();

        states
          ..add(_loaded(loadMoreError: 'offline'))
          // Another state that still carries the same failure.
          ..add(_loaded(loadMoreError: 'offline', isLoadingMore: true));
        await tester.pump();
        expect(errors, hasLength(1));
        final error = errors.single as CometChatException;
        expect(error.code, 'CALL_LOGS_ERROR');
        expect(error.message, 'offline');

        // A retry clears it; failing again is a new failure.
        states
          ..add(_loaded(isLoadingMore: true))
          ..add(_loaded(loadMoreError: 'offline'));
        await tester.pump();
        expect(errors, hasLength(2));
      });
      await states.close();
    });

    testWidgets('P5-C15: the retry row appears when only loadMoreError '
        'changes', (tester) async {
      final states = StreamController<CallLogsState>();
      final before = _loaded();
      final bloc = _bloc(before, states: states.stream);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_app(CometChatCallLogs(callLogsBloc: bloc)));
        await tester.pump();
        expect(_retry, findsNothing);

        // The same rows (the same list), only the failure is new.
        states.add(before.copyWith(loadMoreError: 'offline'));
        await tester.pump();
      });
      expect(_retry, findsOneWidget);
      await states.close();
    });

    testWidgets('P5-N19: with no failure the last row is the loading row, '
        'which asks for the next page', (tester) async {
      final bloc = _bloc(_loaded());
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_app(CometChatCallLogs(callLogsBloc: bloc)));
        await tester.pump();
      });

      expect(_retry, findsNothing);
      verify(() => bloc.add(const LoadMoreCallLogs())).called(greaterThan(0));
    });
  });

  group('CallLogsList', () {
    testWidgets('P5-C15: a failed next page ends the list with a retry row '
        'instead of asking again on every build', (tester) async {
      final state = _loaded(loadMoreError: 'offline');
      final bloc = _bloc(state);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_app(CallLogsList(state: state, bloc: bloc)));
        await tester.pump();
      });

      expect(_retry, findsOneWidget);
      verifyNever(() => bloc.add(const LoadMoreCallLogs()));

      await tester.tap(_retry);
      await tester.pump();
      verify(() => bloc.add(const LoadMoreCallLogs())).called(1);
    });
  });

  testWidgets('P5-E27 end to end: the next page fails, Retry fetches it, '
      'the list grows and onError heard the failure once', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 3)],
        2: [remoteFailure(), callLogPage('b', 3, newest: 1600000000)],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(
      remote,
      builder: CallLogRequestBuilder()..limit = 3,
    );
    final errors = <Exception>[];
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _app(CometChatCallLogs(callLogsBloc: bloc, onError: errors.add)),
      );
      // The first load, then the loading row asks for page 2, which fails.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    });
    expect(bloc.state.callLogs, hasLength(3));
    expect(_retry, findsOneWidget);
    expect(errors, hasLength(1));

    await mockNetworkImagesFor(() async {
      await tester.tap(_retry);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    });
    expect(remote.pagesAsked.take(3), [1, 2, 2]);
    expect(bloc.state.callLogs, hasLength(6));
    expect(bloc.state.loadMoreError, isNull);
    expect(errors, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync<void>(bloc.close);
  });
}
