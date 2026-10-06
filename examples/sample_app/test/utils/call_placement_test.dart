import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'
    show CallButtonsState;
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/utils/call_placement.dart';

/// The card action's "initiate call" builds a call buttons bloc for one
/// call and closes it once the call is placed (round 2 review).
void main() {
  late StreamController<CallButtonsState> states;
  late int closes;

  setUp(() {
    states = StreamController<CallButtonsState>.broadcast();
    closes = 0;
  });

  tearDown(() => states.close());

  Future<void> close() async => closes++;

  testWidgets('not closed while the call is being placed, however long the '
      'permission prompt stays up', (WidgetTester tester) async {
    unawaited(closeWhenPlaced(states.stream, close));
    states.add(const CallButtonsState(isDisabled: true));
    await tester.pump(const Duration(minutes: 10));

    expect(closes, 0);

    // Placed: the outgoing screen is up, the buttons back.
    states.add(
      const CallButtonsState(isDisabled: false, isCallInProgress: true),
    );
    await tester.pump();
    expect(closes, 1);
  });

  test('a refusal before anything was placed closes it', () async {
    final done = closeWhenPlaced(states.stream, close);
    states.add(const CallButtonsState(errorMessage: 'Cannot initiate call'));
    await done;

    expect(closes, 1);
  });

  test(
    'a bloc closed some other way is closed once more, harmlessly',
    () async {
      final done = closeWhenPlaced(states.stream, close);
      await states.close();
      await done;

      expect(closes, 1);
    },
  );
}
