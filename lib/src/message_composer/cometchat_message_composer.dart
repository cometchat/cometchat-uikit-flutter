import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:get/get.dart';
// import 'package:get/get_state_manager/get_state_manager.dart';
// import 'package:get/state_manager.dart';

///
/// [CometChatMessageComposer] component allows users to
/// send messages and attachments to the chat, participating in the conversation.
///
/// ```dart
///  CometChatMessageComposer(
///        user: 'user id',
///        stateCallBack: (CometChatMessageComposerController state) {},
///        enableTypingIndicator: true,
///        customSoundForMessage: 'asset url',
///        excludeMessageTypes: [MessageTypeConstants.image],
///        messageTypes: [
///          TemplateUtils.getAudioMessageTemplate(),
///          TemplateUtils.getTextMessageTemplate(),
///          CometChatMessageTemplate(type: 'custom', name: 'custom')
///        ],
///        enableSoundForMessages: true,
///        hideEmoji: false,
///        hideAttachment: false,
///        hideLiveReaction: false,
///        showSendButton: true,
///        placeholderText: 'Message',
///        style: MessageComposerStyle(
///          cornerRadius: 8,
///          background: Colors.white,
///          border: Border.all(),
///          gradient: LinearGradient(colors: []),
///        ),
///      )
///
/// ```
///

class CometChatMessageComposer extends StatelessWidget {
  CometChatMessageComposer(
      {Key? key,
      User? user,
      Group? group,
      this.messageComposerStyle = const MessageComposerStyle(),
      this.placeholderText,
      bool hideLiveReaction = false,
      bool disableTypingEvents = false,
      bool disableSoundForMessages = false,
      this.parentMessageId = 0,
      String? customSoundForMessage,
      String? customSoundForMessagePackage,
      this.auxiliaryButtonView,
      Widget? Function(BuildContext, {User? user, Group? group})? headerView,
      Widget? Function(BuildContext, {User? user, Group? group})? footerView,
      this.secondaryButtonView,
      this.sendButtonView,
      this.onSendButtonClick,
      List<CometChatMessageComposerAction>? attachmentOptions,
      this.text,
      this.onChange,
      this.maxLine,
      this.auxiliaryButtonsAlignment,
      String? liveReactionIconURL,
      this.attachmentIconURL,
      void Function(CometChatMessageComposerController)? stateCallBack,
      this.theme,
      this.attachmentIcon,
      this.liveReactionIcon,
      OnError? onError})
      : assert(user != null || group != null,
            "One of user or group should be passed"),
        assert(user == null || group == null,
            "Only one of user or group should be passed"),
        cometChatMessageComposerController = CometChatMessageComposerController(
            parentMessageId: parentMessageId,
            disableSoundForMessages: disableSoundForMessages,
            customSoundForMessage: customSoundForMessage,
            customSoundForMessagePackage: customSoundForMessagePackage,
            group: group,
            user: user,
            text: text,
            disableTypingEvents: disableTypingEvents,
            hideLiveReaction: hideLiveReaction,
            attachmentOptions: attachmentOptions,
            liveReactionIconURL: liveReactionIconURL,
            stateCallBack: stateCallBack,
            footerView: footerView,
            headerView: headerView,
            onError: onError),
        super(key: key);

  ///[messageComposerStyle] message composer style
  final MessageComposerStyle messageComposerStyle;

  ///[auxiliaryButtonView] ui component to be forwarded to message input component
  final Widget Function({User? user, Group? group})? auxiliaryButtonView;

  ///[secondaryButtonView] ui component to be forwarded to message input component
  final Widget Function({User? user, Group? group})? secondaryButtonView;

  ///[sendButtonView] ui component to be forwarded to message input component
  final Widget? sendButtonView;

  ///[text] initial text for the input field
  final String? text;

  ///[placeholderText] hint text for input field
  final String? placeholderText;

