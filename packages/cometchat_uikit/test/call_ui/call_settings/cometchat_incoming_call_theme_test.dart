/// Direct tests for [CometChatIncomingCallTheme]: the ring screen colours the
/// app hands the push ringer, taken from the UI Kit theme in light and dark,
/// with the UI Kit's own colours for anything a palette leaves out.
///
///   flutter test test/call_ui/call_settings/cometchat_incoming_call_theme_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'
    show CometChatIncomingCallColors, CometChatIncomingCallTheme;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatColorPalette, CometChatThemeMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The eleven colours of [c], by name, for one comparison.
Map<String, Color> _named(CometChatIncomingCallColors c) => {
  'background': c.background,
  'callerName': c.callerName,
  'subtitle': c.subtitle,
  'avatarBackground': c.avatarBackground,
  'avatarText': c.avatarText,
  'acceptButton': c.acceptButton,
  'acceptIcon': c.acceptIcon,
  'acceptLabel': c.acceptLabel,
  'declineButton': c.declineButton,
  'declineIcon': c.declineIcon,
  'declineLabel': c.declineLabel,
};

/// The UI Kit's own light colours (no palette).
const _lightDefaults = <String, Color>{
  'background': Color(0xFFFFFFFF),
  'callerName': Color(0xFF141414),
  'subtitle': Color(0xFF727272),
  'avatarBackground': Color(0xFF6852D6),
  'avatarText': Colors.white,
  'acceptButton': Color(0xFF09C26F),
  'acceptIcon': Colors.white,
  'acceptLabel': Color(0xFF727272),
  'declineButton': Color(0xFFF44649),
  'declineIcon': Colors.white,
  'declineLabel': Color(0xFF727272),
};

/// The UI Kit's own dark colours (no palette).
const _darkDefaults = <String, Color>{
  'background': Color(0xFF141414),
  'callerName': Color(0xFFFFFFFF),
  'subtitle': Color(0xFF989898),
  'avatarBackground': Color(0xFF604CC3),
  'avatarText': Colors.white,
  'acceptButton': Color(0xFF0B9F5D),
  'acceptIcon': Colors.white,
  'acceptLabel': Color(0xFF989898),
  'declineButton': Color(0xFFC73C3E),
  'declineIcon': Colors.white,
  'declineLabel': Color(0xFF989898),
};

ThemeData _withPalette(CometChatColorPalette palette) =>
    ThemeData(extensions: [palette]);

/// A palette that sets every colour the ring screen reads.
CometChatColorPalette _fullPalette() => CometChatColorPalette(
  background1: const Color(0xFF000001),
  textPrimary: const Color(0xFF000002),
  textSecondary: const Color(0xFF000003),
  primary: const Color(0xFF000004),
  white: const Color(0xFF000005),
  success: const Color(0xFF000006),
  error: const Color(0xFF000007),
);

