/// The outgoing call screen's "Ringing..." (ringing v2): every language the
/// UI Kit ships has its own, and a language an app adds by extending
/// `Translations` falls back to the English one instead of failing to
/// compile.
///
///   flutter test test/shared_ui/l10n_ringing_test.dart
library;

import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_en.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A language an app adds itself, written before "Ringing..." existed.
class _AppLanguage extends TranslationsEn {
  _AppLanguage() : super('xx');
}

void main() {
  test('every shipped language has its own "Ringing...", set apart from '
      '"Calling..."', () {
    for (final locale in Translations.supportedLocales) {
      final t = lookupTranslations(locale);
      expect(t.ringing, isNotEmpty, reason: '$locale');
      expect(t.ringing, isNot(t.calling), reason: '$locale');
      if (locale.languageCode != 'en') {
        expect(t.ringing, isNot('Ringing...'), reason: '$locale');
      }
    }
  });

  test('Traditional Chinese has its own', () {
    final t = lookupTranslations(
      const Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
    );
    expect(t.ringing, '響鈴中...');
  });

  test('a language added by extending the translations keeps working', () {
    expect(_AppLanguage().ringing, 'Ringing...');
  });
}
