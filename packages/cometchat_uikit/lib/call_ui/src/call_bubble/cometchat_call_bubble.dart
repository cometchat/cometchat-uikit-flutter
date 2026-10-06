import 'package:flutter/material.dart';
import '../../../cometchat_chat_uikit.dart';

/// [CometChatCallBubble] is a widget that displays the call information and a button to join the call.
///
/// ```dart
/// CometChatCallBubble(
///  icon: Icon(Icons.call),
///  title: 'Call',
///  buttonText: 'Call',
///  onTap: (context) {
///  print('Call');
///  },
///  callBubbleStyle: CallBubbleStyle(
///  background: Colors.blue,
///  iconTint: Colors.grey,
///  titleStyle: TextStyle(
///  color: Colors.red,
///  fontSize: 16,
///  fontWeight: FontWeight.bold,
///  ),
///  subtitleStyle: TextStyle(
///  color: Colors.red,
///  fontSize: 14,
///  fontWeight: FontWeight.bold,
///  ),
///  buttonTextStyle: TextStyle(
///  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold
///  ),
///  ),
///  theme: cometChatTheme,
///  alignment: BubbleAlignment.left,
///  );
///
class CometChatCallBubble extends StatelessWidget {
  /// [CometChatCallBubble] constructor requires [icon], [title], [onTap], [style] and [theme] while initializing.
  const CometChatCallBubble({
    super.key,
    this.icon,
    this.title,
    this.buttonText,
    this.onTap,
    this.style,
    this.alignment,
    this.height,
    this.width,
    this.subtitle,
    this.iconUrl,
  });

  ///[icon] to show in the leading view of the bubble
  final Widget? icon;

  ///[title] title to be displayed , default is ''
  final String? title;

  ///[buttonText] the text to be displayed on the button; the translated
  ///"Join" when null
  final String? buttonText;

  ///[onTap] to execute some task on tapping of the button
  final Function(BuildContext)? onTap;

  ///[style] will be used to customize the appearance of the widget
  final CometChatCallBubbleStyle? style;

  ///[alignment] will be used to align the widget to left or right of the CometChatMessageList
  final BubbleAlignment? alignment;

  ///[height] sets the height of the widget
  final double? height;

  ///[width] sets the width of the widget
  final double? width;

  ///[subtitle] subtitle to be displayed , default is ''
  final String? subtitle;

  ///[iconUrl] icon url to be displayed if icon is not provided
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final spacing = CometChatThemeHelper.getSpacing(context);
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final style = CometChatThemeHelper.getTheme<CometChatCallBubbleStyle>(
      context: context,
      defaultTheme: CometChatCallBubbleStyle.of,
    ).merge(this.style);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: style.backgroundColor ?? colorPalette.transparent,
        borderRadius:
            style.borderRadius ?? BorderRadius.circular(spacing.radius3 ?? 0),
        border: style.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.padding2 ?? 0,
              spacing.padding2 ?? 0,
              spacing.padding2 ?? 0,
              spacing.padding3 ?? 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (icon != null || iconUrl != null)
                  CircleAvatar(
                    backgroundColor:
                        style.iconBackgroundColor ?? colorPalette.white,
                    // [icon] wins when supplied, as this class's own doc for
                    // [iconUrl] describes — "displayed if icon is not
                    // provided". It used to be read only as a null check while
                    // the avatar always drew Image.asset(iconUrl ?? ''), so a
                    // supplied icon was ignored and an icon-only caller got an
                    // empty asset path (ENG-38939).
                    child:
                        icon ??
                        Image.asset(
                          iconUrl ?? '',
                          package: UIConstants.packageName,
                          color: style.iconColor ?? colorPalette.primary,
                          height: 20,
                          width: 20,
                        ),
                  ),
                Container(
                  width: 180,
                  padding: EdgeInsets.only(left: spacing.padding2 ?? 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? '',
                        style: TextStyle(
                          fontSize: typography.body?.medium?.fontSize,
                          fontWeight: typography.body?.medium?.fontWeight,
                          fontFamily: typography.body?.medium?.fontFamily,
                          color: alignment == BubbleAlignment.right
                              ? colorPalette.white
                              : colorPalette.neutral900,
                        ).merge(style.titleStyle),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle ?? '',
                        style: TextStyle(
                          fontSize: typography.caption1?.regular?.fontSize,
                          fontWeight: typography.caption1?.regular?.fontWeight,
                          fontFamily: typography.caption1?.regular?.fontFamily,
                          color: alignment == BubbleAlignment.right
                              ? colorPalette.white
                              : colorPalette.neutral600,
                        ).merge(style.subtitleStyle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            thickness: 1,
            height: 0,
            color:
                style.dividerColor ??
                (alignment == BubbleAlignment.right
                    ? colorPalette.extendedPrimary800
                    : colorPalette.borderDark),
          ),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (onTap != null) {
                      onTap!(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        style.buttonBackgroundColor ?? colorPalette.transparent,
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText ?? Translations.of(context).join,
                    style: TextStyle(
                      fontSize: typography.button?.medium?.fontSize,
                      fontWeight: typography.button?.medium?.fontWeight,
                      fontFamily: typography.button?.medium?.fontFamily,
                      color: alignment == BubbleAlignment.right
                          ? colorPalette.white
                          : colorPalette.primary,
                    ).merge(style.buttonTextStyle),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
