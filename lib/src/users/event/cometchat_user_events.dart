import '../../../../../flutter_chat_ui_kit.dart';

class CometChatUserEvents {
  static Map<String, CometChatUserListener> usersListener = {};

  static addUsersListener(
      String listenerId, CometChatUserListener listenerClass) {
    usersListener[listenerId] = listenerClass;
  }

  static removeUsersListener(String listenerId) {
    usersListener.remove(listenerId);
  }

  static onUserBlock(String uid) {
    usersListener.forEach((key, value) {
      value.onUserBlock(uid);
    });
  }

  static onUserUnblock(String uid) {
    usersListener.forEach((key, value) {
      value.onUserUnblock(uid);
    });
  }

  static onError(CometChatException error) {
    usersListener.forEach((key, value) {
      value.onError(error);
    });
  }

  static onUserTap(User user) {
    usersListener.forEach((key, value) {
      value.onUserTap(user);
    });
  }

  static onUserLongPress(User user) {
    usersListener.forEach((key, value) {
      value.onUserLongPress(user);
    });
  }

  static onUserBack(User user) {
    usersListener.forEach((key, value) {
      value.onUserBack(user);
    });
  }
}
