import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../cometchat_chat_uikit.dart';

///[CometChatMessages] is a component that provides a skeleton structure that binds together [CometChatMessageHeader], [CometChatMessageList], [CometChatMessageComposer] component.
///and it also facilitates the communication between these components.
///
/// ```dart
///   CometChatMessages(
///    user: User(uid: 'uid', name: 'name'),
///    group: Group(guid: 'guid', name: 'name', type: 'public'),
///    detailsConfiguration: DetailsConfiguration(),
///    messageHeaderConfiguration: MessageHeaderConfiguration(),
///    messageListConfiguration: MessageListConfiguration(),
///    messageComposerConfiguration: MessageComposerConfiguration(),
///    threadedMessagesConfiguration: ThreadedMessagesConfiguration(),
///    messagesStyle: MessagesStyle(),
///  );
/// ```
class CometChatMessages extends StatefulWidget {
  const CometChatMessages(
      {super.key,
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
      this.hideDetails,
      this.messageComposerKey})
      : assert(user != null || group != null,
            "One of user or group should be passed"),
        assert(user == null || group == null,
            "Only one of user or group should be passed");

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

  ///[messageComposerKey] key for message composer, We use this to get  the dimensions of the composer which we then use to set the placeholder for the composer in stack we are using to show the message list
  final GlobalKey? messageComposerKey;

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
                          theme: widget.detailsConfiguration?.theme ?? _theme,
                          onBack: widget.detailsConfiguration?.onBack,
                          onError: widget.detailsConfiguration?.onError,
                          groupMembersConfiguration: widget
                              .detailsConfiguration?.groupMembersConfiguration,
                          leaveGroupDialogStyle: widget
                              .detailsConfiguration?.leaveGroupDialogStyle,
                          stateCallBack:
                              widget.detailsConfiguration?.stateCallBack,
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
            onError: widget.messageListConfiguration.onError,
            theme: widget.messageListConfiguration.theme ?? _theme,
            disableReceipt: widget.messageListConfiguration.disableReceipt,
            messageInformationConfiguration:
                widget.messageListConfiguration.messageInformationConfiguration,
            dateSeparatorStyle:
                widget.messageListConfiguration.dateSeparatorStyle,
            disableReactions: widget.messageListConfiguration.disableReactions,
            reactionListConfiguration:
                widget.messageListConfiguration.reactionListConfiguration,

            textFormatters: widget.messageListConfiguration.textFormatters,
            disableMentions: widget.messageListConfiguration.disableMentions,

            reactionsStyle: widget.messageListConfiguration.reactionsStyle,
            addReactionIcon: widget.messageListConfiguration.addReactionIcon,
            addReactionIconTap:
                widget.messageListConfiguration.addReactionIconTap,
            emojiKeyboardStyle:
                widget.messageListConfiguration.emojiKeyboardStyle,

