/// Construction and round-trip tests for the interactive form elements —
/// Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Twelve exported classes in `data/models/interactive_elements/` had never
/// been constructed by any test: the eight concrete elements, the two base
/// classes they share, `OptionElement` and `TextInputPlaceholder`. They are
/// the model layer under every interactive message a customer receives, and
/// the whole layer is `dynamic`-typed map plumbing — `fromMap` takes
/// `dynamic`, indexes it with string keys and passes the results straight
/// into typed constructors. That shape does not fail at compile time; it
/// fails at runtime on a payload with a key missing.
///
/// So the tests below are mostly about the map boundary: what each element
/// packs into `toMap`, what it accepts back from `fromMap`, what
/// `validateResponse` treats as answered, and which fields do not survive a
/// round trip. Four defects surfaced while writing them; all four are now
/// fixed (ENG-39098) and the cases that recorded them assert the corrected
/// behaviour instead, each marked FIXED with what the bug had been.
///
///   flutter test test/shared_ui/interactive_messages/interactive_elements_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal option pair, used by every element that offers choices.
OptionElement _option(String value, String label) =>
    OptionElement(value: value, label: label);

void main() {
  // ---------------------------------------------------------------------------
  group('ElementEntity', () {
    test('carries its type and id into the map', () {
      final entity = ElementEntity(elementType: 'label', elementId: 'e1');

      expect(entity.toMap(), <String, dynamic>{
        'elementType': 'label',
        'elementId': 'e1',
      });
    });

    test('fromMap dispatches to the subclass named by elementType', () {
      expect(
        ElementEntity.fromMap(<String, dynamic>{
          'elementType': 'label',
          'elementId': 'e1',
          'text': 'Name',
        }),
        isA<LabelElement>(),
      );
      expect(
        ElementEntity.fromMap(<String, dynamic>{
          'elementType': 'textInput',
          'elementId': 'e2',
          'label': 'Email',
        }),
        isA<TextInputElement>(),
      );
      expect(
        ElementEntity.fromMap(<String, dynamic>{
          'elementType': 'dropdown',
          'elementId': 'e3',
          'label': 'Size',
          'options': <dynamic>[],
        }),
        isA<DropdownElement>(),
      );
    });

    test('an unrecognised elementType falls back to a bare entity', () {
      final entity = ElementEntity.fromMap(<String, dynamic>{
        'elementType': 'somethingTheServerAddedLater',
        'elementId': 'e9',
      });

      expect(entity.runtimeType, ElementEntity);
      expect(entity.elementType, 'somethingTheServerAddedLater');
    });

    test('type and id are mutable after construction', () {
      final entity = ElementEntity(elementType: 'label', elementId: 'e1')
        ..elementType = 'button'
        ..elementId = 'e2';

      expect(entity.toMap()['elementType'], 'button');
      expect(entity.toMap()['elementId'], 'e2');
    });
  });

  // ---------------------------------------------------------------------------
  group('BaseInteractiveElement', () {
    test('omits action from the map when there is none, and always writes the '
        'interaction flag', () {
      final element = BaseInteractiveElement(
        elementId: 'b1',
        elementType: 'button',
      );

      final map = element.toMap();
      expect(map.containsKey('action'), isFalse);
      expect(map['disableAfterInteracted'], isFalse);
    });

    test('nests the action map when one is supplied', () {
      final element = BaseInteractiveElement(
        elementId: 'b1',
        elementType: 'button',
        action: URLNavigationAction(url: 'https://cometchat.com'),
        disableAfterInteracted: true,
      );

      final map = element.toMap();
      expect(map['disableAfterInteracted'], isTrue);
      expect(map['action'], isA<Map<String, dynamic>>());
      expect((map['action'] as Map)['url'], 'https://cometchat.com');
    });

    test('fromMap routes a button payload to ButtonElement', () {
      expect(
        BaseInteractiveElement.fromMap(<String, dynamic>{
          'elementType': 'button',
          'elementId': 'b1',
          'buttonText': 'Send',
        }),
        isA<ButtonElement>(),
      );
    });

    test('FIXED — a payload that omits disableAfterInteracted defaults to '
        'false', () {
      // Was a TypeError: the non-nullable bool was assigned straight from a
      // possibly-absent key. The field's own `= false` default said an absent
      // key was legal, so the crash contradicted the constructor. ENG-39098.
      final element = BaseInteractiveElement.fromMap(<String, dynamic>{
        'elementType': 'custom',
        'elementId': 'x1',
      });

      expect(element.disableAfterInteracted, isFalse);
      expect(element.elementId, 'x1');
    });
  });

  // ---------------------------------------------------------------------------
  group('LabelElement', () {
    test('defaults its type to label and round-trips its text', () {
      final label = LabelElement(elementId: 'l1', text: 'Full name');
      expect(label.elementType, 'label');

      final restored = LabelElement.fromMap(label.toMap());
      expect(restored.elementId, 'l1');
      expect(restored.elementType, 'label');
      expect(restored.text, 'Full name');
    });
  });

  // ---------------------------------------------------------------------------
  group('OptionElement', () {
    test('round-trips a value and label pair', () {
      final restored = OptionElement.fromMap(_option('sm', 'Small').toMap());
      expect(restored.value, 'sm');
      expect(restored.label, 'Small');
    });

    test('drops empty strings from the map rather than writing blanks', () {
      // toMap guards both fields with Utils.isValidString, so an option built
      // with empty strings serialises to nothing at all.
      expect(_option('', '').toMap(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('TextInputPlaceholder', () {
    test('round-trips its text', () {
      final restored = TextInputPlaceholder.fromMap(
        TextInputPlaceholder(text: 'you@example.com').toMap(),
      );
      expect(restored.text, 'you@example.com');
    });
  });

  // ---------------------------------------------------------------------------
  group('TextInputElement', () {
    TextInputElement build() => TextInputElement(
      elementId: 't1',
      label: 'Email',
      maxLines: 3,
      placeholder: TextInputPlaceholder(text: 'you@example.com'),
    );

    test('defaults its type to textInput and is optional by default', () {
      final element = TextInputElement(elementId: 't1', label: 'Email');
      expect(element.elementType, 'textInput');
      expect(element.optional, isTrue);
      expect(element.maxLines, 1);
    });

    test('writes label, maxLines and the nested placeholder', () {
      final map = build().toMap();
      expect(map['label'], 'Email');
      expect(map['maxLines'], 3);
      expect((map['placeholder'] as Map)['text'], 'you@example.com');
    });

    test('omits the placeholder key when there is none', () {
      final map = TextInputElement(elementId: 't1', label: 'Email').toMap();
      expect(map.containsKey('placeholder'), isFalse);
    });

    test('round-trips through fromMap', () {
      final restored = TextInputElement.fromMap(build().toMap());
      expect(restored.label, 'Email');
      expect(restored.maxLines, 3);
      expect(restored.placeholder?.text, 'you@example.com');
    });

    test('fromMap supplies defaults for a sparse payload', () {
      // The only element in the family that defends itself against missing
      // keys. The others do not — see the checkbox and date-time cases below.
      final restored = TextInputElement.fromMap(<String, dynamic>{
        'elementType': 'textInput',
        'elementId': 't9',
      });

      expect(restored.label, 'Default text');
      expect(restored.maxLines, 1);
      expect(restored.optional, isTrue);
    });

    test('validateResponse rejects null and empty, accepts text', () {
      final element = build();
      expect(element.validateResponse(), isFalse);

      element.response = '';
      expect(element.validateResponse(), isFalse);

      element.response = 'a@b.com';
      expect(element.validateResponse(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('CheckBoxElement', () {
    CheckBoxElement build() => CheckBoxElement(
      elementId: 'c1',
      label: 'Toppings',
      options: [_option('ch', 'Cheese'), _option('mu', 'Mushroom')],
    );

    test('defaults its type to checkbox and is optional by default', () {
      final element = build();
      expect(element.elementType, 'checkbox');
      expect(element.optional, isTrue);
      expect(element.isChecked, isNull);
    });

    test('serialises its options as a list of maps', () {
      final map = build().toMap();
      expect(map['label'], 'Toppings');
      expect(map['options'], hasLength(2));
      expect((map['options'] as List).first, <String, dynamic>{
        'value': 'ch',
        'label': 'Cheese',
      });
    });

    test('round-trips through fromMap when the payload is complete', () {
      final map = build().toMap()..['optional'] = false;
      final restored = CheckBoxElement.fromMap(map);

      expect(restored.label, 'Toppings');
      expect(restored.optional, isFalse);
      expect(restored.options.map((o) => o.value), ['ch', 'mu']);
    });

    test('validateResponse rejects null and empty, accepts a selection', () {
      final element = build();
      expect(element.validateResponse(), isFalse);

      element.response = <String>[];
      expect(element.validateResponse(), isFalse);

      element.response = <String>['ch'];
      expect(element.validateResponse(), isTrue);
    });

    test('isChecked tracks per-option state independently of the response', () {
      final element = build()..isChecked = {'ch': true, 'mu': false};
      expect(element.isChecked!['ch'], isTrue);
      expect(element.isChecked!['mu'], isFalse);
    });

    test('FIXED — a payload that omits optional defaults to true', () {
      // Was a TypeError: the fallback was the *string* "true" for a `bool?`
      // parameter, which compiles because `map` is dynamic and then fails the
      // implicit downcast. ENG-39098.
      final map = build().toMap()..remove('optional');
      final element = CheckBoxElement.fromMap(map);

      expect(element.optional, isTrue);
      expect(element.label, 'Toppings');
    });
  });

  // ---------------------------------------------------------------------------
  group('DropdownElement', () {
    DropdownElement build() => DropdownElement(
      elementId: 'd1',
      label: 'Size',
      options: [_option('sm', 'Small'), _option('lg', 'Large')],
    );

    test('defaults its type to dropdown and is optional by default', () {
      expect(build().elementType, 'dropdown');
      expect(build().optional, isTrue);
    });

    test('round-trips label and options', () {
      final restored = DropdownElement.fromMap(build().toMap());
      expect(restored.label, 'Size');
      expect(restored.options.map((o) => o.label), ['Small', 'Large']);
    });

    test('fromMap tolerates a missing options key', () {
      // The only one of the four choice elements that guards this — radio and
      // single-select both cast `map['options']` to List unconditionally.
      final restored = DropdownElement.fromMap(<String, dynamic>{
        'elementType': 'dropdown',
        'elementId': 'd9',
        'label': 'Size',
      });
      expect(restored.options, isEmpty);
    });

    test('validateResponse rejects only null', () {
      final element = build();
      expect(element.validateResponse(), isFalse);

      // Unlike the radio and single-select elements, an empty string counts
      // as answered here.
      element.response = '';
      expect(element.validateResponse(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('RadioButtonElement', () {
    RadioButtonElement build() => RadioButtonElement(
      elementId: 'r1',
      label: 'Delivery',
      options: [_option('std', 'Standard'), _option('exp', 'Express')],
    );

    test('defaults its type to radio', () {
      expect(build().elementType, 'radio');
    });

    test('round-trips label and options', () {
      final restored = RadioButtonElement.fromMap(build().toMap());
      expect(restored.label, 'Delivery');
      expect(restored.options.map((o) => o.value), ['std', 'exp']);
    });

    test('validateResponse rejects null and empty, accepts a choice', () {
      final element = build();
      expect(element.validateResponse(), isFalse);

      element.response = '';
      expect(element.validateResponse(), isFalse);

      element.response = 'std';
      expect(element.validateResponse(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('SingleSelectElement', () {
    SingleSelectElement build() => SingleSelectElement(
      elementId: 's1',
      label: 'Plan',
      options: [_option('free', 'Free'), _option('pro', 'Pro')],
    );

    test('defaults its type to singleSelect', () {
      expect(build().elementType, 'singleSelect');
    });

    test('round-trips label and options', () {
      final restored = SingleSelectElement.fromMap(build().toMap());
      expect(restored.label, 'Plan');
      expect(restored.options.map((o) => o.label), ['Free', 'Pro']);
    });

    test('carries a default value into the map', () {
      final map = SingleSelectElement(
        elementId: 's1',
        label: 'Plan',
        options: [_option('free', 'Free')],
        defaultValue: 'free',
      ).toMap();

      expect(map['defaultValue'], 'free');
    });

    test('validateResponse rejects null and empty, accepts a choice', () {
      final element = build();
      expect(element.validateResponse(), isFalse);

      element.response = '';
      expect(element.validateResponse(), isFalse);

      element.response = 'pro';
      expect(element.validateResponse(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('DateTimeElement', () {
    DateTimeElement build() =>
        DateTimeElement(elementId: 'dt1', label: 'Pick a slot');

    test('FIXED — defaults its elementType to dateTime and round-trips as '
        'one', () {
      // The default was `dropdown`. Since toMap writes elementType and
      // ElementEntity.fromMap dispatches on it, a default-constructed element
      // round-tripped into a DropdownElement — and because
      // DateTimeElement.toMap never writes an options key, it arrived as a
      // dropdown with no options. The picker silently became an empty list.
      // ENG-39098.
      expect(build().elementType, 'dateTime');
      expect(ElementEntity.fromMap(build().toMap()), isA<DateTimeElement>());
    });

    test('an explicit dateTime type round-trips correctly', () {
      final element = DateTimeElement(
        elementType: 'dateTime',
        elementId: 'dt1',
        label: 'Pick a slot',
      );

      expect(ElementEntity.fromMap(element.toMap()), isA<DateTimeElement>());
    });

    test('defaults to the dateTime visibility mode and is optional', () {
      final element = build();
      expect(element.mode, DateTimeVisibilityMode.dateTime);
      expect(element.optional, isTrue);
      expect(element.from, isNull);
      expect(element.to, isNull);
    });

    test('toMap carries only the label — the window and format do not '
        'survive it', () {
      final map = DateTimeElement(
        elementId: 'dt1',
        label: 'Pick a slot',
        mode: DateTimeVisibilityMode.date,
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 12, 31),
        dateTimeFormat: 'yyyy-MM-dd',
        placeholder: TextInputPlaceholder(text: 'When?'),
      ).toMap();

      expect(map['label'], 'Pick a slot');
      for (final key in [
        'mode',
        'from',
        'to',
        'dateTimeFormat',
        'placeholder',
      ]) {
        expect(map.containsKey(key), isFalse, reason: '$key is not serialised');
      }
    });

    test('fromMap reads the visibility mode, and falls back to dateTime', () {
      DateTimeElement parse(String? mode) =>
          DateTimeElement.fromMap(<String, dynamic>{
            'elementType': 'dateTime',
            'elementId': 'dt1',
            'label': 'Pick a slot',
            'mode': ?mode,
          });

      expect(parse('date').mode, DateTimeVisibilityMode.date);
      expect(parse('time').mode, DateTimeVisibilityMode.time);
      expect(parse('dateTime').mode, DateTimeVisibilityMode.dateTime);
      expect(parse('nonsense').mode, DateTimeVisibilityMode.dateTime);
      expect(parse(null).mode, DateTimeVisibilityMode.dateTime);
    });

    test('fromMap parses a date window and swallows unparseable bounds', () {
      final element = DateTimeElement.fromMap(<String, dynamic>{
        'elementType': 'dateTime',
        'elementId': 'dt1',
        'label': 'Pick a slot',
        'mode': 'date',
        'from': '2026-01-01',
        'to': 'not a date',
      });

      expect(element.from, DateTime.parse('2026-01-01'));
      expect(element.to, isNull);
    });

    test('fromMap anchors a time-only window to the epoch date', () {
      final element = DateTimeElement.fromMap(<String, dynamic>{
        'elementType': 'dateTime',
        'elementId': 'dt1',
        'label': 'Pick a slot',
        'mode': 'time',
        'from': '09:00:00',
        'to': '17:00:00',
      });

      expect(element.from, DateTime.parse('1970-01-01T09:00:00'));
      expect(element.to, DateTime.parse('1970-01-01T17:00:00'));
    });

    test('fromMap seeds the formatted response from the default value', () {
      final element = DateTimeElement.fromMap(<String, dynamic>{
        'elementType': 'dateTime',
        'elementId': 'dt1',
        'label': 'Pick a slot',
        'mode': 'date',
        'from': '2026-01-01',
        'defaultValue': '2026-06-15',
      });

      expect(element.defaultValue, '2026-06-15');
      expect(element.defaultDateTime, DateTime.parse('2026-06-15'));
      expect(element.formattedResponse, element.defaultDateTime);
    });

    test('FIXED — a default value survives when `from` is absent', () {
      // `from` and `defaultValue` used to be parsed by two consecutive
      // statements inside one try block with an empty catch, `from` first. A
      // payload carrying a default but no lower bound threw on the `from`
      // parse and never reached the default — silently, so the picker opened
      // with no pre-selection even though the server had sent one.
      // ENG-39098.
      final element = DateTimeElement.fromMap(<String, dynamic>{
        'elementType': 'dateTime',
        'elementId': 'dt1',
        'label': 'Pick a slot',
        'mode': 'date',
        'defaultValue': '2026-06-15',
      });

      expect(element.from, isNull, reason: 'none was sent');
      expect(element.defaultDateTime, DateTime.parse('2026-06-15'));
      expect(element.formattedResponse, element.defaultDateTime);
    });

    test(
      'FIXED — an unparseable `from` no longer takes the default with it',
      () {
        final element = DateTimeElement.fromMap(<String, dynamic>{
          'elementType': 'dateTime',
          'elementId': 'dt1',
          'label': 'Pick a slot',
          'mode': 'date',
          'from': 'not a date',
          'defaultValue': '2026-06-15',
          'to': '2026-12-31',
        });

        expect(element.from, isNull, reason: 'unparseable, so still dropped');
        expect(element.defaultDateTime, DateTime.parse('2026-06-15'));
        expect(element.to, DateTime.parse('2026-12-31'));
      },
    );

    test('FIXED — a time-only default is anchored to the epoch date too', () {
      // The time-only branch had the same shared-try problem.
      final element = DateTimeElement.fromMap(<String, dynamic>{
        'elementType': 'dateTime',
        'elementId': 'dt1',
        'label': 'Pick a slot',
        'mode': 'time',
        'defaultValue': '09:30:00',
      });

      expect(element.defaultDateTime, DateTime.parse('1970-01-01T09:30:00'));
    });

    test('validateResponse rejects null and accepts any non-null answer', () {
      final element = build();
      expect(element.validateResponse(), isFalse);

      // Note this one accepts the empty string, unlike radio and
      // single-select.
      element.response = '';
      expect(element.validateResponse(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('BaseInputElement, through its subclasses', () {
    test('optional defaults to true and is honoured when set false', () {
      expect(
        TextInputElement(elementId: 't1', label: 'Email').toMap()['optional'],
        isTrue,
      );
      expect(
        TextInputElement(
          elementId: 't1',
          label: 'Email',
          optional: false,
        ).toMap()['optional'],
        isFalse,
      );
    });

    test('a null default value is left out of the map entirely', () {
      final map = TextInputElement(elementId: 't1', label: 'Email').toMap();
      expect(map.containsKey('defaultValue'), isFalse);
    });

    test('a non-null default value is written', () {
      final map = TextInputElement(
        elementId: 't1',
        label: 'Email',
        defaultValue: 'you@example.com',
      ).toMap();

      expect(map['defaultValue'], 'you@example.com');
    });

    test('response is independent of defaultValue', () {
      final element = TextInputElement(
        elementId: 't1',
        label: 'Email',
        defaultValue: 'you@example.com',
      );

      expect(element.response, isNull);
      expect(element.validateResponse(), isFalse);

      element.response = 'someone@else.com';
      expect(element.defaultValue, 'you@example.com');
      expect(element.validateResponse(), isTrue);
    });
  });
}
