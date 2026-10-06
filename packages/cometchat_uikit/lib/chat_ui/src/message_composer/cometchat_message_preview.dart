import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// [CometChatMessagePreview] is a component that provides a bubble consisting of text
/// that can be appended to the message composer, message bubble or any other component as desired.
/// The appearance is similar to a quote block of markdown files.
class CometChatMessagePreview extends StatelessWidget {
  const CometChatMessagePreview({
    super.key,
    required this.messagePreviewTitle,
    required this.messagePreviewSubtitle,
    this.messagePreviewCloseButtonIcon,
    this.messagePreviewStyle,
    this.onCloseClick,
    this.hideCloseButton = false,
    this.message,
    this.stickerUrl,
    this.subtitleWidget,
  });

  /// [messagePreviewTitle] title shown in the preview bar (e.g. sender name or "Edit Message")
  final String messagePreviewTitle;

  /// [messagePreviewSubtitle] subtitle shown in the preview bar (message text or type label)
  final String messagePreviewSubtitle;

  /// [messagePreviewCloseButtonIcon] replaces the default close icon
  final Icon? messagePreviewCloseButtonIcon;

  /// [messagePreviewStyle] alters styling properties
  final CometChatMessagePreviewStyle? messagePreviewStyle;

  /// [onCloseClick] callback invoked when the close button is tapped
  final Function()? onCloseClick;

  /// [hideCloseButton] hides the close button when true
  final bool hideCloseButton;

  /// [message] message object used to show a media type icon for non-text messages
  final BaseMessage? message;

  /// [stickerUrl] URL of a sticker image to show as a thumbnail in the preview
  final String? stickerUrl;

  /// [subtitleWidget] optional custom widget for the subtitle area.
  /// When provided, takes precedence over [messagePreviewSubtitle] string.
  final Widget? subtitleWidget;

  @override
  Widget build(BuildContext context) {
    CometChatSpacing spacing = CometChatThemeHelper.getSpacing(context);
    CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
      context,
    );
    CometChatTypography typography = CometChatThemeHelper.getTypography(
      context,
    );
    CometChatMessagePreviewStyle style =
        CometChatThemeHelper.getTheme<CometChatMessagePreviewStyle>(
          context: context,
          defaultTheme: CometChatMessagePreviewStyle.of,
        ).merge(messagePreviewStyle);

