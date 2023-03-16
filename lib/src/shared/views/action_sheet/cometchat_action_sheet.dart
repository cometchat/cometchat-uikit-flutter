import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import '../../models/action_item.dart';
import '../../models/action_item.dart' as action_alias;

enum ActionSheetLayoutMode { list, grid }

class CometChatActionSheet extends StatefulWidget {
  const CometChatActionSheet(
      {Key? key,
      required this.actionItems,
      this.backgroundColor,
      this.iconBackground,
      this.title,
      this.titleStyle,
      this.layoutModeIcon,
      this.layoutIconColor,
      this.isLayoutModeIconVisible,
      this.isTitleVisible,
      this.isGridLayout})
      : super(key: key);

  final List<ActionItem> actionItems;
  final Color? backgroundColor;
  final Color? iconBackground;
  final String? title;
  final TextStyle? titleStyle;
  final IconData? layoutModeIcon;
  final Color? layoutIconColor;
  final bool? isLayoutModeIconVisible;
  final bool? isTitleVisible;
  final bool? isGridLayout;

  @override
  _CometChatActionSheetState createState() => _CometChatActionSheetState();
}

class _CometChatActionSheetState extends State<CometChatActionSheet> {
  bool _isGridLayout = false;
  @override
  void initState() {
    super.initState();
    if (widget.isGridLayout == true) _isGridLayout = true;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.5,
      maxChildSize: 0.75,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          padding:
              const EdgeInsets.only(top: 6, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            shape: BoxShape.rectangle,
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 50,
                decoration: BoxDecoration(
                    color: widget.iconBackground ??
                        const Color(0xff141414).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(2)),
              ),
              if (!(widget.isLayoutModeIconVisible == false ||
                  widget.isTitleVisible == false))
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.title ?? "",
                          style: widget.titleStyle ??
                              const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isGridLayout = !_isGridLayout;
                          });
                        },
                        child: CircleAvatar(
                          child: Icon(widget.layoutModeIcon ?? Icons.menu),
                          backgroundColor:
                              widget.layoutIconColor ?? const Color(0xff3399FF),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                  child: _isGridLayout == true
                      ? gridView(widget.actionItems, scrollController)
                      : listView(widget.actionItems, scrollController))
            ],
          ),
        );
      },
    );
  }

  Widget listView(List<ActionItem> actionItems, ScrollController controller) {
    return SingleChildScrollView(
      controller: controller,
      child: Container(
        decoration: BoxDecoration(
            color: widget.iconBackground ??
                const Color(0xff141414).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            for (int index = 0; index < actionItems.length; index++)
              Container(
                decoration: BoxDecoration(
                  border: index != actionItems.length - 1
                      ? Border(
                          bottom: BorderSide(
                              color: widget.iconBackground ??
                                  const Color(0xff141414).withOpacity(0.1),
                              width: 1))
                      : null,
                ),
                height: 54,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Center(
                    child: ListTile(
                        onTap: () {
                          Navigator.of(context).pop(actionItems[index]);
                        },
                        contentPadding: const EdgeInsets.all(0),
                        dense: true,
                        minVerticalPadding: 0,
                        minLeadingWidth: 0,
                        leading: actionItems[index].iconUrl != null
                            ? Image.asset(
                                actionItems[index].iconUrl!,
                                color: actionItems[index].iconTint ??
                                    const Color(0xff141414).withOpacity(0.69),
                                package: actionItems[index].iconUrlPackageName,
                              )
                            : null,
                        title: Text(
                          actionItems[index].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: widget.titleStyle ??
                              const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xff141414)),
                        )),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget gridView(List<ActionItem> actionItems, ScrollController controller) {
    return GridView.count(
      shrinkWrap: false,
      controller: controller,
      childAspectRatio: 2,
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (ActionItem item in actionItems)
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop(item);
            },
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: item.background ??
                    widget.iconBackground ??
                    const Color(0xff000000).withOpacity(0.04),
                borderRadius: const BorderRadius.all(Radius.circular(8.0)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (item.iconUrl != null)
                      Image.asset(
                        item.iconUrl!,
                        color: item.iconTint ??
                            const Color(0xff141414).withOpacity(0.69),
                        package: item.iconUrlPackageName,
                      ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: item.titleStyle,
                    )
                  ],
                ),
              ),
            ),
          )
      ],
    );
  }
}

///Function to show comeChat action sheet
Future<ActionItem?>? showCometChatActionSheet(
    {required BuildContext context,
    WidgetBuilder? builder,
    required List<action_alias.ActionItem> actionItems,
    final Color? backgroundColor,
    final Color? iconBackground,
    final String? title,
    final TextStyle? titleStyle,
    final IconData? layoutModeIcon,
    final bool? isLayoutModeIconVisible,
    final Color? layoutIconColor,
    final bool? isTitleVisible,
    final bool? isGridLayout,
    final ShapeBorder? alertShapeBorder}) {
  return showModalBottomSheet<ActionItem>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: backgroundColor ?? const Color(0xffFFFFFF),
      shape: alertShapeBorder ??
          const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) => CometChatActionSheet(
            actionItems: actionItems,
            backgroundColor: backgroundColor ?? const Color(0xffFFFFFF),
            iconBackground: iconBackground,
            title: title,
            titleStyle: titleStyle,
            layoutModeIcon: layoutModeIcon,
            isLayoutModeIconVisible: isLayoutModeIconVisible,
            isTitleVisible: isTitleVisible,
            isGridLayout: isGridLayout,
            layoutIconColor: layoutIconColor,
          ));
}
