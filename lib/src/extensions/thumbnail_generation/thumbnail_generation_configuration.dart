import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[ThumbnailGenerationConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [ThumbnailGenerationExtension]
///
/// ```dart
///
///   ThumbnailGenerationConfiguration(
///    style: VideoBubbleStyle(),
///    theme: CometChatTheme(palette: Palette(),typography: Typography())
///  );
/// ```
///
class ThumbnailGenerationConfiguration {
  const ThumbnailGenerationConfiguration({this.theme, this.style});

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[style] use this to alter the default video bubble style
  final VideoBubbleStyle? style;
}