void main() {
  late ThemeMode savedMode;

  setUp(() => savedMode = CometChatThemeMode.mode);
  tearDown(() => CometChatThemeMode.mode = savedMode);

  group('from()', () {
    test('without a theme, both sets are the UI Kit\'s own colours', () {
      final theme = CometChatIncomingCallTheme.from();

      expect(_named(theme.light), _lightDefaults);
      expect(_named(theme.dark), _darkDefaults);
    });

    test('a theme without a palette gets the UI Kit\'s own colours too', () {
      final theme = CometChatIncomingCallTheme.from(
        light: ThemeData.light(),
        dark: ThemeData.dark(),
      );

      expect(_named(theme.light), _lightDefaults);
      expect(_named(theme.dark), _darkDefaults);
    });

    test('a full palette maps each ring screen colour to its palette '
        'colour', () {
      final theme = CometChatIncomingCallTheme.from(
        light: _withPalette(_fullPalette()),
      );

      expect(_named(theme.light), const <String, Color>{
        'background': Color(0xFF000001), // background1
        'callerName': Color(0xFF000002), // textPrimary
        'subtitle': Color(0xFF000003), // textSecondary
        'avatarBackground': Color(0xFF000004), // primary
        'avatarText': Color(0xFF000005), // white
        'acceptButton': Color(0xFF000006), // success
        'acceptIcon': Color(0xFF000005), // white
        'acceptLabel': Color(0xFF000003), // textSecondary
        'declineButton': Color(0xFF000007), // error
        'declineIcon': Color(0xFF000005), // white
        'declineLabel': Color(0xFF000003), // textSecondary
      });
      // No dark theme given: the dark set stays the UI Kit's own.
      expect(_named(theme.dark), _darkDefaults);
    });

    test('a palette without the semantic colours falls back to its '
        'neutrals', () {
      final theme = CometChatIncomingCallTheme.from(
        dark: _withPalette(
          CometChatColorPalette(
            neutral50: const Color(0xFF0000A1),
            neutral900: const Color(0xFF0000A2),
            neutral600: const Color(0xFF0000A3),
          ),
        ),
      );

      expect(theme.dark.background, const Color(0xFF0000A1));
      expect(theme.dark.callerName, const Color(0xFF0000A2));
      expect(theme.dark.subtitle, const Color(0xFF0000A3));
      expect(theme.dark.acceptLabel, const Color(0xFF0000A3));
      expect(theme.dark.declineLabel, const Color(0xFF0000A3));
    });

    test('a partial palette keeps what it sets and takes the mode\'s '
        'defaults for the rest', () {
      final palette = CometChatColorPalette(primary: const Color(0xFF0000B1));
      final theme = CometChatIncomingCallTheme.from(
        light: _withPalette(palette),
        dark: _withPalette(palette),
      );

      expect(theme.light.avatarBackground, const Color(0xFF0000B1));
      expect(theme.dark.avatarBackground, const Color(0xFF0000B1));
      final lightRest = _named(theme.light)..remove('avatarBackground');
      final darkRest = _named(theme.dark)..remove('avatarBackground');
      expect(lightRest, Map.of(_lightDefaults)..remove('avatarBackground'));
      expect(darkRest, Map.of(_darkDefaults)..remove('avatarBackground'));
    });

    test('the mode is the UI Kit\'s theme mode unless one is given', () {
      CometChatThemeMode.mode = ThemeMode.dark;
      expect(CometChatIncomingCallTheme.from().mode, ThemeMode.dark);

      CometChatThemeMode.mode = ThemeMode.system;
      expect(CometChatIncomingCallTheme.from().mode, ThemeMode.system);

      expect(
        CometChatIncomingCallTheme.from(mode: ThemeMode.light).mode,
        ThemeMode.light,
      );
    });
  });

  group('of(context)', () {
    Future<CometChatIncomingCallTheme> themeIn(
      WidgetTester tester,
      Widget Function(Widget child) host,
    ) async {
      late CometChatIncomingCallTheme theme;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              theme = CometChatIncomingCallTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return theme;
    }

    testWidgets('reads the MaterialApp\'s theme for light and darkTheme for '
        'dark', (tester) async {
      final theme = await themeIn(
        tester,
        (child) => MaterialApp(
          theme: _withPalette(
            CometChatColorPalette(primary: const Color(0xFF0000C1)),
          ),
          darkTheme: _withPalette(
            CometChatColorPalette(primary: const Color(0xFF0000C2)),
          ),
          home: child,
        ),
      );

      expect(theme.light.avatarBackground, const Color(0xFF0000C1));
      expect(theme.dark.avatarBackground, const Color(0xFF0000C2));
    });

    testWidgets('without a darkTheme, dark reads the MaterialApp\'s theme, '
        'with dark defaults for what it leaves out', (tester) async {
      final theme = await themeIn(
        tester,
        (child) => MaterialApp(
          theme: _withPalette(
            CometChatColorPalette(primary: const Color(0xFF0000D1)),
          ),
          home: child,
        ),
      );

      expect(theme.dark.avatarBackground, const Color(0xFF0000D1));
      expect(theme.dark.background, _darkDefaults['background']);
    });

    testWidgets('without a MaterialApp, both read the enclosing Theme', (
      tester,
    ) async {
      final theme = await themeIn(
        tester,
        (child) => Theme(
          data: _withPalette(
            CometChatColorPalette(success: const Color(0xFF0000E1)),
          ),
          child: child,
        ),
      );

      expect(theme.light.acceptButton, const Color(0xFF0000E1));
      expect(theme.dark.acceptButton, const Color(0xFF0000E1));
      expect(theme.light.background, _lightDefaults['background']);
      expect(theme.dark.background, _darkDefaults['background']);
    });
  });
}
