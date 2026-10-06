import '../../../../../../cometchat_uikit_shared.dart';
import 'package:flutter/material.dart';

/// `CometChatConfirmDialog` is a class that allows you to show a customizable confirmation dialog with a title, message, icon, and two buttons.
///
/// The dialog can be customized using the [CometChatConfirmDialogStyle] class, which allows for setting styles such as background color, button styles, and padding.
///
/// You can show the dialog using the [show] method, which will render it on the current context.
///
/// Example usage:
/// ```dart
/// CometChatConfirmDialog(
///  context: context,
///  title: Text("Block this contact?"),
///  messageText: Text("Are you sure you want to block this contact? You won’t receive messages from them anymore."),
///  confirmButtonText: "Block",
///  cancelButtonText: "Cancel",
///  onConfirm: (dialogContext) {
///     Navigator.of(dialogContext).pop();
///     // Block the contact
///  },
///  onCancel: (dialogContext) {
///     Navigator.of(dialogContext).pop();
///  },
///  style: CometChatConfirmDialogStyle(
///     backgroundColor: Colors.white,
///     shadow: Colors.black,
///     confirmButtonBackground: Colors.red,
///  ),
/// ).show();
/// ```
class CometChatConfirmDialog {
  /// Creates an instance of [CometChatConfirmDialog].
  ///
  /// [context] is required and represents the current widget context to display the dialog.
  /// [title] defines the title of the dialog as a [Widget] (e.g., a [Text] widget).
  /// [messageText] defines the message of the dialog as a [Widget] (e.g., a [Text] widget).
  /// [confirmButtonText] is the text to be displayed on the confirm button.
  /// [cancelButtonText] is the text to be displayed on the cancel button.
  /// [onConfirm] is the callback function that gets invoked when the confirm button is pressed.
  /// [onCancel] is the callback function that gets invoked when the cancel button is pressed.
  /// [style] is an optional [CometChatConfirmDialogStyle] object to customize the dialog appearance. It defaults to [CometChatConfirmDialogStyle].
  /// [contentPadding], [actionsPadding], [titlePadding], and [iconPadding] define padding for different elements of the dialog.
  CometChatConfirmDialog({
    required this.context,
    this.title,
    this.messageText,
    this.confirmButtonText,
    this.cancelButtonText,
    this.onConfirm,
    this.onCancel,
    this.style = const CometChatConfirmDialogStyle(),
    this.contentPadding,
    this.actionsPadding,
    this.titlePadding,
    this.iconPadding,
    this.icon,
    this.cancelButtonTextWidget,
    this.confirmButtonTextWidget,
    this.showIcon = true,
    this.intentPadding,
    this.useRootNavigator = true,
  });

  /// The current [BuildContext] in which the dialog is shown.
  final BuildContext context;

  /// The title widget of the dialog (typically a [Text] widget).
  final Widget? title;

  /// The message widget of the dialog (typically a [Text] widget).
  final Widget? messageText;

  /// The text widget displayed on the confirm button.
  final Widget? confirmButtonTextWidget;

  /// The text widget displayed on the cancel button.
  final Widget? cancelButtonTextWidget;

  /// The text displayed on the confirm button.
  final String? confirmButtonText;

  /// The text displayed on the cancel button.
  final String? cancelButtonText;

  /// Callback function invoked when the confirm button is pressed.
  /// Receives the dialog's [BuildContext] so callers can dismiss it via
  /// `Navigator.of(dialogContext).pop()` without worrying about root vs local navigator.
  final Function(BuildContext dialogContext)? onConfirm;

  /// Callback function invoked when the cancel button is pressed.
  /// Receives the dialog's [BuildContext] so callers can dismiss it via
  /// `Navigator.of(dialogContext).pop()` without worrying about root vs local navigator.
  final Function(BuildContext dialogContext)? onCancel;

  /// A style object to customize the appearance of the dialog.
  final CometChatConfirmDialogStyle style;

  /// The padding applied to the content of the dialog.
  final EdgeInsetsGeometry? contentPadding;

  /// The padding applied to the title of the dialog.
  final EdgeInsetsGeometry? titlePadding;

  /// The padding applied to the actions (buttons) of the dialog.
  final EdgeInsetsGeometry? actionsPadding;

  /// The padding applied to the icon of the dialog.
  final EdgeInsetsGeometry? iconPadding;

  /// The padding applied to the intent of the dialog.
  final EdgeInsets? intentPadding;

  /// The icon displayed at the top of the dialog.
  final Widget? icon;

  ///[showIcon] controls visibility of icon
  final bool showIcon;

  ///[useRootNavigator]
  final bool useRootNavigator;

  /// Shows the dialog by rendering it in the provided [context].
  ///
  /// This method uses [showDialog] to display the dialog and provides options
  /// for styling the title, message, and action buttons.
  void show() {
    final confirmDialogStyle =
        CometChatThemeHelper.getTheme<CometChatConfirmDialogStyle>(
          context: context,
          defaultTheme: CometChatConfirmDialogStyle.of,
        ).merge(style);
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);
    final typography = CometChatThemeHelper.getTypography(context);

