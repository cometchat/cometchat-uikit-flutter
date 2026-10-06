/// Parity guard for the accessibility strings added for checklist row G.
///
/// The nine entries are CONCRETE on [Translations] (an abstract getter would
/// break any host app that maintains its own subclass), so a locale that forgot
/// to override one still compiles — it just silently ships English. This test
/// is what catches that: every one of the 18 shipped locales must override each
/// entry with something of its own.
///
///   flutter test test/shared_ui/l10n/accessibility_label_parity_test.dart
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// The 18 locales resolved by `lookupTranslations`.
const _locales = <Locale>[
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
];

/// The new entries, keyed by name, read off a [Translations] instance.
final _entries = <String, String Function(Translations)>{
  'attachmentOptionsMenuOpened': (t) => t.attachmentOptionsMenuOpened,
  'richTextFormattingToolbar': (t) => t.richTextFormattingToolbar,
  'closeFormattingToolbar': (t) => t.closeFormattingToolbar,
  'sendAudioMessage': (t) => t.sendAudioMessage,
  'messageComposerAuxiliaryActions': (t) => t.messageComposerAuxiliaryActions,
  'attachmentButton': (t) => t.attachmentButton,
  'addAttachment': (t) => t.addAttachment,
  'suggestionListWithItems': (t) => t.suggestionListWithItems(3),
  'messageFrom': (t) => t.messageFrom('Nova'),
};

void main() {
  group('accessibility label parity', () {
    test('every locale overrides every new entry', () {
      final english = TranslationsEn();
      final missing = <String>[];

      for (final locale in _locales) {
        final t = lookupTranslations(locale);
        final isEnglish = locale.languageCode == 'en';

        for (final entry in _entries.entries) {
          final value = entry.value(t);
          expect(
            value.trim(),
            isNotEmpty,
            reason: '${locale.toLanguageTag()} has an empty ${entry.key}',
          );
          // A non-English locale that still reads as the English default did
          // not override the getter — it inherited the concrete base value.
          if (!isEnglish && value == entry.value(english)) {
            missing.add('${locale.toLanguageTag()}.${entry.key}');
          }
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'locales still inheriting the English default: $missing',
      );
    });

    test('parameterised entries embed their argument in every locale', () {
      for (final locale in _locales) {
        final t = lookupTranslations(locale);
        expect(
          t.suggestionListWithItems(7),
          contains('7'),
          reason: '${locale.toLanguageTag()} drops the suggestion count',
        );
        expect(
          t.messageFrom('Nova'),
          contains('Nova'),
          reason: '${locale.toLanguageTag()} drops the sender name',
        );
      }
    });
  });
}