  ///[onChange] callback to handle change in value of text in the input field
  final Function(String)? onChange;

  ///[maxLine] maximum lines allowed to increase in the input field
  final int? maxLine;

  ///[auxiliaryButtonsAlignment] controls position auxiliary button view
  final AuxiliaryButtonsAlignment? auxiliaryButtonsAlignment;

  ///[cometChatMessageComposerController] contains the business logic
  final CometChatMessageComposerController cometChatMessageComposerController;

  ///[attachmentIconURL] path of the icon to show in the attachments button
  final String? attachmentIconURL;

  ///[onSendButtonClick] some task to execute if user presses the primary/send button
  final Function()? onSendButtonClick;

  ///[theme] sets the theme for this component
  final CometChatTheme? theme;

  ///[attachmentIcon] custom attachment icon
  final Widget? attachmentIcon;

  ///[liveReactionIcon] custom live reaction icon
  final Widget? liveReactionIcon;

  final int parentMessageId;

  late Map<String, dynamic> composerId = {};

  Widget _getSendButton(
      CometChatTheme _theme, CometChatMessageComposerController value) {
    if (value.textEditingController.text.isEmpty &&
        value.hideLiveReaction != true) {
      return IconButton(
        padding: const EdgeInsets.all(0),
        constraints: const BoxConstraints(),
        icon: liveReactionIcon ??
            Image.asset(AssetConstants.heart,
                package: UIConstants.packageName,
                color: _theme.palette.getError()),
        onPressed: () async {
          if (value.hideLiveReaction != true) {
            try {
              value.sendLiveReaction();
            } catch (_) {}
            await Future.delayed(
                const Duration(milliseconds: LiveReactionConstants.timeout));
          }
        },
      );
    } else {
      return sendButtonView ??
          IconButton(
              padding: const EdgeInsets.all(0),
              constraints: const BoxConstraints(),
              icon: messageComposerStyle.sendButtonIcon ??
                  Image.asset(
                    AssetConstants.send,
                    package: UIConstants.packageName,
                    color: value.textEditingController.text.isEmpty
                        ? _theme.palette.getAccent400()
                        : messageComposerStyle.sendButtonIconTint ??
                            _theme.palette.getPrimary(),
                  ),
              onPressed: onSendButtonClick ?? value.onSendButtonClick);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CometChatTheme _theme = theme ?? cometChatTheme;
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Column(
        children: [
          Container(
              decoration: BoxDecoration(
                  color: messageComposerStyle.gradient == null
                      ? messageComposerStyle.background ??
                          _theme.palette.getBackground()
                      : null,
                  gradient: messageComposerStyle.gradient),
              padding: messageComposerStyle.contentPadding ??
                  const EdgeInsets.only(
                      left: 16, right: 16, top: 10, bottom: 10),
              child: GetBuilder(
                  init: cometChatMessageComposerController,
                  tag: cometChatMessageComposerController.tag,
                  dispose: (GetBuilderState<CometChatMessageComposerController>
                          state) =>
                      Get.delete<CometChatMessageComposerController>(
                          tag: state.controller?.tag),
                  builder: (CometChatMessageComposerController value) {
                    value.context = context;
                    if (value.getAttachmentOptionsCalled == false) {
                      value.getAttachmentOptionsCalled = true;
                      value.getAttachmentOptions(_theme, context);
                    }
                    value.initializeHeaderAndFooterView();
                    return Column(
                      children: [
                        //-----message preview container-----
                        if (value.messagePreviewTitle != null &&
                            value.messagePreviewTitle!.isNotEmpty)
                          CometChatMessagePreview(
                            messagePreviewTitle: value.messagePreviewTitle!,
                            messagePreviewSubtitle:
                                value.messagePreviewSubtitle ?? '',
                            onCloseClick: value.onMessagePreviewClose,
                            style: CometChatMessagePreviewStyle(
                                messagePreviewTitleStyle: TextStyle(
                                    color: _theme.palette.getAccent600(),
                                    fontSize: _theme.typography.text2.fontSize,
                                    fontWeight:
                                        _theme.typography.text2.fontWeight,
                                    fontFamily:
                                        _theme.typography.text2.fontFamily),
                                messagePreviewSubtitleStyle: TextStyle(
                                    color: _theme.palette.getAccent600(),
                                    fontSize: _theme.typography.text2.fontSize,
                                    fontWeight:
                                        _theme.typography.text2.fontWeight,
                                    fontFamily:
                                        _theme.typography.text2.fontFamily),
                                closeIconColor:
                                    messageComposerStyle.closeIconTint ??
                                        _theme.palette.getAccent500(),
                                messagePreviewBorder: Border(
                                    left: BorderSide(
                                        color: _theme.palette.getAccent100(),
                                        width: 3))),
                          ),

                        //-----
                        Container(
                          decoration: BoxDecoration(
                            border: messageComposerStyle.border,
                            borderRadius: BorderRadius.all(Radius.circular(
                                messageComposerStyle.borderRadius ?? 8.0)),
                          ),
                          child: Column(
                            children: [
                              if (value.header != null) value.header!,
                              CometChatMessageInput(
                                text: text,
                                textEditingController:
                                    value.textEditingController,
                                placeholderText: placeholderText,
                                maxLine: maxLine,
                                onChange: onChange ?? value.onChange,
                                primaryButtonView:
                                    _getSendButton(_theme, value),
                                secondaryButtonView: secondaryButtonView != null
                                    ? secondaryButtonView!(
                                        user: value.user, group: value.group)
                                    : IconButton(
                                        padding: const EdgeInsets.all(0),
                                        constraints: const BoxConstraints(),
                                        icon: attachmentIcon ??
                                            Image.asset(
                                              attachmentIconURL ??
                                                  AssetConstants.add,
                                              package: UIConstants.packageName,
                                              color: messageComposerStyle
                                                      .attachmentIconTint ??
                                                  _theme.palette.getAccent700(),
                                            ),
                                        onPressed: () async {
                                          value.showBottomActionSheet(
                                              _theme, context);
                                        }),
                                auxiliaryButtonsAlignment:
                                    auxiliaryButtonsAlignment ??
                                        AuxiliaryButtonsAlignment.right,
                                auxiliaryButtonView: auxiliaryButtonView != null
                                    ? auxiliaryButtonView!(
                                        user: value.user, group: value.group)
                                    : Row(
                                        children: [
                                          //-----show emoji keyboard-----

                                          ChatConfigurator.getDataSource()
                                              .getAuxiliaryOptions(
                                                  value.user,
                                                  value.group,
                                                  context,
                                                  value.composerId),
                                          IconButton(
                                              padding: const EdgeInsets.only(
                                                  right: 20),
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: Image.asset(
                                                AssetConstants.smileys,
                                                package:
                                                    UIConstants.packageName,
                                                color: messageComposerStyle
                                                        .emojiIconTint ??
                                                    _theme.palette
                                                        .getAccent700(),
                                              ),
                                              onPressed: () => value.useEmojis(
                                                  context, _theme)),
                                        ],
                                      ),
                                style: MessageInputStyle(
                                    dividerTint:
                                        messageComposerStyle.dividerTint ??
                                            _theme.palette.getAccent500(),
                                    background:
                                        messageComposerStyle.inputBackground ??
                                            _theme.palette.getAccent100(),
                                    gradient:
                                        messageComposerStyle.inputGradient,
                                    textStyle:
                                        messageComposerStyle.inputTextStyle,
                                    placeholderTextStyle: messageComposerStyle
                                        .placeholderTextStyle),
                              ),
                              if (value.footer != null) value.footer!,
                            ],
                          ),
                        ),
                      ],
                    );
                  })),
        ],
      ),
    );
  }
}
