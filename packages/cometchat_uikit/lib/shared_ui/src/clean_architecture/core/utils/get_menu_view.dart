import 'package:flutter/material.dart';
import '../constants/ui_kit_constants.dart';
import '../../data/models/cometchat_option.dart';
import '../../presentation/theme/theme/cometchat_theme_helper.dart';

class GetMenuView extends StatelessWidget {
  const GetMenuView({
    super.key,
    required this.option,
    this.iconTint,
    this.textStyle,
  });

  final CometChatOption option;
  final Color? iconTint;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final typography = CometChatThemeHelper.getTypography(context);
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.padding4 ?? 0,
        vertical: spacing.padding4 ?? 0,
      ),
      decoration: BoxDecoration(color: colorPalette.background1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // An option carrying neither an iconWidget nor an icon path gets no
          // icon slot at all. Previously this fell through to
          // Image.asset("") and resolved "packages/cometchat_chat_uikit/",
          // which throws — so any caller-supplied option without an icon broke
          // the whole menu.
          if (option.iconWidget != null ||
              (option.icon != null && option.icon!.isNotEmpty))
            Padding(
              padding: EdgeInsets.only(right: spacing.padding2 ?? 0),
              child:
                  option.iconWidget ??
                  Image.asset(
                    option.icon!,
                    package: option.packageName ?? UIConstants.packageName,
                    color: iconTint ?? option.iconTint ?? colorPalette.error,
                    height: 24,
                    width: 24,
                  ),
            ),
          Expanded(
            child: Text(
              option.title ?? "",
              style: TextStyle(
                color: colorPalette.textPrimary,
                fontSize: typography.body?.regular?.fontSize,
                fontWeight: typography.body?.regular?.fontWeight,
                fontFamily: typography.body?.regular?.fontFamily,
              ).merge(textStyle),
            ),
          ),
        ],
      ),
    );
  }
}
