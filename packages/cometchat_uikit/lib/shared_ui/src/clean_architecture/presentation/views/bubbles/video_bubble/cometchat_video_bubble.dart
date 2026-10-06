import 'package:flutter/material.dart';
import "../../../../clean_architecture.dart";
import 'video_player.dart';

///[CometChatVideoBubble] creates a widget that gives video bubble
///
///used by default when the category and type of [MediaMessage] is message and [MessageTypeConstants.video] respectively
/// ```dart
///  CometChatVideoBubble(
///     videoUrl: 'url for video',
///     style: VideoBubbleStyle(
///     backgroundColor: Colors.white,
///     border: Border.all(color: Colors.red),
///      ),
/// );
/// ```
@Deprecated(
  'Use CometChatVideosBubble instead — the multi-attachment bubble family (enableMultipleAttachments) replaces the single-attachment media bubbles.',
)
class CometChatVideoBubble extends StatefulWidget {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Placeholder image for the video.
  @Deprecated(
    'Has no effect. For the colour shown while a thumbnail loads, use CometChatVideosBubbleStyle.placeholderColor. Will be removed in 7.0.0.',
  )
  final String? placeHolderImage;

  /// Package of the placeholder image.
  @Deprecated(
    'Has no effect. For the colour shown while a thumbnail loads, use CometChatVideosBubbleStyle.placeholderColor. Will be removed in 7.0.0.',
  )
  final String? placeHolderImagePackageName;

  const CometChatVideoBubble({
    super.key,
    this.style,
    this.videoUrl,
    this.thumbnailUrl,
    this.playIcon,
    this.onClick,
    this.height,
    this.width,
    this.padding,
    this.margin,
    this.metadata,
    this.placeHolder,
    this.colorPalette,
    this.spacing,
    this.placeHolderImage,
    this.placeHolderImagePackageName,
  });

  ///[videoUrl] if message object is not passed then video url should be passed
  final String? videoUrl;

  ///[thumbnailUrl] custom thumbnail for the video
  final String? thumbnailUrl;

  ///[style] video bubble styling properties
  final CometChatVideoBubbleStyle? style;

  ///[playIcon] video play pause icon
  final Icon? playIcon;

  ///[onClick] custom action on tapping the image
  final Function()? onClick;

  ///[width] width of the video bubble
  final double? width;

  ///[height] height of the video bubble
  final double? height;

  ///[padding] padding for the video bubble
  final EdgeInsetsGeometry? padding;

  ///[margin] margin for the video bubble
  final EdgeInsetsGeometry? margin;

  ///[metadata] metadata of the message object
  final Map<String, dynamic>? metadata;

  ///[placeHolder]
  final Widget? placeHolder;

  /// [colorPalette] optional pre-cached color palette to avoid expensive lookups during keyboard animation
  final CometChatColorPalette? colorPalette;

  /// [spacing] optional pre-cached spacing to avoid expensive lookups during keyboard animation
  final CometChatSpacing? spacing;

  @override
  State<CometChatVideoBubble> createState() => _CometChatVideoBubbleState();
}

class _CometChatVideoBubbleState extends State<CometChatVideoBubble> {
  late CometChatVideoBubbleStyle videoBubbleStyle;
  late CometChatColorPalette colorPalette;
  late CometChatSpacing spacing;
  Brightness _cachedBrightness = Brightness.light; // Cache platform brightness
  bool _themeInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only initialize theme once to avoid expensive lookups during keyboard animation
    // But re-initialize when brightness changes (dark mode toggle)
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _themeInitialized && _cachedBrightness != currentBrightness;
    if (!_themeInitialized || brightnessChanged) {
      videoBubbleStyle =
          CometChatThemeHelper.getTheme<CometChatVideoBubbleStyle>(
            context: context,
            defaultTheme: CometChatVideoBubbleStyle.of,
          ).merge(widget.style);
      // Use passed values OR fallback to lookup (for standalone usage)
      colorPalette =
          widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
      spacing = widget.spacing ?? CometChatThemeHelper.getSpacing(context);
      // Cache platform brightness to detect dark mode changes
      _cachedBrightness = currentBrightness;
      _themeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(CometChatVideoBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update style if it changed
    if (widget.style != oldWidget.style) {
      videoBubbleStyle =
          CometChatThemeHelper.getTheme<CometChatVideoBubbleStyle>(
            context: context,
            defaultTheme: CometChatVideoBubbleStyle.of,
          ).merge(widget.style);
    }
    // Update cached theme values if they changed
    if (widget.colorPalette != oldWidget.colorPalette &&
        widget.colorPalette != null) {
      colorPalette = widget.colorPalette!;
    }
    if (widget.spacing != oldWidget.spacing && widget.spacing != null) {
      spacing = widget.spacing!;
    }
  }

  Widget _getImageWidget(String imageUrl, int retries) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      // CanvasKit needs CORS to fetch pixels; fall back to an <img> element
      // when the CDN response lacks the headers (fixes thumbnails going
      // blank on web — same fix already applied to CometChatImageBubble).
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Center(
          child: CircularProgressIndicator(
            color: colorPalette.iconSecondary,
            backgroundColor: colorPalette.neutral300,
            strokeWidth: 2.0,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
            if (retries > 2) {
              return const SizedBox();
            }
            return _getImageWidget(imageUrl, retries + 1);
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          widget.onClick ??
          () {
            final localPath = FileUtils.getLocalFilePath(widget.metadata);

            String? videoUrl;
            bool playFromFile = FileUtils.isLocalFileAvailable(localPath ?? '');
            if (playFromFile) {
              videoUrl = localPath;
            } else {
              videoUrl = widget.videoUrl;
            }

            if (videoUrl != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayer(
                    backIcon: colorPalette.primary,
                    handleColor: colorPalette.borderLight,
                    playedColor: colorPalette.primary,
                    fullScreenBackground: colorPalette.black,
                    videoUrl: videoUrl ?? "",
                    playFromFile: playFromFile,
                  ),
                ),
              );
            }
          },
      child: Container(
        height: widget.height ?? 140,
        width: widget.width ?? 232,
        clipBehavior: Clip.hardEdge,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          border: videoBubbleStyle.border,
          borderRadius:
              videoBubbleStyle.borderRadius ??
              BorderRadius.circular(spacing.radius3 ?? 0),
          color: videoBubbleStyle.backgroundColor ?? colorPalette.background3,
        ),
        alignment: Alignment.center,
        child: Stack(
          children: [
            widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
                ? Positioned.fill(
                    child: _getImageWidget(widget.thumbnailUrl!, 0),
                  )
                : const SizedBox(),
            if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty)
              widget.placeHolder ??
                  Center(
                    child: Container(
                      alignment: Alignment.center,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            videoBubbleStyle.playIconBackgroundColor ??
                            ((_cachedBrightness == Brightness.light
                                    ? colorPalette.neutral500
                                    : colorPalette.neutral900))
                                ?.withValues(alpha: 0.6),
                      ),
                      child:
                          widget.playIcon ??
                          Icon(
                            Icons.play_arrow,
                            size: 56.0,
                            color:
                                videoBubbleStyle.playIconColor ??
                                (_cachedBrightness == Brightness.light
                                    ? colorPalette.neutral50
                                    : colorPalette.neutral900),
                          ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
