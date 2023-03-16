import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class SwipeTile extends StatefulWidget {
  ///creates widget for right swipe options on list tile
  const SwipeTile(
      {Key? key,
      required this.child,
      required this.menuItems,
      this.state,
      this.onTap,
      this.id,
      this.theme})
      : super(key: key);

  final Widget child;

  final List<CometChatOption> menuItems;

  final dynamic state;

  final Function? onTap;

  final String? id;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  @override
  _SwipeTileState createState() => _SwipeTileState();
}

class _SwipeTileState extends State<SwipeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  late CometChatTheme? _theme;

  @override
  initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _theme = widget.theme ?? cometChatTheme;
  }

  @override
  dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int _length;
    if (widget.menuItems == null) {
      _length = 0;
    } else {
      _length = widget.menuItems.length;
    }

    final animation =
        Tween(begin: const Offset(0.0, 0.0), end: Offset(-0.2 * _length, 0.0))
            .animate(CurveTween(curve: Curves.decelerate).animate(_controller));

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
                            theme: _theme,
                          ),

                          // Row(
                          //     children: widget.menuItems.map((child) {
                          //   return Expanded(
                          //     child: child,
                          //   );
                          // }).toList()),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class SwipeTileOptions extends StatelessWidget {
  ///Default CometChat menu widget shows
  const SwipeTileOptions(
      {Key? key, required this.menuItems, this.id, this.theme})
      : super(key: key);

  /// List of menu items
  final List<CometChatOption> menuItems;

  final String? id;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  getFirstWidget(CometChatOption item) {
    return GestureDetector(
      key: UniqueKey(),
      onTap: () {
        performOnClick(item);
      },
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
              package: item.packageName,
              color: Colors.white,
              height: 24,
              width: 24,
            ),
            if (item.title != null)
              Text(
                item.title!,
                style: item.titleStyle ??
                    const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.fade,
              )
          ],
        ),
      ),
    );
  }

  getPopUpMenuButtons(
    List<CometChatOption> menuItems,CometChatTheme _theme
  ) {
    return PopupMenuButton<CometChatOption>(
      itemBuilder: (context) => menuItems
          .map((item) => PopupMenuItem<CometChatOption>(
                value: item,
                child: Text(
                  item.title ?? "",
                  style: TextStyle(color: _theme.palette.getAccent()).merge(item.titleStyle),
                ),
              ))
          .toList(),
      onSelected: (CometChatOption option) {
        performOnClick(option);
      },
      color: _theme.palette.mode == PaletteThemeModes.light
          ? _theme.palette.getBackground()
          : Color.alphaBlend(
              _theme.palette.getAccent200(), _theme.palette.getBackground()),
      icon: Icon(Icons.adaptive.more, color: _theme.palette.getAccent(),),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? _firstWidget;
    Widget? _secondWidget;
    Widget? _moreOptions;
    CometChatTheme _theme = theme ?? cometChatTheme;
    List<CometChatOption>? _hiddenMenuItems;
    if (menuItems.isNotEmpty) {
      _firstWidget = getFirstWidget(menuItems.first);
    }
    if (menuItems.length > 1) {
      _secondWidget = getFirstWidget(menuItems[1]);
    }
    if (menuItems.length > 2) {
      _hiddenMenuItems ??= [];
      _hiddenMenuItems.addAll(menuItems.sublist(2));
      _moreOptions = getPopUpMenuButtons(_hiddenMenuItems,_theme);
    }

    return Row(children: [
      Expanded(child: _firstWidget ?? Container()),
      if (_secondWidget != null) Expanded(child: _secondWidget),
      if (_moreOptions != null) Expanded(child: _moreOptions)
    ]);
  }

  performOnClick(CometChatOption option) {
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
