import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../cometchat_chat_uikit.dart';
import '../../cometchat_chat_uikit.dart' as cc;

///[CometChatMessageInformation] is a widget that internally uses [CometChatListBase]
///to display message information.
/// ```dart
///   CometChatMessageInformation(
///      parentMessage: BaseMessage(
///          receiverUid: 'receiverUid',
///          type: 'type',
///          receiverType: 'receiverType',
///          readAt: DateTime.now()),
///      loggedInUser: User(name: 'loggedInUser', uid: 'uid_of_loggedInUser'),
///      messageInformationStyle: MessageInformationStyle(),
///      );
/// ```

class CometChatMessageInformation extends StatefulWidget {
  const CometChatMessageInformation({
    super.key,
    required this.message,
    this.title,
    this.closeIcon,
    this.template,
    this.messageInformationStyle,
    this.theme,
    this.onClose,
    this.bubbleView,
    this.listItemView,
    this.subTitleView,
    this.onError,
    this.receiptDatePattern,
    this.listItemStyle,
    this.readIcon,
    this.deliveredIcon,
    this.emptyStateText,
    this.emptyStateView,
    this.errorStateText,
    this.loadingIconUrl,
    this.loadingStateView,
    this.errorStateView,
  });

  ///[message] parent message for message information
  final BaseMessage message;

  ///[title] to be shown at head
  final String? title;

  ///[template] to get the message template
  final CometChatMessageTemplate? template;

  ///[bubbleView] bubble view for parent message
  final Widget Function(BaseMessage, BuildContext context)? bubbleView;

  ///[listItemView] list item view for parent message
  final Widget Function(BaseMessage message, MessageReceipt messageReceipt,
      BuildContext context)? listItemView;

  ///[subTitleView] gives subtitle view
  final Widget Function(BaseMessage message, MessageReceipt messageReceipt,
      BuildContext context)? subTitleView;

  ///[receiptDatePattern] to format receipt date
  final String? receiptDatePattern;

  ///to update Close Icon
  final Widget? closeIcon;

  ///[onClose] call function to be called on close button click
  final VoidCallback? onClose;

  ///[onError] callback triggered in case any error happens when fetching groups
  final OnError? onError;

  ///[messageInformationStyle] style parameter
  final MessageInformationStyle? messageInformationStyle;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///read icon widget
  final Widget? readIcon;

  ///delivered icon widget
  final Widget? deliveredIcon;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[loadingIconUrl] url to be displayed when loading
  final String? loadingIconUrl;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[errorStateView] returns view fow error state
  final WidgetBuilder? errorStateView;

  @override
  State<CometChatMessageInformation> createState() =>
      _CometChatMessageInformationState();
}

