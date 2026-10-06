/// Behaviour tests for InteractiveMessageUtils — Track 3 TEST3 (ENG-38684).
///
/// `interaction_message_utils.dart` was at zero line coverage. It decides
/// whether an interactive element is disabled, whether a message's interaction
/// goal has been met, and what payload is sent when someone taps one — all
/// pure logic over maps, and all previously unexercised.
///
///   flutter test test/shared_ui/utils/interaction_message_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');

ButtonElement _button(
  String id, {
  bool? disableAfterInteracted,
  ActionEntity? action,
}) => ButtonElement(
  elementId: id,
  buttonText: id,
  disableAfterInteracted: disableAfterInteracted,
  action: action,
);

InteractiveMessage _message({
  String type = MessageTypeConstants.card,
  bool allowSenderInteraction = false,
  InteractionGoal? goal,
  Map<String, dynamic>? data,
}) => InteractiveMessage(
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: type,
  sender: _alice,
  receiver: _bob,
  conversationId: 'u1_user_u2',
  allowSenderInteraction: allowSenderInteraction,
  interactiveData: data ?? {},
  interactionGoal:
      goal ??
      InteractionGoal(type: InteractionGoalTypeConstants.none, elementIds: []),
)..id = 42;

void main() {
  // -------------------------------------------------------------------------
  group('checkIsSentByMe', () {
    test('true when the logged-in user is the sender', () {
      expect(
        InteractiveMessageUtils.checkIsSentByMe(_alice, _message()),
        isTrue,
      );
    });

    test('false for a different user', () {
      expect(
        InteractiveMessageUtils.checkIsSentByMe(_bob, _message()),
        isFalse,
      );
    });

    test('false when there is no logged-in user', () {
      expect(
        InteractiveMessageUtils.checkIsSentByMe(null, _message()),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('checkElementDisabled', () {
    test('disabled once interacted, when the element opts in', () {
      expect(
        InteractiveMessageUtils.checkElementDisabled(
          {'b1': true},
          _button('b1', disableAfterInteracted: true),
          false,
          _message(),
        ),
        isTrue,
      );
    });

    test('an interacted element that does not opt in stays enabled', () {
      expect(
        InteractiveMessageUtils.checkElementDisabled(
          {'b1': true},
          _button('b1', disableAfterInteracted: false),
          false,
          _message(),
        ),
        isFalse,
      );
    });

    test(
      'the sender is disabled unless the message allows sender interaction',
      () {
        expect(
          InteractiveMessageUtils.checkElementDisabled(
            {},
            _button('b1'),
            true, // isSentByMe
            _message(allowSenderInteraction: false),
          ),
          isTrue,
        );
      },
    );

    test('the sender is enabled when the message allows it', () {
      expect(
        InteractiveMessageUtils.checkElementDisabled(
          {},
          _button('b1'),
          true,
          _message(allowSenderInteraction: true),
        ),
        isFalse,
      );
    });

    test('a receiver with no prior interaction is enabled', () {
      expect(
        InteractiveMessageUtils.checkElementDisabled(
          {},
          _button('b1', disableAfterInteracted: true),
          false,
          _message(),
        ),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('checkInteractionGoalAchievedFromMap', () {
    InteractionGoal goal(String type, List<String> ids) =>
        InteractionGoal(type: type, elementIds: ids);

    test('a goal of none is never achieved, even with interactions', () {
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(
          goal(InteractionGoalTypeConstants.none, ['a']),
          {'a': true},
        ),
        isFalse,
      );
    });

    test('anyAction is achieved by a single interaction', () {
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(
          goal(InteractionGoalTypeConstants.anyAction, []),
          {'anything': true},
        ),
        isTrue,
      );
    });

    test('anyAction is not achieved with an empty map', () {
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(
          goal(InteractionGoalTypeConstants.anyAction, []),
          {},
        ),
        isFalse,
      );
    });

    test('allOf needs every named element', () {
      final g = goal(InteractionGoalTypeConstants.allOf, ['a', 'b']);
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(g, {
          'a': true,
        }),
        isFalse,
        reason: 'b is missing',
      );
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(g, {
          'a': true,
          'b': true,
        }),
        isTrue,
      );
    });

    test('allOf with no named elements is vacuously achieved', () {
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(
          goal(InteractionGoalTypeConstants.allOf, []),
          {},
        ),
        isTrue,
      );
    });

    test('anyOf needs one of the named elements', () {
      final g = goal(InteractionGoalTypeConstants.anyOf, ['a', 'b']);
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(g, {
          'b': true,
        }),
        isTrue,
      );
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(g, {
          'c': true,
        }),
        isFalse,
        reason: 'c is not one of the named elements',
      );
    });

    test('anyOf with no named elements is never achieved', () {
      expect(
        InteractiveMessageUtils.checkInteractionGoalAchievedFromMap(
          goal(InteractionGoalTypeConstants.anyOf, []),
          {'a': true},
        ),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('getSpecificMessageFromInteractiveMessage', () {
    test('a card message narrows to CardMessage', () {
      final m =
          InteractiveMessageUtils.getSpecificMessageFromInteractiveMessage(
            _message(type: MessageTypeConstants.card, data: {'text': 'hi'}),
          );
      expect(m, isA<CometChatInteractiveCardMessage>());
    });

    test('a well-formed scheduler message narrows to SchedulerMessage', () {
      final packed = SchedulerMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        sender: _alice,
        receiver: _bob,
        title: 'Book',
        duration: 30,
        bufferTime: 15,
        timezoneCode: 'America/New_York',
        availability: {
          'monday': [TimeRange(from: '0900', to: '1700')],
        },
      ).toInteractiveMessage();

      final m =
          InteractiveMessageUtils.getSpecificMessageFromInteractiveMessage(
            packed,
          );
      expect(m, isA<SchedulerMessage>());
      expect((m as SchedulerMessage).duration, 30);
    });

    test('a scheduler message with an empty payload degrades, not throws', () {
      // Used to raise NoSuchMethodError inside message-list rendering, since
      // type alone is enough to reach the scheduler path. ENG-39022.
      final m =
          InteractiveMessageUtils.getSpecificMessageFromInteractiveMessage(
            _message(type: MessageTypeConstants.scheduler),
          );
      expect(m, isA<SchedulerMessage>());
      expect((m as SchedulerMessage).availability, isEmpty);
    });

    test('a scheduler message with a malformed payload also degrades', () {
      final m =
          InteractiveMessageUtils.getSpecificMessageFromInteractiveMessage(
            _message(
              type: MessageTypeConstants.scheduler,
              data: {'availability': 'not a map'},
            ),
          );
      expect(m, isA<SchedulerMessage>());
      expect((m as SchedulerMessage).availability, isEmpty);
    });

    test('an unrecognised type is returned unchanged', () {
      final original = _message(type: 'something_else');
      expect(
        identical(
          InteractiveMessageUtils.getSpecificMessageFromInteractiveMessage(
            original,
          ),
          original,
        ),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('getInteractiveRequestData', () {
    Map<String, dynamic> build({
      ActionEntity? action,
      Map<String, dynamic>? body,
    }) => InteractiveMessageUtils.getInteractiveRequestData(
      message: _message(),
      element: _button('b1', action: action),
      interactionTimezoneCode: 'America/New_York',
      interactedBy: 'u2',
      body: body,
    );

    test('the data block carries the message identity and the element', () {
      final data = build()['data'] as Map<String, dynamic>;
      expect(data['conversationId'], 'u1_user_u2');
      expect(data['sender'], 'u1');
      expect(data['receiver'], 'u2');
      expect(data['receiverType'], CometChatReceiverType.user);
      expect(data['messageType'], MessageTypeConstants.card);
      expect(data['messageId'], 42);
      expect(data['interactionTimezoneCode'], 'America/New_York');
      expect(data['interactedBy'], 'u2');
      expect(data['interactedElementId'], 'b1');
    });

    test('the trigger marks a UI interaction', () {
      expect(
        build()['trigger'],
        InteractiveMessageConstants.uiMessageInteracted,
      );
    });

    test('an extra body is merged at the top level', () {
      final r = build(body: {'extra': 'value'});
      expect(r['extra'], 'value');
    });

    test('an empty body is not merged', () {
      expect(build(body: {}).containsKey('extra'), isFalse);
    });

    // An inner `action == null` guard used to make this branch unreachable,
    // so the payload was silently dropped from every request. ENG-39022.
    test('an API action contributes its payload', () {
      final r = build(
        action: APIAction(
          url: 'https://example.com/hook',
          method: 'POST',
          payload: {'k': 'v'},
        ),
      );
      expect(r['payload'], {'k': 'v'});
    });

    test('an API action with no payload contributes an empty map', () {
      final r = build(
        action: APIAction(url: 'https://example.com/hook', method: 'POST'),
      );
      expect(r['payload'], isEmpty);
    });

    test('a non-API action contributes no payload key', () {
      expect(build().containsKey('payload'), isFalse);
    });
  });
}
