import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[ThumbnailGenerationConfiguration] configured the v5 thumbnail generation extension. No v6 API accepts it:
/// the extension is enabled from the CometChat Dashboard, and the
/// deprecation message names the components that now configure what it
/// described.
@Deprecated(
  'No API in v6 accepts an extension configuration object; thumbnails from the Dashboard-enabled extension are used automatically. Style video bubbles with videoBubbleStyle on CometChatIncomingMessageBubbleStyle and CometChatOutgoingMessageBubbleStyle. Will be removed in 7.0.0.',
)
class ThumbnailGenerationConfiguration {
  /// Creates a [ThumbnailGenerationConfiguration].
  const ThumbnailGenerationConfiguration({this.style});

  ///[style] use this to alter the default video bubble style
  final CometChatVideoBubbleStyle? style;
}
