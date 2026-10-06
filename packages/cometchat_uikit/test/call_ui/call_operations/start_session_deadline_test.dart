/// `joinWithDeadline` waits for the Calls SDK's call view instead of
/// resolving early with a placeholder.
///
/// It used to resolve with an empty widget after 5 s, "assuming Android
/// native UI launched". The SDK returns an embedded view on Android and iOS
/// alike and joins only once that view is mounted, so a join slower than 5 s
/// showed a blank call screen that never joined.
///
/// `testWidgets` runs on a fake clock, so the deadlines below cost nothing.
///
///   flutter test test/call_ui/call_operations/start_session_deadline_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/start_session_deadline.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts [joinWithDeadline] and records how it settles.
class _Join {
  _Join({void Function()? onLateSuccess}) {
    unawaited(
      joinWithDeadline(
        (ok, err) {
          succeed = ok;
          fail = err;
        },
        onLateSuccess: onLateSuccess,
      ).then((w) => result = w, onError: (Object e) => error = e),
    );
  }

  late void Function(Widget? screen) succeed;
  late void Function(CometChatCallsException e) fail;
  Widget? result;
  Object? error;
}

void main() {
  group('joinWithDeadline', () {
    testWidgets('a join slower than 5 s still returns the real call view', (
      tester,
    ) async {
      final join = _Join();

      await tester.pump(const Duration(seconds: 6));
      expect(
        join.result,
        isNull,
        reason: 'still waiting at 6 s; the old code had given up at 5 s',
      );

      const view = Text('call view', textDirection: TextDirection.ltr);
      join.succeed(view);
      await tester.pump();

      expect(join.result, same(view));
      expect(join.error, isNull);
    });

    testWidgets('an SDK error becomes a CallOperationsException', (
      tester,
    ) async {
      final join = _Join();
      final sdkError = CometChatCallsException('ERR_X', 'join failed', null);

      join.fail(sdkError);
      await tester.pump();

      expect(join.result, isNull);
      final error = join.error as CallOperationsException;
      expect(error.code, 'ERR_X');
      expect(error.message, 'join failed');
      expect(error.originalException, same(sdkError));
    });

    testWidgets('no answer by the deadline fails instead of faking success', (
      tester,
    ) async {
      final join = _Join();

      await tester.pump(kStartSessionTimeout - const Duration(seconds: 1));
      expect(join.error, isNull);
      expect(join.result, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(join.result, isNull, reason: 'no placeholder view');
      final error = join.error as CallOperationsException;
      expect(error.code, kStartSessionTimeoutCode);
      expect(error.message, isNotEmpty);
    });

    testWidgets('a view that arrives after the deadline is undone once', (
      tester,
    ) async {
      var lateSuccesses = 0;
      final join = _Join(onLateSuccess: () => lateSuccesses++);

      await tester.pump(kStartSessionTimeout);
      expect(join.error, isA<CallOperationsException>());

      join.succeed(const SizedBox());
      join.fail(CometChatCallsException('ERR_LATE', 'late', null));
      await tester.pump();

      expect(lateSuccesses, 1);
      expect(join.result, isNull, reason: 'the late view is never shown');
      expect(
        (join.error as CallOperationsException).code,
        kStartSessionTimeoutCode,
        reason: 'the late error does not replace the timeout',
      );
    });

    testWidgets('a success in time does not call onLateSuccess', (
      tester,
    ) async {
      var lateSuccesses = 0;
      final join = _Join(onLateSuccess: () => lateSuccesses++);

      join.succeed(const SizedBox());
      await tester.pump(kStartSessionTimeout * 2);

      expect(lateSuccesses, 0);
      expect(join.error, isNull);
    });

    testWidgets('a null view resolves to an empty widget', (tester) async {
      final join = _Join();

      join.succeed(null);
      await tester.pump();

      expect(join.result, isA<SizedBox>());
    });

    testWidgets('an SDK that answers synchronously leaves no timer behind', (
      tester,
    ) async {
      Widget? result;
      unawaited(
        joinWithDeadline(
          (ok, err) => ok(const SizedBox()),
        ).then((w) => result = w),
      );
      await tester.pump();

      // testWidgets fails the test if a Timer is still pending here.
      expect(result, isA<SizedBox>());
    });
  });
}
