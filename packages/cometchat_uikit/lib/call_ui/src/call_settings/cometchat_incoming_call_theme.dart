import 'package:flutter/material.dart';

import '../../../cometchat_chat_uikit.dart'
    show CometChatColorPalette, CometChatThemeMode;

/// One set of ring screen colours, light or dark, taken from the UI Kit theme.
///
/// The same eleven colours, by the same names, as the push ringer's theme
/// (`cometchat_voip`'s `CometChatVoipIncomingCallColors`, the Android Push
/// SDK's `CometChatPNIncomingCallTheme.Colors`), so the app copies them across
/// one to one.
@immutable
class CometChatIncomingCallColors {
  /// Creates a colour set.
  const CometChatIncomingCallColors({
    required this.background,
    required this.callerName,
    required this.subtitle,
    required this.avatarBackground,
    required this.avatarText,
    required this.acceptButton,
    required this.acceptIcon,
    required this.acceptLabel,
    required this.declineButton,
    required this.declineIcon,
    required this.declineLabel,
  });

  /// The page: the palette's `background1`.
  final Color background;

  /// The caller's name: `textPrimary`.
  final Color callerName;

  /// The line under the name: `textSecondary`.
  final Color subtitle;

  /// The circle behind the initials: `primary`.
  final Color avatarBackground;

  /// The initials: `white`.
  final Color avatarText;

  /// The Answer button: `success`.
  final Color acceptButton;

  /// The glyph on the Answer button: `white`.
  final Color acceptIcon;

  /// "Answer" under the button: `textSecondary`.
  final Color acceptLabel;

  /// The Decline button: `error`.
  final Color declineButton;

  /// The glyph on the Decline button: `white`.
  final Color declineIcon;

  /// "Decline" under the button: `textSecondary`.
  final Color declineLabel;
}

/// The UI Kit theme's colours for the ring screen the push ringer draws, in
/// light and in dark, and which of the two to use.
///
/// The UI Kit does not draw the ring screen and does not depend on the push
/// ringer: the app hands this to it in one line, for example with
/// `cometchat_voip`:
///
/// ```dart
/// final theme = CometChatIncomingCallTheme.of(context);
/// await CometChatVoip.setIncomingCallTheme(theme.toVoip()); // the app's mapping
/// ```
///
/// Both sets are built up front, whatever the phone's mode, so the first ring
/// after a mode change is right. Call it again when the app's theme or its
/// light/dark mode changes.
@immutable
class CometChatIncomingCallTheme {
  /// Creates a theme.
  const CometChatIncomingCallTheme({
    required this.mode,
    required this.light,
    required this.dark,
  });

  /// Which set the ring screen uses: [CometChatThemeMode.mode] by default.
  /// [ThemeMode.system] follows the phone's setting at the moment it rings.
  final ThemeMode mode;

  /// The colours in light mode.
  final CometChatIncomingCallColors light;

  /// The colours in dark mode.
  final CometChatIncomingCallColors dark;

  /// The theme for the app around [context]: the light and dark colours from
  /// the enclosing [MaterialApp]'s `theme` and `darkTheme` (or from [Theme.of]
  /// when there is no [MaterialApp]), and the UI Kit's own colours for
  /// anything their [CometChatColorPalette] leaves out.
  factory CometChatIncomingCallTheme.of(BuildContext context) {
    final app = context.findAncestorWidgetOfExactType<MaterialApp>();
    final current = Theme.of(context);
    return CometChatIncomingCallTheme.from(
      light: app?.theme ?? current,
      dark: app?.darkTheme ?? app?.theme ?? current,
    );
  }

  /// The theme from the app's [light] and [dark] [ThemeData], each read for
  /// its [CometChatColorPalette]; the UI Kit's own colours fill what a palette
  /// leaves out, or both sets when none is given.
  factory CometChatIncomingCallTheme.from({
    ThemeData? light,
    ThemeData? dark,
    ThemeMode? mode,
  }) {
    return CometChatIncomingCallTheme(
      mode: mode ?? CometChatThemeMode.mode,
      light: _colors(light?.extension<CometChatColorPalette>(), dark: false),
      dark: _colors(dark?.extension<CometChatColorPalette>(), dark: true),
    );
  }

  /// One set from [palette], with the UI Kit's default for each colour it
  /// leaves out: the same values the UI Kit's own components fall back to.
  static CometChatIncomingCallColors _colors(
    CometChatColorPalette? palette, {
    required bool dark,
  }) {
    Color pick(Color? set, Color light, Color darkColor) =>
        set ?? (dark ? darkColor : light);

    final textSecondary = pick(
      palette?.textSecondary ?? palette?.neutral600,
      const Color(0xFF727272),
      const Color(0xFF989898),
    );
    final white = palette?.white ?? Colors.white;
    return CometChatIncomingCallColors(
      background: pick(
        palette?.background1 ?? palette?.neutral50,
        const Color(0xFFFFFFFF),
        const Color(0xFF141414),
      ),
      callerName: pick(
        palette?.textPrimary ?? palette?.neutral900,
        const Color(0xFF141414),
        const Color(0xFFFFFFFF),
      ),
      subtitle: textSecondary,
      avatarBackground: pick(
        palette?.primary,
        const Color(0xFF6852D6),
        const Color(0xFF604CC3),
      ),
      avatarText: white,
      acceptButton: pick(
        palette?.success,
        const Color(0xFF09C26F),
        const Color(0xFF0B9F5D),
      ),
      acceptIcon: white,
      acceptLabel: textSecondary,
      declineButton: pick(
        palette?.error,
        const Color(0xFFF44649),
        const Color(0xFFC73C3E),
      ),
      declineIcon: white,
      declineLabel: textSecondary,
    );
  }
}
