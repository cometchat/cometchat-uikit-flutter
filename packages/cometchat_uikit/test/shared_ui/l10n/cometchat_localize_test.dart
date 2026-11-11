import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PeopleEnglish extends TranslationsEn {
  @override
  String get users => 'People';
}

class _FolksBritish extends TranslationsEnGb {
  @override
  String get users => 'Folks';
}

/// [supported] defaults to the kit's language-only list; a regional list is how
/// an app ends up with a locale like en_US reaching the delegate.
Widget _app(
  Locale locale,
  void Function(BuildContext) onBuild, {
  List<Locale>? supported,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: CometChatLocalize.localizationsDelegates,
    supportedLocales: supported ?? CometChatLocalize.supportedLocales,
    home: Builder(
      builder: (BuildContext context) {
        onBuild(context);
        return const SizedBox();
      },
    ),
  );
}

void main() {
  tearDown(CometChatLocalize.resetToDefault);

  testWidgets('of returns the strings Translations.of returns', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(_app(const Locale('de'), (c) => captured = c));

    expect(CometChatLocalize.of(captured), isA<TranslationsDe>());
    expect(
      CometChatLocalize.of(captured).users,
      // ignore: deprecated_member_use_from_same_package
      Translations.of(captured).users,
    );
  });

  testWidgets('getLocale, getLanguage and isRtl follow the app locale', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(_app(const Locale('ar'), (c) => captured = c));
    expect(CometChatLocalize.getLocale(captured), const Locale('ar'));
    expect(CometChatLocalize.getLanguage(captured), 'ar');
    expect(CometChatLocalize.isRtl(captured), isTrue);

    await tester.pumpWidget(_app(const Locale('en'), (c) => captured = c));
    await tester.pumpAndSettle();
    expect(CometChatLocalize.isRtl(captured), isFalse);
  });

  testWidgets('registerTranslations overrides the built-in strings', (
    tester,
  ) async {
    CometChatLocalize.registerTranslations(_PeopleEnglish());
    late BuildContext captured;
    await tester.pumpWidget(_app(const Locale('en'), (c) => captured = c));

    expect(CometChatLocalize.of(captured).users, 'People');
    expect(CometChatLocalize.of(captured).chats, TranslationsEn().chats);
  });

  testWidgets('a translation registered for en serves a regional locale', (
    tester,
  ) async {
    CometChatLocalize.registerTranslations(_PeopleEnglish());
    late BuildContext captured;
    await tester.pumpWidget(
      _app(
        const Locale('en', 'US'),
        (c) => captured = c,
        supported: const <Locale>[Locale('en', 'US')],
      ),
    );

    expect(Localizations.localeOf(captured), const Locale('en', 'US'));
    expect(CometChatLocalize.of(captured).users, 'People');
  });

  testWidgets('a translation registered for the exact locale wins over the '
      'language one', (tester) async {
    CometChatLocalize.registerTranslations(_PeopleEnglish());
    CometChatLocalize.registerTranslations(_FolksBritish());
    late BuildContext captured;
    await tester.pumpWidget(
      _app(
        const Locale('en', 'GB'),
        (c) => captured = c,
        supported: const <Locale>[Locale('en', 'GB')],
      ),
    );

    expect(CometChatLocalize.of(captured).users, 'Folks');
  });

  testWidgets('the deprecated Translations delegate serves registered '
      'translations too (an app mid-migration)', (tester) async {
    CometChatLocalize.registerTranslations(_PeopleEnglish());
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        // ignore: deprecated_member_use_from_same_package
        localizationsDelegates: Translations.localizationsDelegates,
        // ignore: deprecated_member_use_from_same_package
        supportedLocales: Translations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    // ignore: deprecated_member_use_from_same_package
    expect(Translations.of(captured).users, 'People');
    expect(CometChatLocalize.of(captured).users, 'People');
    expect(CometChatLocalize.of(captured).chats, TranslationsEn().chats);
  });

  test('CometChatLocalizations is the type Translations names', () {
    final CometChatLocalizations strings = TranslationsEn();
    expect(strings.runtimeType, TranslationsEn);
    expect(_PeopleEnglish(), isA<CometChatLocalizations>());
  });

  testWidgets('resetToDefault drops registered translations', (tester) async {
    CometChatLocalize.registerTranslations(_PeopleEnglish());
    CometChatLocalize.resetToDefault();
    late BuildContext captured;
    await tester.pumpWidget(_app(const Locale('en'), (c) => captured = c));

    expect(CometChatLocalize.of(captured).users, TranslationsEn().users);
  });

  test('setLocale publishes the locale and resetToDefault clears it', () {
    expect(CometChatLocalize.localeListenable.value, isNull);
    CometChatLocalize.setLocale(const Locale('fr'));
    expect(CometChatLocalize.localeListenable.value, const Locale('fr'));
    CometChatLocalize.resetToDefault();
    expect(CometChatLocalize.localeListenable.value, isNull);
  });

  test('setLocale rejects a language the kit has no translation for', () {
    expect(
      () => CometChatLocalize.setLocale(const Locale('xx')),
      throwsArgumentError,
    );
    expect(CometChatLocalize.localeListenable.value, isNull);
  });
}
