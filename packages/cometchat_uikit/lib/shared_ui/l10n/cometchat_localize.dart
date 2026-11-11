import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'translations.dart';

/// The type of the UI Kit's localized strings: what [CometChatLocalize.of]
/// returns and what [CometChatLocalize.registerTranslations] takes.
///
/// It is the same runtime type as the deprecated [Translations], so the two
/// are interchangeable. Name this type, not [Translations], in fields,
/// parameters and `extends` clauses (to add or override strings).
// The alias is how the deprecated name is kept out of the replacement API:
// `CometChatLocalize` is typed in terms of this name, so an integrator can
// finish migrating without a `deprecated_member_use` warning left behind.
// ignore: deprecated_member_use_from_same_package
typedef CometChatLocalizations = Translations;

/// The localization entry point of the UI Kit, matching `CometChatLocalize`
/// in the React, Angular, iOS and Android UI Kits.
///
/// It replaces the deprecated [Translations] class as the API integrators
/// code against. The strings are still the ones [Translations] carries, so
/// `CometChatLocalize.of(context)` returns the same object as
/// `Translations.of(context)` and the two can be mixed while you migrate.
///
/// Wire it into your app once:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: CometChatLocalize.localizationsDelegates,
///   supportedLocales: CometChatLocalize.supportedLocales,
/// );
/// ```
class CometChatLocalize {
  CometChatLocalize._();

  /// The localizations delegate that provides the UI Kit's strings.
  ///
  /// Use it in place of `Translations.delegate`. It serves any translation
  /// registered with [registerTranslations] before the built-in one. The
  /// deprecated `Translations.delegate` serves them too, so an app that has
  /// not migrated its `MaterialApp` yet still shows the registered strings.
  static const LocalizationsDelegate<CometChatLocalizations> delegate =
      _CometChatLocalizeDelegate();

  /// This delegate together with the Material, Cupertino and widgets
  /// delegates, for `MaterialApp.localizationsDelegates`.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        CometChatLocalize.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// The locales the UI Kit ships built-in translations for, for
  /// `MaterialApp.supportedLocales`.
  // ignore: deprecated_member_use_from_same_package
  static List<Locale> get supportedLocales => Translations.supportedLocales;

  static final Map<String, CometChatLocalizations> _registered =
      <String, CometChatLocalizations>{};

  static final ValueNotifier<Locale?> _selectedLocale = ValueNotifier<Locale?>(
    null,
  );

  /// The UI Kit's strings in the locale in effect for [context].
  static CometChatLocalizations of(BuildContext context) =>
      // ignore: deprecated_member_use_from_same_package
      Translations.of(context);

  /// The locale the UI Kit's strings are resolved in for [context]: the one
  /// `MaterialApp` chose from its `locale` and `supportedLocales`.
  static Locale getLocale(BuildContext context) =>
      Localizations.localeOf(context);

  /// The language code of [getLocale], for example `ar`.
  static String getLanguage(BuildContext context) =>
      getLocale(context).languageCode;

  /// Whether the locale in effect for [context] is written right to left.
  static bool isRtl(BuildContext context) =>
      intl.Bidi.isRtlLanguage(getLanguage(context));

  /// Records [locale] as the language the app wants the UI Kit to use.
  ///
  /// Flutter resolves the locale in the app, so this does not re-localize
  /// the screen by itself: listen to [localeListenable] and pass its value to
  /// `MaterialApp.locale`. Throws an [ArgumentError] when the UI Kit has no
  /// built-in translation for the language of [locale].
  static void setLocale(Locale locale) {
    if (!kCometChatSupportedLanguage.contains(locale.languageCode)) {
      throw ArgumentError.value(
        locale,
        'locale',
        'CometChatLocalize has no translation for "${locale.languageCode}"',
      );
    }
    _selectedLocale.value = locale;
  }

  /// The locale chosen with [setLocale], or null when the app follows the
  /// device. Pass it to `MaterialApp.locale`.
  static ValueListenable<Locale?> get localeListenable => _selectedLocale;

  /// Clears the locale chosen with [setLocale] and every translation
  /// registered with [registerTranslations].
  static void resetToDefault() {
    _selectedLocale.value = null;
    _registered.clear();
  }

  /// Registers [translations] to be used instead of the built-in strings for
  /// the locale it was created for, to override single strings of a language
  /// the UI Kit ships (see [supportedLocales]). Extend the built-in class of
  /// the language and override the getters you want to change:
  ///
  /// ```dart
  /// class MyEnglish extends TranslationsEn {
  ///   @override
  ///   String get users => 'People';
  /// }
  ///
  /// CometChatLocalize.registerTranslations(MyEnglish());
  /// ```
  ///
  /// A translation registered for a regional locale of the same language
  /// (for example `en_US` when you registered `en`) is used too, unless one
  /// is registered for that exact locale. Register before the app builds;
  /// widgets already on screen keep the strings they were given.
  ///
  /// The strings reach the app through a localizations delegate, so the app
  /// needs [delegate] (or the deprecated `Translations.delegate`) in its
  /// `localizationsDelegates`. An app with neither gets the built-in English
  /// strings from [of], registered or not.
  static void registerTranslations(CometChatLocalizations translations) {
    _registered[translations.localeName] = translations;
  }
}

/// Serves the strings registered with [CometChatLocalize.registerTranslations]
/// and falls back to the built-in translation of the locale.
class _CometChatLocalizeDelegate
    extends LocalizationsDelegate<CometChatLocalizations> {
  const _CometChatLocalizeDelegate();

  @override
  bool isSupported(Locale locale) =>
      kCometChatSupportedLanguage.contains(locale.languageCode);

  @override
  Future<CometChatLocalizations> load(Locale locale) {
    final String name = intl.Intl.canonicalizedLocale(locale.toString());
    // An app that lists en_US or en_IN would otherwise skip a translation
    // registered for en, which is how `TranslationsEn().localeName` is keyed.
    return SynchronousFuture<CometChatLocalizations>(
      CometChatLocalize._registered[name] ??
          CometChatLocalize._registered[locale.languageCode] ??
          lookupTranslations(locale),
    );
  }

  @override
  bool shouldReload(_CometChatLocalizeDelegate old) => false;
}
