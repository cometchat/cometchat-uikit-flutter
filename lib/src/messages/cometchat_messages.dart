import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/src/messages/cometchat_messages_controller.dart';
import 'package:get/get.dart';
import '../../flutter_chat_ui_kit.dart';

///
///[CometChatMessages] component encompasses [CometChatMessageHeader], [CometChatMessageList], [CometChatMessageComposer] component.
///It handles communication between these components.
///
class CometChatMessages extends StatefulWidget {
  const CometChatMessages(
      {Key? key,
      this.user,
      this.group,
      this.hideMessageComposer = false,
      this.messageListConfiguration = const MessageListConfiguration(),
      this.messageHeaderConfiguration = const MessageHeaderConfiguration(),
      this.messageComposerConfiguration = const MessageComposerConfiguration(),
      this.disableTyping = false,
      this.detailsConfiguration,
      this.messagesStyle,
      this.customSoundForIncomingMessages,
      this.customSoundForIncomingMessagePackage,
      this.customSoundForOutgoingMessages,
      this.customSoundForOutgoingMessagePackage,
      this.hideMessageHeader,
      this.messageComposerView,
      this.messageHeaderView,
      this.messageListView,
      this.disableSoundForMessages,
      this.theme,
      this.threadedMessagesConfiguration,
      this.hideDetails})
      : assert(user != null || group != null,
            "One of user or group should be passed"),
        assert(user == null || group == null,
            "Only one of user or group should be passed"),
        super(key: key);

  ///[hideMessageComposer] hides the composer , default false
  final bool hideMessageComposer;

  ///[disableTyping] if true then show typing indicator for composer
  final bool disableTyping;

  ///To set the configuration  of message list [messageListConfiguration] is used
  final MessageListConfiguration messageListConfiguration;

  ///To set the configuration  of message list [messageHeaderConfiguration] is used
  final MessageHeaderConfiguration messageHeaderConfiguration;

  ///To set the configuration  of message list [messageComposerConfiguration] is used
  final MessageComposerConfiguration messageComposerConfiguration;

  /// [messageHeaderView] to set custom header
  final PreferredSizeWidget Function(
      User? user, Group? group, BuildContext context)? messageHeaderView;

  ///[messageComposerView] to set custom message composer
  final Widget Function(User? user, Group? group, BuildContext context)?
      messageComposerView;

  ///[messageListView] to set custom message list
  final Widget Function(User? user, Group? group, BuildContext context)?
      messageListView;

  ///[hideMessageHeader] toggle visibility for message header
  final bool? hideMessageHeader;

  ///[disableSoundForMessages] disable sound for incoming and outgoing message
  final bool? disableSoundForMessages;

  ///[customSoundForIncomingMessages] custom sound path for incoming messages
  final String? customSoundForIncomingMessages;

  ///[customSoundForIncomingMessagePackage] is the package name for sound incoming from different package
  final String? customSoundForIncomingMessagePackage;

  ///[customSoundForOutgoingMessagePackage] custom sound path for outgoing  messages
  final String? customSoundForOutgoingMessagePackage;

  ///[customSoundForOutgoingMessages]  custom sound path for outgoing messages
  final String? customSoundForOutgoingMessages;

  ///[detailsConfiguration] config properties for details module
  final DetailsConfiguration? detailsConfiguration;

  ///[messagesStyle] contains properties that affect the appearance of this widget
  final MessagesStyle? messagesStyle;

  ///[theme] custom theme
  final CometChatTheme? theme;

  ///[user] if not null will [CometChatMessages] for the [user]
  final User? user;

  ///[group] if not null will [CometChatMessages] for the [group]
  final Group? group;

  ///[threadedMessagesConfiguration] sets configuration properties for [CometChatThreadedMessages]
  final ThreadedMessagesConfiguration? threadedMessagesConfiguration;

  ///[hideDetails] toggle visibility for details icons
  final bool? hideDetails;

  @override
  State<CometChatMessages> createState() => _CometChatMessagesState();
}

class _CometChatMessagesState extends State<CometChatMessages> {
  late final CometChatTheme _theme;
  late CometChatMessagesController cometchatMessagesController;
  List<Widget> appbarOptions = [];

  @override
  void initState() {
    super.initState();
    cometchatMessagesController = CometChatMessagesController(
        user: widget.user,
        group: widget.group,
        threadedMessagesConfiguration: widget.threadedMessagesConfiguration);
    _theme = widget.theme ?? cometChatTheme;
  }

