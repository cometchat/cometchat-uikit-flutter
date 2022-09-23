import 'package:flutter/material.dart';
import '../../../flutter_chat_ui_kit.dart';

class CometChatListBase extends StatelessWidget {
  /// Creates a widget that that gives Cometchat ListBase UI
  const CometChatListBase(
      {Key? key,
      this.style = const ListBaseStyle(),
      this.backIcon,
      required this.title,
      this.hideSearch = false,
      this.searchBoxIcon,
      required this.container,
      this.showBackButton = false,
      this.onSearch,
      this.menuOptions,
      this.placeholder,
      this.searchText,
      this.theme})
      : super(key: key);

  ///[style] styling properties
  final ListBaseStyle style;

  ///[showBackButton] show back button
  final bool? showBackButton;

  ///[placeholder] hint text to be shown in search box
  final String? placeholder;

  ///[backIcon] back button icon
  final Widget? backIcon;

  ///[title] title string
  final String title;

  ///[hideSearch] show the search box
  final bool? hideSearch;

  ///[searchBoxIcon] search box prefix icon
  final Widget? searchBoxIcon;

  ///[container] listview of users
  final Widget container;

  ///[menuOptions] list of widgets options to be shown
  final List<Widget>? menuOptions;

  ///[onSearch] onSearch callback
  final void Function(String val)? onSearch;

  ///[searchText] initial text to be searched
  final String? searchText;

  final CometChatTheme? theme;

  Widget? getBackButton(context, CometChatTheme _theme) {
    Widget? _backButton;
    if (showBackButton != null && showBackButton == true) {
      _backButton = IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: backIcon ??
              Image.asset(
                "assets/icons/back.png",
                package: UIConstants.packageName,
                color: _theme.palette.getAccent(),
              ));
    }
    return _backButton;
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(gradient: style.gradient),
        child: Scaffold(
          //appbar with back button and menu options
          appBar: AppBar(
            elevation: 0,
            toolbarHeight: 56,
            title: Text(
              title,
              style: style.titleStyle ??
                  TextStyle(
                      fontWeight: _theme.typography.title1.fontWeight,
                      fontSize: _theme.typography.title1.fontSize,
                      color: _theme.palette.getAccent()),
            ),
            backgroundColor: style.background ?? _theme.palette.getBackground(),
            leading: getBackButton(context, _theme),
            automaticallyImplyLeading: showBackButton ?? false,
            actions: menuOptions ?? [],
          ),

          backgroundColor: style.background ?? _theme.palette.getBackground(),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //-----------------------------------
              //----------show search box----------
              if (hideSearch == false)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SizedBox(
                    height: 42,
                    child: Center(
                      child: TextField(
                        //--------------------------------------
                        //----------on search callback----------
                        controller: TextEditingController(text: searchText),
                        onChanged: onSearch,
                        style: style.searchTextStyle ??
                            TextStyle(
                                color: _theme.palette.getAccent(),
                                fontSize: _theme.typography.body.fontSize,
                                fontWeight: _theme.typography.body.fontWeight),

                        //-----------------------------------------
                        //----------search box decoration----------
                        decoration: InputDecoration(
                            contentPadding: const EdgeInsets.all(0),
                            hintText:
                                placeholder ?? Translations.of(context).search,
                            prefixIcon: searchBoxIcon ??
                                Icon(
                                  Icons.search,
                                  color: _theme.palette.getAccent600(),
                                ),
                            hintStyle: style.searchTextStyle ??
                                TextStyle(
                                    color: _theme.palette.getAccent600(),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400),

                            //-------------------------------------
                            //----------search box border----------
                            focusedBorder: OutlineInputBorder(
                                borderSide: style.searchBorderColor == null
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: style.searchBorderColor!,
                                        width: style.searchBorderWidth ?? 1),
                                borderRadius: BorderRadius.circular(
                                    style.searchBoxRadius ?? 28)),
                            enabledBorder: OutlineInputBorder(
                                borderSide: style.searchBorderColor == null
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: style.searchBorderColor!,
                                        width: style.searchBorderWidth ?? 1),
                                borderRadius: BorderRadius.circular(
                                    style.searchBoxRadius ?? 28)),
                            border: OutlineInputBorder(
                                borderSide: style.searchBorderColor == null
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: style.searchBorderColor!,
                                        width: style.searchBorderWidth ?? 1),
                                borderRadius: BorderRadius.circular(
                                    style.searchBoxRadius ?? 28)),

                            //-----------------------------------------
                            //----------search box fill color----------
                            fillColor: style.searchBoxBackground ??
                                _theme.palette.getAccent100(),
                            filled: true),
                      ),
                    ),
                  ),
                ),

              //--------------------------------
              //----------showing list----------
              Expanded(child: container)
            ],
          ),
        ),
      ),
    );
  }
}

class ListBaseStyle {
  const ListBaseStyle(
      {this.background,
      this.titleStyle,
      this.searchBoxRadius,
      this.searchTextStyle,
      this.searchBorderWidth,
      this.searchBorderColor,
      this.searchBoxBackground,
      this.gradient});

  ///[background] background color of screen
  final Color? background;

  ///[titleStyle] TextStyle for tvTitle
  final TextStyle? titleStyle;

  ///[searchBoxRadius] search box radius
  final double? searchBoxRadius;

  ///[searchTextStyle] TextStyle for search text
  final TextStyle? searchTextStyle;

  ///[searchBorderWidth] border width for search box
  final double? searchBorderWidth;

  ///[searchBorderColor] border color for search box
  final Color? searchBorderColor;

  ///[searchBoxBackground] background color for search box
  final Color? searchBoxBackground;

  final Gradient? gradient;
}
