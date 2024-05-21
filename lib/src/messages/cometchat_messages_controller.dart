import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../cometchat_chat_uikit.dart';
import '../message_composer/live_reaction_animation.dart';

///[CometChatMessagesController] is the view model for [CometChatMessages]
///it contains all the business logic involved in changing the state of the UI of [CometChatMessages]
class CometChatMessagesController extends GetxController
    with
        CometChatMessageEventListener,
        MessageListener,
        CometChatGroupEventListener,
        CometChatUserEventListener {
  late String _dateString;
  late String _uiMessageListener;
  late String _uiGroupListener;
  late String _uiUserListener;
  bool isOverlayOpen = false;
  List<Widget> liveAnimationList = [];
  CometChatMessageComposerController? composerState;
  CometChatDetailsController? detailsState;
  User? user;
  Group? group;
  User? loggedInUser;
  late BuildContext context;
  static int counter = 0;
  late String tag;

  ///[threadedMessagesConfiguration] sets configuration properties for [CometChatThreadedMessages]
  final ThreadedMessagesConfiguration? threadedMessagesConfiguration;

  CometChatMessagesController(
      {this.user, this.group, this.threadedMessagesConfiguration}) {
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _uiMessageListener = "${_dateString}UI_message_listener";
    _uiGroupListener = "${_dateString}UI_group_listener";
    _uiUserListener = "${_dateString}UI_user_listener";

    tag = "tag$counter";
    counter++;
  }

  final GlobalKey messageComposerKey = GlobalKey();

  Widget? composerPlaceHolder;
  void getComposerPlaceHolder() {
    BuildContext? context = messageComposerKey.currentContext;
    if (context == null) {
      composerPlaceHolder = const SizedBox();
    } else {
      RenderBox renderBox = context.findRenderObject() as RenderBox;

      var size = renderBox.size;
      composerPlaceHolder = SizedBox(
        height: size.height,
      );
    }
    update();
  }

  @override
  void onInit() {
    super.onInit();
    CometChatMessageEvents.addMessagesListener(_uiMessageListener, this);
    CometChatGroupEvents.addGroupsListener(_uiGroupListener, this);
    CometChatUserEvents.addUsersListener(_uiUserListener, this);
    _initializeLoggedInUser();
  }

  @override
  void onClose() {
    CometChatMessageEvents.removeMessagesListener(_uiMessageListener);
    CometChatGroupEvents.removeGroupsListener(_uiGroupListener);
    CometChatUserEvents.removeUsersListener(_uiUserListener);
    super.onClose();
  }

  //-----MessageComposerListener methods-----

  @override
  void onTransientMessageReceived(TransientMessage message) async {
    if ((message.receiverType == ReceiverTypeConstants.user &&
            message.receiverId == loggedInUser?.uid &&
            (message.sender != null &&
                user != null &&
                message.sender?.uid == user?.uid)) ||
        (message.receiverType == ReceiverTypeConstants.group &&
            group != null &&
            message.receiverId == group?.guid)) {
      if (message.data["type"] == "live_reaction") {
        isOverlayOpen = true;
        String reaction = message.data["reaction"];
        _addAnimations(reaction);
      }
    }
  }

  @override
  void ccLiveReaction(String reaction) async {
    isOverlayOpen = true;
    _addAnimations(reaction);
  }

  //----------User Event Listeners--------------
  @override
  void ccUserBlocked(User user) {
    if (this.user?.uid == user.uid) {
      this.user?.blockedByMe = true;
    }
  }

  @override
  void ccUserUnblocked(User user) {
    if (this.user?.uid == user.uid) {
      this.user?.blockedByMe = false;
    }
  }

  _initializeLoggedInUser() async {
    loggedInUser = await CometChat.getLoggedInUser();
  }

  _addAnimations(String reaction) async {
    //Counter to add no of live reactions
    int counter = 2;
    for (int i = 0; i < counter; i++) {
      _addAnimation(reaction);
      await Future.delayed(const Duration(milliseconds: 40));
    }
  }

  _addAnimation(String reaction) {
    liveAnimationList.add(
      Positioned(
          bottom: 100,
          right: 0,
          child: AnimatedSwitcher(
            key: UniqueKey(),
            duration: const Duration(milliseconds: 1000),
            child: LiveReactionAnimation(
              endAnimation: setOverLayFalse,
              reaction: reaction,
            ),
          )),
    );
    update();
  }

  setOverLayFalse() {
    if (liveAnimationList.isNotEmpty) {
      liveAnimationList.removeAt(0);
      if (liveAnimationList.isEmpty) {
        isOverlayOpen = false;
        update();
      }
    }
  }

  composerStateCallBack(CometChatMessageComposerController composerState) {
    composerState = composerState;
  }

  detailsStateCallBack(CometChatDetailsController detailsState) {
    detailsState = detailsState;
  }

  onThreadRepliesClick(BaseMessage message, BuildContext context,
      {Widget Function(BaseMessage, BuildContext)? bubbleView}) async {
    if (loggedInUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatThreadedMessages(
                  parentMessage: message,
                  loggedInUser: loggedInUser!,
                  title: threadedMessagesConfiguration?.title,
                  closeIcon: threadedMessagesConfiguration?.closeIcon,
                  bubbleView:
                      threadedMessagesConfiguration?.bubbleView ?? bubbleView,
                  messageActionView:
                      threadedMessagesConfiguration?.messageActionView,
                  messageListConfiguration:
                      threadedMessagesConfiguration?.messageListConfiguration,
                  messageComposerConfiguration: threadedMessagesConfiguration
                      ?.messageComposerConfiguration,
                  threadedMessagesStyle:
                      threadedMessagesConfiguration?.threadedMessagesStyle,
                  hideMessageComposer:
                      threadedMessagesConfiguration?.hideMessageComposer,
                  messageComposerView:
                      threadedMessagesConfiguration?.messageComposerView,
                  messageListView:
                      threadedMessagesConfiguration?.messageListView,
                )),
      );
    }
  }
}