class _CometChatMessageInformationState
    extends State<CometChatMessageInformation> {
  late CometchatMessageInformationController
      cometchatMessageInformationController;
  late CometChatTheme _theme;

  late CometChatMessageTemplate _messageTemplate;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? cometChatTheme;
    List<CometChatMessageTemplate> template =
        CometChatUIKit.getDataSource().getAllMessageTemplates();
    for (var element in template) {
      if (widget.message.category == element.category &&
          widget.message.type == element.type) {
        _messageTemplate = element;
      }
    }
    _messageTemplate = widget.template ?? _messageTemplate;
    cometchatMessageInformationController =
        CometchatMessageInformationController(
            widget.message, _theme, widget.onError);
    cometchatMessageInformationController.fetchMessageRecipients(
        cometchatMessageInformationController.group,
        cometchatMessageInformationController.parentMessage);
  }

  @override
  Widget build(BuildContext context) {
    return CometChatListBase(
      title: widget.title ?? cc.Translations.of(context).messageInformation,
      hideSearch: true,
      backIcon: widget.closeIcon ??
          Image.asset(
            AssetConstants.back,
            package: UIConstants.packageName,
            color: _theme.palette.getPrimary(),
          ),
      showBackButton: true,
      theme: _theme,
      onBack: widget.onClose ??
          () {
            Navigator.of(context).pop();
          },
      style: ListBaseStyle(
        background: widget.messageInformationStyle?.gradient == null
            ? widget.messageInformationStyle?.background
            : Colors.transparent,
        titleStyle: widget.messageInformationStyle?.titleStyle,
        gradient: widget.messageInformationStyle?.gradient,
        height: widget.messageInformationStyle?.height,
        width: widget.messageInformationStyle?.width,
        backIconTint: widget.messageInformationStyle?.closeIconTint ??
            _theme.palette.getPrimary(),
        border: widget.messageInformationStyle?.border,
        borderRadius: widget.messageInformationStyle?.borderRadius,
      ),
      container: GetBuilder(
        init: cometchatMessageInformationController,
        builder: (CometchatMessageInformationController value) {
          if (value.hasError == true) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _showError(value, context, _theme));
            if (widget.errorStateView != null) {
              return widget.errorStateView!(context);
            }
            return _getLoadingIndicator(context, _theme);
          } else if (value.isLoading == true) {
            return _getLoadingIndicator(context, _theme);
          } else {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    cc.Translations.of(context).message,
                    style: widget.messageInformationStyle?.titleStyle ??
                        TextStyle(
                            fontSize: _theme.typography.text1.fontSize,
                            fontWeight: _theme.typography.text1.fontWeight,
                            color: _theme.palette.getAccent400()),
                  ),
                  Divider(
                    color: widget.messageInformationStyle?.dividerTint ??
                        _theme.palette.getAccent500(),
                  ),
                  (widget.bubbleView != null)
                      ? getBubbleView(value, context)
                      : MessageUtils.getMessageBubble(
                          context: context,
                          theme: _theme,
                          bubbleAlignment: BubbleAlignment.right,
                          message: value.parentMessage,
                          template: _messageTemplate,
                        ),
                  Divider(
                    color: widget.messageInformationStyle?.dividerTint ??
                        _theme.palette.getAccent500(),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    cc.Translations.of(context).receiptInformation,
                    style: widget.messageInformationStyle?.titleStyle ??
                        TextStyle(
                            fontSize: _theme.typography.text1.fontSize,
                            fontWeight: _theme.typography.text1.fontWeight,
                            color: _theme.palette.getAccent400()),
                  ),
                  Divider(
                    color: widget.messageInformationStyle?.dividerTint ??
                        _theme.palette.getAccent500(),
                  ),
                  SizedBox(
                    child: (cometchatMessageInformationController
                            .messageReceiptList.isEmpty)
                        ? _getNoRecipient(context, _theme)
                        : ListView.separated(
                            itemCount: cometchatMessageInformationController
                                .messageReceiptList.length,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              final messageReceipt =
                                  cometchatMessageInformationController
                                      .messageReceiptList[index];
                              return ((cometchatMessageInformationController
                                              .parentMessage.receiver is User &&
                                          cometchatMessageInformationController
                                                  .parentMessage.sentAt !=
                                              null) &&
                                      (cometchatMessageInformationController
                                                  .parentMessage.readAt ==
                                              null &&
                                          cometchatMessageInformationController
                                                  .parentMessage.deliveredAt ==
                                              null))
                                  ? _getNoRecipient(context, _theme)
                                  : _getListItemView(
                                      value, messageReceipt, context);
                            },
                            separatorBuilder: (context, index) {
                              return Divider(
                                color: widget
                                        .messageInformationStyle?.dividerTint ??
                                    _theme.palette.getAccent500(),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  _getListItemView(CometchatMessageInformationController value,
      MessageReceipt messageReceipt, BuildContext context) {
    if (widget.listItemView != null) {
      return widget.listItemView!(value.parentMessage, messageReceipt, context);
    } else {
      return CometChatListItem(
        avatarURL: messageReceipt.sender.avatar,
        avatarName: messageReceipt.sender.name,
        title: messageReceipt.sender.name,
        subtitleView: _getSubTitleView(value, messageReceipt, context),
        style: widget.listItemStyle ??
            ListItemStyle(
              background: Colors.transparent,
              titleStyle: TextStyle(
                fontSize: _theme.typography.title1.fontSize,
                fontWeight: _theme.typography.title1.fontWeight,
                fontFamily: _theme.typography.title1.fontFamily,
                color: _theme.palette.getAccent(),
              ),
            ),
      );
    }
  }

  _getSubTitleView(CometchatMessageInformationController value,
      MessageReceipt messageReceipt, BuildContext context) {
    if (widget.subTitleView != null) {
      return widget.subTitleView!(value.parentMessage, messageReceipt, context);
    } else {
      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                time(
                  value,
                  messageReceipt.deliveredAt,
                  cc.Translations.of(context).delivered,
                  widget.receiptDatePattern ?? "MMM dd, kk:mm:a",
                  widget.deliveredIcon ??
                      Image.asset(
                        AssetConstants.messageReceived,
                        package: UIConstants.packageName,
                        color:
                            widget.messageInformationStyle?.deliveredIconTint ??
                                _theme.palette.getAccent(),
                      ),
                  widget.messageInformationStyle ??
                      MessageInformationStyle(
                        titleStyle: TextStyle(
                          color: _theme.palette.getAccent(),
                          fontSize: _theme.typography.text2.fontSize,
                          fontWeight: _theme.typography.subtitle1.fontWeight,
                        ),
                        subTitleStyle: TextStyle(
                          color: _theme.palette.getAccent(),
                          fontSize: _theme.typography.text2.fontSize,
                          fontWeight: _theme.typography.name.fontWeight,
                        ),
                      ),
                ),
                const SizedBox(
                  height: 5,
                ),
                time(
                  value,
                  messageReceipt.readAt,
                  cc.Translations.of(context).read,
                  widget.receiptDatePattern ?? "MMM dd, kk:mm:a",
                  widget.readIcon ??
                      Image.asset(
                        AssetConstants.messageReceived,
                        package: UIConstants.packageName,
                        color: widget.messageInformationStyle?.readIconTint ??
                            _theme.palette.getPrimary(),
                      ),
                  widget.messageInformationStyle ??
                      MessageInformationStyle(
                        titleStyle: TextStyle(
                          color: _theme.palette.getAccent(),
                          fontSize: _theme.typography.text2.fontSize,
                          fontWeight: _theme.typography.subtitle1.fontWeight,
                        ),
                        subTitleStyle: TextStyle(
                          color: _theme.palette.getAccent(),
                          fontSize: _theme.typography.text2.fontSize,
                          fontWeight: _theme.typography.name.fontWeight,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  getBubbleView(
      CometchatMessageInformationController controller, BuildContext context) {
    if (widget.bubbleView != null) {
      return widget.bubbleView!(controller.parentMessage, context);
    } else {
      return const SizedBox();
    }
  }

  static Widget time(
    CometchatMessageInformationController value,
    DateTime? date,
    String status,
    String receiptDatePattern,
    Widget icon,
    MessageInformationStyle messageInformationStyle,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        icon,
        const SizedBox(
          width: 10,
        ),
        Text(
          status,
          style: messageInformationStyle.titleStyle,
        ),
        const Spacer(),
        Text(
          convertTime(date, receiptDatePattern),
          style: messageInformationStyle.subTitleStyle,
        ),
      ],
    );
  }

  static String convertTime(DateTime? time, String receiptDatePattern) {
    String formattedDate = "";
    if (time != null) {
      formattedDate = DateFormat(receiptDatePattern).format(time);
    }
    return formattedDate;
  }

  Widget _getNoRecipient(BuildContext context, CometChatTheme theme) {
    if (widget.emptyStateView != null) {
      return Center(child: widget.emptyStateView!(context));
    } else {
      return Center(
        child: Text(
          widget.emptyStateText ?? cc.Translations.of(context).noRecipient,
          style: widget.messageInformationStyle?.emptyTextStyle ??
              TextStyle(
                  fontSize: theme.typography.title1.fontSize,
                  fontWeight: theme.typography.title1.fontWeight,
                  color: theme.palette.getAccent400()),
        ),
      );
    }
  }

  Widget _getLoadingIndicator(BuildContext context, CometChatTheme theme) {
    if (widget.loadingStateView != null) {
      return Center(child: widget.loadingStateView!(context));
    } else {
      return Center(
        child: Image.asset(
          widget.loadingIconUrl ?? AssetConstants.spinner,
          package: UIConstants.packageName,
          color: widget.messageInformationStyle?.loadingIconTint ??
              theme.palette.getAccent600(),
        ),
      );
    }
  }

  _showError(CometchatMessageInformationController controller,
      BuildContext context, CometChatTheme theme) {
    String error;
    if (controller.error != null && controller.error is CometChatException) {
      error = widget.errorStateText ??
          Utils.getErrorTranslatedText(
              context, (controller.error as CometChatException).code);
    } else {
      error = widget.errorStateText ?? cc.Translations.of(context).noRecipient;
    }
    if (widget.errorStateView != null) {}
    _showErrorDialog(error, context, theme, controller);
  }

  _showErrorDialog(String errorText, BuildContext context, CometChatTheme theme,
      CometchatMessageInformationController controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          widget.errorStateText ?? errorText,
          style: widget.messageInformationStyle?.errorTextStyle ??
              TextStyle(
                  fontSize: theme.typography.title2.fontSize,
                  fontWeight: theme.typography.title2.fontWeight,
                  color: theme.palette.getAccent(),
                  fontFamily: theme.typography.title2.fontFamily),
        ),
        cancelButtonText: cc.Translations.of(context).ok,
        style: ConfirmDialogStyle(
            backgroundColor: theme.palette.mode == PaletteThemeModes.light
                ? theme.palette.getBackground()
                : Color.alphaBlend(theme.palette.getAccent200(),
                    theme.palette.getBackground()),
            shadowColor: theme.palette.getAccent300(),
            confirmButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight,
                color: theme.palette.getPrimary()),
            cancelButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight,
                color: theme.palette.getPrimary())),
        onCancel: () {
          Navigator.pop(context);
          Navigator.pop(context);
        });
  }
}
