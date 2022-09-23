import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatMenuList extends StatelessWidget {
  ///Default CometChat menu widget shows
  const CometChatMenuList(
      {Key? key,
      required this.menuItems,
      required this.icon,
      required this.label,
      required this.background,
      required this.id})
      : super(key: key);

  /// List of menu items
  final List<ActionItem> menuItems;
  final Widget icon;
  final int id;
  final String label;
  final Color background;

  getFirstWidget(ActionItem item) {
    return GestureDetector(
      onTap: () {
        item.onItemClick();
      },
      child: Container(
        color: item.background,
        height: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              item.iconUrl!,
              package: item.iconUrlPackageName,
              color: item.iconTint,
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.fade,
            )
          ],
        ),
      ),
    );
  }

  getPopUpMenuButtons(List<ActionItem> menuItems) {
    return PopupMenuButton<ActionItem>(
      itemBuilder: (context) => menuItems
          .map((item) => PopupMenuItem<ActionItem>(
                value: item,
                child: Text(
                  item.title,
                  style: item.titleStyle,
                ),
              ))
          .toList(),
      onSelected: (ActionItem item) {
        item.onItemClick();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? _firstWidget;
    Widget? _secondWidget;
    List<ActionItem>? _hiddenMenuItems;
    if (menuItems.isNotEmpty) {
      _firstWidget = getFirstWidget(menuItems.first);
    }
    if (menuItems.length > 1) {
      _hiddenMenuItems ??= [];
      _hiddenMenuItems.addAll(menuItems.sublist(1));
      _secondWidget = getPopUpMenuButtons(_hiddenMenuItems);
    }

    return Row(children: [
      Expanded(child: _firstWidget ?? Container()),
      if (_secondWidget != null) Expanded(child: _secondWidget)
    ]);
  }
}
