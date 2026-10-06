import 'package:flutter/material.dart';
import '../../../../../../cometchat_uikit_shared.dart';

///[SwipeTile] is stacked widget which can take a child widget as input
///upon pressing that child widget down and sliding it to the left menu items are revealed
class SwipeTile extends StatefulWidget {
  ///creates widget for right swipe options on list tile
  const SwipeTile({
    super.key,
    required this.child,
    required this.menuItems,
    this.state,
    this.onTap,
    this.id,
  });

  final Widget child;

  final List<CometChatOption> menuItems;

  final dynamic state;

  final Function? onTap;

  final String? id;

  @override
  State<SwipeTile> createState() => _SwipeTileState();
}

class _SwipeTileState extends State<SwipeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int length = widget.menuItems.length;

    final animation = Tween(
      begin: const Offset(0.0, 0.0),
      end: Offset(-0.2 * length, 0.0),
    ).animate(CurveTween(curve: Curves.decelerate).animate(_controller));

    return GestureDetector(
      onTap: widget.onTap != null
          ? () {
              widget.onTap!();
            }
          : null,
      onHorizontalDragUpdate: (inputData) {
        setState(() {
          _controller.value -= (inputData.primaryDelta! / context.size!.width);
        });
      },
      onHorizontalDragEnd: (inputData) {
        if (inputData.primaryVelocity! > 500) {
          _controller.animateTo(0.0);
        } else if (_controller.value >= 0.5 ||
            inputData.primaryVelocity! < -500) {
          _controller.animateTo(1.0);
        } else {
          _controller.animateTo(0.0);
        }
      },
      child: Stack(
        children: <Widget>[
          SlideTransition(position: animation, child: widget.child),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraint) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Stack(
                      children: <Widget>[
                        Positioned(
                          right: -1,
                          top: 0,
                          bottom: 0,
                          width: constraint.maxWidth * animation.value.dx * -1,
                          child: SwipeTileOptions(
                            menuItems: widget.menuItems,
                            id: widget.id,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SwipeTileOptions extends StatelessWidget {
  ///Default CometChat menu widget shows
  const SwipeTileOptions({super.key, required this.menuItems, this.id});

  /// List of menu items
  final List<CometChatOption> menuItems;

  final String? id;

  GestureDetector getFirstWidget(CometChatOption item) {
    return GestureDetector(
      key: UniqueKey(),
      onTap: () {
        performOnClick(item);
      },
      // The label sits inside the detector rather than around it so this
      // public method keeps returning a GestureDetector. The label, the button
      // role and the tap action still merge into one semantics node.
      child: Semantics(
        button: true,
        label: item.title ?? '',
        child: Container(
          color: item.backgroundColor,
          height: 70,
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                item.icon!,
                excludeFromSemantics: true,
                package: item.packageName,
                color: Colors.white,
                height: 24,
                width: 24,
              ),
              if (item.title != null)
                Text(
                  item.title!,
                  style:
                      item.titleStyle ??
                      const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuButton<CometChatOption> getPopUpMenuButtons(
    List<CometChatOption> menuItems,
  ) {
    return PopupMenuButton<CometChatOption>(
      itemBuilder: (context) => menuItems
          .map(
            (item) => PopupMenuItem<CometChatOption>(
              value: item,
              child: Text(item.title ?? "", style: item.titleStyle),
            ),
          )
          .toList(),
      onSelected: (CometChatOption option) {
        performOnClick(option);
      },
      icon: Icon(Icons.adaptive.more),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? firstWidget;
    Widget? secondWidget;
    Widget? moreOptions;
    List<CometChatOption>? hiddenMenuItems;
    if (menuItems.isNotEmpty) {
      firstWidget = getFirstWidget(menuItems.first);
    }
    if (menuItems.length > 1) {
      secondWidget = getFirstWidget(menuItems[1]);
    }
    if (menuItems.length > 2) {
      hiddenMenuItems ??= [];
      hiddenMenuItems.addAll(menuItems.sublist(2));
      moreOptions = getPopUpMenuButtons(hiddenMenuItems);
    }

    return Row(
      children: [
        Expanded(child: firstWidget ?? Container()),
        if (secondWidget != null) Expanded(child: secondWidget),
        if (moreOptions != null) Expanded(child: moreOptions),
      ],
    );
  }

  void performOnClick(CometChatOption option) {
    // if (option is CometChatGroupMemberOption<CometChatGroupMembersController>) {
    //   if (option.onClick2 != null) {
    //     option.onClick2!();
    //   }
    // } else if (option.action != null) {
    //   option.action!(option.id, id ?? "");
    // }

    if (option.onClick != null) {
      option.onClick!();
    }
  }
}
