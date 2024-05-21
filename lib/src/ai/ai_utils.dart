import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

class AIUtils {
  static Widget getOnError(BuildContext context, CometChatTheme theme,
      {Color? backgroundColor,
      Color? shadowColor,
      String? errorIconUrl,
      String? errorIconPackageName,
      String? errorStateText,
      Color? errorIconTint,
      TextStyle? errorTextStyle}) {
    return Chip(
      backgroundColor: backgroundColor ?? theme.palette.getBackground(),
      shadowColor: shadowColor ?? theme.palette.getBackground(),
      label: Row(
        children: [
          Image.asset(
            errorIconUrl ?? AssetConstants.repliesError,
            package: errorIconPackageName ?? UIConstants.packageName,
            color: errorIconTint ?? theme.palette.getAccent700(),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            errorStateText ?? Translations.of(context).somethingWentWrongError,
            style: errorTextStyle ??
                TextStyle(
                  fontSize: theme.typography.title2.fontSize,
                  fontWeight: theme.typography.title2.fontWeight,
                  color: theme.palette.getAccent400(),
                ),
          ),
        ],
      ),
    );
  }

  static Widget getEmptyView(BuildContext context, CometChatTheme theme,
      {Color? backgroundColor,
      Color? shadowColor,
      String? emptyIconUrl,
      String? emptyIconPackageName,
      String? emptyStateText,
      Color? emptyIconTint,
      TextStyle? emptyTextStyle}) {
    return Chip(
      backgroundColor: backgroundColor ?? theme.palette.getBackground(),
      shadowColor: shadowColor ?? theme.palette.getBackground(),
      label: Row(
        children: [
          Image.asset(
            emptyIconUrl ?? AssetConstants.repliesEmpty,
            package: emptyIconPackageName ?? UIConstants.packageName,
            color: emptyIconTint ?? theme.palette.getAccent600(),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            emptyStateText ?? Translations.of(context).noMessagesFound,
            style: emptyTextStyle ??
                TextStyle(
                  fontSize: theme.typography.title1.fontSize,
                  fontWeight: theme.typography.title1.fontWeight,
                  color: theme.palette.getAccent400(),
                ),
          ),
        ],
      ),
    );
  }

  static Widget getLoadingIndicator(BuildContext context, CometChatTheme theme,
      {Color? backgroundColor,
      Color? shadowColor,
      String? loadingIconUrl,
      String? loadingIconPackageName,
      String? loadingStateText,
      Color? loadingIconTint,
      TextStyle? loadingTextStyle}) {
    return Chip(
      backgroundColor: backgroundColor ?? theme.palette.getBackground(),
      shadowColor: shadowColor ?? theme.palette.getBackground(),
      label: Row(
        children: [
          Image.asset(
            loadingIconUrl ?? AssetConstants.spinner,
            package: loadingIconPackageName ?? UIConstants.packageName,
            color: loadingIconTint ?? theme.palette.getAccent600(),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            loadingStateText ?? Translations.of(context).generatingIceBreakers,
            style: loadingTextStyle ??
                TextStyle(
                    fontSize: theme.typography.subtitle1.fontSize,
                    fontWeight: theme.typography.subtitle1.fontWeight,
                    color: theme.palette.getAccent()),
          ),
        ],
      ),
    );
  }
}
