import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
// import '../../flutter_chat_ui_kit.dart' as cc;

class CometChatTransferOwnershipController extends GetxController {

  CometChatTransferOwnershipController({required this.group,this.onTransferOwnership, this.onError});

  ///[group] is the group in which ownership is to change
  final Group group;

    ///[onTransferOwnership] overrides default on selection functionality
  final Function(GroupMember, Group)? onTransferOwnership;

  ///[onError] callback triggered in case any error happens when transferring ownership
  final OnError? onError;

  //  User? _loggedInUser;

   Conversation? _conversation;

  String? _conversationId;

  @override
  void onInit() {
    initializeInternalDependencies();
    
    super.onInit();
  }

  initializeInternalDependencies() async {
    // _loggedInUser = await CometChat.getLoggedInUser();
    _conversation ??= (await CometChat.getConversation(
        group.guid, ConversationType.group, onSuccess: (_conversation) {
      if (_conversation.lastMessage != null) {
       
      }
    }, onError: (_) {}));
    _conversationId ??= _conversation?.conversationId;
  }

 void getOnSelection(BuildContext context, List<GroupMember>? members) {
    if (members == null || members.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (onTransferOwnership != null) {
      onTransferOwnership!(members.first, group);
    } else {
      CometChat.transferGroupOwnership(
          guid: group.guid,
          uid: members.first.uid,
          onSuccess: (String result) {
            group.owner = members.first.uid;
            CometChatGroupEvents.ccOwnershipChanged(group, members.first);
            Navigator.of(context).pop();
          },
          onError: onError);
    }
  }
  
}