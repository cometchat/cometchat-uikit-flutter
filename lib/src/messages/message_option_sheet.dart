import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

List<String> frequentlyUsedEmojis = [
  '😍',
  '😀',
  '😯',
  '😢',
  '😠',
  '👍',
];

class MessageOptionSheet extends StatefulWidget {
  const MessageOptionSheet(
      {Key? key,
      required this.actionItems,
      this.backgroundColor,
      this.title,
      this.titleStyle,
      this.state,
      this.data,
      this.theme})
      : super(key: key);

  final List<ActionItem> actionItems;
  final Color? backgroundColor;
  final String? title;
  final TextStyle? titleStyle;
  final dynamic data;
  final CometChatMessageListController? state;
  final CometChatTheme? theme;
  @override
  _MessageOptionSheetState createState() => _MessageOptionSheetState();
}

class _MessageOptionSheetState extends State<MessageOptionSheet> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = widget.theme ?? cometChatTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.75,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
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

              //---reactions---
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (ActionItem item in widget.actionItems)
                        if (item.id != MessageOptionConstants.reactToMessage)
                          GestureDetector(
                            onTap: () {
                              // Navigator.pop(context, item);
                              // item.onItemClick!(widget.data, widget.state!);
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
                                            _theme.palette.getAccent600(),
                                                // const Color(0xff141414)
                                                //     .withOpacity(0.58),
                                            package: item.iconUrlPackageName,
                                          )
                                        : null,
                                    title: Text(
                                      item.title,
                                      style: item.titleStyle ??
                                           TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w400,
                                              color: _theme.palette.getAccent()),
                                    )),
                              ),
                            ),
                          ),
                    ],
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
    required final CometChatMessageListController state}) {
  return showModalBottomSheet<ActionItem>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: alertShapeBorder ??
          const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) => MessageOptionSheet(
            actionItems: actionItems,
            backgroundColor: backgroundColor ?? const Color(0xffFFFFFF),
            title: title,
            titleStyle: titleStyle,
            data: message,
            state: state,
            theme: theme,
          ));
}
