/// Parity guard for the two strings an incoming call shows when a refused
/// permission keeps it from being answered (round 3, P3-C05; localised in
/// the round 3 review).
///
/// The getters are concrete on [Translations], so a locale that forgot to
/// override one still compiles and silently shows English. Every shipped
/// locale must say it in its own language.
///
///   flutter test test/shared_ui/l10n/call_permission_strings_parity_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The locales resolved by `lookupTranslations`, Traditional Chinese
/// included.
const List<Locale> _locales = <Locale>[
  Locale('ar'),
  Locale('de'),
  Locale('en'),
  Locale('en', 'GB'),
  Locale('es'),
  Locale('fr'),
  Locale('hi'),
  Locale('hu'),
  Locale('ja'),
  Locale('ko'),
  Locale('lt'),
  Locale('ms'),
  Locale('nl'),
  Locale('pt'),
  Locale('ru'),
  Locale('sv'),
  Locale('tr'),
  Locale('zh'),
  Locale('zh', 'TW'),
];

final Map<String, String Function(Translations)> _entries =
    <String, String Function(Translations)>{
      'microphoneRequiredToAnswerCall': (Translations t) =>
          t.microphoneRequiredToAnswerCall,
      'cameraAndMicrophoneRequiredToAnswerCall': (Translations t) =>
          t.cameraAndMicrophoneRequiredToAnswerCall,
    };

void main() {
  test('every locale says why an incoming call could not be answered in its '
      'own language', () {
    final Translations english = TranslationsEn();
    final List<String> missing = <String>[];

    for (final Locale locale in _locales) {
      final Translations t = lookupTranslations(locale);
      final bool isEnglish = locale.languageCode == 'en';
      for (final MapEntry<String, String Function(Translations)> entry
          in _entries.entries) {
        final String value = entry.value(t);
        expect(value.trim(), isNotEmpty, reason: '$locale ${entry.key}');
        if (!isEnglish && value == entry.value(english)) {
          missing.add('${locale.toLanguageTag()}.${entry.key}');
        }
      }
    }

    expect(missing, isEmpty, reason: 'still English: $missing');
  });

  test('Traditional Chinese has its own wording, not the Simplified one', () {
    for (final MapEntry<String, String Function(Translations)> entry
        in _entries.entries) {
      expect(
        entry.value(lookupTranslations(const Locale('zh', 'TW'))),
        isNot(entry.value(lookupTranslations(const Locale('zh')))),
        reason: entry.key,
      );
    }
  });

  test('the voice and the video wording differ in every locale', () {
    for (final Locale locale in _locales) {
      final Translations t = lookupTranslations(locale);
      expect(
        t.microphoneRequiredToAnswerCall,
        isNot(t.cameraAndMicrophoneRequiredToAnswerCall),
        reason: '$locale',
      );
    }
  });
}
