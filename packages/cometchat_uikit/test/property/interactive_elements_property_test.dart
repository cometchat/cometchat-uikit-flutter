/// Properties of the interactive-message element and action models: what
/// `fromMap` does with a payload, and whether `toMap` writes something
/// `fromMap` can read back.
///
///   flutter test test/property/interactive_elements_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';

/// A string `Utils.isValidString` accepts — `OptionElement.toMap` writes only
/// those, so only those can round-trip.
String _genNonBlank(Random r) {
  final s = genUnicode(r, maxParts: 4);
  return s.trim().isEmpty ? 'x$s' : s;
}

List<OptionElement> _genOptions(Random r) => List.generate(
  r.between(0, 5),
  (_) => OptionElement(value: _genNonBlank(r), label: _genNonBlank(r)),
);

/// One well-formed element of a random kind.
ElementEntity _genElement(Random r) {
  final id = genUnicode(r, maxParts: 3);
  final label = genUnicode(r, maxParts: 4);
  final optional = r.nextBool();
  switch (r.nextInt(7)) {
    case 0:
      return LabelElement(elementId: id, text: label);
    case 1:
      return ButtonElement(
        elementId: id,
        buttonText: label,
        disableAfterInteracted: r.nextBool(),
        action: r.nextBool() ? _genAction(r) : null,
      );
    case 2:
      return CheckBoxElement(
        elementId: id,
        label: label,
        options: _genOptions(r),
        optional: optional,
        defaultValue: r.nextBool()
            ? List.generate(r.nextInt(3), (_) => genAlnum(r))
            : null,
      );
    case 3:
      return DropdownElement(
        elementId: id,
        label: label,
        options: _genOptions(r),
        optional: optional,
        defaultValue: r.nextBool() ? _genNonBlank(r) : null,
      );
    case 4:
      return RadioButtonElement(
        elementId: id,
        label: label,
        options: _genOptions(r),
        optional: optional,
        defaultValue: r.nextBool() ? _genNonBlank(r) : null,
      );
    case 5:
      return SingleSelectElement(
        elementId: id,
        label: label,
        options: _genOptions(r),
        optional: optional,
        defaultValue: r.nextBool() ? _genNonBlank(r) : null,
      );
    default:
      return TextInputElement(
        elementId: id,
        label: label,
        optional: optional,
        maxLines: r.between(1, 9),
        placeholder: r.nextBool()
            ? TextInputPlaceholder(text: genUnicode(r, maxParts: 3))
            : null,
        defaultValue: r.nextBool() ? _genNonBlank(r) : null,
      );
  }
}

ActionEntity _genAction(Random r) {
  switch (r.nextInt(3)) {
    case 0:
      return APIAction(
        url: 'https://${genAlnum(r)}.example/${genAlnum(r)}',
        method: r.pick(['POST', 'PUT', 'PATCH', 'DELETE']),
        payload: r.nextBool() ? {'k': genInt(r), 's': genAlnum(r)} : null,
        headers: r.nextBool() ? {'X-${genAlnum(r)}': genAlnum(r)} : null,
        dataKey: r.nextBool() ? genAlnum(r) : null,
      );
    case 1:
      return URLNavigationAction(url: 'https://${genAlnum(r)}.example');
    default:
      return CustomAction();
  }
}

List<(String, String)> _optionPairs(List<OptionElement> o) => [
  for (final e in o) (e.value, e.label),
];

/// The comparable state of an element, per concrete type.
List<Object?> _stateOf(ElementEntity e) => [
  e.runtimeType,
  e.elementType,
  e.elementId,
  if (e is LabelElement) e.text,
  if (e is BaseInteractiveElement) ...[
    e.disableAfterInteracted,
    e.action?.runtimeType,
    e.action?.actionType,
  ],
  if (e is ButtonElement) e.buttonText,
  if (e is BaseInputElement) ...[e.optional, e.defaultValue],
  if (e is CheckBoxElement) ...[e.label, _optionPairs(e.options)],
  if (e is DropdownElement) ...[e.label, _optionPairs(e.options)],
  if (e is RadioButtonElement) ...[e.label, _optionPairs(e.options)],
  if (e is SingleSelectElement) ...[e.label, _optionPairs(e.options)],
  if (e is TextInputElement) ...[e.label, e.maxLines, e.placeholder?.text],
];

String _describe(ElementEntity e) => show(e.toMap());

