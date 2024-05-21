import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessageOptionSheet] renders a bottom modal sheet
///that contains all the actions available to execute on a particular type of message
class MessageOptionSheet extends StatefulWidget {
  const MessageOptionSheet({
    super.key,
    required this.messageObject,
    required this.actionItems,
    this.backgroundColor,
    this.title,
    this.titleStyle,
    this.state,
    this.data,
    this.theme,
    this.favoriteReactions,
    this.hideReactions = false,
    this.onReactionTap,
    this.onAddReactionIconTap,
    this.addReactionIcon,
  });

  ///[actionItems] is a list of [ActionItem] which is used to set the actions
  final List<ActionItem> actionItems;

  ///[backgroundColor] sets the background color for the bottom sheet
  final Color? backgroundColor;

  ///[title] sets the title for the bottom sheet
  final String? title;

  ///[titleStyle] sets the style for the title
  final TextStyle? titleStyle;
  final dynamic data;

  ///[state] is a parameter used to set the state
  final CometChatMessageListController? state;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[favoriteReactions] is a list of frequently used reactions
  final List<String>? favoriteReactions;

  ///[messageObject] is a parameter used to set the message object
  final BaseMessage messageObject;

  ///[hideReactions] is a parameter used to hide the reactions
  final bool? hideReactions;

  ///[onReactionTap] is a callback which gets called when a reaction is pressed
  final Function(BaseMessage message, String? reaction)? onReactionTap;

  ///[addReactionIcon] sets custom icon for adding reaction
  final Widget? addReactionIcon;

  ///[onAddReactionIconTap] sets custom onTap for adding reaction
  final Function(BaseMessage)? onAddReactionIconTap;

  @override
  State<MessageOptionSheet> createState() => _MessageOptionSheetState();
}

class _MessageOptionSheetState extends State<MessageOptionSheet> {
  late List<String> favoriteReactions;
  @override
  void initState() {
    super.initState();
    favoriteReactions =
        widget.favoriteReactions ?? ['👍', '❤️', '😂', '😢', '🙏'];
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme theme = widget.theme ?? cometChatTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.75,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          padding: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
              color: widget.backgroundColor ?? const Color(0xffFFFFFF),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Container(
                  height: 4,
                  width: 50,
                  decoration: BoxDecoration(
                      color: const Color(0xff141414).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (!(widget.hideReactions ?? false))
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ...favoriteReactions.map((reaction) => GestureDetector(
                            onTap: () async {
                              Navigator.of(context).pop();
                              if (widget.onReactionTap != null) {
                                widget.onReactionTap!(
                                    widget.messageObject, reaction);
                              }
                            },
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: theme.palette.getAccent50(),
                              child: Text(
                                reaction,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: theme.typography.heading.fontSize,
                                    fontWeight:
                                        theme.typography.name.fontWeight),
                              ),
                            ),
                          )),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.palette.getAccent50(),
                        child: IconButton(
                            onPressed: () async {
                              if (widget.onAddReactionIconTap != null) {
                                widget.onAddReactionIconTap!(
                                    widget.messageObject);
                              }
                            },
                            icon: Image.asset(
                              AssetConstants.addReaction,
                              package: UIConstants.packageName,
                              height: theme.typography.heading.fontSize + 4,
                              width: theme.typography.heading.fontSize + 4,
                            )),
                      )
                    ],
                  ),
                ),
              if (!(widget.hideReactions ?? false))
                Divider(
                  thickness: .5,
                  color: theme.palette.getAccent300(),
                ),
              //---reactions---
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (ActionItem item in widget.actionItems)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop(item);
                            },
                            child: SizedBox(
                              height: 48,
                              child: Center(
                                child: ListTile(
                                    contentPadding: const EdgeInsets.all(0),
                                    dense: true,
                                    minVerticalPadding: 0,
                                    minLeadingWidth: 0,
                                    leading: item.iconUrl != null
                                        ? Image.asset(
                                            item.iconUrl!,
                                            color: item.iconTint ??
                                                theme.palette.getAccent600(),
                                            package: item.iconUrlPackageName,
                                          )
                                        : null,
                                    title: Text(
                                      item.title,
                                      style: item.titleStyle ??
                                          TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w400,
                                              color: theme.palette.getAccent()),
                                    )),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

///Function to show message option bottom sheet
Future<ActionItem?> showMessageOptionSheet(
    {required BuildContext context,
    required List<ActionItem> actionItems,
    final Color? backgroundColor,
    final String? title,
    final TextStyle? titleStyle,
    final ShapeBorder? alertShapeBorder,
    final CometChatTheme? theme,
    required final dynamic message,
    required final CometChatMessageListController state,
    final Function(BaseMessage, String?)? onReactionTap,
    final Widget? addReactionIcon,
    final Function(BaseMessage)? addReactionIconTap,
    bool hideReactions = false,
    List<String>? favoriteReactions}) {
  return showModalBottomSheet<ActionItem>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: alertShapeBorder ??
          const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) => MessageOptionSheet(
            messageObject: message,
            actionItems: actionItems,
            backgroundColor: backgroundColor ?? const Color(0xffFFFFFF),
            title: title,
            titleStyle: titleStyle,
            data: message,
            state: state,
            theme: theme,
            addReactionIcon: addReactionIcon,
            onAddReactionIconTap: addReactionIconTap,
            hideReactions: hideReactions,
            favoriteReactions: favoriteReactions,
            onReactionTap: onReactionTap,
          ));
}
