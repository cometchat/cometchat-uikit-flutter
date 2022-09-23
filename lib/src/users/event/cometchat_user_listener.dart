import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';

import '../../../../../flutter_chat_ui_kit.dart';

///Events can be triggered by the user action for
///e.g. Clicking on a particular user item. All public-facing components in each module will trigger events.
abstract class CometChatUserListener implements UIEventHandler {
  ///This will get triggered when the logged in user blocks another user
  void onUserBlock(String uid) {}

  ///This will get triggered when the logged in user unblocks another user
  void onUserUnblock(String uid) {}

  ///This will get triggered whenever an error occurs
  void onError(CometChatException error) {}

  ///This will get triggered when a user clicks/presses on single user i.e CometChatDataItem
  void onUserTap(User user) {}

  ///This will get triggered when a user clicks/presses on single user i.e CometChatDataItem
  void onUserLongPress(User user) {}

  ///This will get triggered when a user clicks/presses back button
  void onUserBack(User user) {}
}