  Widget detailsWidget(User? user, Group? group, BuildContext context) {
    if ((user != null && user.uid == user.uid) ||
        ((group != null && group.guid == group.guid))) {
      return IconButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CometChatDetails(
                          user: user,
                          group: group,
                          data: widget.detailsConfiguration?.data,
                          title: widget.detailsConfiguration?.title,
                          closeButtonIcon:
                              widget.detailsConfiguration?.closeButtonIcon,
                          showCloseButton:
                              widget.detailsConfiguration?.showCloseButton,
                          //stateCallBack: detailsStateCallBack,
                          detailsStyle:
                              widget.detailsConfiguration?.detailsStyle,
                          addMemberConfiguration: widget
                              .detailsConfiguration?.addMemberConfiguration,
                          transferOwnershipConfiguration: widget
                              .detailsConfiguration
                              ?.transferOwnershipConfiguration,
                          bannedMemberConfiguration: widget
                              .detailsConfiguration?.bannedMemberConfiguration,
                          appBarOptions:
                              widget.detailsConfiguration?.appBarOptions,
                          avatarStyle: widget.detailsConfiguration?.avatarStyle,
                          customProfileView:
                              widget.detailsConfiguration?.customProfileView,
                          disableUsersPresence: widget
                                  .detailsConfiguration?.disableUsersPresence ??
                              false,
                          hideProfile: widget.detailsConfiguration?.hideProfile,
                          listItemStyle:
                              widget.detailsConfiguration?.listItemStyle,
                          subtitleView:
                              widget.detailsConfiguration?.subtitleView,
                          privateGroupIcon:
                              widget.detailsConfiguration?.privateGroupIcon,
                          protectedGroupIcon:
                              widget.detailsConfiguration?.protectedGroupIcon,
                          statusIndicatorStyle:
                              widget.detailsConfiguration?.statusIndicatorStyle,
                          theme: _theme,
                          onBack: widget.detailsConfiguration?.onBack,
                          onError: widget.detailsConfiguration?.onError,
                        ))).then((value) {
              if (value != null && value > 0) {
                Navigator.of(context).pop(value - 1);
              }
            });
          },
          icon: Image.asset(
            AssetConstants.info,
            package: UIConstants.packageName,
            color: _theme.palette.getPrimary(),
          ));
    }

    return const SizedBox();
  }

  Widget getMessageList(
      CometChatMessagesController controller, BuildContext context) {
    return widget.messageListView != null
        ? widget.messageListView!(controller.user, controller.group, context)
        : CometChatMessageList(
            user: controller.user,
            group: controller.group,
            alignment: widget.messageListConfiguration.alignment ??
                ChatAlignment.standard,
            templates: widget.messageListConfiguration.templates,
            //stateCallBack: messageListStateCallBack,
            messagesRequestBuilder:
                widget.messageListConfiguration.messagesRequestBuilder,
            footerView: widget.messageListConfiguration.footerView,
            headerView: widget.messageListConfiguration.headerView,
            controller: widget.messageListConfiguration.controller,
            datePattern: widget.messageListConfiguration.datePattern,
            avatarStyle: widget.messageListConfiguration.avatarStyle,
            dateSeparatorPattern:
                widget.messageListConfiguration.dateSeparatorPattern,
            deliveredIcon: widget.messageListConfiguration.deliveredIcon,
            emptyStateText: widget.messageListConfiguration.emptyStateText,
            emptyStateView: widget.messageListConfiguration.emptyStateView,
            errorStateText: widget.messageListConfiguration.errorStateText,
            errorStateView: widget.messageListConfiguration.errorStateView,
            hideError: widget.messageListConfiguration.hideError,
            hideTimestamp: widget.messageListConfiguration.hideTimestamp,
            waitIcon: widget.messageListConfiguration.waitIcon,
            showAvatar: widget.messageListConfiguration.showAvatar,
            loadingStateView: widget.messageListConfiguration.loadingStateView,
            disableSoundForMessages:
                widget.messageListConfiguration.disableSoundForMessages ??
                    widget.disableSoundForMessages,
            customSoundForMessagePackage:
                widget.messageListConfiguration.customSoundForMessagePackage ??
                    widget.customSoundForIncomingMessagePackage,
            customSoundForMessages:
                widget.messageListConfiguration.customSoundForMessages ??
                    widget.customSoundForIncomingMessages,
            messageListStyle:
                widget.messageListConfiguration.messageListStyle ??
                    const MessageListStyle(),
            sentIcon: widget.messageListConfiguration.sentIcon,
            readIcon: widget.messageListConfiguration.readIcon,
            onThreadRepliesClick:
                widget.messageListConfiguration.onThreadRepliesClick ??
                    controller.onThreadRepliesClick,
            scrollToBottomOnNewMessages:
                widget.messageListConfiguration.scrollToBottomOnNewMessages,
            newMessageIndicatorText:
                widget.messageListConfiguration.newMessageIndicatorText,
            timestampAlignment:
                widget.messageListConfiguration.timestampAlignment ??
                    TimeAlignment.bottom,
            // eventStreamController: controller.messageListEventStreamController,
            onError: widget.messageListConfiguration.onError,
            theme: widget.messageListConfiguration.theme,
            disableReceipt: widget.messageListConfiguration.disableReceipt);
  }

  Widget getMessageComposer(
      CometChatMessagesController controller, BuildContext context) {
    return widget.messageComposerView != null
        ? widget.messageComposerView!(
            controller.user, controller.group, context)
        : CometChatMessageComposer(
            user: controller.user,
            group: controller.group,
            placeholderText:
                widget.messageComposerConfiguration.placeholderText,
            hideLiveReaction:
                widget.messageComposerConfiguration.hideLiveReaction ?? false,
            text: widget.messageComposerConfiguration.text,
            auxiliaryButtonView:
                widget.messageComposerConfiguration.auxiliaryButtonView,
            headerView: widget.messageComposerConfiguration.headerView,
            footerView: widget.messageComposerConfiguration.footerView,
            secondaryButtonView:
                widget.messageComposerConfiguration.secondaryButtonView,
            sendButtonView: widget.messageComposerConfiguration.sendButtonView,
            attachmentOptions:
                widget.messageComposerConfiguration.attachmentOptions,
            onChange: widget.messageComposerConfiguration.onChange,
            maxLine: widget.messageComposerConfiguration.maxLine,
            auxiliaryButtonsAlignment:
                widget.messageComposerConfiguration.auxiliaryButtonsAlignment,
            // stateCallBack: composerStateCallBack,
            stateCallBack: widget.messageComposerConfiguration.stateCallBack,
            attachmentIcon: widget.messageComposerConfiguration.attachmentIcon,
            liveReactionIcon: widget.messageComposerConfiguration.liveReactionIcon,
            messageComposerStyle: MessageComposerStyle(
                background: widget.messageComposerConfiguration
                        .messageComposerStyle?.background ??
                    (widget.messagesStyle?.gradient != null
                        ? Colors.transparent
                        : widget.messagesStyle?.background),
                border:
                    widget.messageComposerConfiguration.messageComposerStyle?.border ??
                        (widget.messagesStyle?.background != null ||
                                widget.messagesStyle?.gradient != null
                            ? null
                            : widget.messagesStyle?.border),
                borderRadius: widget.messageComposerConfiguration
                        .messageComposerStyle?.borderRadius ??
                    widget.messagesStyle?.borderRadius,
                inputBackground: widget.messageComposerConfiguration
                        .messageComposerStyle?.inputBackground ??
                    _theme.palette.getAccent100(),
                gradient: widget.messageComposerConfiguration.messageComposerStyle?.gradient,
                height: widget.messageComposerConfiguration.messageComposerStyle?.height,
                width: widget.messageComposerConfiguration.messageComposerStyle?.width,
                attachmentIconTint: widget.messageComposerConfiguration.messageComposerStyle?.attachmentIconTint,
                closeIconTint: widget.messageComposerConfiguration.messageComposerStyle?.closeIconTint,
                dividerTint: widget.messageComposerConfiguration.messageComposerStyle?.dividerTint ?? _theme.palette.getAccent500(),
                emojiIconTint: widget.messageComposerConfiguration.messageComposerStyle?.emojiIconTint,
                inputTextStyle: widget.messageComposerConfiguration.messageComposerStyle?.inputTextStyle,
                placeholderTextStyle: widget.messageComposerConfiguration.messageComposerStyle?.placeholderTextStyle,
                sendButtonIcon: widget.messageComposerConfiguration.messageComposerStyle?.sendButtonIcon,
                sendButtonIconTint: widget.messageComposerConfiguration.messageComposerStyle?.sendButtonIconTint,
                stickerIconTint: widget.messageComposerConfiguration.messageComposerStyle?.stickerIconTint),
            attachmentIconURL:
                widget.messageComposerConfiguration.attachmentIconURL,
            customSoundForMessage:
                widget.messageComposerConfiguration.customSoundForMessage,
            customSoundForMessagePackage: widget
                .messageComposerConfiguration.customSoundForMessagePackage,
            disableSoundForMessages:
                widget.messageComposerConfiguration.disableSoundForMessages,
            onError: widget.messageComposerConfiguration.onError,
            onSendButtonClick:
                widget.messageComposerConfiguration.onSendButtonClick,
            theme: widget.messageComposerConfiguration.theme,
            liveReactionIconURL:
                widget.messageComposerConfiguration.liveReactionIconURL,
          );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DecoratedBox(
          decoration: BoxDecoration(
              gradient: widget.messagesStyle?.gradient,
              color: widget.messagesStyle?.gradient == null
                  ? widget.messagesStyle?.background
                  : null,
              border: widget.messagesStyle?.border,
              borderRadius: BorderRadius.circular(
                  widget.messagesStyle?.borderRadius ?? 0)),
          child: GetBuilder(
              init: cometchatMessagesController,
              tag: cometchatMessagesController.tag,
              builder: (CometChatMessagesController value) {
                value.context = context;
                return Scaffold(
                  backgroundColor: widget.messagesStyle?.gradient != null ||
                          widget.messagesStyle?.background != null
                      ? Colors.transparent
                      : null,
                  appBar: widget.hideMessageHeader == true
                      ? null
                      : widget.messageHeaderView != null
                          ? widget.messageHeaderView!(
                              value.user, value.group, context)
                          : CometChatMessageHeader(
                              appBarOptions: widget.messageHeaderConfiguration
                                      .appBarOptions ??
                                  (widget.hideDetails != true
                                      ? (User? user, Group? group,
                                          BuildContext context) {
                                          return [
                                            detailsWidget(user, group, context)
                                          ];
                                        }
                                      : null),
                              user: value.user,
                              group: value.group,
                              disableTyping: widget.disableTyping,
                              theme: _theme,
                              avatarStyle:
                                  widget.messageHeaderConfiguration.avatarStyle,
                              statusIndicatorStyle: widget
                                  .messageHeaderConfiguration
                                  .statusIndicatorStyle,
                              backButton:
                                  widget.messageHeaderConfiguration.backButton,
                              subtitleView: widget
                                  .messageHeaderConfiguration.subtitleView,
                              disableUserPresence: widget
                                  .messageHeaderConfiguration
                                  .disableUserPresence,
                              hideBackButton: widget
                                  .messageHeaderConfiguration.hideBackButton,
                              listItemStyle: widget
                                  .messageHeaderConfiguration.listItemStyle,
                              listItemView: widget
                                  .messageHeaderConfiguration.listItemView,
                              privateGroupIcon: widget
                                  .messageHeaderConfiguration.privateGroupIcon,
                              protectedGroupIcon: widget
                                  .messageHeaderConfiguration
                                  .protectedGroupIcon,
                              messageHeaderStyle: MessageHeaderStyle(
                                background: widget.messageHeaderConfiguration
                                        .messageHeaderStyle?.background ??
                                    (widget.messagesStyle?.background != null ||
                                            widget.messagesStyle?.gradient !=
                                                null
                                        ? Colors.transparent
                                        : null),
                                backButtonIconTint: widget
                                    .messageHeaderConfiguration
                                    .messageHeaderStyle
                                    ?.backButtonIconTint,
                                border: widget.messageHeaderConfiguration
                                    .messageHeaderStyle?.border,
                                borderRadius: widget.messageHeaderConfiguration
                                    .messageHeaderStyle?.borderRadius,
                                gradient: widget.messageHeaderConfiguration
                                    .messageHeaderStyle?.gradient,
                                height: widget.messageHeaderConfiguration
                                    .messageHeaderStyle?.height,
                                width: widget.messageHeaderConfiguration
                                    .messageHeaderStyle?.width,
                              ),
                              onBack: widget.messageHeaderConfiguration.onBack,
                            ),
                  body: Stack(
                    children: [
                      Column(
                        children: [
                          //----message list-----
                          Expanded(
                              child: GestureDetector(
                                  onTap: () {
                                    if (Platform.isIOS) {
                                      FocusScopeNode currentFocus =
                                          FocusScope.of(context);

                                      if (!currentFocus.hasPrimaryFocus) {
                                        currentFocus.unfocus();
                                      }
                                    }
                                  },
                                  child: getMessageList(value, context))),

                          //-----message composer-----
                          if (widget.hideMessageComposer == false)
                            getMessageComposer(value, context)
                        ],
                      ),
                      if (value.isOverlayOpen == true)
                        ...value.liveAnimationList
                    ],
                  ),
                );
              })),
    );
  }
}