    showDialog(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: confirmDialogStyle.shadow,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            side:
                confirmDialogStyle.border ??
                BorderSide(
                  color: colorPalette.borderLight ?? Colors.transparent,
                  width: 1,
                ),
            borderRadius:
                confirmDialogStyle.borderRadius ??
                BorderRadius.all(Radius.circular(spacing.radius4 ?? 0)),
          ),
          backgroundColor:
              confirmDialogStyle.backgroundColor ?? colorPalette.background1,
          insetPadding:
              intentPadding ??
              EdgeInsets.symmetric(horizontal: spacing.padding2 ?? 0),
          titlePadding:
              titlePadding ??
              EdgeInsets.only(
                left: spacing.padding6 ?? 0,
                right: spacing.padding6 ?? 0,
                bottom: spacing.padding2 ?? 0,
              ),
          contentPadding:
              contentPadding ??
              EdgeInsets.only(
                left: spacing.padding6 ?? 0,
                right: spacing.padding6 ?? 0,
                bottom: spacing.padding3 ?? 0,
              ),
          iconPadding:
              iconPadding ??
              EdgeInsets.only(
                left: spacing.padding6 ?? 0,
                right: spacing.padding6 ?? 0,
                top: spacing.padding6 ?? 0,
                bottom: spacing.padding3 ?? 0,
              ),
          actionsPadding:
              actionsPadding ??
              EdgeInsets.only(
                left: spacing.padding6 ?? 0,
                right: spacing.padding6 ?? 0,
                bottom: spacing.padding3 ?? 0,
              ),
          icon: showIcon
              ? Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color:
                        confirmDialogStyle.iconBackgroundColor ??
                        colorPalette.background2,
                    shape: BoxShape.circle,
                  ),
                  child:
                      icon ??
                      Icon(
                        Icons.block,
                        color:
                            confirmDialogStyle.iconColor ?? colorPalette.error,
                        size: 48,
                      ),
                )
              : const SizedBox(),
          title: title ?? Text(Translations.of(context).blockContact),
          titleTextStyle:
              TextStyle(
                    fontSize: typography.heading2?.medium?.fontSize,
                    fontWeight: typography.heading2?.medium?.fontWeight,
                    fontFamily: typography.heading2?.medium?.fontFamily,
                    color:
                        confirmDialogStyle.titleTextColor ??
                        colorPalette.textPrimary,
                  )
                  .merge(confirmDialogStyle.titleTextStyle)
                  .copyWith(color: confirmDialogStyle.titleTextColor),
          contentTextStyle:
              TextStyle(
                    fontSize: typography.body?.regular?.fontSize,
                    fontWeight: typography.body?.regular?.fontWeight,
                    fontFamily: typography.body?.regular?.fontFamily,
                    color:
                        confirmDialogStyle.messageTextColor ??
                        colorPalette.textSecondary,
                  )
                  .merge(confirmDialogStyle.messageTextStyle)
                  .copyWith(color: confirmDialogStyle.messageTextColor),
          content:
              messageText ??
              const Text(
                "Are you sure you want to block this contact? You won’t receive messages from them anymore.",
                textAlign: TextAlign.center,
              ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.margin3 ?? 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (cancelButtonText != null)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: spacing.padding2 ?? 0),
                        child: TextButton(
                          onPressed: onCancel != null
                              ? () => onCancel!(context)
                              : () {
                                  Navigator.of(context).pop();
                                },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              confirmDialogStyle.cancelButtonBackground,
                            ),
                            side: WidgetStateProperty.all(
                              BorderSide(
                                color:
                                    colorPalette.borderDark ??
                                    Colors.transparent,
                                width: 1,
                              ),
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                side: BorderSide(
                                  color:
                                      colorPalette.borderDark ??
                                      Colors.transparent,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(spacing.radius2 ?? 0),
                                ),
                              ),
                            ),
                          ),
                          child:
                              cancelButtonTextWidget ??
                              Text(
                                cancelButtonText ?? "",
                                style:
                                    TextStyle(
                                          fontSize: typography
                                              .button
                                              ?.medium
                                              ?.fontSize,
                                          fontWeight: typography
                                              .button
                                              ?.medium
                                              ?.fontWeight,
                                          fontFamily: typography
                                              .button
                                              ?.medium
                                              ?.fontFamily,
                                          color:
                                              confirmDialogStyle
                                                  .cancelButtonTextColor ??
                                              colorPalette.textPrimary,
                                        )
                                        .merge(
                                          confirmDialogStyle
                                              .cancelButtonTextStyle,
                                        )
                                        .copyWith(
                                          color: confirmDialogStyle
                                              .cancelButtonTextColor,
                                        ),
                              ),
                        ),
                      ),
                    ),
                  if (confirmButtonText != null)
                    Expanded(
                      child: TextButton(
                        onPressed: onConfirm != null
                            ? () => onConfirm!(context)
                            : () {
                                Navigator.of(context).pop();
                              },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            confirmDialogStyle.confirmButtonBackground,
                          ),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color:
                                  colorPalette.borderDark ?? Colors.transparent,
                              width: 0,
                            ),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              side: BorderSide(
                                color:
                                    colorPalette.borderDark ??
                                    Colors.transparent,
                                width: 0,
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(spacing.radius2 ?? 0),
                              ),
                            ),
                          ),
                        ),
                        child:
                            confirmButtonTextWidget ??
                            Text(
                              confirmButtonText!,
                              style:
                                  TextStyle(
                                        fontSize:
                                            typography.button?.medium?.fontSize,
                                        fontWeight: typography
                                            .button
                                            ?.medium
                                            ?.fontWeight,
                                        fontFamily: typography
                                            .button
                                            ?.medium
                                            ?.fontFamily,
                                        color:
                                            confirmDialogStyle
                                                .confirmButtonTextColor ??
                                            colorPalette.textPrimary,
                                      )
                                      .merge(
                                        confirmDialogStyle
                                            .confirmButtonTextStyle,
                                      )
                                      .copyWith(
                                        color: confirmDialogStyle
                                            .confirmButtonTextColor,
                                      ),
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