    return ClipRRect(
      borderRadius:
          style.messagePreviewBorderRadius ??
          BorderRadius.all(Radius.circular(spacing.radius2 ?? 0)),
      child: Container(
        decoration: BoxDecoration(
          color: style.messagePreviewBackground,
          border:
              style.messagePreviewBorder ??
              Border(
                top: BorderSide.none,
                bottom: BorderSide.none,
                left: BorderSide(
                  color: colorPalette.borderHighlight ?? Colors.transparent,
                  width: 2,
                ),
                right: BorderSide.none,
              ),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.padding2 ?? 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: spacing.padding1 ?? 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      messagePreviewTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(
                                fontSize: typography.caption1?.medium?.fontSize,
                                fontWeight:
                                    typography.caption1?.medium?.fontWeight,
                                color: colorPalette.textHighlight,
                              )
                              .merge(style.messagePreviewTitleStyle)
                              .copyWith(color: style.messagePreviewTitleColor),
                    ),
                    if (hideCloseButton == false)
                      Semantics(
                        button: true,
                        label: Translations.of(context).close,
                        child: GestureDetector(
                          onTap: onCloseClick,
                          child:
                              messagePreviewCloseButtonIcon ??
                              Icon(
                                Icons.close,
                                size: 16,
                                color:
                                    style.closeIconColor ??
                                    colorPalette.iconSecondary,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (message != null)
                    Padding(
                      padding: EdgeInsets.only(right: spacing.padding1 ?? 0),
                      child: ComposerUtils.getReplyIcon(
                        message!,
                        context,
                        style.replyMessagePreviewCloseIconColor ??
                            colorPalette.iconSecondary,
                      ),
                    ),
                  if (stickerUrl != null && stickerUrl!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(right: spacing.padding1 ?? 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          spacing.radius1 ?? 4,
                        ),
                        child: Image.network(
                          stickerUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                      ),
                      child:
                          subtitleWidget ??
                          Text(
                            messagePreviewSubtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(
                                      fontSize: typography
                                          .caption1
                                          ?.regular
                                          ?.fontSize,
                                      fontWeight: typography
                                          .caption1
                                          ?.regular
                                          ?.fontWeight,
                                      color: colorPalette.textSecondary,
                                    )
                                    .merge(style.messagePreviewSubtitleStyle)
                                    .copyWith(
                                      color: style.messagePreviewSubtitleColor,
                                    ),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class CometChatMessagePreviewStyle
    extends ThemeExtension<CometChatMessagePreviewStyle> {
  const CometChatMessagePreviewStyle({
    this.messagePreviewBackground,
    this.messagePreviewBorder,
    this.messagePreviewBorderRadius,
    this.messagePreviewTitleStyle,
    this.messagePreviewTitleColor,
    this.messagePreviewSubtitleStyle,
    this.messagePreviewSubtitleColor,
    this.closeIconColor,
    this.replyMessagePreviewCloseIconColor,
  });

  final Color? messagePreviewBackground;
  final BoxBorder? messagePreviewBorder;
  final BorderRadius? messagePreviewBorderRadius;
  final TextStyle? messagePreviewTitleStyle;
  final Color? messagePreviewTitleColor;
  final TextStyle? messagePreviewSubtitleStyle;
  final Color? messagePreviewSubtitleColor;
  final Color? closeIconColor;

  /// Color for the media type icon shown next to the subtitle for non-text messages
  final Color? replyMessagePreviewCloseIconColor;

  static CometChatMessagePreviewStyle of(BuildContext context) =>
      const CometChatMessagePreviewStyle();

  CometChatMessagePreviewStyle merge(CometChatMessagePreviewStyle? other) {
    if (other == null) return this;
    return CometChatMessagePreviewStyle(
      messagePreviewBackground:
          other.messagePreviewBackground ?? messagePreviewBackground,
      messagePreviewBorder: other.messagePreviewBorder ?? messagePreviewBorder,
      messagePreviewBorderRadius:
          other.messagePreviewBorderRadius ?? messagePreviewBorderRadius,
      messagePreviewTitleStyle:
          other.messagePreviewTitleStyle ?? messagePreviewTitleStyle,
      messagePreviewTitleColor:
          other.messagePreviewTitleColor ?? messagePreviewTitleColor,
      messagePreviewSubtitleStyle:
          other.messagePreviewSubtitleStyle ?? messagePreviewSubtitleStyle,
      messagePreviewSubtitleColor:
          other.messagePreviewSubtitleColor ?? messagePreviewSubtitleColor,
      closeIconColor: other.closeIconColor ?? closeIconColor,
      replyMessagePreviewCloseIconColor:
          other.replyMessagePreviewCloseIconColor ??
          replyMessagePreviewCloseIconColor,
    );
  }

  @override
  CometChatMessagePreviewStyle copyWith({
    Color? messagePreviewBackground,
    BoxBorder? messagePreviewBorder,
    BorderRadius? messagePreviewBorderRadius,
    TextStyle? messagePreviewTitleStyle,
    Color? messagePreviewTitleColor,
    TextStyle? messagePreviewSubtitleStyle,
    Color? messagePreviewSubtitleColor,
    Color? closeIconColor,
    Color? replyMessagePreviewCloseIconColor,
  }) {
    return CometChatMessagePreviewStyle(
      messagePreviewBackground:
          messagePreviewBackground ?? this.messagePreviewBackground,
      messagePreviewBorder: messagePreviewBorder ?? this.messagePreviewBorder,
      messagePreviewBorderRadius:
          messagePreviewBorderRadius ?? this.messagePreviewBorderRadius,
      messagePreviewTitleStyle:
          messagePreviewTitleStyle ?? this.messagePreviewTitleStyle,
      messagePreviewTitleColor:
          messagePreviewTitleColor ?? this.messagePreviewTitleColor,
      messagePreviewSubtitleStyle:
          messagePreviewSubtitleStyle ?? this.messagePreviewSubtitleStyle,
      messagePreviewSubtitleColor:
          messagePreviewSubtitleColor ?? this.messagePreviewSubtitleColor,
      closeIconColor: closeIconColor ?? this.closeIconColor,
      replyMessagePreviewCloseIconColor:
          replyMessagePreviewCloseIconColor ??
          this.replyMessagePreviewCloseIconColor,
    );
  }

  @override
  CometChatMessagePreviewStyle lerp(
    ThemeExtension<CometChatMessagePreviewStyle>? other,
    double t,
  ) {
    if (other is! CometChatMessagePreviewStyle) return this;
    return CometChatMessagePreviewStyle(
      messagePreviewBackground: Color.lerp(
        messagePreviewBackground,
        other.messagePreviewBackground,
        t,
      ),
      messagePreviewBorder: t < 0.5
          ? messagePreviewBorder
          : other.messagePreviewBorder,
      messagePreviewBorderRadius: BorderRadius.lerp(
        messagePreviewBorderRadius,
        other.messagePreviewBorderRadius,
        t,
      ),
      messagePreviewTitleStyle: TextStyle.lerp(
        messagePreviewTitleStyle,
        other.messagePreviewTitleStyle,
        t,
      ),
      messagePreviewTitleColor: Color.lerp(
        messagePreviewTitleColor,
        other.messagePreviewTitleColor,
        t,
      ),
      messagePreviewSubtitleStyle: TextStyle.lerp(
        messagePreviewSubtitleStyle,
        other.messagePreviewSubtitleStyle,
        t,
      ),
      messagePreviewSubtitleColor: Color.lerp(
        messagePreviewSubtitleColor,
        other.messagePreviewSubtitleColor,
        t,
      ),
      closeIconColor: Color.lerp(closeIconColor, other.closeIconColor, t),
      replyMessagePreviewCloseIconColor: Color.lerp(
        replyMessagePreviewCloseIconColor,
        other.replyMessagePreviewCloseIconColor,
        t,
      ),
    );
  }
}