            reactionsConfiguration:
                widget.messageListConfiguration.reactionsConfiguration,
            favoriteReactions:
                widget.messageListConfiguration.favoriteReactions,
          );
  }

  Widget getMessageComposer(
      CometChatMessagesController controller, BuildContext context) {
    GlobalKey key = widget.messageComposerKey ?? controller.messageComposerKey;

    if (controller.composerPlaceHolder == null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        controller.getComposerPlaceHolder();
      });
    }

    return widget.messageComposerView != null
        ? Container(
            key: key,
            child: widget.messageComposerView!(
                controller.user, controller.group, context),
          )
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
            stateCallBack: widget.messageComposerConfiguration.stateCallBack,
            attachmentIcon: widget.messageComposerConfiguration.attachmentIcon,
            liveReactionIcon:
                widget.messageComposerConfiguration.liveReactionIcon,
            deleteIcon: widget.messageComposerConfiguration.deleteIcon,
            playIcon: widget.messageComposerConfiguration.playIcon,
            recordIcon: widget.messageComposerConfiguration.recordIcon,
            stopIcon: widget.messageComposerConfiguration.stopIcon,
            pauseIcon: widget.messageComposerConfiguration.pauseIcon,
            submitIcon: widget.messageComposerConfiguration.submitIcon,
            disableTypingEvents:
                widget.messageComposerConfiguration.disableTypingEvents ??
                    false,
            mediaRecorderStyle:
                widget.messageComposerConfiguration.mediaRecorderStyle,
            hideVoiceRecording:
                widget.messageComposerConfiguration.hideVoiceRecording ?? false,
            voiceRecordingIcon:
                widget.messageComposerConfiguration.voiceRecordingIcon,
            messageComposerStyle: MessageComposerStyle(
              background: widget.messageComposerConfiguration
                      .messageComposerStyle?.background ??
                  (widget.messagesStyle?.gradient != null
                      ? Colors.transparent
                      : widget.messagesStyle?.background),
              border: widget.messageComposerConfiguration.messageComposerStyle
                      ?.border ??
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
              gradient: widget
                  .messageComposerConfiguration.messageComposerStyle?.gradient,
              height: widget
                  .messageComposerConfiguration.messageComposerStyle?.height,
              width: widget
                  .messageComposerConfiguration.messageComposerStyle?.width,
              attachmentIconTint: widget.messageComposerConfiguration
                  .messageComposerStyle?.attachmentIconTint,
              closeIconTint: widget.messageComposerConfiguration
                  .messageComposerStyle?.closeIconTint,
              dividerTint: widget.messageComposerConfiguration
                      .messageComposerStyle?.dividerTint ??
                  _theme.palette.getAccent500(),
              voiceRecordingIconTint: widget.messageComposerConfiguration
                  .messageComposerStyle?.voiceRecordingIconTint,
              inputTextStyle: widget.messageComposerConfiguration
                  .messageComposerStyle?.inputTextStyle,
              placeholderTextStyle: widget.messageComposerConfiguration
                  .messageComposerStyle?.placeholderTextStyle,
              sendButtonIcon: widget.messageComposerConfiguration
                  .messageComposerStyle?.sendButtonIcon,
              sendButtonIconTint: widget.messageComposerConfiguration
                  .messageComposerStyle?.sendButtonIconTint,
              contentPadding: widget.messageComposerConfiguration
                  .messageComposerStyle?.contentPadding,
            ),
            attachmentIconURL:
                widget.messageComposerConfiguration.attachmentIconURL,
            customSoundForMessage:
                widget.messageComposerConfiguration.customSoundForMessage,
            customSoundForMessagePackage: widget
                .messageComposerConfiguration.customSoundForMessagePackage,
            disableSoundForMessages:
                widget.messageComposerConfiguration.disableSoundForMessages,
            onError: widget.messageComposerConfiguration.onError,
            onSendButtonTap:
                widget.messageComposerConfiguration.onSendButtonTap,
            theme: widget.messageComposerConfiguration.theme ?? _theme,
            liveReactionIconURL:
                widget.messageComposerConfiguration.liveReactionIconURL,
            aiOptionStyle: widget.messageComposerConfiguration.aiOptionStyle,
            aiIconPackageName:
                widget.messageComposerConfiguration.aiIconPackageName,
            aiIconURL: widget.messageComposerConfiguration.aiIconURL,
            aiIcon: widget.messageComposerConfiguration.aiIcon,
            textFormatters: widget.messageComposerConfiguration.textFormatters,
            messageComposerKey: controller.messageComposerKey,
            disableMentions:
                widget.messageComposerConfiguration.disableMentions,
            textEditingController:
                widget.messageComposerConfiguration.textEditingController,
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
                                  (User? user, Group? group,
                                      BuildContext context) {
                                    //retrieving customized menu to be shown in Message Header
                                    Widget? auxiliaryHeaderMenu =
                                        CometChatUIKit.getDataSource()
                                            .getAuxiliaryHeaderMenu(
                                                context, user, group, _theme);
                                    return [
                                      if (auxiliaryHeaderMenu != null)
                                        auxiliaryHeaderMenu,
                                      if (widget.hideDetails != true)
                                        detailsWidget(user, group, context)
                                    ];
                                  },
                              user: value.user,
                              group: value.group,
                              disableTyping: widget.disableTyping,
                              theme: widget.messageHeaderConfiguration.theme ??
                                  _theme,
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
                                onlineStatusColor: widget
                                    .messageHeaderConfiguration
                                    .messageHeaderStyle
                                    ?.onlineStatusColor,
                                subtitleTextStyle: widget
                                    .messageHeaderConfiguration
                                    .messageHeaderStyle
                                    ?.subtitleTextStyle,
                                typingIndicatorTextStyle: widget
                                    .messageHeaderConfiguration
                                    .messageHeaderStyle
                                    ?.typingIndicatorTextStyle,
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
                                    FocusScopeNode currentFocus =
                                        FocusScope.of(context);

                                    if (!currentFocus.hasPrimaryFocus) {
                                      currentFocus.unfocus();
                                    }
                                  },
                                  child: getMessageList(value, context))),

                          //-----message composer-----
                          if (widget.hideMessageComposer == false &&
                              value.composerPlaceHolder != null)
                            value.composerPlaceHolder ?? const SizedBox(),
                        ],
                      ),
                      Positioned.fill(
                          child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Stack(
                                children: [
                                  if (widget.hideMessageComposer == false)
                                    getMessageComposer(value, context)
                                ],
                              ))),
                      if (value.isOverlayOpen == true)
                        ...value.liveAnimationList
                    ],
                  ),
                );
              })),
    );
  }
}
