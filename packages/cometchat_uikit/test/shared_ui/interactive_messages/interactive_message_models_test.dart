/// Behaviour tests for the interactive message models —
/// Track 3 TEST3 (ENG-38684).
///
/// `card_message.dart`, `form_message.dart` and `scheduler_message.dart` were
/// all at zero line coverage. Each is a thin model over
/// [InteractiveMessage.interactiveData], and each carries the same three
/// conversions, which is where the interesting behaviour is:
///
///   * the constructor, which packs its fields into `interactiveData`
///   * `toInteractiveMessage()`, which repacks them
///   * `fromInteractiveMessage()`, which unpacks them again
///
/// A round trip through those three is the contract the message list depends
/// on, and none of it was exercised.
///
///   flutter test test/shared_ui/interactive_messages/interactive_message_models_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

ButtonElement _button(String id, String label) =>
    ButtonElement(elementId: id, buttonText: label);

final _sender = User(uid: 'u1', name: 'Alice');

/// `InteractiveMessage.toJson` in the SDK casts `receiver` to `User`
/// unconditionally, so a message with no receiver throws on serialisation.
final _receiver = User(uid: 'u2', name: 'Bob');

void main() {
  // -------------------------------------------------------------------------
  group('CardMessage', () {
    CometChatInteractiveCardMessage build() => CometChatInteractiveCardMessage(
      text: 'Pick one',
      imageUrl: 'https://x/card.png',
      cardActions: [_button('b1', 'Yes'), _button('b2', 'No')],
      receiverUid: 'u2',
      receiverType: CometChatReceiverType.user,
      sender: _sender,
      receiver: _receiver,
    );

    test(
      'the constructor packs text, image and actions into interactiveData',
      () {
        final card = build();
        expect(card.text, 'Pick one');
        expect(card.imageUrl, 'https://x/card.png');
        expect(card.cardActions, hasLength(2));

        // The packing is what the wire format actually carries.
        expect(card.interactiveData['text'], 'Pick one');
        expect(card.interactiveData['imageUrl'], 'https://x/card.png');
        expect(card.interactiveData['cardActions'], hasLength(2));
      },
    );

    test('the alias names the same class', () {
      expect(build(), isA<CometChatInteractiveCardMessage>());
    });

    test('defaults fill in for the inherited optionals', () {
      final card = build();
      expect(card.id, 0);
      expect(card.muid, '');
      expect(card.parentMessageId, 0);
      expect(card.replyCount, 0);
      expect(card.allowSenderInteraction, isFalse);
      expect(card.interactionGoal?.elementIds, isEmpty);
      expect(card.type, MessageTypeConstants.card);
    });

    test('toInteractiveMessage repacks after the fields are mutated', () {
      final card = build();
      card.text = 'Changed';
      card.imageUrl = null;
      card.cardActions = [_button('b3', 'Maybe')];

      final packed = card.toInteractiveMessage();
      expect(packed.interactiveData['text'], 'Changed');
      expect(packed.interactiveData['imageUrl'], isNull);
      expect(packed.interactiveData['cardActions'], hasLength(1));
    });

    test('fromInteractiveMessage round-trips text, image and actions', () {
      final restored = CometChatInteractiveCardMessage.fromInteractiveMessage(
        build().toInteractiveMessage(),
      );
      expect(restored.text, 'Pick one');
      expect(restored.imageUrl, 'https://x/card.png');
      expect(restored.cardActions, hasLength(2));
      expect(restored.cardActions.first.elementId, 'b1');
      expect(restored.receiverUid, 'u2');
      expect(restored.sender?.uid, 'u1');
    });

    test('fromInteractiveMessage tolerates missing actions and text', () {
      final bare = InteractiveMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: MessageTypeConstants.card,
        interactiveData: {},
        interactionGoal: InteractionGoal(
          type: InteractionGoalTypeConstants.none,
          elementIds: [],
        ),
      );
      final restored = CometChatInteractiveCardMessage.fromInteractiveMessage(
        bare,
      );
      expect(restored.text, '', reason: 'missing text falls back to empty');
      expect(restored.cardActions, isEmpty);
      expect(restored.imageUrl, isNull);
    });

    test('toJson carries the card fields alongside the base message', () {
      final json = build().toJson();
      expect(json['text'], 'Pick one');
      expect(json['imageUrl'], 'https://x/card.png');
      expect(json['actions'], hasLength(2));
    });
  });

  // -------------------------------------------------------------------------
  group('FormMessage', () {
    FormMessage build() => FormMessage(
      title: 'Sign up',
      formFields: [_button('f1', 'Name')],
      submitElement: _button('submit', 'Send'),
      goalCompletionText: 'Thanks',
      receiverUid: 'u2',
      receiverType: CometChatReceiverType.user,
      sender: _sender,
      receiver: _receiver,
      interactionGoal: InteractionGoal(
        type: InteractionGoalTypeConstants.none,
        elementIds: [],
      ),
    );

    test('the constructor holds its fields but does NOT pack them', () {
      // Asymmetry worth knowing: CardMessage packs interactiveData eagerly in
      // its constructor, FormMessage leaves it empty — the packing lines are
      // commented out — and relies on toInteractiveMessage(), which
      // sdk_methods.dart calls on the send path.
      final form = build();
      expect(form.title, 'Sign up');
      expect(form.formFields, hasLength(1));
      expect(form.submitElement.elementId, 'submit');
      expect(
        form.interactiveData,
        isEmpty,
        reason: 'packing is deferred to toInteractiveMessage()',
      );
    });

    test('toInteractiveMessage is what actually fills interactiveData', () {
      final packed = build().toInteractiveMessage();
      expect(packed.interactiveData['title'], 'Sign up');
      expect(packed.interactiveData['formFields'], hasLength(1));
    });

    test('type defaults to the form message type', () {
      expect(build().type, MessageTypeConstants.form);
    });

    test('fromInteractiveMessage round-trips the form', () {
      final restored = FormMessage.fromInteractiveMessage(
        build().toInteractiveMessage(),
      );
      expect(restored.title, 'Sign up');
      expect(restored.formFields, hasLength(1));
      expect(restored.formFields.first.elementId, 'f1');
      expect(restored.submitElement.elementId, 'submit');
      expect(restored.goalCompletionText, 'Thanks');
    });

    test('toInteractiveMessage repacks a mutated title', () {
      final form = build();
      form.title = 'Renamed';
      expect(form.toInteractiveMessage().interactiveData['title'], 'Renamed');
    });

    test('toJson carries the form fields', () {
      final json = build().toJson();
      expect(json['title'], 'Sign up');
      expect(json['formFields'], hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  group('SchedulerMessage', () {
    SchedulerMessage build() => SchedulerMessage(
      receiverUid: 'u2',
      receiverType: CometChatReceiverType.user,
      sender: _sender,
      receiver: _receiver,
      title: 'Book a slot',
      duration: 30,
      bufferTime: 15,
      timezoneCode: 'America/New_York',
      availability: {
        'monday': [TimeRange(from: '0900', to: '1700')],
      },
    );

    test('the constructor packs the scheduling fields', () {
      final s = build();
      expect(s.title, 'Book a slot');
      expect(s.duration, 30);
      expect(s.bufferTime, 15);
      expect(s.timezoneCode, 'America/New_York');
      expect(s.availability?['monday'], hasLength(1));
    });

    test('type defaults to the scheduler message type', () {
      expect(build().type, MessageTypeConstants.scheduler);
    });

    test('fromInteractiveMessage round-trips duration and availability', () {
      final restored = SchedulerMessage.fromInteractiveMessage(
        build().toInteractiveMessage(),
      );
      expect(restored.title, 'Book a slot');
      expect(restored.duration, 30);
      expect(restored.bufferTime, 15);
      expect(restored.timezoneCode, 'America/New_York');
      expect(restored.availability?['monday'], hasLength(1));
      expect(restored.availability!['monday']!.first.from, '0900');
    });

    /// Everything optional filled in, so each `isValidString` /
    /// `isValidInteger` guard in `toInteractiveMessage` and `toJson` takes
    /// its true arm.
    SchedulerMessage buildFull() => SchedulerMessage(
      receiverUid: 'u2',
      receiverType: CometChatReceiverType.user,
      sender: _sender,
      receiver: _receiver,
      title: 'Book a slot',
      avatarUrl: 'https://x/avatar.png',
      goalCompletionText: 'Booked!',
      timezoneCode: 'America/New_York',
      bufferTime: 15,
      duration: 30,
      dateRangeStart: '2026-09-08',
      dateRangeEnd: '2026-09-30',
      icsFileUrl: 'https://x/event.ics',
      scheduleElement: _button('sched', 'Schedule'),
      availability: {
        'monday': [TimeRange(from: '0900', to: '1700')],
        'tuesday': [
          TimeRange(from: '0900', to: '1200'),
          TimeRange(from: '1300', to: '1700'),
        ],
      },
    );

    test('toInteractiveMessage repacks every optional field', () {
      final data = buildFull().toInteractiveMessage().interactiveData;
      expect(data[ModelFieldConstants.title], 'Book a slot');
      expect(data[ModelFieldConstants.goalCompletionText], 'Booked!');
      expect(data[ModelFieldConstants.avatarUrl], 'https://x/avatar.png');
      expect(data[ModelFieldConstants.icsFileUrl], 'https://x/event.ics');
      expect(data[ModelFieldConstants.timezoneCode], 'America/New_York');
      expect(data[ModelFieldConstants.bufferTime], 15);
      expect(data[ModelFieldConstants.duration], 30);
      expect(data[ModelFieldConstants.dateRangeStart], '2026-09-08');
      expect(data[ModelFieldConstants.dateRangeEnd], '2026-09-30');
      // The button is written twice, under both keys the renderer may read.
      for (final key in [
        ModelFieldConstants.submitElement,
        ModelFieldConstants.scheduleElement,
      ]) {
        final map = data[key] as Map<String, dynamic>;
        expect(map[ModelFieldConstants.elementId], 'sched');
        expect(map[ModelFieldConstants.buttonText], 'Schedule');
      }
      final availability =
          data[ModelFieldConstants.availability] as Map<String, dynamic>;
      expect(availability['tuesday'], hasLength(2));
    });

    test('toInteractiveMessage skips blank strings and non-positive ints', () {
      // The guards are `isValidString` / `isValidInteger`, so whitespace and
      // zero are treated as absent and the constructor's value stands.
      final s = SchedulerMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        sender: _sender,
        receiver: _receiver,
        title: '   ',
        avatarUrl: '',
        icsFileUrl: '',
        goalCompletionText: '',
        timezoneCode: '',
        bufferTime: 0,
        duration: -5,
        dateRangeStart: '',
        dateRangeEnd: '   ',
      );
      final data = s.toInteractiveMessage().interactiveData;
      // Constructor wrote the raw values; the guarded re-write did not fire,
      // so what is there is exactly what the constructor put there.
      expect(data[ModelFieldConstants.title], '   ');
      expect(data[ModelFieldConstants.bufferTime], 0);
      expect(data[ModelFieldConstants.duration], -5);
      // No schedule element was supplied, so both keys stay null.
      expect(data[ModelFieldConstants.submitElement], isNull);
      expect(data[ModelFieldConstants.scheduleElement], isNull);
    });

    test('fromInteractiveMessage restores the schedule button', () {
      final restored = SchedulerMessage.fromInteractiveMessage(
        buildFull().toInteractiveMessage(),
      );
      expect(restored.scheduleElement?.elementId, 'sched');
      expect(restored.scheduleElement?.buttonText, 'Schedule');
      expect(restored.avatarUrl, 'https://x/avatar.png');
      expect(restored.icsFileUrl, 'https://x/event.ics');
      expect(restored.goalCompletionText, 'Booked!');
      expect(restored.dateRangeStart, '2026-09-08');
      expect(restored.dateRangeEnd, '2026-09-30');
      expect(restored.availability?['tuesday'], hasLength(2));
      expect(restored.availability!['tuesday']![1].to, '1700');
    });

    test('fromInteractiveMessage substitutes a placeholder button', () {
      // A scheduler message whose payload has no button still has to render,
      // so the model fabricates one rather than returning null.
      final restored = SchedulerMessage.fromInteractiveMessage(
        build().toInteractiveMessage(),
      );
      expect(restored.scheduleElement?.buttonText, 'Not found');
      expect(restored.scheduleElement?.elementType, 'button');
    });

    test('toJson carries the scheduling fields and flattens availability', () {
      final json = buildFull().toJson();
      expect(json[ModelFieldConstants.title], 'Book a slot');
      expect(json[ModelFieldConstants.goalCompletionText], 'Booked!');
      expect(json[ModelFieldConstants.avatarUrl], 'https://x/avatar.png');
      expect(json[ModelFieldConstants.icsFileUrl], 'https://x/event.ics');
      expect(json[ModelFieldConstants.timezoneCode], 'America/New_York');
      expect(json[ModelFieldConstants.bufferTime], 15);
      expect(json[ModelFieldConstants.duration], 30);
      expect(json[ModelFieldConstants.dateRangeStart], '2026-09-08');
      expect(json[ModelFieldConstants.dateRangeEnd], '2026-09-30');
      expect(
        (json[ModelFieldConstants.scheduleElement]
            as Map)[ModelFieldConstants.buttonText],
        'Schedule',
      );
      expect(json[ModelFieldConstants.availability], {
        'monday': [
          {'from': '0900', 'to': '1700'},
        ],
        'tuesday': [
          {'from': '0900', 'to': '1200'},
          {'from': '1300', 'to': '1700'},
        ],
      });
    });

    test('toJson omits the optional fields that are blank or non-positive', () {
      final json = SchedulerMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        sender: _sender,
        receiver: _receiver,
        title: 'Only a title',
        avatarUrl: '',
        icsFileUrl: '  ',
        timezoneCode: '',
        bufferTime: 0,
        duration: 0,
        dateRangeStart: '',
        dateRangeEnd: '',
      ).toJson();
      expect(json[ModelFieldConstants.title], 'Only a title');
      expect(json.containsKey(ModelFieldConstants.avatarUrl), isFalse);
      expect(json.containsKey(ModelFieldConstants.icsFileUrl), isFalse);
      expect(json.containsKey(ModelFieldConstants.timezoneCode), isFalse);
      expect(json.containsKey(ModelFieldConstants.bufferTime), isFalse);
      expect(json.containsKey(ModelFieldConstants.duration), isFalse);
      expect(json.containsKey(ModelFieldConstants.dateRangeStart), isFalse);
      expect(json.containsKey(ModelFieldConstants.dateRangeEnd), isFalse);
      // goalCompletionText is guarded on null, not on blankness, and there
      // was none, so it is absent too.
      expect(json.containsKey(ModelFieldConstants.goalCompletionText), isFalse);
      // A null scheduleElement is still written, as an explicit null.
      expect(json.containsKey(ModelFieldConstants.scheduleElement), isTrue);
      expect(json[ModelFieldConstants.scheduleElement], isNull);
      // No availability at all still produces an (empty) map, never null.
      expect(json[ModelFieldConstants.availability], isEmpty);
    });

    test('toJson keeps an empty goalCompletionText, since it checks null', () {
      final json = SchedulerMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        sender: _sender,
        receiver: _receiver,
        goalCompletionText: '',
      ).toJson();
      expect(json[ModelFieldConstants.goalCompletionText], '');
    });

    test('toString names every scheduling field', () {
      final s = buildFull().toString();
      for (final fragment in [
        'Book a slot',
        'Booked!',
        'https://x/avatar.png',
        'https://x/event.ics',
        'America/New_York',
        '15',
        '30',
        '2026-09-08',
        '2026-09-30',
        'monday',
      ]) {
        expect(s, contains(fragment), reason: fragment);
      }
    });

    test('TimeRange serialises to its from/to pair', () {
      expect(TimeRange(from: '0900', to: '1700').toJson(), {
        'from': '0900',
        'to': '1700',
      });
    });

    test('TimeRange toString names both ends', () {
      final s = TimeRange(from: '0900', to: '1700').toString();
      expect(s, contains('0900'));
      expect(s, contains('1700'));
    });
  });
}
