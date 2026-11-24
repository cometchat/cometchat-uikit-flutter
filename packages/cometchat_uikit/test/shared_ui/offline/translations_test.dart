import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_ar.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_de.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_en.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_en_GB.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_es.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_fr.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_hi.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_hu.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_ja.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_ko.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_lt.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_ms.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_nl.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_pt.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_ru.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_sv.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_tr.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations_zh.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every new offline string, keyed by name.
Map<String, String> offlineStrings(Translations t, int n) => {
  'messageNotSentYet': t.messageNotSentYet,
  'messageNotSentTapToRetry': t.messageNotSentTapToRetry,
  'unsentMessageRemoved': t.unsentMessageRemoved,
  'unsentMessagesMaybeLost': t.unsentMessagesMaybeLost,
  'queueFull': t.queueFull,
  'fileTooLargeOffline': t.fileTooLargeOffline,
  'connectToLoadMore': t.connectToLoadMore,
  'mediaAvailableWhenOnline': t.mediaAvailableWhenOnline,
  'jumpToLatest': t.jumpToLatest,
  'sendingTryAgain': t.sendingTryAgain,
  'fileNotSaved': t.fileNotSaved,
  'messagesNotSent': t.messagesNotSent(n),
  'unsentMessagesLost': t.unsentMessagesLost(n),
};

void main() {
  final english = TranslationsEn();
  final locales = <String, Translations>{
    'ar': TranslationsAr(),
    'de': TranslationsDe(),
    'en': english,
    'en_GB': TranslationsEnGb(),
    'es': TranslationsEs(),
    'fr': TranslationsFr(),
    'hi': TranslationsHi(),
    'hu': TranslationsHu(),
    'ja': TranslationsJa(),
    'ko': TranslationsKo(),
    'lt': TranslationsLt(),
    'ms': TranslationsMs(),
    'nl': TranslationsNl(),
    'pt': TranslationsPt(),
    'ru': TranslationsRu(),
    'sv': TranslationsSv(),
    'tr': TranslationsTr(),
    'zh': TranslationsZh(),
    'zh_TW': TranslationsZhTw(),
  };

  // English locales legitimately share the English text.
  const englishLocales = {'en', 'en_GB'};

  test('every new offline string is non-empty in every locale', () {
    for (final entry in locales.entries) {
      for (final n in [0, 1, 2, 5]) {
        offlineStrings(entry.value, n).forEach((key, value) {
          expect(value.trim(), isNotEmpty, reason: '${entry.key}.$key($n)');
        });
      }
    }
  });

  test('every non-English locale translates every new string', () {
    for (final entry in locales.entries) {
      if (englishLocales.contains(entry.key)) continue;
      for (final n in [0, 1, 2, 5]) {
        final en = offlineStrings(english, n);
        offlineStrings(entry.value, n).forEach((key, value) {
          expect(
            value,
            isNot(en[key]),
            reason: '${entry.key}.$key($n) is still English',
          );
        });
      }
    }
  });

  test('counted strings carry the count and use the right plural forms', () {
    for (final entry in locales.entries) {
      for (final n in [2, 5, 11, 21, 101]) {
        // Arabic's dual form names the pair without the digit (رسالتين).
        if (entry.key == 'ar' && n == 2) continue;
        expect(
          entry.value.messagesNotSent(n),
          contains('$n'),
          reason: '${entry.key} messagesNotSent($n)',
        );
        expect(
          entry.value.unsentMessagesLost(n),
          contains('$n'),
          reason: '${entry.key} unsentMessagesLost($n)',
        );
      }
    }
    final ru = TranslationsRu();
    expect(ru.messagesNotSent(1), '1 сообщение не отправлено');
    expect(ru.messagesNotSent(3), '3 сообщения не отправлены');
    expect(ru.messagesNotSent(5), '5 сообщений не отправлено');
    expect(ru.messagesNotSent(12), '12 сообщений не отправлено');
    expect(ru.messagesNotSent(22), '22 сообщения не отправлены');
    final lt = TranslationsLt();
    expect(lt.messagesNotSent(1), '1 žinutė neišsiųsta');
    expect(lt.messagesNotSent(2), '2 žinutės neišsiųstos');
    expect(lt.messagesNotSent(10), '10 žinučių neišsiųsta');
    expect(lt.messagesNotSent(11), '11 žinučių neišsiųsta');
    final ar = TranslationsAr();
    expect(ar.messagesNotSent(2), 'لم يتم إرسال رسالتين');
    expect(ar.messagesNotSent(3), 'لم يتم إرسال 3 رسائل');
    expect(ar.messagesNotSent(11), 'لم يتم إرسال 11 رسالة');
    final fr = TranslationsFr();
    expect(fr.messagesNotSent(0), "0 message n'a pas été envoyé");
    expect(fr.messagesNotSent(2), "2 messages n'ont pas été envoyés");
    expect(english.messagesNotSent(1), "1 message wasn't sent");
    expect(english.messagesNotSent(2), "2 messages weren't sent");
  });
}
