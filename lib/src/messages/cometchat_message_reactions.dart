import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

import 'message_bubbles/bubble_utils.dart';

class CometChatReactions extends StatelessWidget {
  ///creates a widget that gives message reactions
  const CometChatReactions(
      {Key? key,
      required this.messageObject,
      required this.loggedInUserId,
      this.theme,
      this.addReactionIcon})
      : super(key: key);

  ///[messageObject] base message object
  final BaseMessage messageObject;

  ///[loggedInUserId] loggedIn user id to check loggedIn user reacted or not
  final String loggedInUserId;

  ///[theme] theme
  final CometChatTheme? theme;

  ///[addReactionIcon] add reaction icon
  final Widget? addReactionIcon;

  Map<String, dynamic> getMessageReactions(CometChatTheme _theme) {
    Map<String, dynamic>? map = Extensions.extensionCheck(messageObject);

    if (map != null && map.containsKey(ExtensionConstants.reactions)) {
      Map<String, dynamic> reactions = map[ExtensionConstants.reactions];

      List<String> emojis = reactions.keys.toList();

      Map<String, dynamic> items = {};
      for (int i = 0; i < emojis.length; i++) {
        Map<String, dynamic> reactedUsers = reactions[emojis[i]];
        items[emojis[i]] = {
          'emoji': emojis[i],
          'count': reactedUsers.keys.length,
          'background': reactedUsers.containsKey(loggedInUserId)
              ? _theme.palette.getPrimary()
              : _theme.palette.getBackground(),
          'reactedByUser': reactedUsers.containsKey(loggedInUserId),
        };
      }
      return items;
    }

    return {};
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;
    Map<String, dynamic> emojiItems = getMessageReactions(_theme);

    return emojiItems.isEmpty
        ? const SizedBox(
            height: 0,
            width: 0,
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Wrap(
              direction: Axis.horizontal,
              spacing: 6.0,
              runSpacing: 6.0,
              children: [
                for (String item in emojiItems.keys)
                  if (emojiItems[item]['count'] != 0)
                    GestureDetector(
                      onTap: () {
                        CometChatMessageEvents.onMessageReact(
                            messageObject, item, MessageStatus.inProgress);
                      },
                      child: Container(
                        height: 22,
                        width: (32 +
                                8 *
                                    (emojiItems[item]['count'])
                                        .toString()
                                        .length)
                            .toDouble(),
                        decoration: BoxDecoration(
                          color: emojiItems[item]['background'],
                          border: Border.all(
                              color: _theme.palette
                                  .getBackground()
                                  .withOpacity(0.14),
                              width: 1),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(11)),
                        ),
                        child: Center(
                          child: Text(
                            '$item ${emojiItems[item]['count']}',
                            style: TextStyle(
                                fontSize: _theme.typography.caption1.fontSize,
                                color: _theme.palette.getAccent(),
                                fontWeight:
                                    _theme.typography.caption1.fontWeight),
                          ),
                        ),
                      ),
                    ),
                if (emojiItems.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      String? _emoji = await showCometChatEmojiKeyboard(
                          context: context,
                          backgroundColor: _theme.palette.getBackground(),
                          titleStyle: TextStyle(
                              fontSize: 17,
                              fontWeight: _theme.typography.name.fontWeight,
                              color: _theme.palette.getAccent()),
                          categoryLabel: TextStyle(
                              fontSize: _theme.typography.caption1.fontSize,
                              fontWeight: _theme.typography.caption1.fontWeight,
                              color: _theme.palette.getAccent600()),
                          dividerColor: _theme.palette.getAccent100(),
                          selectedCategoryIconColor:
                              _theme.palette.getPrimary(),
                          unselectedCategoryIconColor:
                              _theme.palette.getAccent600());
                      if (_emoji != null) {
                        CometChatMessageEvents.onMessageReact(
                            messageObject, _emoji, MessageStatus.inProgress);
                      }
                    },
                    child: Container(
                      height: 22,
                      width: 32,
                      decoration: BoxDecoration(
                        // color: _theme.palette.getBackground(),
                        border: Border.all(
                            color: _theme.palette
                                .getBackground()
                                .withOpacity(0.14),
                            width: 1),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(11)),
                      ),
                      child: Center(
                        child: addReactionIcon ??
                            Image.asset(
                              "assets/icons/reactions_add.png",
                              package: UIConstants.packageName,
                              height: 16,
                              width: 16,
                              color: _theme.palette.getBackground(),
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          );
  }
}
