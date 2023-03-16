import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';

import '../../../../../flutter_chat_ui_kit.dart';

///Events can be triggered by the user action for
///e.g. Clicking on a particular user item. All public-facing components in each module will trigger events.
abstract class CometChatUserEventListener implements UIEventHandler {
  ///This will get triggered when the logged in user blocks another user
  void ccUserBlocked(User user) {}

  ///This will get triggered when the logged in user unblocks another user
  void ccUserUnblocked(User user) {}

}
