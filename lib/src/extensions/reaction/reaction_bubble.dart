import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ReactionsBubble extends StatelessWidget {
  ///creates a widget that gives message reactions
  const ReactionsBubble(
      {Key? key,
      required this.messageObject,
      required this.loggedInUserId,
      this.theme,
      this.addReactionIcon,
      this.onReactionClick,
      this.style,
      this.emojiKeyboardStyle
      })
      : super(key: key);

  ///[messageObject] base message object
  final BaseMessage messageObject;

  ///[loggedInUserId] loggedIn user id to check loggedIn user reacted or not
  final String loggedInUserId;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[addReactionIcon] add reaction icon
  final Widget? addReactionIcon;

  ///[onReactionClick] add reaction icon
  final Function(String? emoji, BaseMessage message)? onReactionClick;

  ///[style] provides style to the emoji keyboard and the emoji
  final ReactionsStyle? style;

  ///[emojiKeyboardStyle] provides styling to the keyboard that contains the emojis
  final ReactionsEmojiKeyboardStyle? emojiKeyboardStyle;

  Map<String, dynamic> getMessageReactions(CometChatTheme _theme) {
    Map<String, dynamic>? map =
        ExtensionModerator.extensionCheck(messageObject);

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
          'textColor':reactedUsers.containsKey(loggedInUserId)||messageObject.sender?.uid==loggedInUserId?_theme.palette.backGroundColor.light:_theme.palette.backGroundColor.dark
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
                        if (onReactionClick != null) {
                          onReactionClick!(item, messageObject);
                        }

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
                          color: style?.emojiBackground ?? emojiItems[item]['background'],
                          border: style?.emojiBorder ?? Border.all(
                              color: _theme.palette
                                  .getBackground()
                                  .withOpacity(0.14),
                              width: 1),
                          borderRadius:
                               BorderRadius.all(Radius.circular(style?.emojiBorderRadius ?? 11)),
                        ),
                        child: Center(
                          child: Text(
                            '$item ${emojiItems[item]['count']}',
                            style: TextStyle(
                                fontSize: _theme.typography.caption1.fontSize,
                                color: emojiItems[item]['textColor'] ?? _theme.palette.getAccent(),
               
                                fontWeight:
                                    _theme.typography.caption1.fontWeight).merge(style?.emojiCountStyle),
                          ),
                        ),
                      ),
                    ),
                if (emojiItems.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      String? _emoji = await showCometChatEmojiKeyboard(
                          context: context,
                          backgroundColor:emojiKeyboardStyle?.backgroundColor ?? _theme.palette.getBackground(),
                          titleStyle: TextStyle(
                              fontSize: 17,
                              fontWeight: _theme.typography.name.fontWeight,
                              color: _theme.palette.getAccent()).merge(emojiKeyboardStyle?.titleStyle),
                          categoryLabel: TextStyle(
                              fontSize: _theme.typography.caption1.fontSize,
                              fontWeight: _theme.typography.caption1.fontWeight,
                              color: _theme.palette.getAccent600()).merge(emojiKeyboardStyle?.categoryLabelStyle),
                          dividerColor: emojiKeyboardStyle?.dividerColor ?? _theme.palette.getAccent100(),
                          selectedCategoryIconColor: emojiKeyboardStyle?.selectedCategoryIconColor ??
                              _theme.palette.getPrimary(),
                          unselectedCategoryIconColor: emojiKeyboardStyle?.unselectedCategoryIconColor ??
                              _theme.palette.getAccent600());
                      if (_emoji != null) {
                        if (onReactionClick != null) {
                          onReactionClick!(_emoji, messageObject);
                        }
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
                              AssetConstants.reactionsAdd,
                              package: UIConstants.packageName,
                              height: 16,
                              width: 16,
                              color: messageObject.sender?.uid!=loggedInUserId?_theme.palette.backGroundColor.dark:_theme.palette.backGroundColor.light,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          );
  }
}