void main() {
  test('every element survives toMap → fromMap with its type and fields '
      'intact', () {
    forAll(
      _genElement,
      (element) {
        final back = ElementEntity.fromMap(element.toMap());
        expect(_stateOf(back), _stateOf(element));
      },
      cases: 300,
      describe: _describe,
    );
  });

  test(
    'serializing an element twice through the map form is a fixed point',
    () {
      forAll(_genElement, (element) {
        final once = ElementEntity.fromMap(element.toMap()).toMap();
        final twice = ElementEntity.fromMap(once).toMap();
        expect(twice, once);
      }, describe: _describe);
    },
  );

  test('every action survives toMap → fromMap with its type and fields '
      'intact', () {
    forAll(_genAction, (action) {
      final back = ActionEntity.fromMap(action.toMap());
      expect(back.runtimeType, action.runtimeType);
      expect(back.actionType, action.actionType);
      if (action is APIAction) {
        back as APIAction;
        expect(back.url, action.url);
        expect(back.method, action.method);
        expect(back.payload, action.payload);
        expect(back.headers, action.headers);
        expect(back.dataKey, action.dataKey);
      }
      if (action is URLNavigationAction) {
        expect((back as URLNavigationAction).url, action.url);
      }
    }, describe: (a) => show(a.toMap()));
  });

  test('an unknown element or action type falls back to the base class '
      'rather than failing', () {
    const known = {
      'label',
      'textInput',
      'button',
      'checkbox',
      'dropdown',
      'radio',
      'singleSelect',
      'dateTime',
      'apiAction',
      'urlNavigation',
      'customAction',
    };
    forAll((r) => genUnicode(r, maxParts: 3), (type) {
      if (known.contains(type)) return;
      final element = ElementEntity.fromMap({
        'elementType': type,
        'elementId': 'e1',
        'label': 'ignored',
      });
      expect(element.runtimeType, ElementEntity);
      expect(element.elementType, type);
      expect(
        ActionEntity.fromMap({'actionType': type}).runtimeType,
        ActionEntity,
      );
    });
  });

  test('a button without text and a text input without label, lines or '
      'placeholder still parse, with documented defaults', () {
    forAll((r) => (genUnicode(r, maxParts: 3), r.nextBool()), (input) {
      final (id, withNulls) = input;
      final button = ElementEntity.fromMap({
        'elementType': 'button',
        'elementId': id,
        if (withNulls) 'buttonText': null,
        if (withNulls) 'action': null,
      });
      expect(button, isA<ButtonElement>());
      expect((button as ButtonElement).buttonText, '');
      expect(button.disableAfterInteracted, isFalse);

      final input0 = ElementEntity.fromMap({
        'elementType': 'textInput',
        'elementId': id,
        if (withNulls) 'label': null,
        if (withNulls) 'maxLines': null,
      });
      expect(input0, isA<TextInputElement>());
      expect((input0 as TextInputElement).label, 'Default text');
      expect(input0.maxLines, 1);
      expect(input0.optional, isTrue);
    });
  });

  test('a damaged payload either parses to the announced type or fails with '
      'a cast error — and most damage does fail', () {
    // FINDING: none of the element `fromMap` factories validate their input.
    // Required fields are read with an implicit `dynamic → String` /
    // `dynamic → List` cast, so a payload with a missing or wrongly-typed
    // `elementId`, `label`, `text`, `options`, `value`… does not produce a
    // documented exception (FormatException / ArgumentError) or a degraded
    // element: it throws a bare `TypeError` (or `NoSuchMethodError` when
    // `.map` is called on a non-list) out of the middle of message rendering.
    // iOS drops the damaged element and keeps the rest of the form.
    // Pinned here: the ONLY failure modes are those two error types, and the
    // damage does reach them (so a fix that starts returning/throwing
    // something documented trips this test and gets it rewritten).
    var parsed = 0;
    var failed = 0;
    forAll((r) => damage(r, _genElement(r).toMap()), (map) {
      try {
        final element = ElementEntity.fromMap(map);
        expect(element.elementType, map['elementType']);
        parsed++;
      } on TypeError {
        failed++;
      } on NoSuchMethodError {
        failed++;
      }
    }, cases: 300);
    expect(parsed, greaterThan(0));
    expect(
      failed,
      greaterThan(parsed),
      reason: 'parsed=$parsed failed=$failed',
    );

    // The smallest reproductions.
    expect(
      () => ElementEntity.fromMap({'elementType': 'label', 'elementId': 'a'}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => ElementEntity.fromMap({
        'elementType': 'radio',
        'elementId': 'a',
        'label': 'l',
      }),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => ElementEntity.fromMap({
        'elementType': 'checkbox',
        'elementId': 'a',
        'label': 'l',
        'options': 7,
      }),
      throwsA(isA<NoSuchMethodError>()),
    );
  });

  test('an option whose label or value is blank cannot be read back from its '
      'own map', () {
    // FINDING: `OptionElement.toMap` omits `label` / `value` when they are
    // blank (`Utils.isValidString`), but `OptionElement.fromMap` requires
    // both as non-null Strings. `fromMap(toMap(x))` therefore throws a
    // TypeError for any option with a blank label or value — toMap and
    // fromMap disagree about the schema.
    forAll((r) => r.pick(['', ' ', '\t', '\n  ']), (blank) {
      final option = OptionElement(value: 'v', label: blank);
      expect(option.toMap().containsKey('label'), isFalse);
      expect(
        () => OptionElement.fromMap(option.toMap()),
        throwsA(isA<TypeError>()),
      );
    }, cases: 20);
  });

  test('a date-time element parses any ISO bound and ignores any garbage '
      'bound without throwing', () {
    forAll(
      (r) {
        final good = DateTime.utc(
          r.between(1971, 2100),
          r.between(1, 12),
          r.between(1, 28),
          r.nextInt(24),
          r.nextInt(60),
        );
        return (good, genJunk(r));
      },
      (input) {
        final (good, junk) = input;
        final element = DateTimeElement.fromMap({
          'elementType': 'dateTime',
          'elementId': 'when',
          'label': 'When',
          'optional': false,
          'mode': 'dateTime',
          'from': good.toIso8601String(),
          'to': junk is String ? junk : null,
        });
        expect(element.from, good);
        expect(element.to, junk is String ? DateTime.tryParse(junk) : isNull);
        expect(element.mode, DateTimeVisibilityMode.dateTime);
      },
    );
  });

  test('a date-time element loses its mode, bounds and format on the way '
      'through toMap', () {
    // FINDING: `DateTimeElement.toMap` writes only the base fields plus
    // `label`. `mode`, `from`, `to`, `dateTimeFormat` and `placeholder` are
    // never serialized, so a `date`- or `time`-only picker round-trips into
    // the default `dateTime` picker with no bounds. Every other element type
    // round-trips (first property in this file).
    forAll(
      (r) => r.pick([DateTimeVisibilityMode.date, DateTimeVisibilityMode.time]),
      (mode) {
        final original = DateTimeElement(
          elementId: 'when',
          label: 'When',
          mode: mode,
          from: DateTime.utc(2030),
          to: DateTime.utc(2031),
          dateTimeFormat: 'yyyy',
        );
        final back = DateTimeElement.fromMap(original.toMap());
        expect(back.mode, DateTimeVisibilityMode.dateTime);
        expect(back.from, isNull);
        expect(back.to, isNull);
        expect(back.dateTimeFormat, isNull);
      },
      cases: 10,
    );
  });

  test(
    'a date-time element with a well-formed placeholder cannot be parsed',
    () {
      // FINDING: `DateTimeElement.fromMap` passes `map['placeholder']` straight
      // to a `TextInputPlaceholder?` parameter instead of going through
      // `TextInputPlaceholder.fromMap` (as `TextInputElement` does). A payload
      // that carries the documented `{"placeholder": {"text": …}}` object
      // throws a TypeError, so a date picker with a placeholder never renders.
      forAll((r) => genUnicode(r, maxParts: 3), (text) {
        expect(
          () => DateTimeElement.fromMap({
            'elementType': 'dateTime',
            'elementId': 'when',
            'label': 'When',
            'placeholder': {'text': text},
          }),
          throwsA(isA<TypeError>()),
        );
      }, cases: 30);
    },
  );

  test('an API action with a non-string header value parses, then fails '
      'when the header is read', () {
    // FINDING: `APIAction.fromMap` builds a stringified copy of the headers
    // (`parsedMap`) and then ignores it, returning
    // `map['headers']?.cast<String, String>()` instead. `cast` is lazy, so a
    // numeric or boolean header value is accepted at parse time and throws a
    // TypeError later, when the request is being assembled.
    forAll((r) => r.pick(<Object>[genInt(r), r.nextBool(), r.nextDouble()]), (
      value,
    ) {
      final action = APIAction.fromMap(<String, dynamic>{
        'actionType': 'apiAction',
        'url': 'https://example.com',
        'method': 'POST',
        'headers': <String, dynamic>{'X-Retry': value},
      });
      expect(action.headers, isNotNull);
      expect(() => action.headers!['X-Retry'], throwsA(isA<TypeError>()));
    }, cases: 30);
  });
}
