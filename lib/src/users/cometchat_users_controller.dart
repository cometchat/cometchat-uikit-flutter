import '../../../cometchat_chat_uikit.dart';

///[CometChatUsersController] is the view model for [CometChatUsers]
class CometChatUsersController
    extends CometChatSearchListController<User, String>
    with
        CometChatSelectable,
        UserListener,
        CometChatUserEventListener,
        ConnectionListener {
  //--------------------Constructor-----------------------
  CometChatUsersController(
      {required this.usersBuilderProtocol,
      SelectionMode? mode,
      OnError? onError})
      : super(builderProtocol: usersBuilderProtocol, onError: onError) {
    selectionMode = mode ?? SelectionMode.none;
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    userListenerID = "${dateStamp}user_listener";
    _uiUserListener = "${dateStamp}UI_user_listener";
  }

  //-------------------------Variable Declaration-----------------------------
  late UsersBuilderProtocol usersBuilderProtocol;
  late String dateStamp;
  late String userListenerID;
  late String _uiUserListener;

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    CometChat.addUserListener(userListenerID, this);
    CometChatUserEvents.addUsersListener(_uiUserListener, this);
    CometChat.addConnectionListener(userListenerID, this);
    super.onInit();
  }

  @override
  void onClose() {
    CometChat.removeUserListener(userListenerID);
    CometChatUserEvents.removeUsersListener(_uiUserListener);
    CometChat.removeConnectionListener(userListenerID);
    super.onClose();
  }

  //-------------------------Parent List overriding Methods-----------------------------
  @override
  bool match(User elementA, User elementB) {
    return elementA.uid == elementB.uid;
  }

  @override
  String getKey(User element) {
    return element.uid;
  }

  //------------------------SDK User Event Listeners------------------------------
  @override
  void onUserOffline(User user) {
    updateElement(user);
  }

  @override
  void onUserOnline(User user) {
    updateElement(user);
  }

  //------------------------UI User Event Listeners-----------------------------
  @override
  void ccUserBlocked(User user) {
    updateElement(user);
  }

  @override
  void ccUserUnblocked(User user) {
    updateElement(user);
  }

  @override
  void onConnected() {
    if(!isLoading) {
      request = usersBuilderProtocol.getRequest();
      list = [];
      loadMoreElements();
    }
  }
}
