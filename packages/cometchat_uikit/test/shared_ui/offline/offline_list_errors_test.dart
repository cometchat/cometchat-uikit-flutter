/// D83 (ENG-41552): the route from a list's bloc to its widget's `onError` for
/// a server error over cached rows that stay on screen.
///
///   flutter test test/shared_ui/offline/offline_list_errors_test.dart
library;

import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final error = CometChatException('ERR_CONNECTION', 'x', 'x');

  test('a report reaches the sink listening for that owner only', () {
    final a = Object();
    final b = Object();
    final got = <CometChatException>[];
    OfflineListErrors.listen(a, got.add);
    OfflineListErrors.report(b, error);
    expect(got, isEmpty);
    OfflineListErrors.report(a, error);
    expect(got, [error]);
  });

  test('a report with no listener does nothing', () {
    expect(() => OfflineListErrors.report(Object(), error), returnsNormally);
  });

  test('cancel stops the sink; a stale cancel leaves a newer sink', () {
    final owner = Object();
    final first = <CometChatException>[];
    final second = <CometChatException>[];
    void firstSink(CometChatException e) => first.add(e);
    void secondSink(CometChatException e) => second.add(e);

    OfflineListErrors.listen(owner, firstSink);
    OfflineListErrors.listen(owner, secondSink);
    OfflineListErrors.cancel(owner, firstSink);
    OfflineListErrors.report(owner, error);
    expect(first, isEmpty);
    expect(second, [error]);

    OfflineListErrors.cancel(owner, secondSink);
    OfflineListErrors.report(owner, error);
    expect(second, [error]);
  });
}
