import '../../../../../../cometchat_uikit_shared.dart';
import 'package:flutter/material.dart';

class CometChatDecoratedContainer extends StatelessWidget {
  const CometChatDecoratedContainer({
    super.key,
    this.content,
    this.style,
    this.title,
    this.closeIconUrl,
    this.maxHeight,
    this.onCloseIconTap,
    this.closeIconUrlPackageName,
    this.colorPalette,
    this.typography,
    this.spacing,
    this.height,
    this.width,
    this.padding,
    this.margin,
  });

  ///[maxHeight] The maximum height of the container.
  final double? maxHeight;

  ///[title] is a String parameter which takes the title of the Container.
  final String? title;

  ///[content] is a String parameter which takes the content of the Container.
  final Widget? content;

  ///[closeIconUrl] is a String parameter which takes the url of the close icon.
  final String? closeIconUrl;

  ///[closeIconUrlPackageName] is a String parameter which takes the package name of the close icon.
  final String? closeIconUrlPackageName;

  ///[style] is a parameter which takes the style of the Container.
  final DecoratedContainerStyle? style;

  ///[onCloseIconTap] is a callback which takes the function to be executed on tapping the close icon.
  final VoidCallback? onCloseIconTap;

  ///[colorPalette] is a parameter which takes the colorPalette of the Container.
  final CometChatColorPalette? colorPalette;

  ///[typography] is a parameter which takes the typography of the Container.
  final CometChatTypography? typography;

  ///[spacing] is a parameter which takes the spacing of the Container.
  final CometChatSpacing? spacing;

  ///[height] is a double parameter which takes the height of the Container.
  final double? height;

  ///[width] is a double parameter which takes the width of the Container.
  final double? width;

  ///[padding] is a EdgeInsetsGeometry parameter which takes the padding of the Container.
  final EdgeInsetsGeometry? padding;

  ///[margin] is a EdgeInsetsGeometry parameter which takes the margin of the Container.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: style?.backgroundColor ?? colorPalette?.background1,
        borderRadius:
            style?.borderRadius ?? BorderRadius.circular(spacing?.radius2 ?? 0),
        border:
            style?.border ??
            Border.all(
              width: 1,
              color: colorPalette?.borderLight ?? Colors.transparent,
            ),
      ),
      constraints: BoxConstraints(maxHeight: maxHeight ?? 400.0),
      padding: padding,
      margin:
          margin ??
          EdgeInsets.only(
            left: spacing?.margin2 ?? 0,
            right: spacing?.margin2 ?? 0,
            bottom: spacing?.margin1 ?? 0,
          ),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(bottom: spacing?.padding2 ?? 0),
              height: 21,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: TextStyle(
                        color: colorPalette?.textPrimary,
                        fontSize: typography?.heading4?.medium?.fontSize,
                        fontWeight: typography?.heading4?.medium?.fontWeight,
                      ).merge(style?.titleStyle),
                    ),
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: IconButton(
                      tooltip: Translations.of(context).close,
                      onPressed: onCloseIconTap,
                      padding: EdgeInsets.zero,
                      icon: closeIconUrl == null
                          ? Icon(
                              Icons.close,
                              color:
                                  style?.closeIconColor ??
                                  colorPalette?.iconPrimary,
                            )
                          : Image.asset(
                              excludeFromSemantics: true,
                              closeIconUrl!,
                              package: closeIconUrlPackageName,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            ?content,
          ],
        ),
      ),
    );
  }
}
