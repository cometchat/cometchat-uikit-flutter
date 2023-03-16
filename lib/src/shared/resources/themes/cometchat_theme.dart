import 'package:flutter_chat_ui_kit/src/shared/resources/themes/palette.dart';
import 'package:flutter_chat_ui_kit/src/shared/resources/themes/typography.dart';

/// Themes class for defining palette and typography
///
///
/// ```dart
///
///```

class CometChatTheme {
  ///Colour themes can be altered from [palette]
  ///
  /// ```dart
  /// const PaletteTheme paletteObj =  PaletteTheme();
  ///```
  Palette palette;

  ///Font properties can be altered from [typography]
  /// ```dart
  /// Typography typographyObject =  Typography.fromDefault();;
  ///```
  Typography typography;

  ///Constructor
  ///Custom Theme can  be generated
  CometChatTheme({required this.palette, required this.typography});
}

//Default cometchat theme object used buy CometChatUI
//Directly alter this object for small theme changes
CometChatTheme cometChatTheme = CometChatTheme(
    palette: defaultPaletteTheme, typography: defaultTypographyTheme);
